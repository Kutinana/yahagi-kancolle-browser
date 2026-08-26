import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class KcwikiReportSettingsStore {
  Future<bool> loadEnabled();

  Future<void> saveEnabled(bool enabled);

  Future<KcwikiReportStatus> loadStatus();

  Future<void> saveStatus(KcwikiReportStatus status);
}

final class SharedPreferencesKcwikiReportSettingsStore
    implements KcwikiReportSettingsStore {
  static const String _enabledKey = 'kcwiki.report.enabled.v1';
  static const String _statusKey = 'kcwiki.report.status.v1';

  @override
  Future<bool> loadEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? true;

  @override
  Future<void> saveEnabled(bool enabled) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _enabledKey,
      enabled,
    );
    if (!saved) throw StateError('KCWiki report preference was not saved');
  }

  @override
  Future<KcwikiReportStatus> loadStatus() async {
    final raw = (await SharedPreferences.getInstance()).getString(_statusKey);
    if (raw == null || raw.isEmpty) return const KcwikiReportStatus();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const KcwikiReportStatus();
      return KcwikiReportStatus.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return const KcwikiReportStatus();
    }
  }

  @override
  Future<void> saveStatus(KcwikiReportStatus status) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _statusKey,
      jsonEncode(status.toJson()),
    );
    if (!saved) throw StateError('KCWiki report status was not saved');
  }
}

final class MemoryKcwikiReportSettingsStore
    implements KcwikiReportSettingsStore {
  MemoryKcwikiReportSettingsStore([
    this.enabled = true,
    KcwikiReportStatus? initialStatus,
  ]) : status = initialStatus ?? const KcwikiReportStatus();

  bool enabled;
  KcwikiReportStatus status;

  @override
  Future<bool> loadEnabled() async => enabled;

  @override
  Future<void> saveEnabled(bool enabled) async => this.enabled = enabled;

  @override
  Future<KcwikiReportStatus> loadStatus() async => status;

  @override
  Future<void> saveStatus(KcwikiReportStatus status) async =>
      this.status = status;
}

enum KcwikiReportActivity {
  waiting,
  processing,
  succeeded,
  failed,
  parseRecovered,
}

enum KcwikiReportFailure {
  httpRejected,
  bodyTooLarge,
  timeout,
  network,
  queueFull,
  local,
}

final class KcwikiReportStatus {
  const KcwikiReportStatus({
    this.activity = KcwikiReportActivity.waiting,
    this.module,
    this.path,
    this.occurredAt,
    this.statusCode,
    this.failure,
    this.succeededCount = 0,
    this.failedCount = 0,
    this.droppedCount = 0,
  });

  final KcwikiReportActivity activity;
  final String? module;
  final String? path;
  final DateTime? occurredAt;
  final int? statusCode;
  final KcwikiReportFailure? failure;
  final int succeededCount;
  final int failedCount;
  final int droppedCount;

  bool? get lastSucceeded => switch (activity) {
    KcwikiReportActivity.succeeded => true,
    KcwikiReportActivity.failed => false,
    _ => null,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'activity': activity.name,
    'module': module,
    'path': path,
    'occurredAt': occurredAt?.toUtc().toIso8601String(),
    'statusCode': statusCode,
    'failure': failure?.name,
    'succeededCount': succeededCount,
    'failedCount': failedCount,
    'droppedCount': droppedCount,
  };

  factory KcwikiReportStatus.fromJson(Map<String, Object?> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      if (raw is! String) return fallback;
      for (final value in values) {
        if (value.name == raw) return value;
      }
      return fallback;
    }

