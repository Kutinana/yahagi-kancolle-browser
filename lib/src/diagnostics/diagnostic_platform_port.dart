import 'package:flutter/services.dart';

final class DiagnosticPlatformSchemaException implements Exception {
  const DiagnosticPlatformSchemaException();
}

final class DiagnosticDeviceSnapshot {
  const DiagnosticDeviceSnapshot({
    required this.manufacturer,
    required this.model,
    required this.androidSdk,
    required this.androidRelease,
    required this.supportedAbi,
    required this.memoryClassMb,
    required this.screenWidthPx,
    required this.screenHeightPx,
    required this.webViewVersion,
    required this.previousExitReason,
  });

  final String manufacturer;
  final String model;
  final int androidSdk;
  final String androidRelease;
  final String supportedAbi;
  final int memoryClassMb;
  final int screenWidthPx;
  final int screenHeightPx;
  final String webViewVersion;
  final String previousExitReason;

  Map<String, Object?> toJson() => <String, Object?>{
    'manufacturer': manufacturer,
    'model': model,
    'androidSdk': androidSdk,
    'androidRelease': androidRelease,
    'supportedAbi': supportedAbi,
    'memoryClassMb': memoryClassMb,
    'screenWidthPx': screenWidthPx,
    'screenHeightPx': screenHeightPx,
    'webViewVersion': webViewVersion,
    'previousExitReason': previousExitReason,
  };
}

final class DiagnosticRuntimeSnapshot {
  const DiagnosticRuntimeSnapshot({
    required this.pssKb,
    required this.javaHeapKb,
    required this.nativeHeapKb,
    required this.graphicsKb,
    required this.privateOtherKb,
    required this.systemAvailableKb,
    required this.lowMemory,
  });

  final int pssKb;
  final int javaHeapKb;
  final int nativeHeapKb;
  final int graphicsKb;
  final int privateOtherKb;
  final int systemAvailableKb;
  final bool lowMemory;
}

abstract interface class DiagnosticPlatformPort {
  Future<DiagnosticDeviceSnapshot> deviceSnapshot();

  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot();

  Future<String?> saveJson(String path);

  Future<void> shareJson(String path);
}

final class MethodChannelDiagnosticPlatformPort
    implements DiagnosticPlatformPort {
  const MethodChannelDiagnosticPlatformPort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/diagnostics',
    ),
  ]);

  final MethodChannel channel;

  static const Set<String> _deviceKeys = <String>{
    'manufacturer',
    'model',
    'androidSdk',
    'androidRelease',
    'supportedAbi',
    'memoryClassMb',
    'screenWidthPx',
    'screenHeightPx',
    'webViewVersion',
    'previousExitReason',
  };
  static const Set<String> _runtimeKeys = <String>{
    'pssKb',
    'javaHeapKb',
    'nativeHeapKb',
    'graphicsKb',
    'privateOtherKb',
    'systemAvailableKb',
    'lowMemory',
  };

  @override
  Future<DiagnosticDeviceSnapshot> deviceSnapshot() async {
    final map = _map(await channel.invokeMethod<Object?>('deviceSnapshot'));
    _requireExactKeys(map, _deviceKeys);
    return DiagnosticDeviceSnapshot(
      manufacturer: _string(map, 'manufacturer'),
      model: _string(map, 'model'),
      androidSdk: _int(map, 'androidSdk'),
      androidRelease: _string(map, 'androidRelease'),
      supportedAbi: _string(map, 'supportedAbi'),
      memoryClassMb: _int(map, 'memoryClassMb'),
      screenWidthPx: _int(map, 'screenWidthPx'),
      screenHeightPx: _int(map, 'screenHeightPx'),
      webViewVersion: _string(map, 'webViewVersion'),
      previousExitReason: _string(map, 'previousExitReason'),
    );
  }

  @override
  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot() async {
    final map = _map(await channel.invokeMethod<Object?>('runtimeSnapshot'));
    _requireExactKeys(map, _runtimeKeys);
    final lowMemory = map['lowMemory'];
    if (lowMemory is! bool) throw const DiagnosticPlatformSchemaException();
    return DiagnosticRuntimeSnapshot(
      pssKb: _int(map, 'pssKb'),
      javaHeapKb: _int(map, 'javaHeapKb'),
      nativeHeapKb: _int(map, 'nativeHeapKb'),
      graphicsKb: _int(map, 'graphicsKb'),
      privateOtherKb: _int(map, 'privateOtherKb'),
      systemAvailableKb: _int(map, 'systemAvailableKb'),
      lowMemory: lowMemory,
    );
  }

  @override
  Future<String?> saveJson(String path) async {
    final value = await channel.invokeMethod<Object?>(
      'saveJson',
      <String, Object?>{'path': path},
    );
    if (value == null) return null;
    if (value is! String ||
        !RegExp(
          r'^Yahagi-Diagnostics-\d{8}-\d{6}(?:-\d+)?\.json$',
        ).hasMatch(value)) {
      throw const DiagnosticPlatformSchemaException();
    }
    return value;
  }

  @override
  Future<void> shareJson(String path) =>
      channel.invokeMethod<void>('shareJson', <String, Object?>{'path': path});

  static Map<Object?, Object?> _map(Object? value) {
    if (value is! Map) throw const DiagnosticPlatformSchemaException();
    return value;
  }

  static void _requireExactKeys(
    Map<Object?, Object?> map,
    Set<String> expected,
  ) {
    if (map.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(map.keys.toSet()).isNotEmpty) {
      throw const DiagnosticPlatformSchemaException();
    }
  }

  static String _string(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.length > 128) {
      throw const DiagnosticPlatformSchemaException();
    }
    return value;
  }

  static int _int(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is! int || value < 0) {
      throw const DiagnosticPlatformSchemaException();
    }
    return value;
  }
}
