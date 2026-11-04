import Flutter
import Foundation
import UIKit
import WebKit

/// Fits the fixed game canvas to the mounted WKWebView's current bounds.
/// WebKit's visual viewport can lag a native resize, so use native dimensions
/// converted by the current page scale and recalibrate on viewport updates.
@objc public class IOSFixedCanvasScaleBridge: NSObject {
  private weak var viewController: UIViewController?
  private let channel: FlutterMethodChannel
  private weak var boundWebView: WKWebView?
  private var geometryReporter: IOSCanvasGeometryView?
  private var debounceWorkItem: DispatchWorkItem?
  private var bindingGeneration = 0
  private var wasPinchEnabled: Bool?
  private var isFixedCanvasActive = false
  private var contentWidth = 1200
  private var contentHeight = 720

  @objc public init(viewController: UIViewController?, channel: FlutterMethodChannel) {
    self.viewController = viewController
    self.channel = channel
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "bindFixedCanvas":
      let args = call.arguments as? [String: Any]
      contentWidth = max(1, (args?["contentWidth"] as? Int) ?? 1200)
      contentHeight = max(1, (args?["contentHeight"] as? Int) ?? 720)
      isFixedCanvasActive = true
      bindingGeneration += 1
      bind(generation: bindingGeneration, attempts: 40, result: result)
    case "releaseFixedCanvas":
      releaseFixedCanvas(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func bind(generation: Int, attempts: Int, result: @escaping FlutterResult) {
    guard isFixedCanvasActive, generation == bindingGeneration else {
      result(nil)
      return
    }
    guard let webView = resolveWebView() ?? boundWebView else {
      guard attempts > 0 else {
        result(FlutterError(code: "webview_not_ready", message: "Game viewport is not ready.", details: nil))
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
        guard let self = self else { result(nil); return }
        self.bind(generation: generation, attempts: attempts - 1, result: result)
      }
      return
    }
    attach(to: webView)
    // Offstage workspaces temporarily detach the live WebView. Acknowledge
    // the binding so page readiness does not time out while settings are open;
    // applyScale waits for real bounds and the reporter refits on remount.
    applyScale(to: webView)
    result(nil)
  }

  private func attach(to webView: WKWebView) {
    guard boundWebView !== webView else { return }
    geometryReporter?.removeFromSuperview()
    boundWebView = webView
    wasPinchEnabled = webView.scrollView.pinchGestureRecognizer?.isEnabled
    // UIKit can resize a platform view through setFrame without emitting KVO
    // for bounds. An autoresizing child receives its actual layout completion.
    let reporter = IOSCanvasGeometryView(frame: webView.bounds)
    reporter.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    reporter.isHidden = true
    reporter.isUserInteractionEnabled = false
    reporter.onLayout = { [weak self, weak webView] in
      guard let webView = webView else { return }
      self?.scheduleScaleUpdate(for: webView)
    }
    geometryReporter = reporter
    webView.addSubview(reporter)
  }

  private func scheduleScaleUpdate(for webView: WKWebView) {
    guard isFixedCanvasActive else { return }
    debounceWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self, weak webView] in
      guard let self = self, let webView = webView else { return }
      self.applyScale(to: webView)
    }
    debounceWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.025, execute: workItem)
  }

  private func applyScale(to webView: WKWebView) {
    guard isFixedCanvasActive, webView === boundWebView, webView.window != nil,
      webView.bounds.width > 0, webView.bounds.height > 0
    else { return }
    webView.isOpaque = false
    webView.backgroundColor = .black
    let scrollView = webView.scrollView
    scrollView.backgroundColor = .black
    // Lock the gesture, not zoomScale: WebKit owns the initial page scale and
    // updates it asynchronously when a fold changes the available size.
    scrollView.pinchGestureRecognizer?.isEnabled = false
    scrollView.isScrollEnabled = false
    scrollView.bounces = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.contentInset = .zero
    if scrollView.contentOffset != .zero {
      scrollView.setContentOffset(.zero, animated: false)
    }

    webView.evaluateJavaScript("""
      (() => {
        const key = '__yahagiIOSCanvasFit';
        let runtime = window[key];
        if (!runtime) {
          const apply = () => {
            if (document.querySelector('#ooi-page, #ooi-game, #flashWrap')) return;
            if (!document.querySelector('#game_frame, #game-container')) return;
            const pageScale = window.visualViewport?.scale || 1;
            const {width: nativeWidth, height: nativeHeight, contentWidth, contentHeight} = runtime.size;
            const width = nativeWidth / pageScale;
            const height = nativeHeight / pageScale;
            const scale = Math.min(width / contentWidth, height / contentHeight);
            let style = document.getElementById('__yahagi_ios_canvas_fit__');
            if (!style) {
              style = document.createElement('style');
              style.id = '__yahagi_ios_canvas_fit__';
              (document.head || document.documentElement).appendChild(style);
            }
            const css = `html,body{background:#000!important;}
              #game_frame,#game-container{
                left:${Math.max(0, (width - contentWidth * scale) / 2)}px!important;
                top:${Math.max(0, (height - contentHeight * scale) / 2)}px!important;
                transform:scale(${scale})!important;transform-origin:0 0!important;}`;
            if (style.textContent !== css) style.textContent = css;
          };
          const dispose = () => {
            window.removeEventListener('resize', apply);
            window.removeEventListener('load', apply);
            window.visualViewport?.removeEventListener('resize', apply);
            document.getElementById('__yahagi_ios_canvas_fit__')?.remove();
            delete window[key];
          };
          runtime = {apply, dispose};
          window[key] = runtime;
          window.addEventListener('resize', apply);
          window.addEventListener('load', apply);
          window.visualViewport?.addEventListener('resize', apply);
        }
        runtime.size = {
          width: \(webView.bounds.width), height: \(webView.bounds.height),
          contentWidth: \(contentWidth), contentHeight: \(contentHeight)
        };
        runtime.apply();
      })();
      """, completionHandler: nil)
  }

  private func releaseFixedCanvas(result: @escaping FlutterResult) {
    isFixedCanvasActive = false
    bindingGeneration += 1
    geometryReporter?.removeFromSuperview()
    geometryReporter = nil
    debounceWorkItem?.cancel()
    debounceWorkItem = nil
    if let webView = boundWebView {
      webView.evaluateJavaScript("window.__yahagiIOSCanvasFit?.dispose();", completionHandler: nil)
      let scrollView = webView.scrollView
      if let wasPinchEnabled = wasPinchEnabled {
        scrollView.pinchGestureRecognizer?.isEnabled = wasPinchEnabled
      }
      scrollView.contentInset = .zero
      scrollView.isScrollEnabled = true
      scrollView.bounces = true
      scrollView.showsVerticalScrollIndicator = true
      scrollView.showsHorizontalScrollIndicator = true
    }
    wasPinchEnabled = nil
    boundWebView = nil
    result(nil)
  }

  private func resolveWebView() -> WKWebView? {
    // Stay in this Flutter scene; another screen may have its own WKWebView.
    guard let root = viewController?.view else { return nil }
    return findWKWebView(in: root)
  }

  private func findWKWebView(in view: UIView) -> WKWebView? {
    if let webView = view as? WKWebView { return webView }
    for subview in view.subviews {
      if let found = findWKWebView(in: subview) { return found }
    }
    return nil
  }

  public func dispose() {
    releaseFixedCanvas { _ in }
  }
}

/// Follows the WKWebView through initial mounting, folds and sidebar resizing.
private final class IOSCanvasGeometryView: UIView {
  var onLayout: (() -> Void)?
  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    onLayout?()
  }
}
