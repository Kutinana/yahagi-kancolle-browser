import 'dart:io';

import 'package:flutter/foundation.dart';

import 'sortie_map_catalog_update_service.dart';
import 'sortie_map_models.dart';

final class SortieMapCatalogController extends ChangeNotifier {
  SortieMapCatalogController({
    required SortieMapCatalogData data,
    required SortieMapCatalogUpdateClient updater,
    Directory? cacheRoot,
  }) : _data = data,
       _updater = updater,
       _cacheRoot = cacheRoot;

  SortieMapCatalogData _data;
  final SortieMapCatalogUpdateClient _updater;
  Directory? _cacheRoot;
  Future<SortieMapCatalogUpdateResult>? _activeCheck;
  SortieMapCatalogUpdateResult? _lastResult;
  DateTime? _lastCheckedAt;
  String _sourceHost = '';
  bool _disposed = false;

  SortieMapCatalogData get data => _data;
  bool get isChecking => _activeCheck != null;
  SortieMapCatalogUpdateResult? get lastResult => _lastResult;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  String get sourceHost => _sourceHost;
  bool get usesCachedData => _cacheRoot != null;

  File? resolveCachedImage(String logicalPath) => _cacheRoot == null
      ? null
      : File(
          '${_cacheRoot!.path}${Platform.pathSeparator}${logicalPath.replaceAll('/', Platform.pathSeparator)}',
        );

  Future<SortieMapCatalogUpdateResult> checkForUpdates() {
    final active = _activeCheck;
    if (active != null) return active;
    final operation = _performCheck();
    _activeCheck = operation;
    notifyListeners();
    return operation;
  }

  Future<SortieMapCatalogUpdateResult> _performCheck() async {
    try {
      final result = await _updater.checkAndUpdate(current: _data);
      _lastResult = result;
      _lastCheckedAt = DateTime.now().toUtc();
      if (result is SortieMapCatalogUpdated) {
        _data = result.catalog.data;
        _cacheRoot = result.catalog.root;
      }
      if (result is! SortieMapCatalogUpdateFailed) {
        _sourceHost = result.sourceHost;
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

// ignore_for_file: prefer_initializing_formals
