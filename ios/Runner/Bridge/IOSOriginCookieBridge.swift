import Flutter
import WebKit

/// Bridge for origin-specific cookie management (e.g. clearing OOI cookies) on iOS.
final class IOSOriginCookieBridge: NSObject {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "clearCookiesForOrigin":
      guard let args = call.arguments as? [String: Any],
            let origin = args["origin"] as? String else {
        result(FlutterError(code: "invalid_argument", message: "Expected origin argument", details: nil))
        return
      }

      guard origin == "https://ooi.moe" else {
        result(FlutterError(code: "invalid_origin", message: "Only the OOI origin may be cleared", details: nil))
        return
      }

      let cookieStore = WKWebsiteDataStore.default().httpCookieStore
      cookieStore.getAllCookies { cookies in
        let group = DispatchGroup()
        for cookie in cookies {
          if cookie.domain.contains("ooi.moe") {
            group.enter()
            cookieStore.delete(cookie) {
              group.leave()
            }
          }
        }
        group.notify(queue: .main) {
          result(nil)
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
