import Flutter
import Foundation
import WebKit

/// Swift native bridge for WKWebView API capture on iOS and macOS.
///
/// Implements `WKScriptMessageHandler` to intercept `/kcsapi/` responses injected by
/// `nativeGameCaptureScript` at document start via `WKUserScript`.
@objc public class IOSGameCaptureBridge: NSObject, WKScriptMessageHandler {
  private static let messageObjectName = "YahagiNativeCapture"

  private weak var viewController: UIViewController?
  private let channel: FlutterMethodChannel

  private var isCaptureEnabled = false
  private var userScript: WKUserScript?
  private weak var contentController: WKUserContentController?
  private var sequence: Int64 = 0
  private let isoFormatter = ISO8601DateFormatter()

  @objc public init(viewController: UIViewController?, channel: FlutterMethodChannel) {
    self.viewController = viewController
    self.channel = channel
    super.init()
  }

  @objc public func isSupported() -> Bool {
    return true
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

  @objc public func configure(
    enabled: Bool,
    script: String,
    contentController: WKUserContentController?,
    completion: @escaping (FlutterError?) -> Void
  ) {
    if let cc = contentController {
      self.contentController = cc
    }
    self.isCaptureEnabled = enabled

    let (targetContentController, targetWebView) = resolveUserContentController()

    guard let userContentController = targetContentController else {
      completion(
        FlutterError(
          code: "webview_not_found", message: "WKUserContentController is not available.",
          details: nil))
      return
    }

    // Clean up any existing handler or user script
    userContentController.removeScriptMessageHandler(
      forName: IOSGameCaptureBridge.messageObjectName)
    if userScript != nil {
      userContentController.removeAllUserScripts()
      userScript = nil
    }

    if !enabled {
      completion(nil)
      return
    }

    if script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      completion(
        FlutterError(
          code: "invalid_capture_script", message: "Capture script must not be empty.", details: nil
        ))
      return
    }

    // Register script message handler
    userContentController.add(self, name: IOSGameCaptureBridge.messageObjectName)

    // Adapt the shared Android-oriented script without changing shared Dart
    // sources. WKWebView exposes script handlers under window.webkit, and
    // does not support the Android ArrayBuffer bridge protocol.
    let bridgeAdapter = """
      window.YahagiNativeCapture = {
        postMessage: function(payload) {
          window.webkit.messageHandlers.YahagiNativeCapture.postMessage(payload);
        }
      };
      """
    let platformScript = script.replacingOccurrences(
      of: "__YAHAGI_BINARY_CAPTURE_ENABLED__",
      with: "false"
    )
    let injectedSource = bridgeAdapter + "\n" + platformScript

    // Inject script at document start
    let injectedScript = WKUserScript(
      source: injectedSource,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false
    )
    userContentController.addUserScript(injectedScript)
    self.userScript = injectedScript

    // Evaluate immediately in active WKWebView if attached
    targetWebView?.evaluateJavaScript(injectedSource, completionHandler: nil)

    completion(nil)
  }

  // MARK: - WKScriptMessageHandler
  public func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    guard isCaptureEnabled, message.name == IOSGameCaptureBridge.messageObjectName else {
      return
    }

    guard let messageBody = message.body as? String else {
      return
    }

    // Parse and validate payload structure before forwarding to Dart
    guard let data = messageBody.data(using: .utf8),
      let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
      var eventMap = jsonObject as? [String: Any]
    else {
      return
    }

    let version = (eventMap["version"] as? NSNumber)?.intValue ?? -1
    let kind = eventMap["kind"] as? String ?? ""
    let method = eventMap["method"] as? String ?? ""
    let path = eventMap["path"] as? String ?? ""
    let transport = eventMap["transport"] as? String ?? ""
    let responseBody = eventMap["responseBody"] as? String
    let requestParams = eventMap["requestParams"] as? [String: Any]
    let statusCode = (eventMap["statusCode"] as? NSNumber)?.intValue

    guard version == 1,
      kind == "kcsapi_response",
      method == "GET" || method == "POST",
      path.hasPrefix("/kcsapi/"),
      transport == "xhr" || transport == "fetch",
      responseBody != nil,
      requestParams != nil,
      let code = statusCode, code >= 0 && code <= 599
    else {
      return
    }

    // Determine source origin from frameInfo or webView URL
    var sourceOrigin = ""
    let secOrigin = message.frameInfo.securityOrigin
    if !secOrigin.host.isEmpty {
      let scheme = secOrigin.protocol.isEmpty ? "https" : secOrigin.protocol
      let port = secOrigin.port
      if port == 0 || (scheme == "http" && port == 80) || (scheme == "https" && port == 443) {
        sourceOrigin = "\(scheme)://\(secOrigin.host)"
      } else {
        sourceOrigin = "\(scheme)://\(secOrigin.host):\(port)"
      }
    }
    if sourceOrigin.isEmpty, let webViewUrl = message.webView?.url {
      if let scheme = webViewUrl.scheme, let host = webViewUrl.host {
        if let port = webViewUrl.port {
          sourceOrigin = "\(scheme)://\(host):\(port)"
        } else {
          sourceOrigin = "\(scheme)://\(host)"
        }
      }
    }
    if sourceOrigin.isEmpty {
      sourceOrigin = "https://play.games.dmm.com"
    }

    sequence += 1
    let capturedAt = isoFormatter.string(from: Date())

    eventMap["sourceOrigin"] = sourceOrigin
    eventMap["capturedAt"] = capturedAt
    eventMap["sequence"] = sequence

    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod("onCaptureEvent", arguments: eventMap)
    }
  }

  @objc public func dispose() {
    if let controller = contentController {
      controller.removeScriptMessageHandler(forName: IOSGameCaptureBridge.messageObjectName)
      controller.removeAllUserScripts()
    }
    userScript = nil
    contentController = nil
  }
}
