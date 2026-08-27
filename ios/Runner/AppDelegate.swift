import AVFoundation
import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let gameAudioChannel = "app.yahagi.kancollebrowser/game_audio"
  private static let gameCaptureChannel = "app.yahagi.kancollebrowser/game_capture"
  private static let scaleChannel = "app.webview/fixed_canvas_scaling"
  private static let proxyChannel = "app.yahagi.kancollebrowser/network_proxy"
  private static let gadgetBypassChannel = "app.yahagi.kancollebrowser/gadget_bypass"
  private static let screenAwakeChannel = "app.yahagi.kancollebrowser/screen_awake"
  private static let gameScreenshotChannel = "app.yahagi.kancollebrowser/game_screenshot"

  private var gameCaptureBridge: IOSGameCaptureBridge?
  private var proxyManager: IOSWebViewProxyManager?
  private var audioPort: IOSGameAudioPort?
  private var gadgetBypassManager: IOSGadgetBypassManager?
  private var isChannelsConfigured = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configure default AVAudioSession category
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .ambient, mode: .default, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      NSLog("[AppDelegate] Failed to set AVAudioSession category: \(error)")
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      setupChannels(controller: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

  func setupChannels(controller: FlutterViewController) {
    if isChannelsConfigured { return }
    isChannelsConfigured = true

    NSLog("[AppDelegate] Setting up Flutter MethodChannels...")

    // 1. Network Proxy MethodChannel
    let proxyChannel = FlutterMethodChannel(
      name: Self.proxyChannel, binaryMessenger: controller.binaryMessenger)
    let proxyManager = IOSWebViewProxyManager()
    self.proxyManager = proxyManager
    proxyChannel.setMethodCallHandler { call, result in
      proxyManager.handle(call, result: result)
    }

    // 2. Game Audio MethodChannel
    let audioChannel = FlutterMethodChannel(
      name: Self.gameAudioChannel, binaryMessenger: controller.binaryMessenger)
    let audioPort = IOSGameAudioPort(viewController: controller)
    self.audioPort = audioPort
    audioChannel.setMethodCallHandler { call, result in
      audioPort.handle(call, result: result)
    }

    // 3. Game API Capture MethodChannel
    let captureChannel = FlutterMethodChannel(
      name: Self.gameCaptureChannel, binaryMessenger: controller.binaryMessenger)
    let captureBridge = IOSGameCaptureBridge(viewController: controller, channel: captureChannel)
    self.gameCaptureBridge = captureBridge
    captureChannel.setMethodCallHandler { [weak captureBridge] call, result in
      switch call.method {
      case "isSupported":
        result(captureBridge?.isSupported() ?? true)
      case "configure":
        guard let args = call.arguments as? [String: Any],
          let enabled = args["enabled"] as? Bool,
          let script = args["script"] as? String
        else {
          result(
            FlutterError(
              code: "invalid_argument", message: "enabled and script are required.", details: nil))
          return
        }
        captureBridge?.configure(enabled: enabled, script: script, contentController: nil) {
          error in
          if let err = error {
            result(err)
          } else {
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 4. Fixed Canvas Scaling MethodChannel
    let scaleChannel = FlutterMethodChannel(
      name: Self.scaleChannel, binaryMessenger: controller.binaryMessenger)
    scaleChannel.setMethodCallHandler { call, result in
      if call.method == "bindFixedCanvas" {
        // Fixed canvas scaling handled by WKWebView JavaScript viewport on iOS
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // 5. Gadget Bypass MethodChannel
    let gadgetChannel = FlutterMethodChannel(
      name: Self.gadgetBypassChannel, binaryMessenger: controller.binaryMessenger)
    let gadgetBypass = IOSGadgetBypassManager()
    self.gadgetBypassManager = gadgetBypass
    gadgetChannel.setMethodCallHandler { call, result in
      gadgetBypass.handle(call, result: result)
    }

    // 6. Screen Awake MethodChannel
    let screenAwakeChannel = FlutterMethodChannel(
      name: Self.screenAwakeChannel, binaryMessenger: controller.binaryMessenger)
    screenAwakeChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "isEnabled":
        result(UIApplication.shared.isIdleTimerDisabled)
      case "setEnabled":
        guard let args = call.arguments as? [String: Any],
          let enabled = args["enabled"] as? Bool
        else {
          result(
            FlutterError(
              code: "invalid_argument", message: "enabled must be a boolean", details: nil))
          return
        }
        DispatchQueue.main.async {
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 7. Game Screenshot MethodChannel
    let screenshotChannel = FlutterMethodChannel(
      name: Self.gameScreenshotChannel, binaryMessenger: controller.binaryMessenger)
    screenshotChannel.setMethodCallHandler { [weak self, weak controller] call, result in
      if call.method == "captureWebView" {
        guard let root = controller?.view, let wkWebView = self?.findWKWebView(in: root) else {
          result(
            FlutterError(code: "webview_not_found", message: "WKWebView not found", details: nil))
          return
        }
        let config = WKSnapshotConfiguration()
        wkWebView.takeSnapshot(with: config) { image, error in
          guard let image = image, error == nil else {
            result(
              FlutterError(
                code: "snapshot_failed",
                message: error?.localizedDescription ?? "Failed to capture snapshot", details: nil))
            return
          }
          guard let data = image.pngData() else {
            result(
              FlutterError(
                code: "png_encoding_failed", message: "Failed to encode PNG", details: nil))
            return
          }
          let tempDir = FileManager.default.temporaryDirectory
          let fileName = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
          let fileURL = tempDir.appendingPathComponent(fileName)
          do {
            try data.write(to: fileURL)
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            result(fileURL.path)
          } catch {
            result(
              FlutterError(
                code: "file_write_failed", message: error.localizedDescription, details: nil))
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
