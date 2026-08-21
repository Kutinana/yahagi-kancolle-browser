enum GameNotificationType {
  expedition,
  repair,
  anchorage,
  construction,
  morale;

  String get channelId => 'channel_$name';
}

class ScheduledNotificationItem {
  const ScheduledNotificationItem({
    required this.key,
    required this.type,
    required this.triggerTime,
    required this.title,
    required this.body,
  });

  final String key;
  final GameNotificationType type;
  final DateTime triggerTime;
  final String title;
  final String body;

  Map<String, Object?> toMap() => {
    'key': key,
    'type': type.name,
    'channelId': type.channelId,
    'triggerTimeEpochMs': triggerTime.millisecondsSinceEpoch,
    'title': title,
    'body': body,
  };
}

class OngoingTaskItem {
  const OngoingTaskItem({
    required this.id,
    required this.type,
    required this.title,
    required this.progress,
    required this.remainingSeconds,
    this.targetEpochMs,
    this.totalDurationSec,
  });

  final String id;
  final GameNotificationType type;
  final String title;
  final double progress; // 0.0 to 1.0
  final int remainingSeconds;
  final int? targetEpochMs;
  final int? totalDurationSec;

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'progress': progress,
    'remainingSeconds': remainingSeconds,
    'targetEpochMs': targetEpochMs,
    'totalDurationSec': totalDurationSec,
  };
}

class OngoingProgressSummary {
  const OngoingProgressSummary({
    required this.items,
    this.showProgress = true,
    this.showPercent = true,
    this.showCountdown = true,
  });

  final List<OngoingTaskItem> items;
  final bool showProgress;
  final bool showPercent;
  final bool showCountdown;

  Map<String, Object?> toMap() => {
    'items': items.map((e) => e.toMap()).toList(),
    'showProgress': showProgress,
    'showPercent': showPercent,
    'showCountdown': showCountdown,
  };
}