    int nonNegative(Object? raw) => raw is int && raw >= 0 ? raw : 0;
    final occurredAtRaw = json['occurredAt'];
    final failureRaw = json['failure'];
    return KcwikiReportStatus(
      activity: enumValue(
        KcwikiReportActivity.values,
        json['activity'],
        KcwikiReportActivity.waiting,
      ),
      module: json['module'] is String ? json['module'] as String : null,
      path: json['path'] is String ? json['path'] as String : null,
      occurredAt: occurredAtRaw is String
          ? DateTime.tryParse(occurredAtRaw)?.toUtc()
          : null,
      statusCode: json['statusCode'] is int ? json['statusCode'] as int : null,
      failure: failureRaw == null
          ? null
          : enumValue(
              KcwikiReportFailure.values,
              failureRaw,
              KcwikiReportFailure.local,
            ),
      succeededCount: nonNegative(json['succeededCount']),
      failedCount: nonNegative(json['failedCount']),
      droppedCount: nonNegative(json['droppedCount']),
    );
  }
}

final class KcwikiReportController extends ChangeNotifier {
  KcwikiReportController._(this._store, this._enabled, this._status);

  final KcwikiReportSettingsStore _store;
  bool _enabled;
  KcwikiReportStatus _status;
  Future<void> _changeQueue = Future<void>.value();
  Future<void> _statusQueue = Future<void>.value();

  bool get enabled => _enabled;
  KcwikiReportStatus get status => _status;
  Future<void> get settled async {
    await _changeQueue;
    await _statusQueue;
  }

  static Future<KcwikiReportController> load(
    KcwikiReportSettingsStore store,
  ) async => KcwikiReportController._(
    store,
    await store.loadEnabled(),
    await store.loadStatus(),
  );

  Future<void> setEnabled(bool enabled) {
    final operation = _changeQueue.then((_) => _setEnabled(enabled));
    _changeQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    await _store.saveEnabled(enabled);
    _enabled = enabled;
    notifyListeners();
  }

  void recordQueued({required String module, required DateTime occurredAt}) {
    _replaceStatus(
      KcwikiReportStatus(
        activity: KcwikiReportActivity.processing,
        module: module,
        occurredAt: occurredAt.toUtc(),
        succeededCount: _status.succeededCount,
        failedCount: _status.failedCount,
        droppedCount: _status.droppedCount,
      ),
    );
  }

  void recordResult({
    required String module,
    required bool succeeded,
    required DateTime occurredAt,
    int? statusCode,
    KcwikiReportFailure? failure,
  }) {
    _replaceStatus(
      KcwikiReportStatus(
        activity: succeeded
            ? KcwikiReportActivity.succeeded
            : KcwikiReportActivity.failed,
        module: module,
        occurredAt: occurredAt.toUtc(),
        statusCode: statusCode,
        failure: succeeded ? null : failure ?? KcwikiReportFailure.local,
        succeededCount: _status.succeededCount + (succeeded ? 1 : 0),
        failedCount: _status.failedCount + (succeeded ? 0 : 1),
        droppedCount: _status.droppedCount,
      ),
    );
  }

  void recordParseRecovered({
    required String path,
    required DateTime occurredAt,
  }) {
    _replaceStatus(
      KcwikiReportStatus(
        activity: KcwikiReportActivity.parseRecovered,
        path: path,
        occurredAt: occurredAt.toUtc(),
        succeededCount: _status.succeededCount,
        failedCount: _status.failedCount,
        droppedCount: _status.droppedCount,
      ),
    );
  }

  void recordDropped() {
    _replaceStatus(
      KcwikiReportStatus(
        activity: KcwikiReportActivity.failed,
        module: _status.module,
        occurredAt: DateTime.now().toUtc(),
        failure: KcwikiReportFailure.queueFull,
        succeededCount: _status.succeededCount,
        failedCount: _status.failedCount,
        droppedCount: _status.droppedCount + 1,
      ),
    );
  }

  void _replaceStatus(KcwikiReportStatus status) {
    _status = status;
    notifyListeners();
    final snapshot = status;
    _statusQueue = _statusQueue
        .then(
          (_) => _store.saveStatus(snapshot),
          onError: (_) => _store.saveStatus(snapshot),
        )
        .catchError((Object _) {});
  }
}
