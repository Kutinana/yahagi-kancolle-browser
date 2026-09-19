import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class GameFrameRefreshShortcutSettings extends ChangeNotifier {
  GameFrameRefreshShortcutSettings._(
    this._preferences,
    this._skipHeaderConfirmation,
  );

  static const skipHeaderConfirmationPreferenceKey =
      'game.frameRefreshSkipConfirmation';

  final SharedPreferences _preferences;
  bool _skipHeaderConfirmation;
  bool _saving = false;
  bool _saveFailed = false;
  bool _disposed = false;

  bool get skipHeaderConfirmation => _skipHeaderConfirmation;
  bool get saving => _saving;
  bool get saveFailed => _saveFailed;

  static Future<GameFrameRefreshShortcutSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return GameFrameRefreshShortcutSettings._(
      preferences,
      preferences.getBool(skipHeaderConfirmationPreferenceKey) ?? false,
    );
  }

  Future<void> setSkipHeaderConfirmation(bool value) => _save(
    key: skipHeaderConfirmationPreferenceKey,
    value: value,
    currentValue: _skipHeaderConfirmation,
    apply: (saved) => _skipHeaderConfirmation = saved,
  );

  Future<void> _save({
    required String key,
    required bool value,
    required bool currentValue,
    required ValueChanged<bool> apply,
  }) async {
    if (_disposed || _saving || value == currentValue) return;
    _saving = true;
    _saveFailed = false;
    notifyListeners();
    try {
      if (!await _preferences.setBool(key, value)) {
        throw StateError('Frame refresh shortcut preference was not saved');
      }
      apply(value);
    } catch (_) {
      try {
        await _preferences.setBool(key, currentValue);
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
