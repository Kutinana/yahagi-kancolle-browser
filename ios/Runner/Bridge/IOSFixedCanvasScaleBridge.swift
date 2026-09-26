import Flutter
import Foundation
import UIKit
import WebKit

/// Native bridge for fixed canvas scaling on iOS WKWebView.
///
/// Communicates via `app.webview/fixed_canvas_scaling` MethodChannel.
/// Provides native `pageZoom` scaling, viewport centering via `contentInset`,
/// and gesture/scroll locking to guarantee stability during sidebar resize animations
/// and avoid WebKit canvas compositing layer drops.
@objc public class IOSFixedCanvasScaleBridge: NSObject {
  private weak var viewController: UIViewController?
  private let channel: FlutterMethodChannel

  private weak var boundWebView: WKWebView?
  private var boundsObservation: NSKeyValueObservation?
  private var debounceWorkItem: DispatchWorkItem?

  private var isFixedCanvasActive = false
  private var contentWidth: Int = 1200
  private var contentHeight: Int = 720
  private var lastAppliedScale: CGFloat?

  @objc public init(viewController: UIViewController?, channel: FlutterMethodChannel) {
    self.viewController = viewController
    self.channel = channel
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "bindFixedCanvas":
      let args = call.arguments as? [String: Any]
      let width = (args?["contentWidth"] as? Int) ?? 1200
      let height = (args?["contentHeight"] as? Int) ?? 720
      bindFixedCanvas(contentWidth: width, contentHeight: height, result: result)
    case "releaseFixedCanvas":
      releaseFixedCanvas(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func bindFixedCanvas(
    contentWidth: Int,
    contentHeight: Int,
    result: @escaping FlutterResult
  ) {
    self.isFixedCanvasActive = true
    self.contentWidth = contentWidth
    self.contentHeight = contentHeight

    guard let webView = boundWebView ?? resolveWebView() else {
      // If the WKWebView is still mounting into the Flutter view hierarchy,
      // retry shortly on the main runloop.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
        guard let self = self, self.isFixedCanvasActive else { return }
        if let delayedWebView = self.resolveWebView() {
          self.attach(to: delayedWebView)
          self.applyScale(to: delayedWebView, force: true)
        }
      }
      result(nil)
      return
    }

    attach(to: webView)
    applyScale(to: webView, force: true)
    result(nil)
  }

  private func attach(to webView: WKWebView) {
    if boundWebView !== webView {
      boundsObservation?.invalidate()
      boundsObservation = nil
      boundWebView = webView

      boundsObservation = webView.observe(\.bounds, options: [.new]) { [weak self] wv, _ in
        self?.scheduleScaleUpdate(for: wv)
      }
    }
  }

  private func scheduleScaleUpdate(for webView: WKWebView) {
    guard isFixedCanvasActive else { return }
    debounceWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self, weak webView] in
      guard let self = self, let wv = webView, self.isFixedCanvasActive else { return }
      self.applyScale(to: wv, force: false)
    }
    debounceWorkItem = workItem
    // Debounce by 25ms to gracefully coalesce rapid bounds updates during Flutter sidebar animations
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.025, execute: workItem)
  }

  private func applyScale(to webView: WKWebView, force: Bool = false) {
    guard isFixedCanvasActive else { return }

    // Ensure solid dark background on all layers
    webView.isOpaque = false
    webView.backgroundColor = .black
    webView.scrollView.backgroundColor = .black

    let scrollView = webView.scrollView
    scrollView.minimumZoomScale = 1.0
    scrollView.maximumZoomScale = 1.0
    if scrollView.zoomScale != 1.0 {
      scrollView.setZoomScale(1.0, animated: false)
    }
    scrollView.isScrollEnabled = false
    scrollView.bounces = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    if #available(iOS 11.0, *) {
      scrollView.contentInsetAdjustmentBehavior = .never
    }
    scrollView.contentInset = .zero
    if scrollView.contentOffset != .zero {
      scrollView.setContentOffset(.zero, animated: false)
    }
  }

  private func releaseFixedCanvas(result: @escaping FlutterResult) {
    isFixedCanvasActive = false
    boundsObservation?.invalidate()
    boundsObservation = nil
    debounceWorkItem?.cancel()
    debounceWorkItem = nil
    lastAppliedScale = nil

    if let webView = boundWebView ?? resolveWebView() {
      if #available(iOS 14.0, *) {
        webView.pageZoom = 1.0
      }
      let scrollView = webView.scrollView
      scrollView.contentInset = .zero
      scrollView.minimumZoomScale = 1.0
      scrollView.maximumZoomScale = 5.0
      scrollView.isScrollEnabled = true
      scrollView.bounces = true
      scrollView.showsVerticalScrollIndicator = true
      scrollView.showsHorizontalScrollIndicator = true
    }

    boundWebView = nil
    result(nil)
  }

  private func resolveWebView() -> WKWebView? {
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

  public func dispose() {
    releaseFixedCanvas { _ in }
  }
}
