import Flutter
import Foundation
import WebKit

/// Swift native bridge for reloading the inner game frame on iOS.
///
/// Communicates via `app.yahagi.kancollebrowser/game_frame_reload` MethodChannel.
/// Injects a listener into all subframes of the game WKWebView (with `forMainFrameOnly: false`)
/// to find `#htmlWrap` or `#game_frame` and reload it without reloading the parent DMM web page.
@objc public class IOSGameFrameReloadBridge: NSObject, WKScriptMessageHandler {
  private static let messageObjectName = "YahagiGameFrameReload"

  private weak var viewController: UIViewController?
  private let channel: FlutterMethodChannel

  private weak var contentController: WKUserContentController?
  private weak var attachedWebView: WKWebView?
  private var userScript: WKUserScript?
  private var isConfigured = false
  private var hasTargetFrame = false
  private var pendingReloadResult: ((String) -> Void)?

  @objc public init(viewController: UIViewController?, channel: FlutterMethodChannel) {
    self.viewController = viewController
    self.channel = channel
    super.init()
  }

  public func isSupported() -> Bool {
    return true
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      configure(result: result)
    case "reload":
      reload(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configure(result: @escaping FlutterResult) {
    let (targetContentController, targetWebView) = resolveUserContentController()
    guard let userContentController = targetContentController else {
      result(nil)
      return
    }

    self.attachedWebView = targetWebView

    // Clean up previous registration if any
    userContentController.removeScriptMessageHandler(forName: Self.messageObjectName)
    if userScript != nil {
      userScript = nil
    }

    let handlerProxy = WeakFrameReloadScriptMessageHandler(delegate: self)
    userContentController.add(handlerProxy, name: Self.messageObjectName)

    let scriptSource = buildInjectedScript()
    let injectedScript = WKUserScript(
      source: scriptSource,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false
    )
    userContentController.addUserScript(injectedScript)
    self.userScript = injectedScript
    self.isConfigured = true

    result(nil)
  }

  private func reload(result: @escaping FlutterResult) {
    guard let targetWebView = attachedWebView ?? findWKWebViewInApp() else {
      result("blocked")
      return
    }

    // Direct JavaScript evaluation in WKWebView as fast path, broadcasting to all nested frames
    let reloadScript = """
      (function() {
        var reloaded = false;
        function tryReload(w) {
          try {
            var htmlWrap = w.document.getElementById('htmlWrap');
            if (htmlWrap) {
              try {
                htmlWrap.contentWindow.location.reload();
                reloaded = true;
              } catch (_) {
                var s = htmlWrap.getAttribute('src');
                if (s) { htmlWrap.setAttribute('src', s); reloaded = true; }
              }
            }
            var gameFrame = w.document.getElementById('game_frame');
            if (gameFrame) {
              try {
                gameFrame.contentWindow.location.reload();
                reloaded = true;
              } catch (_) {
                var s2 = gameFrame.getAttribute('src');
                if (s2) { gameFrame.setAttribute('src', s2); reloaded = true; }
              }
            }
          } catch (_) {}
          try {
            w.postMessage({ type: 'yahagi_frame_reload' }, '*');
          } catch (_) {}
          for (var i = 0; i < w.frames.length; i++) {
            try { tryReload(w.frames[i]); } catch (_) {}
          }
        }
        tryReload(window);
        return reloaded ? 'reloaded' : 'attempted';
      })();
      """

    targetWebView.evaluateJavaScript(reloadScript) { [weak self] evalResult, error in
      if let resStr = evalResult as? String, resStr == "reloaded" {
        result("reloaded")
        return
      }

      // If direct access was blocked or still loading, await message handler or fallback
      self?.pendingReloadResult = { res in
        result(res)
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
        if let pending = self?.pendingReloadResult {
          self?.pendingReloadResult = nil
          pending("reloaded")
        }
      }
    }
  }

  private func buildInjectedScript() -> String {
    return """
      (() => {
        'use strict';
        if (window.__yahagiFrameReloadInstalled) return;
        window.__yahagiFrameReloadInstalled = true;

        const postBridgeMessage = (data) => {
          try {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(Self.messageObjectName)) {
              window.webkit.messageHandlers.\(Self.messageObjectName).postMessage(data);
            }
          } catch (_) {}
        };

        const checkTargetAvailability = () => {
          const game = document.getElementById('htmlWrap') || document.getElementById('game_frame');
          if (game) {
            postBridgeMessage({ kind: 'target', available: true });
          }
        };

        const doReload = () => {
          const game = document.getElementById('htmlWrap') || document.getElementById('game_frame');
          if (!game) return false;
          try {
            game.contentWindow.location.reload();
            postBridgeMessage({ kind: 'result', result: 'reloaded' });
            return true;
          } catch (_) {
            const src = game.getAttribute('src');
            if (src) {
              game.setAttribute('src', src);
              postBridgeMessage({ kind: 'result', result: 'reloaded' });
              return true;
            }
          }
          return false;
        };

        window.addEventListener('message', (event) => {
          try {
            const data = typeof event.data === 'string'
              ? JSON.parse(event.data)
              : event.data;
            if (data && data.type === 'yahagi_frame_reload') {
              doReload();
            }
          } catch (_) {}
        });

        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', checkTargetAvailability, { once: true });
        } else {
          checkTargetAvailability();
        }
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
    var resultStr: String?

    if let dict = message.body as? [String: Any] {
      kind = dict["kind"] as? String
      resultStr = dict["result"] as? String
    }

    if kind == "target" {
      self.hasTargetFrame = true
    } else if kind == "result" {
      if let pending = self.pendingReloadResult {
        self.pendingReloadResult = nil
        pending(resultStr ?? "reloaded")
      }
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
    pendingReloadResult = nil
  }
}

/// Helper proxy to prevent WKUserContentController from retaining WKScriptMessageHandler strongly.
private class WeakFrameReloadScriptMessageHandler: NSObject, WKScriptMessageHandler {
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
