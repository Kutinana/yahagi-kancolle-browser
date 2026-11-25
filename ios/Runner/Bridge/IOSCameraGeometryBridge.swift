import Flutter
import UIKit

/// Maps the iPhone's camera-side system safe area into Flutter logical points.
/// No private notch dimensions or device-model tables are needed.
final class IOSCameraGeometryBridge {
  private weak var viewController: UIViewController?
  private let channel: FlutterMethodChannel
  private let reporter = IOSCameraGeometryView()
  private var lastGeometry: NSDictionary?

  init(viewController: UIViewController, channel: FlutterMethodChannel) {
    self.viewController = viewController
    self.channel = channel
    reporter.isUserInteractionEnabled = false
    reporter.isAccessibilityElement = false
    reporter.isHidden = true
    reporter.frame = viewController.view.bounds
    reporter.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    reporter.onGeometryChanged = { [weak self] in self?.publish() }
    viewController.view.addSubview(reporter)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "getGeometry" else {
      result(FlutterMethodNotImplemented)
      return
    }
    result(geometry())
  }

  private func geometry() -> [String: CGFloat] {
    guard let view = viewController?.view else { return [:] }
    let bounds = view.bounds
    var result: [String: CGFloat] = ["width": bounds.width, "height": bounds.height]
    guard let window = view.window, window.screen === UIScreen.main,
      view.traitCollection.userInterfaceIdiom == .phone,
      window.safeAreaInsets.bottom > 0,
      bounds.width > 0, bounds.height > 0
    else { return result }

    // Home-button phones have no bottom safe-area inset. On other iPhones,
    // transform the portrait screen's top midpoint to follow the camera through
    // both landscape orientations. Symmetric landscape safe-area insets alone
    // cannot tell which side actually contains the camera.
    let fixed = window.screen.fixedCoordinateSpace
    let camera = view.convert(CGPoint(x: fixed.bounds.midX, y: fixed.bounds.minY), from: fixed)
    let distances = [
      abs(camera.x - bounds.minX), abs(camera.y - bounds.minY),
      abs(camera.x - bounds.maxX), abs(camera.y - bounds.maxY),
    ]
    guard let nearest = distances.min(), nearest < 1,
      let edge = distances.firstIndex(of: nearest)
    else { return result }
    let safe = view.safeAreaInsets
    let depths = [safe.left, safe.top, safe.right, safe.bottom]
    let depth = depths[edge]
    guard depth > 0 else { return result }
    let band: CGRect
    switch edge {
    case 0: band = CGRect(x: 0, y: 0, width: depth, height: bounds.height)
    case 1: band = CGRect(x: 0, y: 0, width: bounds.width, height: depth)
    case 2: band = CGRect(x: bounds.width - depth, y: 0, width: depth, height: bounds.height)
    default: band = CGRect(x: 0, y: bounds.height - depth, width: bounds.width, height: depth)
    }
    result["x"] = band.minX
    result["y"] = band.minY
    result["bandWidth"] = band.width
    result["bandHeight"] = band.height
    return result
  }

  private func publish() {
    let payload = geometry()
    let next = payload as NSDictionary
    guard next != lastGeometry else { return }
    lastGeometry = next
    channel.invokeMethod("geometryChanged", arguments: payload)
  }
}

/// Receives UIKit's final safe-area/layout updates as well as Flutter metrics.
private final class IOSCameraGeometryView: UIView {
  var onGeometryChanged: (() -> Void)?
  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onGeometryChanged?()
  }
  override func layoutSubviews() {
    super.layoutSubviews()
    onGeometryChanged?()
  }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    onGeometryChanged?()
  }
}
