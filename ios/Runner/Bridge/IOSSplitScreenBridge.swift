import Flutter
import UIKit

/// Reports the actual Duo window, independently of the requested layout mode.
final class IOSSplitScreenBridge {
  private weak var viewController: UIViewController?
  private let channel: FlutterMethodChannel
  private let reporter = IOSSplitScreenGeometryView()
  private var hingeIsOpen = false
  private var lastGeometry: NSDictionary?

  init(viewController: UIViewController, channel: FlutterMethodChannel) {
    self.viewController = viewController
    self.channel = channel
    reporter.isUserInteractionEnabled = false
    reporter.isAccessibilityElement = false
    reporter.isHidden = true
    reporter.frame = viewController.view.bounds
    reporter.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    reporter.onGeometryChanged = { [weak self] in self?.refresh() }
    viewController.view.addSubview(reporter)

    if #available(iOS 27.1, *) {
      viewController.view.addInteraction(
        UIHingeInteraction { [weak self] _, update in
          self?.hingeIsOpen = update.hinge.map {
            $0.status == .fullyOpen || $0.status == .partiallyOpen
          } ?? false
          self?.refresh()
        })
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "getGeometry" else {
      result(FlutterMethodNotImplemented)
      return
    }
    result(geometry())
  }

  private func geometry() -> [String: Any] {
    guard let view = viewController?.view else { return [:] }
    let size = view.bounds.size
    var payload: [String: Any] = [
      "width": size.width, "height": size.height,
      "isSplitScreen": false, "quarterTurns": 0,
    ]
    guard #available(iOS 27.1, *), hingeIsOpen,
      let scene = view.window?.windowScene
    else { return payload }

    let window = scene.effectiveGeometry.coordinateSpace.bounds
    let screen = scene.screen.bounds
    // A full-screen fold or the cover display must not enable this policy.
    // Use this scene's screen, rather than a model table or UIScreen.main.
    let split = window.width + 1 < screen.width && window.height > window.width
    payload["isSplitScreen"] = split
    payload["quarterTurns"] = split
      ? (scene.effectiveGeometry.interfaceOrientation == .landscapeRight ? 1 : 3) : 0
    return payload
  }

  func refresh() {
    let payload = geometry()
    let next = payload as NSDictionary
    guard next != lastGeometry else { return }
    lastGeometry = next
    channel.invokeMethod("geometryChanged", arguments: payload)
  }
}

private final class IOSSplitScreenGeometryView: UIView {
  var onGeometryChanged: (() -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    onGeometryChanged?()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onGeometryChanged?()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    onGeometryChanged?()
  }
}
