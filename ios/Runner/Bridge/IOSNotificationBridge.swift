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
  private var latestSnapshot: [String: Any]?
  private var alarmAuthorization = false
  private var applying = false
  private var requestingPermission = false
  private var permissionReplies: [FlutterResult] = []

  override init() {
    super.init()
    center.delegate = self
    if #available(iOS 26.0, *) {
      alarmAuthorization = IOSAlarmPreview.authorized
      NotificationCenter.default.addObserver(self, selector: #selector(refreshAlarmAuthorization),
        name: UIApplication.didBecomeActiveNotification, object: nil)
    }
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
      latestSnapshot = snapshot
      snapshots.append((snapshot, result))
      applyNextSnapshot()
    case "getCapabilities":
      center.getNotificationSettings { settings in
        DispatchQueue.main.async {
          result([
            "notificationsGranted": self.isGranted(settings.authorizationStatus),
            "canRequestNotifications": settings.authorizationStatus == .notDetermined,
          ])
        }
      }
    case "getAlarmPreview", "setAlarmPreview":
      guard #available(iOS 26.0, *) else { result(["supported": false]); return }
      if call.method == "getAlarmPreview" { result(IOSAlarmPreview.settings()); return }
      guard let enabled = call.arguments as? Bool else {
        result(FlutterError(code: "invalid_argument", message: "Expected a switch value", details: nil))
        return
      }
      Task { @MainActor in
        do {
          try await IOSAlarmPreview.setEnabled(enabled)
          self.alarmAuthorization = IOSAlarmPreview.authorized
          self.replayTimers { error in
            var settings = IOSAlarmPreview.settings()
            settings["syncFailed"] = error != nil
            result(settings)
          }
        } catch {
          result(FlutterError(code: "alarm_authorization", message: error.localizedDescription, details: nil))
        }
      }
    case "openAlarmPreviewSettings":
      if #available(iOS 26.0, *), let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "getLiveActivitySettings", "setLiveActivitySettings":
      liveActivities.handle(call, result: result)
    case "requestNotificationPermission":
      requestPermission(result: result)
    case "requestExactAlarmPermission":
      result(nil)
    case "openSystemNotificationSettings":
      let settingsURL: String
      if #available(iOS 16.0, *) {
        settingsURL = UIApplication.openNotificationSettingsURLString
      } else {
        settingsURL = UIApplication.openSettingsURLString
      }
      if let url = URL(string: settingsURL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func refreshAlarmAuthorization() {
    guard #available(iOS 26.0, *), alarmAuthorization != IOSAlarmPreview.authorized else { return }
    alarmAuthorization = IOSAlarmPreview.authorized
    replayTimers { _ in }
  }

  private func replayTimers(completion: @escaping (FlutterError?) -> Void) {
    guard var snapshot = latestSnapshot else { completion(nil); return }
    snapshot["immediateAlerts"] = []
    snapshots.append((snapshot, { response in
      if let failures = (response as? [String: Any])?["failures"] as? [String], !failures.isEmpty {
        completion(FlutterError(code: "timer_delivery", message: failures.joined(separator: ", "), details: nil))
      } else {
        completion(response as? FlutterError)
      }
    }))
    applyNextSnapshot()
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
        Task { @MainActor in
          await self.apply(snapshot, pending: pending, delivered: delivered, result: result)
        }
      }
    }
  }

  @MainActor private func apply(
    _ snapshot: [String: Any], pending: [UNNotificationRequest],
    delivered: [UNNotification], result: @escaping FlutterResult
  ) async {
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
    var completionAlarms: [IOSCompletionAlarm] = []
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
      if alarm["stage"] as? String == "complete",
        let kind = alarm["type"] as? String, ["expedition", "repair", "construction"].contains(kind) {
        completionAlarms.append(IOSCompletionAlarm(identifier: id,
          date: Date(timeIntervalSince1970: fireAt / 1000), title: content.title))
      }
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

    var failures: [String] = []
    var systemAlarms = Set<String>()
    if #available(iOS 26.0, *) {
      do {
        systemAlarms = try await IOSAlarmPreview.reconcile(timers: completionAlarms,
          member: member, audible: enabled && sound, locale: presentation["localeCode"] as? String ?? "zh")
        requests.removeAll { systemAlarms.contains($0.identifier) }
        desiredAlarmIDs.subtract(systemAlarms)
      } catch {
        // Keep the current delivery route for these completions until the coordinator retries.
        // Independent alerts and early reminders can still be delivered in this snapshot.
        let uncertain = Set(completionAlarms.map(\.identifier))
        requests.removeAll { uncertain.contains($0.identifier) }
        failures.append("AlarmKit: \(error.localizedDescription)")
      }
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
    var scheduled = systemAlarms.count
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
