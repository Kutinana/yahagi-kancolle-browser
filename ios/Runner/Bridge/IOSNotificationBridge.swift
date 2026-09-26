import Flutter
import UIKit
import UserNotifications

/// Handles local notification requests on iOS using UserNotifications.framework.
final class IOSNotificationBridge: NSObject, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()

  override init() {
    super.init()
    center.delegate = self
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "applySnapshot":
      guard let snapshot = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_argument", message: "Snapshot dictionary required", details: nil))
        return
      }
      applySnapshot(snapshot, result: result)

    case "getCapabilities":
      center.getNotificationSettings { settings in
        let granted = settings.authorizationStatus == .authorized ||
                      settings.authorizationStatus == .provisional
        DispatchQueue.main.async {
          result([
            "notificationsGranted": granted,
            "exactAlarmsGranted": true,
            "channelsEnabled": true
          ])
        }
      }

    case "requestNotificationPermission":
      center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        DispatchQueue.main.async {
          if let error = error {
            NSLog("[IOSNotificationBridge] Request authorization error: \(error)")
          }
          result(granted)
        }
      }

    case "requestExactAlarmPermission":
      // iOS has no separate exact alarm permission; local notifications trigger precisely.
      result(nil)

    case "openSystemNotificationSettings":
      DispatchQueue.main.async {
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func applySnapshot(_ snapshot: [String: Any], result: @escaping FlutterResult) {
    let canceledKeys = snapshot["canceledKeys"] as? [String] ?? []
    if !canceledKeys.isEmpty {
      center.removePendingNotificationRequests(withIdentifiers: canceledKeys)
      center.removeDeliveredNotifications(withIdentifiers: canceledKeys)
    }

    var scheduledExact = 0
    var failures: [String] = []
    let group = DispatchGroup()

    // 1. Scheduled alarms
    if let scheduled = snapshot["scheduled"] as? [[String: Any]] {
      for item in scheduled {
        guard let key = item["key"] as? String,
              let title = item["title"] as? String,
              let body = item["body"] as? String else {
          continue
        }

        let triggerEpochMs: Double? = {
          if let ms = item["triggerTimeEpochMs"] as? Double { return ms }
          if let ms = item["triggerTimeEpochMs"] as? Int64 { return Double(ms) }
          if let ms = item["triggerTimeEpochMs"] as? Int { return Double(ms) }
          return nil
        }()

        guard let epochMs = triggerEpochMs else { continue }
        let delaySeconds = max(1.0, (epochMs / 1000.0) - Date().timeIntervalSince1970)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
        let request = UNNotificationRequest(identifier: key, content: content, trigger: trigger)

        group.enter()
        center.add(request) { error in
          if let error = error {
            failures.append("\(key): \(error.localizedDescription)")
          } else {
            scheduledExact += 1
          }
          group.leave()
        }
      }
    }

    // 2. Immediate alerts
    if let immediate = snapshot["immediate"] as? [[String: Any]] {
      for item in immediate {
        guard let key = item["key"] as? String,
              let title = item["title"] as? String,
              let body = item["body"] as? String else {
          continue
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: key, content: content, trigger: nil)
        group.enter()
        center.add(request) { error in
          if let error = error {
            failures.append("\(key): \(error.localizedDescription)")
          } else {
            scheduledExact += 1
          }
          group.leave()
        }
      }
    }

    group.notify(queue: .main) {
      result([
        "scheduledExact": scheduledExact,
        "scheduledInexact": 0,
        "canceled": canceledKeys.count,
        "failures": failures
      ])
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
