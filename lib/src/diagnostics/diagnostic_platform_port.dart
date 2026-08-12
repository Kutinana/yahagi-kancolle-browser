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
  };
}

final class DiagnosticRuntimeSnapshot {
  const DiagnosticRuntimeSnapshot({
    required this.pssKb,
    required this.javaHeapKb,
    required this.nativeHeapKb,
    required this.lowMemory,
  });

  final int pssKb;
  final int javaHeapKb;
  final int nativeHeapKb;
  final bool lowMemory;
}

abstract interface class DiagnosticPlatformPort {
  Future<DiagnosticDeviceSnapshot> deviceSnapshot();

  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot();

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
  };
  static const Set<String> _runtimeKeys = <String>{
    'pssKb',
    'javaHeapKb',
    'nativeHeapKb',
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
      lowMemory: lowMemory,
    );
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
