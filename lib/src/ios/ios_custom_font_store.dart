import 'package:flutter/services.dart';

import '../theme/custom_font_descriptor.dart';
import '../theme/custom_font_store.dart';

/// Resolve the current container path after an iOS restore or container move.
final class IOSCustomFontStore implements CustomFontStore {
  const IOSCustomFontStore();
  static const _preferences = SharedPreferencesCustomFontStore();
  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/custom_fonts',
  );

  @override
  Future<CustomFontDescriptor?> load() async {
    final saved = await _preferences.load();
    if (saved == null) return null;
    final resolved = await _channel.invokeMethod<Object?>('resolveFont', {
      'id': saved.id,
      'name': saved.name,
    });
    if (resolved == null) {
      await _preferences.save(null);
      return null;
    }
    return CustomFontDescriptor.fromMap(resolved);
  }

  @override
  Future<void> save(CustomFontDescriptor? font) => _preferences.save(font);
}
