import ActivityKit
import Flutter
import UIKit

/// iOS-only preferences and rendering adapter for the existing notification snapshot.
/// No background modes, network service, or game-state calculation are introduced.
final class IOSLiveActivityBridge: NSObject {
  private let defaults = UserDefaults.standard
  private let enabledKey = "yahagi.ios.liveActivity.enabled"
  private let kindKey = "yahagi.ios.liveActivity.kind"
  private let kinds = ["expedition", "repair", "construction"]
  private var snapshot: [String: Any]?
  private var revision = 0
  private var updating = false
  private var replies: [FlutterResult] = []
  private var lastActivityId: String?
  private var lastSelection: String?
  private var lastNearestId: String?
  private var suppressedSelection: String?
  private var deadlineTimer: Timer?
  private var lastError: String?

  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(resumed), name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    deadlineTimer?.invalidate()
  }

  private var enabled: Bool { defaults.bool(forKey: enabledKey) }
  private var kind: String {
    let value = defaults.string(forKey: kindKey) ?? "expedition"
    return kinds.contains(value) ? value : "expedition"
  }

  private var supported: Bool {
    if #available(iOS 17.0, *) { return true }
    if #available(iOS 16.1, *) { return UIDevice.current.userInterfaceIdiom == .phone }
    return false
  }

  private func options() -> [String: Any] {
    var authorized = false
    if #available(iOS 16.1, *), supported {
      authorized = ActivityAuthorizationInfo().areActivitiesEnabled
    }
    return [
      "supported": supported, "authorized": authorized, "enabled": enabled, "kind": kind,
      "error": lastError ?? "",
    ]
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getLiveActivitySettings" { result(options()); return }
    guard let args = call.arguments as? [String: Any],
      let nextEnabled = args["enabled"] as? Bool,
      let nextKind = args["kind"] as? String, kinds.contains(nextKind)
    else {
      result(FlutterError(code: "invalid_argument", message: "Invalid Live Activity settings", details: nil))
      return
    }
    if nextEnabled != enabled || nextKind != kind { suppressedSelection = nil }
    defaults.set(nextEnabled, forKey: enabledKey)
    defaults.set(nextKind, forKey: kindKey)
    replies.append(result)
    refresh()
  }

  func applySnapshot(_ value: [String: Any]) {
    snapshot = value
    refresh()
  }

  @objc private func resumed() { refresh() }
  @objc private func timerFired(_ timer: Timer) { refresh() }

  private func refresh() {
    revision += 1
    guard !updating else { return }
    updating = true
    Task { @MainActor in
      var applied = -1
      while applied != self.revision {
        applied = self.revision
        self.lastError = nil
        if #available(iOS 16.1, *), self.supported {
          do { try await self.reconcile() }
          catch {
            self.lastError = error.localizedDescription
            NSLog("[Yahagi Live Activity] %@", error.localizedDescription)
          }
        }
      }
      self.updating = false
      let replies = self.replies
      self.replies.removeAll()
      replies.forEach { $0(self.options()) }
    }
  }

  @available(iOS 16.1, *)
  @MainActor private func reconcile() async throws {
    deadlineTimer?.invalidate()
    deadlineTimer = nil
    // Settings can be opened before the first game snapshot arrives. Leave any
    // restored activity alone until account state is known, unless disabled.
    if snapshot == nil && enabled { return }
    let snapshot = snapshot ?? [:]
    let presentation = snapshot["presentation"] as? [String: Any] ?? [:]
    let member = (snapshot["memberId"] as? NSNumber)?.intValue ?? 0
    let selection = "\(member):\(kind)"
    if lastSelection != selection {
      lastSelection = selection
      lastActivityId = nil
      lastNearestId = nil
      suppressedSelection = nil
    }
    let now = Date()
    let captured = (snapshot["updatedAtEpochMs"] as? NSNumber)?.doubleValue ?? now.timeIntervalSince1970 * 1000
    let capturedAt = Date(timeIntervalSince1970: captured.isFinite ? captured / 1000 : now.timeIntervalSince1970)
    let raw = snapshot["ongoingItems"] as? [[String: Any]] ?? []
    var seen = Set<String>()
    let timers: [YahagiTimerAttributes.TimerItem] = raw.compactMap { item in
      guard item["type"] as? String == kind,
        item["clockMode"] as? String == "countdown",
        let id = item["id"] as? String, id.hasPrefix(kind + ":"), id.utf8.count <= 32,
        let title = item["title"] as? String,
        let value = (item["targetEpochMs"] as? NSNumber)?.doubleValue,
        value.isFinite, value > 0, value / 1000 <= Date.distantFuture.timeIntervalSince1970,
        seen.insert(id).inserted
      else { return nil }
      return YahagiTimerAttributes.TimerItem(
        id: id, title: String(decoding: title.utf8.prefix(160), as: UTF8.self),
        deadline: Date(timeIntervalSince1970: value / 1000), capturedAt: capturedAt)
    }.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    // The game exposes at most four slots per supported type. Bound payloads
    // defensively so a malformed snapshot cannot exceed ActivityKit's 4 KB limit.
    let locale = presentation["localeCode"] as? String ?? "zh"
    let state = YahagiTimerAttributes.ContentState(
      kind: kind, locale: ["zh", "zh_Hant", "ja", "ko", "en"].contains(locale) ? locale : "zh",
      timers: Array(timers.prefix(4)))
    let canDisplay = enabled && member > 0 && presentation["enabled"] as? Bool == true
      && ActivityAuthorizationInfo().areActivitiesEnabled && !state.timers.isEmpty
    let activities = Activity<YahagiTimerAttributes>.activities
    var current: Activity<YahagiTimerAttributes>?
    for activity in activities {
      if canDisplay && activity.attributes.memberId == member && current == nil
        && isActive(activity) {
        current = activity
      } else {
        await end(activity)
      }
    }
    guard canDisplay else {
      lastActivityId = nil
      lastNearestId = nil
      suppressedSelection = nil
      return
    }
    if current == nil && lastActivityId != nil {
      // Respect a person's dismissal instead of recreating the card on every
      // game packet. Toggling the feature or changing its type enables it again.
      suppressedSelection = selection
      lastActivityId = nil
      lastNearestId = nil
    }
    let future = state.timers.filter { $0.deadline > now }.map(\.deadline)
    guard let nextDeadline = future.min() else {
      if let current { await end(current, state: state) }
      lastActivityId = nil
      lastNearestId = nil
      return
    }
    let nearestId = state.nearest(at: now)?.id
    if let current {
      // capturedAt only sets the timer's lower bound. Retain the old bound to
      // avoid emitting ActivityKit updates for otherwise identical snapshots.
      let existing = if #available(iOS 16.2, *) { current.content.state } else { current.contentState }
      let unchanged = existing.kind == state.kind && existing.locale == state.locale
        && existing.timers.map { [$0.id, $0.title, String($0.deadline.timeIntervalSince1970)] }
          == state.timers.map { [$0.id, $0.title, String($0.deadline.timeIntervalSince1970)] }
      // A deadline refresh also changes which timer the Dynamic Island selects.
      if !unchanged || lastNearestId != nearestId || isStale(current) {
        if #available(iOS 16.2, *) {
          await current.update(ActivityContent(state: state, staleDate: nextDeadline))
        } else {
          await current.update(using: state)
        }
      }
      lastActivityId = current.id
    } else if suppressedSelection != selection && UIApplication.shared.applicationState == .active {
      let attributes = YahagiTimerAttributes(memberId: member)
      let activity: Activity<YahagiTimerAttributes>
      if #available(iOS 16.2, *) {
        activity = try Activity.request(
          attributes: attributes, content: ActivityContent(state: state, staleDate: nextDeadline), pushType: nil)
      } else {
        activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
      }
      lastActivityId = activity.id
    }
    lastNearestId = nearestId
    if UIApplication.shared.applicationState == .active {
      scheduleDeadline(nextDeadline)
    }
  }

  @MainActor private func scheduleDeadline(_ date: Date) {
    let timer = Timer(
      timeInterval: max(0.1, date.timeIntervalSinceNow), target: self,
      selector: #selector(timerFired(_:)), userInfo: nil, repeats: false)
    deadlineTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  @available(iOS 16.1, *)
  private func isStale(_ activity: Activity<YahagiTimerAttributes>) -> Bool {
    if #available(iOS 16.2, *) { return activity.activityState == .stale }
    return false
  }

  @available(iOS 16.1, *)
  private func isActive(_ activity: Activity<YahagiTimerAttributes>) -> Bool {
    activity.activityState == .active || isStale(activity)
  }

  @available(iOS 16.1, *)
  private func end(_ activity: Activity<YahagiTimerAttributes>, state: YahagiTimerAttributes.ContentState? = nil) async {
    if #available(iOS 16.2, *) {
      await activity.end(state.map { ActivityContent(state: $0, staleDate: nil) }, dismissalPolicy: .immediate)
    } else {
      await activity.end(using: state, dismissalPolicy: .immediate)
    }
  }
}
