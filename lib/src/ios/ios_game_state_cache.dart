import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps large iOS game-state JSON out of NSUserDefaults.
final class IOSGameStateCache {
  IOSGameStateCache(this.directory);

  static Future<IOSGameStateCache> create() async => IOSGameStateCache(
    Directory(
      path.join((await getApplicationSupportDirectory()).path, 'game-state'),
    ),
  );

  final Directory directory;
  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/game_state_cache',
  );
  Future<void> _tail = Future<void>.value();

  static bool _owns(String key) =>
      key == 'yahagi_kancolle_browser_game_state' ||
      key == 'game_state.shared.v1' ||
      RegExp(r'^account\.[1-9][0-9]*\.game_state\.v1$').hasMatch(key);

  File _file(String key) {
    if (!_owns(key)) throw ArgumentError('Unsupported game cache key');
    return File(path.join(directory.path, '$key.json'));
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Old whole-state backups remain available as files for legacy migration.
  /// Move the largest values first so each preferences write reduces its size.
  Future<void> migratePreferences(SharedPreferences preferences) =>
      _serial(() async {
        final keys = preferences.getKeys().where(_owns).toList()
          ..sort(
            (a, b) => (preferences.getString(b)?.length ?? 0).compareTo(
              preferences.getString(a)?.length ?? 0,
            ),
          );
        for (final key in keys) {
          final raw = preferences.getString(key);
          if (raw != null) await _migrate(preferences, key, raw);
        }
        if (keys.isNotEmpty) await _flushPreferences();
      });

  Future<String?> readString(SharedPreferences preferences, String key) =>
      _serial(() async {
        // A restored backup or older app can have written a newer preference.
        final raw = preferences.getString(key);
        if (raw != null) {
          try {
            await _migrate(preferences, key, raw);
            await _flushPreferences();
          } on Object {
            // Retain usable data if disk migration is temporarily unavailable.
          }
          return raw;
        }
        final file = _file(key);
        for (final candidate in [file, File('${file.path}.previous')]) {
          try {
            return await _readValid(candidate);
          } on FileSystemException {
            // Missing or damaged primaries can recover from the previous copy.
          } on FormatException {
            // Keep corrupt files for recovery; never replace their backup.
          }
        }
        return null;
      });

  Future<bool> writeString(
    SharedPreferences preferences,
    String key,
    String value,
  ) => _serial(() async {
    await _writeVerified(_file(key), value);
    if (preferences.containsKey(key)) {
      if (!await preferences.remove(key)) {
        throw StateError('Could not remove migrated game cache preference');
      }
      await _flushPreferences();
    }
    return true;
  });

  Future<void> _flushPreferences() async {
    if (await _channel.invokeMethod<bool>('flushPreferences') != true) {
      throw const FileSystemException(
        'Could not flush migrated game cache preferences',
      );
    }
  }

  Future<void> _migrate(
    SharedPreferences preferences,
    String key,
    String value,
  ) async {
    await _writeVerified(_file(key), value);
    if (!await preferences.remove(key)) {
      throw StateError('Could not remove migrated game cache preference');
    }
  }

  static void _validate(String value) {
    if (jsonDecode(value) is! Map<String, dynamic>) {
      throw const FormatException('Invalid game cache');
    }
  }

  static Future<String> _readValid(File file) async {
    final value = await file.readAsString();
    _validate(value);
    return value;
  }

  Future<void> _writeVerified(File file, String value) async {
    _validate(value);
    await directory.create(recursive: true);
    final temporary = File('${file.path}.pending');
    await temporary.writeAsString(value, flush: true);
    if (await _readValid(temporary) != value) {
      throw const FileSystemException('Game cache verification failed');
    }
    if (await file.exists()) {
      try {
        await _readValid(file);
        await file.copy('${file.path}.previous');
      } on FormatException {
        // Preserve the last valid backup when replacing a damaged primary.
      }
    }
    // Renaming on the same iOS filesystem atomically replaces the destination.
    await temporary.rename(file.path);
    if (await _readValid(file) != value) {
      throw const FileSystemException(
        'Installed game cache verification failed',
      );
    }
  }
}
