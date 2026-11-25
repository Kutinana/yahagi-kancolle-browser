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
      return DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          TimerCard(state: context.state, isStale: stale(context))
        }
      } compactLeading: {
        HStack(spacing: 3) {
          Image(systemName: symbol(context.state.kind))
          if let nearest { Text(nearest.slot) }
        }
        .font(.caption2)
        .foregroundStyle(.cyan)
      } compactTrailing: {
        if let nearest {
          TimerCountdown(item: nearest)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .frame(width: 64)
        }
      } minimal: {
        if let nearest {
          TimerCountdown(item: nearest)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.7)
        }
      }
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

private struct TimerCountdown: View {
  let item: YahagiTimerAttributes.TimerItem

  var body: some View {
    Text(timerInterval: item.interval, countsDown: true, showsHours: true)
      .monospacedDigit()
      .multilineTextAlignment(.center)
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
