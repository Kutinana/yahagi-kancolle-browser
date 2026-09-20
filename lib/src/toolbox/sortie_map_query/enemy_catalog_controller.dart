// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'enemy_catalog.dart';
import 'enemy_catalog_update_service.dart';

final class EnemyCatalogController extends ChangeNotifier {
  EnemyCatalogController({
    required EnemyCatalogData data,
    required EnemyCatalogUpdateClient updater,
    this.usesCachedData = false,
  }) : _data = data,
       _updater = updater;

  EnemyCatalogData _data;
  final EnemyCatalogUpdateClient _updater;
  Future<EnemyCatalogUpdateResult>? _activeCheck;
  EnemyCatalogUpdateResult? _lastResult;
  bool _disposed = false;
  DateTime? _lastCheckedAt;

  DateTime? get lastCheckedAt => _lastCheckedAt;

  EnemyCatalogData get data => _data;
  bool get isChecking => _activeCheck != null;
  bool usesCachedData;
  EnemyCatalogUpdateResult? get lastResult => _lastResult;

  Future<EnemyCatalogUpdateResult> checkForUpdates() {
    final active = _activeCheck;
    if (active != null) return active;
    final operation = _performCheck();
    _activeCheck = operation;
    notifyListeners();
    return operation;
  }

  Future<EnemyCatalogUpdateResult> _performCheck() async {
    try {
      final result = await _updater.checkAndUpdate(current: _data);
      _lastResult = result;
      _lastCheckedAt = DateTime.now().toUtc();
      if (result is EnemyCatalogUpdated) {
        _data = result.catalog;
        usesCachedData = true;
      }
      return result;
    } finally {
      _activeCheck = null;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
