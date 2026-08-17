import 'package:flutter/services.dart';

import 'game_resource_cache_store.dart';

enum GameResourceCacheState {
  idle,
  downloading,
  paused,
  complete,
  checking,
  capacityBlocked,
  error,
}

final class GameResourceManifest {
  const GameResourceManifest({
    required this.profile,
    required this.urls,
    required this.targetBytes,
  });

  final String profile;
  final List<String> urls;
  final int targetBytes;
}

final class GameResourceCacheStatus {
  const GameResourceCacheStatus({
    required this.mode,
    required this.state,
    required this.cachedBytes,
    required this.maxBytes,
    required this.targetBytes,
    required this.downloadedBytes,
    required this.bytesPerSecond,
    required this.remainingSeconds,
    required this.missingCount,
    required this.damagedCount,
    required this.fileCount,
    required this.capacityBlocked,
  });

  static const empty = GameResourceCacheStatus(
    mode: GameResourceCacheMode.none,
    state: GameResourceCacheState.idle,
    cachedBytes: 0,
    maxBytes: 10000000000,
    targetBytes: 0,
    downloadedBytes: 0,
    bytesPerSecond: 0,
    remainingSeconds: null,
    missingCount: 0,
    damagedCount: 0,
    fileCount: 0,
    capacityBlocked: false,
  );

  final GameResourceCacheMode mode;
  final GameResourceCacheState state;
  final int cachedBytes;
  final int maxBytes;
  final int targetBytes;
  final int downloadedBytes;
  final int bytesPerSecond;
  final int? remainingSeconds;
  final int missingCount;
  final int damagedCount;
  final int fileCount;
  final bool capacityBlocked;

  bool get isRunning =>
      state == GameResourceCacheState.downloading ||
      state == GameResourceCacheState.checking;

  factory GameResourceCacheStatus.fromMap(Map<Object?, Object?> map) {
    int number(String key) => (map[key] as num?)?.toInt() ?? 0;
    final stateName = map['state'] as String?;
    return GameResourceCacheStatus(
      mode: GameResourceCacheModeWire.fromWireName(map['mode'] as String?),
      state: GameResourceCacheState.values.firstWhere(
        (state) => state.name == stateName,
        orElse: () => GameResourceCacheState.idle,
      ),
      cachedBytes: number('cachedBytes'),
      maxBytes: number('maxBytes'),
      targetBytes: number('targetBytes'),
      downloadedBytes: number('downloadedBytes'),
      bytesPerSecond: number('bytesPerSecond'),
      remainingSeconds: map['remainingSeconds'] == null
          ? null
          : number('remainingSeconds'),
      missingCount: number('missingCount'),
      damagedCount: number('damagedCount'),
      fileCount: number('fileCount'),
      capacityBlocked: map['capacityBlocked'] as bool? ?? false,
    );
  }
}

abstract interface class GameResourceCachePort {
  Future<bool> configure(GameResourceCacheMode mode);
  Future<GameResourceCacheStatus> status();
  Future<bool> setManifest(GameResourceManifest manifest);
  Future<bool> startDownload();
  Future<bool> pauseDownload();
  Future<GameResourceCacheStatus> checkIntegrity();
  Future<bool> repair();
  Future<bool> clear();
}

final class MethodChannelGameResourceCachePort
    implements GameResourceCachePort {
  const MethodChannelGameResourceCachePort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/game_resource_cache',
    ),
  ]);

  final MethodChannel channel;

  @override
  Future<bool> configure(GameResourceCacheMode mode) async =>
      await channel.invokeMethod<bool>('configure', <String, Object?>{
        'mode': mode.wireName,
      }) ??
      false;

  @override
  Future<GameResourceCacheStatus> status() async =>
      _statusFrom(await channel.invokeMethod<Map<Object?, Object?>>('status'));

  @override
  Future<bool> setManifest(GameResourceManifest manifest) async =>
      await channel.invokeMethod<bool>('setManifest', <String, Object?>{
        'profile': manifest.profile,
        'urls': manifest.urls,
        'targetBytes': manifest.targetBytes,
      }) ??
      false;

  @override
  Future<bool> startDownload() async =>
      await channel.invokeMethod<bool>('startDownload') ?? false;

  @override
  Future<bool> pauseDownload() async =>
      await channel.invokeMethod<bool>('pauseDownload') ?? false;

  @override
  Future<GameResourceCacheStatus> checkIntegrity() async => _statusFrom(
    await channel.invokeMethod<Map<Object?, Object?>>('checkIntegrity'),
  );

  @override
  Future<bool> repair() async =>
      await channel.invokeMethod<bool>('repair') ?? false;

  @override
  Future<bool> clear() async =>
      await channel.invokeMethod<bool>('clear') ?? false;

  GameResourceCacheStatus _statusFrom(Map<Object?, Object?>? value) =>
      value == null
      ? GameResourceCacheStatus.empty
      : GameResourceCacheStatus.fromMap(value);
}
