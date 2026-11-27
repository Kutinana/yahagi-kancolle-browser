import ActivityKit
import SwiftUI
import WidgetKit

@main
struct YahagiTimerWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: YahagiTimerAttributes.self) { context in
      TimerCard(state: context.state, isStale: stale(context))
        .padding(14)
        .activityBackgroundTint(Color(red: 0.07, green: 0.13, blue: 0.19))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let nearest = context.state.nearest(at: Date())
      let strings = YahagiTimerStrings(locale: context.state.locale)
      let icon = Image(systemName: symbol(context.state.kind))
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.cyan)
        .accessibilityLabel(Text(strings.title(context.state.kind)))
      return DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          TimerCard(state: context.state, isStale: stale(context))
        }
      } compactLeading: {
        icon
      } compactTrailing: {
        if let nearest {
          CompactIslandCountdown(item: nearest)
        }
      } minimal: {
        if let nearest {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) {
              icon
              NarrowIslandCountdown(item: nearest)
            }
            NarrowIslandCountdown(item: nearest)
          }
        } else {
          icon
        }
      }
      .contentMargins(.leading, 6, for: .compactLeading)
      .contentMargins(.trailing, 5, for: .compactTrailing)
      .contentMargins(.horizontal, 4, for: .minimal)
      .keylineTint(.cyan)
    }
  }
}

private func stale(_ context: ActivityViewContext<YahagiTimerAttributes>) -> Bool {
  if #available(iOS 16.2, *) { return context.isStale }
  return false
}

private func symbol(_ kind: String) -> String {
  switch kind {
  case "repair": return "wrench.and.screwdriver"
  case "construction": return "hammer"
  default: return "sailboat"
  }
}

private struct CompactIslandCountdown: View {
  @Environment(\.self) private var environment
  let item: YahagiTimerAttributes.TimerItem

  private var isLimitedInWidth: Bool {
    if #available(iOS 27.0, *) { return environment.isDynamicIslandLimitedInWidth }
    return false
  }

  var body: some View {
    if isLimitedInWidth {
      NarrowIslandCountdown(item: item)
    } else {
      TimerCountdown(item: item, alignment: .trailing)
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .frame(maxWidth: 56)
    }
  }
}

private struct NarrowIslandCountdown: View {
  let item: YahagiTimerAttributes.TimerItem

  var body: some View {
    let hasHours = item.deadline.timeIntervalSinceNow >= 3600
    TimerCountdown(item: item)
      .font(.system(size: hasHours ? 9 : 12, weight: .semibold))
      .fontWidth(hasHours ? .compressed : .condensed)
      .foregroundStyle(.white)
      .frame(width: 28)
  }
}

private struct TimerCountdown: View {
  let item: YahagiTimerAttributes.TimerItem
  var alignment: TextAlignment = .center

  var body: some View {
    Text(timerInterval: item.interval, countsDown: true, showsHours: true)
      .monospacedDigit()
      .multilineTextAlignment(alignment)
      .lineLimit(1)
      .minimumScaleFactor(0.65)
      .accessibilityLabel(Text(item.title))
      .accessibilityValue(Text(timerInterval: item.interval, countsDown: true))
  }
}

private struct TimerCard: View {
  let state: YahagiTimerAttributes.ContentState
  let isStale: Bool

  var body: some View {
    let strings = YahagiTimerStrings(locale: state.locale)
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: symbol(state.kind)).foregroundStyle(.cyan)
        Text(strings.title(state.kind)).fontWeight(.semibold)
        Spacer(minLength: 0)
        Text("ヤハギ").foregroundStyle(.secondary)
      }
      .font(.caption)

      HStack(alignment: .top, spacing: 0) {
        ForEach(Array(state.timers.enumerated()), id: \.element.id) { index, timer in
          if index > 0 {
            Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 56)
          }
          VStack(spacing: 5) {
            Text(strings.slot(timer.slot, kind: state.kind))
              .font(.system(size: 11, weight: .medium))
              .lineLimit(1)
              .minimumScaleFactor(0.7)
              .foregroundStyle(.secondary)
            TimerCountdown(item: timer)
              .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(timer.detail)
              .font(.system(size: 10))
              .lineLimit(1)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 5)
          .frame(maxWidth: .infinity)
        }
      }

      if isStale {
        Text(strings.expired).font(.system(size: 10)).foregroundStyle(.secondary)
      }
    }
    .foregroundStyle(.white)
  }
}
