import Flutter
import UIKit
import WebKit

/// Installs iOS-only WebKit safeguards before the first real navigation.
final class IOSWebViewRuntimeBridge {
  private weak var viewController: UIViewController?
  private weak var webView: WKWebView?
  private let channel: FlutterMethodChannel
  private var navigationDelegate: IOSGameNavigationDelegate?
  private var generation = 0

  init(viewController: UIViewController, channel: FlutterMethodChannel) {
    self.viewController = viewController
    self.channel = channel
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "prepare":
      generation += 1
      prepare(generation: generation, attempts: 20, result: result)
    case "dispose":
      generation += 1
      detach()
      result(nil)
    case "stopLoading":
      generation += 1
      webView?.stopLoading()
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func prepare(generation: Int, attempts: Int, result: @escaping FlutterResult) {
    guard generation == self.generation else {
      result(
        FlutterError(code: "cancelled", message: "WebView preparation cancelled.", details: nil))
      return
    }
    guard let root = viewController?.view, let target = findWebView(root),
      let delegate = target.navigationDelegate
    else {
      guard attempts > 0 else {
        result(
          FlutterError(
            code: "webview_not_found", message: "Game WebView is not ready.", details: nil))
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
        prepare(generation: generation, attempts: attempts - 1, result: result)
      }
      return
    }
    if target === webView, delegate === navigationDelegate {
      result(nil)
      return
    }
    detach()
    let proxy = IOSGameNavigationDelegate(
      delegate: delegate,
      httpFailure: { [weak self] url, status in
        self?.channel.invokeMethod(
          "onMainFrameHttpError",
          arguments: [
            "url": url.absoluteString, "statusCode": status,
          ])
      }
    ) { [weak self] in
      self?.report("webContentProcessTerminated")
    }
    navigationDelegate = proxy
    webView = target
    target.navigationDelegate = proxy
    result(nil)
  }

  private func detach() {
    if let target = webView {
      // Do not navigate to a blank page during teardown: that creates more
      // navigation/authentication callbacks while the Dart engine is stopping.
      target.stopLoading()
      if target.navigationDelegate === navigationDelegate { target.navigationDelegate = nil }
    }
    webView = nil
    navigationDelegate = nil
  }

  private func report(_ state: String) {
    channel.invokeMethod("onRuntimeEvent", arguments: ["state": state])
  }

  private func findWebView(_ view: UIView) -> WKWebView? {
    if let webView = view as? WKWebView { return webView }
    for child in view.subviews {
      if let found = findWebView(child) { return found }
    }
    return nil
  }
}

/// The app uses system authentication handling, with no custom HTTP auth or
/// certificate override. Complete it natively so engine/scene teardown cannot
/// strand WebKit's completion handler in a pending Pigeon response to Dart.
private final class IOSGameNavigationDelegate: NSObject, WKNavigationDelegate {
  private weak var delegate: WKNavigationDelegate?
  private let processTerminated: () -> Void
  private let httpFailure: (URL, Int) -> Void

  init(
    delegate: WKNavigationDelegate, httpFailure: @escaping (URL, Int) -> Void,
    processTerminated: @escaping () -> Void
  ) {
    self.delegate = delegate
    self.processTerminated = processTerminated
    self.httpFailure = httpFailure
  }

  func webView(
    _ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
    completionHandler:
      @escaping @MainActor (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    completionHandler(.performDefaultHandling, nil)
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    delegate?.webView?(webView, didStartProvisionalNavigation: navigation)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    delegate?.webView?(webView, didFinish: navigation)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    delegate?.webView?(webView, didFail: navigation, withError: error)
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    delegate?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    processTerminated()
    delegate?.webViewWebContentProcessDidTerminate?(webView)
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
  ) {
    if delegate?.webView?(
      webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler) == nil
    {
      decisionHandler(.cancel)
    }
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
    decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void
  ) {
    if navigationResponse.isForMainFrame,
      let response = navigationResponse.response as? HTTPURLResponse,
      response.statusCode >= 400, let url = response.url
    {
      httpFailure(url, response.statusCode)
    }
    if delegate?.webView?(
      webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler) == nil
    {
      decisionHandler(.cancel)
    }
  }
}
