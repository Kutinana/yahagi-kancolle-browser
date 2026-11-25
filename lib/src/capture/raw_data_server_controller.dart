import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller for managing captured raw game master data (`api_start2/getData`)
/// and developer mode state on iOS.
final class RawDataServerController extends ChangeNotifier {
  RawDataServerController() {
    _initStorage();
  }

  static const String _developerModeKey = 'yahagi_developer_mode';

  bool _developerMode = false;
  DateTime? _lastCapturedAt;
  int _fileSizeBytes = 0;
  String? _statusMessage;
  String? _documentsDirPath;

  bool get developerMode => _developerMode;
  DateTime? get lastCapturedAt => _lastCapturedAt;
  int get fileSizeBytes => _fileSizeBytes;
  String? get statusMessage => _statusMessage;

  String get fileSizeFormatted {
    if (_fileSizeBytes <= 0) return '0 B';
    if (_fileSizeBytes < 1024) return '$_fileSizeBytes B';
    if (_fileSizeBytes < 1024 * 1024) {
      return '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _initStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _developerMode = prefs.getBool(_developerModeKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('读取开发者模式配置失败: $e');
    }
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _documentsDirPath = docDir.path;
      await checkExistingFile();
    } catch (e) {
      debugPrint('初始化原始数据存储路径失败: $e');
    }
  }

  Future<void> setDeveloperMode(bool enabled) async {
    if (_developerMode == enabled) return;
    _developerMode = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_developerModeKey, enabled);
    } catch (e) {
      debugPrint('保存开发者模式配置失败: $e');
    }
  }

  Future<File?> get _targetFile async {
    final baseDirPath =
        _documentsDirPath ?? (await getApplicationDocumentsDirectory()).path;
    final legacyFile = File(p.join(baseDirPath, 'raw_data', 'api_start2_raw.json'));
    if (await legacyFile.exists()) {
      return legacyFile;
    }
    return File(p.join(baseDirPath, 'api_start2_raw.json'));
  }

  Future<void> checkExistingFile() async {
    try {
      final file = await _targetFile;
      if (file != null && await file.exists()) {
        final stat = await file.stat();
        _fileSizeBytes = stat.size;
        _lastCapturedAt = stat.modified;
        _statusMessage = null;
        notifyListeners();
      } else {
        _fileSizeBytes = 0;
        _lastCapturedAt = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('检查原始数据文件状态失败: $e');
    }
  }

  Future<void> saveRawMasterData(String jsonBody) async {
    if (!_developerMode) return;
    try {
      final file = await _targetFile;
      if (file == null) return;
      await file.writeAsString(jsonBody);
      final stat = await file.stat();
      _fileSizeBytes = stat.size;
      _lastCapturedAt = DateTime.now().toUtc();
      _statusMessage = null;
      notifyListeners();
    } catch (e) {
      _statusMessage = '保存 api_start2 失败: $e';
      debugPrint('保存 api_start2 原始数据失败: $e');
      notifyListeners();
    }
  }

  Future<bool> deleteRawMasterData() async {
    try {
      final file = await _targetFile;
      if (file != null && await file.exists()) {
        await file.delete();
      }
      final baseDirPath =
          _documentsDirPath ?? (await getApplicationDocumentsDirectory()).path;
      final legacyFile = File(p.join(baseDirPath, 'raw_data', 'api_start2_raw.json'));
      if (await legacyFile.exists()) {
        await legacyFile.delete();
      }
      _fileSizeBytes = 0;
      _lastCapturedAt = null;
      _statusMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _statusMessage = '删除文件失败: $e';
      notifyListeners();
      return false;
    }
  }
}
