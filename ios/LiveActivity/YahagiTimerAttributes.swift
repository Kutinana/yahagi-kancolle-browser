import ActivityKit
import Foundation

/// Shared by the host and its widget extension; contains no Flutter dependencies.
@available(iOS 16.1, *)
struct YahagiTimerAttributes: ActivityAttributes {
  struct TimerItem: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let deadline: Date
    let capturedAt: Date

    var slot: String { id.split(separator: ":").last.map(String.init) ?? "" }
    var detail: String {
      (title.components(separatedBy: "·").last ?? title).trimmingCharacters(in: .whitespaces)
    }
    var interval: ClosedRange<Date> { min(capturedAt, deadline.addingTimeInterval(-1))...deadline }
  }

  struct ContentState: Codable, Hashable {
    let kind: String
    let locale: String
    let timers: [TimerItem]

    // The host refreshes this selection at deadlines while it has runtime.
    // System timer text continues ticking without running the host or extension.
    func nearest(at date: Date) -> TimerItem? {
      timers.filter { $0.deadline > date }.min { $0.deadline < $1.deadline }
        ?? timers.max { $0.deadline < $1.deadline }
    }
  }

  let memberId: Int
}

struct YahagiTimerStrings {
  let locale: String

  private func text(_ zh: String, _ hant: String, _ ja: String, _ ko: String, _ en: String) -> String {
    switch locale {
    case "zh_Hant": return hant
    case "ja": return ja
    case "ko": return ko
    case "en": return en
    default: return zh
    }
  }

  func title(_ kind: String) -> String {
    switch kind {
    case "repair": return text("入渠修复", "入渠修復", "入渠修理", "입거 수리", "Dock repairs")
    case "construction": return text("建造", "建造", "建造", "건조", "Construction")
    default: return text("远征", "遠征", "遠征", "원정", "Expeditions")
    }
  }

  func slot(_ value: String, kind: String) -> String {
    kind == "expedition"
      ? text("第\(value)舰队", "第\(value)艦隊", "第\(value)艦隊", "제\(value)함대", "Fleet \(value)")
      : text("船坞 #\(value)", "船塢 #\(value)", "ドック #\(value)", "도크 #\(value)", "Dock #\(value)")
  }

  var expired: String {
    text("有计时已到期 · 返回游戏更新", "有計時已到期 · 返回遊戲更新", "タイマー終了 · ゲームで更新", "타이머 종료 · 게임에서 갱신", "Timer elapsed · Open game to refresh")
  }
}
