import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class KcwikiReportSettingsStore {
  Future<bool> loadEnabled();

  Future<void> saveEnabled(bool enabled);
}

final class SharedPreferencesKcwikiReportSettingsStore
    implements KcwikiReportSettingsStore {
  static const String _enabledKey = 'kcwiki.report.enabled.v1';

  @override
  Future<bool> loadEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  @override
  Future<void> saveEnabled(bool enabled) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _enabledKey,
      enabled,
    );
    if (!saved) throw StateError('KCWiki report preference was not saved');
  }
}

final class MemoryKcwikiReportSettingsStore
    implements KcwikiReportSettingsStore {
  MemoryKcwikiReportSettingsStore([this.enabled = false]);

  bool enabled;

  @override
  Future<bool> loadEnabled() async => enabled;

  @override
  Future<void> saveEnabled(bool enabled) async => this.enabled = enabled;
}

final class KcwikiReportStatus {
  const KcwikiReportStatus({
    this.module,
    this.occurredAt,
    this.statusCode,
    this.lastSucceeded,
    this.succeededCount = 0,
    this.failedCount = 0,
    this.droppedCount = 0,
  });

  final String? module;
  final DateTime? occurredAt;
  final int? statusCode;
  final bool? lastSucceeded;
  final int succeededCount;
  final int failedCount;
  final int droppedCount;

  KcwikiReportStatus copyWith({
    String? module,
    DateTime? occurredAt,
    int? statusCode,
    bool? lastSucceeded,
    int? succeededCount,
    int? failedCount,
    int? droppedCount,
  }) => KcwikiReportStatus(
    module: module ?? this.module,
    occurredAt: occurredAt ?? this.occurredAt,
    statusCode: statusCode ?? this.statusCode,
    lastSucceeded: lastSucceeded ?? this.lastSucceeded,
    succeededCount: succeededCount ?? this.succeededCount,
    failedCount: failedCount ?? this.failedCount,
    droppedCount: droppedCount ?? this.droppedCount,
  );
}

final class KcwikiReportController extends ChangeNotifier {
  KcwikiReportController._(this._store, this._enabled);

  final KcwikiReportSettingsStore _store;
  bool _enabled;
  KcwikiReportStatus _status = const KcwikiReportStatus();
  Future<void> _changeQueue = Future<void>.value();

  bool get enabled => _enabled;
  KcwikiReportStatus get status => _status;

  static Future<KcwikiReportController> load(
    KcwikiReportSettingsStore store,
  ) async => KcwikiReportController._(store, await store.loadEnabled());

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

  void recordResult({
    required String module,
    required bool succeeded,
    required DateTime occurredAt,
    int? statusCode,
  }) {
    _status = KcwikiReportStatus(
      module: module,
      occurredAt: occurredAt.toUtc(),
      statusCode: statusCode,
      lastSucceeded: succeeded,
      succeededCount: _status.succeededCount + (succeeded ? 1 : 0),
      failedCount: _status.failedCount + (succeeded ? 0 : 1),
      droppedCount: _status.droppedCount,
    );
    notifyListeners();
  }

  void recordDropped() {
    _status = _status.copyWith(droppedCount: _status.droppedCount + 1);
    notifyListeners();
  }
}
