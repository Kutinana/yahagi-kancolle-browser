import AlarmKit
import CryptoKit
import Foundation
import SwiftUI

struct IOSCompletionAlarm {
  let identifier: String
  let date: Date
  let title: String

  // Including the deadline and title makes changed slots and languages replace old alarms.
  var id: UUID {
    let identity = "\(identifier)\n\(Int64(date.timeIntervalSince1970 * 1000))\n\(title)"
    let digest = SHA256.hash(data: Data(identity.utf8))
    return NSUUID(uuidBytes: Array(digest.prefix(16))) as UUID
  }
}

@available(iOS 26.0, *)
private struct TimerAlarmMetadata: AlarmMetadata {}

/// Fixed-date completion alarms share the same account and timer snapshot as local reminders.
@available(iOS 26.0, *)
enum IOSAlarmPreview {
  private static let enabledKey = "yahagi.alarmPreview.enabled"
  private static let memberKey = "yahagi.alarmPreview.scheduledMember"
  private static let manager = AlarmManager.shared

  static var authorized: Bool { manager.authorizationState == .authorized }

  static func settings() -> [String: Any] {
    [
      "supported": true,
      "enabled": UserDefaults.standard.bool(forKey: enabledKey) && authorized,
      "denied": manager.authorizationState == .denied,
    ]
  }

  @MainActor static func setEnabled(_ enabled: Bool) async throws {
    var allowed = authorized
    if enabled && manager.authorizationState == .notDetermined {
      allowed = try await manager.requestAuthorization() == .authorized
    }
    UserDefaults.standard.set(enabled && allowed, forKey: enabledKey)
  }

  @MainActor static func reconcile(
    timers: [IOSCompletionAlarm], member: Int, audible: Bool, locale: String
  ) async throws -> Set<String> {
    let defaults = UserDefaults.standard
    let previousMember = defaults.integer(forKey: memberKey)
    let active = defaults.bool(forKey: enabledKey) && authorized && audible && member > 0
    guard authorized, active || previousMember > 0 else { return [] }
    let desired = active ? timers : []
    guard !desired.isEmpty || previousMember > 0 else { return [] }
    let ids = Set(desired.map(\.id))
    let installed: [Alarm]
    do {
      installed = try manager.alarms
    } catch {
      // Before our first system alarm, every item can safely use local delivery.
      guard previousMember == 0 else { throw error }
      NSLog("[Yahagi AlarmKit] Could not read scheduled alarms: %@", error.localizedDescription)
      return []
    }
    for alarm in installed where !ids.contains(alarm.id) {
      // Once due, the shared snapshot drops the timer. Let the user stop the ringing alarm.
      if active && member == previousMember && alarm.state == .alerting { continue }
      try manager.cancel(id: alarm.id)
    }
    defaults.set(active ? member : 0, forKey: memberKey)
    let existing = Set(installed.map(\.id))
    var handled = Set<String>()
    for timer in desired {
      if !existing.contains(timer.id) {
        guard timer.date > Date() else { continue }
        let title: LocalizedStringResource = "\(timer.title)"
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
          alert = AlarmPresentation.Alert(title: title)
        } else {
          let label: String
          switch locale {
          case "ja": label = "停止"
          case "ko": label = "중지"
          case "en": label = "Stop"
          default: label = "停止"
          }
          let stop = AlarmButton(text: "\(label)", textColor: .white, systemImageName: "stop.fill")
          alert = AlarmPresentation.Alert(title: title, stopButton: stop)
        }
        let attributes = AlarmAttributes<TimerAlarmMetadata>(
          presentation: AlarmPresentation(alert: alert), tintColor: .teal)
        do {
          _ = try await manager.schedule(id: timer.id, configuration: .alarm(
            schedule: .fixed(timer.date), attributes: attributes))
        } catch {
          // Includes the system alarm limit. Ordinary local delivery remains available for this item.
          NSLog("[Yahagi AlarmKit] Could not schedule completion alarm: %@", error.localizedDescription)
          continue
        }
      }
      handled.insert(timer.identifier)
    }
    return handled
  }
}
