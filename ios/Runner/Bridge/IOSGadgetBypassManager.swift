import Flutter
import Foundation
import WebKit

/// Swift native manager for OOG/W00g gadget bypass and static asset caching on iOS and macOS.
@objc public class IOSGadgetBypassManager: NSObject {
  @objc public private(set) var isEnabled: Bool = false
  @objc public private(set) var endpoint: String =
    "https://raw.githubusercontent.com/poooi/poi/master/assets/js/gadget.js"

  @objc public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      guard let args = call.arguments as? [String: Any] else {
        result(["success": false, "error": "invalid_arguments"])
        return
      }
      let requestedEnabled = args["enabled"] as? Bool ?? false
      let requestedEndpoint = args["endpoint"] as? String ?? endpoint

      self.isEnabled = false
      self.endpoint = requestedEndpoint

      result([
        "success": !requestedEnabled,
        "endpoint": endpoint,
        "error": requestedEnabled ? "ios_unsupported" : "",
      ])
    case "status":
      result([
        "enabled": isEnabled,
        "endpoint": endpoint,
        "supported": false,
        "cacheBytes": 0,
      ])
    case "clearCache":
      result(["success": true])
    case "diagnose":
      result(FlutterError(code: "ios_unsupported", message: "Gadget resource interception is unavailable on iOS.", details: nil))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
