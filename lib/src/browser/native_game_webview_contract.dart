import 'safe_page_address.dart';

const nativeGameWebViewMethodChannelName =
    'app.yahagi.kancollebrowser/native_game_webview';
const nativeGameWebViewEventChannelName =
    'app.yahagi.kancollebrowser/native_game_webview_events';

final class NativeGameWebViewSchemaException implements Exception {
  const NativeGameWebViewSchemaException([
    this.message = 'Invalid native WebView schema.',
  ]);

  final String message;

  @override
  String toString() => 'NativeGameWebViewSchemaException: $message';
}

final class NativeGameWebViewBounds {
  NativeGameWebViewBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.devicePixelRatio,
  }) {
    _requireFinite('left', left);
    _requireFinite('top', top);
    _requirePositive('width', width);
    _requirePositive('height', height);
    _requirePositive('devicePixelRatio', devicePixelRatio);
  }

  final double left;
  final double top;
  final double width;
  final double height;
  final double devicePixelRatio;

  Map<String, double> toMap() => <String, double>{
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'devicePixelRatio': devicePixelRatio,
  };

  static void _requireFinite(String name, double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'must be finite');
    }
  }

  static void _requirePositive(String name, double value) {
    _requireFinite(name, value);
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'must be greater than zero');
    }
  }
}

enum NativeGameWebViewEventType {
  created,
  pageStarted,
  pageFinished,
  mainFrameError,
  navigationBlocked,
  renderProcessGone,
  destroyed,
}

final class NativeGameWebViewEvent {
  const NativeGameWebViewEvent._({
    required this.type,
    required this.generationId,
    this.url,
    this.errorCode,
    this.description,
    this.scheme,
    this.didCrash,
  });

  final NativeGameWebViewEventType type;
  final int generationId;
  final String? url;
  final int? errorCode;
  final String? description;
  final String? scheme;
  final bool? didCrash;

  factory NativeGameWebViewEvent.decode(Object? raw) {
    if (raw is! Map) {
      throw const NativeGameWebViewSchemaException('Event must be a map.');
    }
    final map = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        throw const NativeGameWebViewSchemaException(
          'Event keys must be strings.',
        );
      }
      map[entry.key as String] = entry.value;
    }

    final typeName = _string(map, 'type');
    final type = _eventTypes[typeName];
    if (type == null) {
      throw const NativeGameWebViewSchemaException('Unknown event type.');
    }
    _requireKeys(map, _keysForType[type]!);
    final generationId = _int(map, 'generationId');
    if (generationId < 0) {
      throw const NativeGameWebViewSchemaException(
        'generationId must be non-negative.',
      );
    }

    switch (type) {
      case NativeGameWebViewEventType.created:
      case NativeGameWebViewEventType.destroyed:
        return NativeGameWebViewEvent._(type: type, generationId: generationId);
      case NativeGameWebViewEventType.pageStarted:
      case NativeGameWebViewEventType.pageFinished:
        final rawUrl = _string(map, 'url');
        final uri = Uri.tryParse(rawUrl);
        if (uri == null || !SafePageAddress.canNavigate(uri)) {
          throw const NativeGameWebViewSchemaException('Event URL is unsafe.');
        }
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          url: SafePageAddress.fromRaw(rawUrl).displayText,
        );
      case NativeGameWebViewEventType.mainFrameError:
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          errorCode: _int(map, 'errorCode'),
          description: _string(map, 'description', maxLength: 256),
        );
      case NativeGameWebViewEventType.navigationBlocked:
        final scheme = _string(map, 'scheme', maxLength: 32);
        if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]{0,31}$').hasMatch(scheme)) {
          throw const NativeGameWebViewSchemaException(
            'Invalid navigation scheme.',
          );
        }
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          scheme: scheme,
        );
      case NativeGameWebViewEventType.renderProcessGone:
        final didCrash = map['didCrash'];
        if (didCrash is! bool) {
          throw const NativeGameWebViewSchemaException(
            'didCrash must be a bool.',
          );
        }
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          didCrash: didCrash,
        );
    }
  }

  static const Map<String, NativeGameWebViewEventType> _eventTypes =
      <String, NativeGameWebViewEventType>{
        'created': NativeGameWebViewEventType.created,
        'pageStarted': NativeGameWebViewEventType.pageStarted,
        'pageFinished': NativeGameWebViewEventType.pageFinished,
        'mainFrameError': NativeGameWebViewEventType.mainFrameError,
        'navigationBlocked': NativeGameWebViewEventType.navigationBlocked,
        'renderProcessGone': NativeGameWebViewEventType.renderProcessGone,
        'destroyed': NativeGameWebViewEventType.destroyed,
      };

  static const Map<NativeGameWebViewEventType, Set<String>> _keysForType =
      <NativeGameWebViewEventType, Set<String>>{
        NativeGameWebViewEventType.created: <String>{'type', 'generationId'},
        NativeGameWebViewEventType.destroyed: <String>{'type', 'generationId'},
        NativeGameWebViewEventType.pageStarted: <String>{
          'type',
          'generationId',
          'url',
        },
        NativeGameWebViewEventType.pageFinished: <String>{
          'type',
          'generationId',
          'url',
        },
        NativeGameWebViewEventType.mainFrameError: <String>{
          'type',
          'generationId',
          'errorCode',
          'description',
        },
        NativeGameWebViewEventType.navigationBlocked: <String>{
          'type',
          'generationId',
          'scheme',
        },
        NativeGameWebViewEventType.renderProcessGone: <String>{
          'type',
          'generationId',
          'didCrash',
        },
      };

  static void _requireKeys(Map<String, Object?> map, Set<String> allowed) {
    if (map.length != allowed.length || !map.keys.every(allowed.contains)) {
      throw const NativeGameWebViewSchemaException(
        'Event keys do not match schema.',
      );
    }
  }

  static String _string(
    Map<String, Object?> map,
    String key, {
    int maxLength = 2048,
  }) {
    final value = map[key];
    if (value is! String || value.length > maxLength) {
      throw NativeGameWebViewSchemaException('$key must be a short string.');
    }
    return value;
  }

  static int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw NativeGameWebViewSchemaException('$key must be an int.');
    }
    return value;
  }
}
