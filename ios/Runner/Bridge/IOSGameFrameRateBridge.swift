import Flutter
import Foundation
import WebKit

/// Swift native bridge for frame rate management and high refresh rate unlocking on iOS.
///
/// Communicates via `app.yahagi.kancollebrowser/game_frame_rate` MethodChannel.
/// Injects a CreateJS/Ticker hook into all frames of the game WKWebView to toggle between
/// capped 30 FPS, capped 60 FPS, and unlocked ProMotion high refresh rate (up to 120 FPS).
@objc public class IOSGameFrameRateBridge: NSObject, WKScriptMessageHandler {
  private static let messageObjectName = "YahagiFrameRate"
  private static let sampleMaxAgeSeconds: TimeInterval = 3.0

  private weak var viewController: UIViewController?
  private let channel: FlutterMethodChannel

  private weak var contentController: WKUserContentController?
  private weak var attachedWebView: WKWebView?
  private var userScript: WKUserScript?
  private var currentTarget: String = "fps60"
  private var latestFps: Double?
  private var latestFpsAt: Date = Date.distantPast
  private var isConfigured = false

  @objc public init(viewController: UIViewController?, channel: FlutterMethodChannel) {
    self.viewController = viewController
    self.channel = channel
    super.init()
  }

  @objc public func isSupported() -> Bool {
    return true
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(isSupported())
    case "configure":
      guard let args = call.arguments as? [String: Any],
        let mode = args["mode"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_argument",
            message: "Missing 'mode' argument.",
            details: nil
          ))
        return
      }
      configure(mode: mode, result: result)
    case "applyTarget":
      guard let args = call.arguments as? [String: Any],
        let target = args["target"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_argument",
            message: "Missing 'target' argument.",
            details: nil
          ))
        return
      }
      applyTarget(target: target, result: result)
    case "measuredFps":
      if Date().timeIntervalSince(latestFpsAt) <= Self.sampleMaxAgeSeconds {
        result(latestFps)
      } else {
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configure(mode: String, result: @escaping FlutterResult) {
    let initialTarget: String = (mode == "stable30") ? "fps30" : "fps60"
    self.currentTarget = initialTarget

    let (targetContentController, targetWebView) = resolveUserContentController()
    guard let userContentController = targetContentController else {
      result(
        FlutterError(
          code: "webview_not_found",
          message: "WKWebView is not yet available.",
          details: nil
        ))
      return
    }

    self.attachedWebView = targetWebView

    // Clean up previous registration if any
    userContentController.removeScriptMessageHandler(forName: Self.messageObjectName)
    if let existingScript = userScript {
      userContentController.removeAllUserScripts()
      userScript = nil
    }

    // Register script message handler (wrapped in a weak proxy to avoid retain cycle)
    let handlerProxy = WeakScriptMessageHandler(delegate: self)
    userContentController.add(handlerProxy, name: Self.messageObjectName)

    let scriptSource = buildInjectedScript(initialTarget: initialTarget)
    let injectedScript = WKUserScript(
      source: scriptSource,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false
    )
    userContentController.addUserScript(injectedScript)
    self.userScript = injectedScript
    self.isConfigured = true

    // Evaluate broadcast immediately in case the game is already loaded
    broadcastTarget(initialTarget, in: targetWebView)

    result(nil)
  }

  private func applyTarget(target: String, result: @escaping FlutterResult) {
    guard target == "fps30" || target == "fps60" || target == "highRefresh" else {
      result(
        FlutterError(
          code: "invalid_frame_rate_target",
          message: "Unknown target: \(target)",
          details: nil
        ))
      return
    }

    self.currentTarget = target
    broadcastTarget(target, in: attachedWebView ?? findWKWebViewInApp())
    result(nil)
  }

  private func broadcastTarget(_ target: String, in webView: WKWebView?) {
    guard let targetWebView = webView ?? attachedWebView ?? findWKWebViewInApp() else { return }
    let broadcastScript = """
      (function() {
        function broadcast(win, msg) {
          try { win.postMessage(msg, '*'); } catch (_) {}
          try {
            for (var i = 0; i < win.frames.length; i++) {
              broadcast(win.frames[i], msg);
            }
          } catch (_) {}
        }
        broadcast(window, { type: 'yahagi_frame_rate', target: '\(target)' });
      })();
      """
    targetWebView.evaluateJavaScript(broadcastScript, completionHandler: nil)
  }

  private func buildInjectedScript(initialTarget: String) -> String {
    return """
      (() => {
        'use strict';
        if (window.__yahagiFrameRateBridgeInstalled) return;
        window.__yahagiFrameRateBridgeInstalled = true;

        let requestedTarget = '\(initialTarget)';

        const postBridgeMessage = (data) => {
          try {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(Self.messageObjectName)) {
              window.webkit.messageHandlers.\(Self.messageObjectName).postMessage(data);
            }
          } catch (_) {}
        };

        const applyTarget = () => {
          const ticker = window.createjs && window.createjs.Ticker;
          if (!ticker) return false;
          if (requestedTarget === 'highRefresh') {
            if (typeof ticker.RAF === 'undefined') return false;
            if (ticker.timingMode !== ticker.RAF) {
              ticker.timingMode = ticker.RAF;
            }
          } else if (requestedTarget === 'fps30') {
            if (ticker.framerate !== 30) ticker.framerate = 30;
            if (ticker.timingMode !== ticker.TIMEOUT) {
              ticker.timingMode = ticker.TIMEOUT;
            }
          } else {
            if (ticker.framerate !== 60) ticker.framerate = 60;
            const cappedMode = typeof ticker.RAF_SYNCHED !== 'undefined'
              ? ticker.RAF_SYNCHED
              : ticker.TIMEOUT;
            if (ticker.timingMode !== cappedMode) {
              ticker.timingMode = cappedMode;
            }
          }
          return true;
        };

        window.addEventListener('message', (event) => {
          try {
            const data = typeof event.data === 'string'
              ? JSON.parse(event.data)
              : event.data;
            if (data && data.type === 'yahagi_frame_rate' && (
              data.target === 'fps30' ||
              data.target === 'fps60' ||
              data.target === 'highRefresh'
            )) {
              requestedTarget = data.target;
              applyTarget();
            }
          } catch (_) {}
        });

        postBridgeMessage({ kind: 'ready' });

        window.setInterval(() => {
          if (!applyTarget()) return;
          const ticker = window.createjs && window.createjs.Ticker;
          if (!ticker || typeof ticker.getMeasuredFPS !== 'function') return;
          const fps = Number(ticker.getMeasuredFPS());
          if (Number.isFinite(fps) && fps >= 0) {
            postBridgeMessage({ kind: 'sample', fps: fps });
          }
        }, 1000);
      })();
      """
  }

  // MARK: - WKScriptMessageHandler
  public func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard message.name == Self.messageObjectName else { return }

    var kind: String?
    var fpsValue: Double?

    if let dict = message.body as? [String: Any] {
      kind = dict["kind"] as? String
      if let fps = dict["fps"] as? NSNumber {
        fpsValue = fps.doubleValue
      }
    } else if let jsonString = message.body as? String,
      let data = jsonString.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      kind = dict["kind"] as? String
      if let fps = dict["fps"] as? NSNumber {
        fpsValue = fps.doubleValue
      }
    }

    if kind == "sample", let fps = fpsValue, fps >= 0 {
      self.latestFps = fps
      self.latestFpsAt = Date()
    } else if kind == "ready" {
      // Newly loaded frame announced readiness: broadcast current target
      broadcastTarget(currentTarget, in: attachedWebView ?? findWKWebViewInApp())
    }
  }

  // MARK: - WKWebView Resolution
  private func resolveUserContentController() -> (WKUserContentController?, WKWebView?) {
    if let wkWebView = findWKWebViewInApp() {
      let ucc = wkWebView.configuration.userContentController
      self.contentController = ucc
      return (ucc, wkWebView)
    }
    if let controller = contentController {
      return (controller, nil)
    }
    return (nil, nil)
  }

  private func findWKWebView(in view: UIView) -> WKWebView? {
    if let wkWebView = view as? WKWebView {
      return wkWebView
    }
    for subview in view.subviews {
      if let found = findWKWebView(in: subview) {
        return found
      }
    }
    return nil
  }

  private func findWKWebViewInApp() -> WKWebView? {
    if let root = viewController?.view, let found = findWKWebView(in: root) {
      return found
    }
    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes {
        if let windowScene = scene as? UIWindowScene {
          for window in windowScene.windows {
            if let found = findWKWebView(in: window) {
              return found
            }
          }
        }
      }
    }
    for window in UIApplication.shared.windows {
      if let found = findWKWebView(in: window) {
        return found
      }
    }
    return nil
  }

  public func dispose() {
    contentController?.removeScriptMessageHandler(forName: Self.messageObjectName)
    contentController = nil
    attachedWebView = nil
    userScript = nil
    isConfigured = false
  }
}

/// Helper proxy to prevent WKUserContentController from retaining WKScriptMessageHandler strongly.
private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  private weak var delegate: WKScriptMessageHandler?

  init(delegate: WKScriptMessageHandler) {
    self.delegate = delegate
    super.init()
  }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    delegate?.userContentController(userContentController, didReceive: message)
  }
}
