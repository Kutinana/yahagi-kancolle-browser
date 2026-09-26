import Flutter
import UIKit

/// Swift native bridge for battle damage alert haptic feedback on iOS.
///
/// Communicates via `app.yahagi.kancollebrowser/battle_damage_alert` MethodChannel.
/// Triggers Taptic Engine haptic patterns based on damage severity (moderate vs heavy).
@objc public class IOSBattleDamageAlertBridge: NSObject {
  private let channel: FlutterMethodChannel

  @objc public init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "alert":
      guard let args = call.arguments as? [String: Any],
        let severity = args["severity"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_argument",
            message: "Missing 'severity' argument.",
            details: nil
          ))
        return
      }

      DispatchQueue.main.async {
        if severity == "heavy" {
          let generator = UINotificationFeedbackGenerator()
          generator.prepare()
          generator.notificationOccurred(.warning)
        } else {
          let generator = UIImpactFeedbackGenerator(style: .medium)
          generator.prepare()
          generator.impactOccurred()
        }
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
