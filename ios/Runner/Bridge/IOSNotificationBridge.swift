import Flutter
import UIKit
import UserNotifications

/// Adapts the shared full-snapshot notification contract to UserNotifications.
final class IOSNotificationBridge: NSObject, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  private let liveActivities = IOSLiveActivityBridge()
  private let alarmPrefix = "yahagi.alarm:"
  private let alertPrefix = "yahagi.alert:"
  private let deliveredKey = "yahagi.notifications.delivered.v1"
  private var snapshots: [([String: Any], FlutterResult)] = []
  private var applying = false
  private var requestingPermission = false
  private var permissionReplies: [FlutterResult] = []

  override init() {
    super.init()
    center.delegate = self
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "applySnapshot":
      guard let snapshot = call.arguments as? [String: Any],
        (snapshot["schemaVersion"] as? NSNumber)?.intValue == 1
      else {
        result(FlutterError(code: "invalid_argument", message: "Invalid notification snapshot", details: nil))
        return
      }
      snapshots.append((snapshot, result))
      applyNextSnapshot()
    case "getCapabilities":
      center.getNotificationSettings { settings in
        DispatchQueue.main.async {
          result([
            "notificationsGranted": self.isGranted(settings.authorizationStatus),
            "exactAlarmsGranted": true,
            "channelsEnabled": settings.alertSetting == .enabled,
          ])
        }
      }
    case "getLiveActivitySettings", "setLiveActivitySettings":
      liveActivities.handle(call, result: result)
    case "requestNotificationPermission":
      requestPermission(result: result)
    case "requestExactAlarmPermission":
      result(nil)
    case "openSystemNotificationSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func isGranted(_ status: UNAuthorizationStatus) -> Bool {
    status == .authorized || status == .provisional || status == .ephemeral
  }

  /// Startup and manual requests share one prompt. Denial is never re-prompted.
  private func requestPermission(result: @escaping FlutterResult) {
    permissionReplies.append(result)
    guard !requestingPermission else { return }
    requestingPermission = true
    center.getNotificationSettings { settings in
      if settings.authorizationStatus == .notDetermined {
        self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
          DispatchQueue.main.async { self.finishPermissionRequest(granted) }
        }
      } else {
        DispatchQueue.main.async {
          self.finishPermissionRequest(self.isGranted(settings.authorizationStatus))
        }
      }
    }
  }

  private func finishPermissionRequest(_ granted: Bool) {
    let replies = permissionReplies
    permissionReplies.removeAll()
    requestingPermission = false
    replies.forEach { $0(granted) }
  }

  private func applyNextSnapshot() {
    guard !applying, !snapshots.isEmpty else { return }
    applying = true
    let (snapshot, result) = snapshots.removeFirst()
    center.getPendingNotificationRequests { pending in
      self.center.getDeliveredNotifications { delivered in
        DispatchQueue.main.async {
          self.apply(snapshot, pending: pending, delivered: delivered, result: result)
        }
      }
    }
  }

  private func apply(
    _ snapshot: [String: Any], pending: [UNNotificationRequest],
    delivered: [UNNotification], result: @escaping FlutterResult
  ) {
    liveActivities.applySnapshot(snapshot)
    let presentation = snapshot["presentation"] as? [String: Any] ?? [:]
    let member = (snapshot["memberId"] as? NSNumber)?.intValue ?? 0
    let enabled = presentation["enabled"] as? Bool == true && member > 0
    let sound = presentation["sound"] as? Bool == true
    let now = Date().timeIntervalSince1970 * 1000
    let memberAlarmPrefix = "\(alarmPrefix)\(member):"
    let memberAlertPrefix = "\(alertPrefix)\(member):"
    let alarms = enabled ? snapshot["alarms"] as? [[String: Any]] ?? [] : []
    let alerts = enabled ? snapshot["immediateAlerts"] as? [[String: Any]] ?? [] : []
    var requests: [UNNotificationRequest] = []
    var immediateKeys: [String: String] = [:]
    var desiredAlarmIDs = Set<String>()
    var history = UserDefaults.standard.dictionary(forKey: deliveredKey) as? [String: Double] ?? [:]
    history = history.filter { now - $0.value < 7 * 24 * 60 * 60 * 1000 }

    for alarm in alarms {
      guard let key = alarm["key"] as? String,
        let fireAt = (alarm["triggerTimeEpochMs"] as? NSNumber)?.doubleValue,
        fireAt.isFinite, fireAt > now,
        let content = content(alarm, sound: sound)
      else { continue }
      let id = memberAlarmPrefix + key
      guard desiredAlarmIDs.insert(id).inserted else { continue }
      let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: max(1, (fireAt - now) / 1000), repeats: false)
      requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
    for alert in alerts {
      guard let key = alert["key"] as? String,
        let occurred = (alert["occurredAtEpochMs"] as? NSNumber)?.doubleValue,
        occurred.isFinite, now - occurred <= 60_000, occurred <= now + 1000,
        let content = content(alert, sound: sound)
      else { continue }
      let id = memberAlertPrefix + key
      guard history[id] == nil, immediateKeys[id] == nil else { continue }
      immediateKeys[id] = key
      requests.append(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    // Snapshots describe the complete desired state, rather than cancellation deltas.
    let canceled = pending.map(\.identifier).filter {
      ($0.hasPrefix(alarmPrefix) && !desiredAlarmIDs.contains($0)) ||
        ($0.hasPrefix(alertPrefix) && (!enabled || !$0.hasPrefix(memberAlertPrefix)))
    }
    center.removePendingNotificationRequests(withIdentifiers: canceled)
    let staleDelivered = delivered.map { $0.request.identifier }.filter {
      ($0.hasPrefix(alarmPrefix) || $0.hasPrefix(alertPrefix)) &&
        (!enabled || (!$0.hasPrefix(memberAlarmPrefix) && !$0.hasPrefix(memberAlertPrefix)))
    }
    center.removeDeliveredNotifications(withIdentifiers: staleDelivered)
    var scheduled = 0
    var failures: [String] = []
    let group = DispatchGroup()
    for request in requests {
      group.enter()
      center.add(request) { error in
        DispatchQueue.main.async {
          if let error = error {
            failures.append("\(request.identifier): \(error.localizedDescription)")
          } else {
            scheduled += 1
            if immediateKeys[request.identifier] != nil { history[request.identifier] = now }
          }
          group.leave()
        }
      }
    }
    group.notify(queue: .main) {
      UserDefaults.standard.set(history, forKey: self.deliveredKey)
      result([
        "scheduledExact": scheduled, "scheduledInexact": 0,
        "canceled": canceled.count, "failures": failures,
      ])
      self.applying = false
      self.applyNextSnapshot()
    }
  }

  private func content(_ item: [String: Any], sound: Bool) -> UNMutableNotificationContent? {
    guard let title = item["title"] as? String, let body = item["body"] as? String else { return nil }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = sound ? .default : nil
    return content
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    var options: UNNotificationPresentationOptions = [.banner, .list]
    if notification.request.content.sound != nil { options.insert(.sound) }
    completionHandler(options)
  }
}
