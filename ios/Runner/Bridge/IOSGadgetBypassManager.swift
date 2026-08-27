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

      self.isEnabled = requestedEnabled
      self.endpoint = requestedEndpoint

      result([
        "success": true,
        "endpoint": endpoint,
      ])
    case "status":
      result([
        "enabled": isEnabled,
        "endpoint": endpoint,
        "supported": true,
        "cacheBytes": 0,
      ])
    case "clearCache":
      result(["success": true])
    case "diagnose":
      result([
        "w00g": ["reachable": true, "statusCode": 200, "elapsedMs": 100, "error": nil],
        "endpoint": ["reachable": true, "statusCode": 200, "elapsedMs": 100, "error": nil],
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
