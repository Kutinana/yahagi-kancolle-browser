import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in compatibility for physical mouse wheels; does not change touch input.
final class GameMouseWheelSettingsController extends ChangeNotifier {
  GameMouseWheelSettingsController._(this._preferences, this._enabled);

  static const preferenceKey = 'game.mouseWheelCompatibility';
  final SharedPreferences _preferences;
  bool _enabled;
  bool _saving = false;
  bool _disposed = false;
  bool _saveFailed = false;

  bool get enabled => _enabled;
  bool get saving => _saving;
  bool get saveFailed => _saveFailed;

  static Future<GameMouseWheelSettingsController> load() async {
    final preferences = await SharedPreferences.getInstance();
    return GameMouseWheelSettingsController._(
      preferences,
      preferences.getBool(preferenceKey) ?? false,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _saving || enabled == _enabled) return;
    _saving = true;
    _saveFailed = false;
    notifyListeners();
    try {
      if (!await _preferences.setBool(preferenceKey, enabled)) {
        throw StateError('Mouse wheel preference was not saved');
      }
      _enabled = enabled;
    } catch (_) {
      // SharedPreferences updates its Dart cache before awaiting the platform.
      // Restore that cache too if the write failed.
      try {
        await _preferences.setBool(preferenceKey, _enabled);
      } catch (_) {}
      _saveFailed = true;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
