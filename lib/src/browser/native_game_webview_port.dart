import 'dart:async';

import 'package:flutter/services.dart';

import 'game_browser_controller.dart';
import 'native_game_webview_contract.dart';
import 'safe_page_address.dart';

final class MethodChannelNativeGameWebViewPort implements GameBrowserPort {
  MethodChannelNativeGameWebViewPort({
    MethodChannel? channel,
    Stream<Object?>? eventStream,
  }) : _channel =
           channel ?? const MethodChannel(nativeGameWebViewMethodChannelName),
       _eventStream =
           eventStream ??
           const EventChannel(
             nativeGameWebViewEventChannelName,
           ).receiveBroadcastStream();

  late final StreamController<NativeGameWebViewEvent> _events =
      StreamController<NativeGameWebViewEvent>.broadcast(
        onListen: _replayInitialEvents,
      );

  final MethodChannel _channel;
  final Stream<Object?> _eventStream;

  StreamSubscription<Object?>? _eventSubscription;
  Future<void>? _eventCancellation;
  Future<int>? _createFuture;
  Future<void>? _disposeFuture;
  int? _generationId;
  bool _disposed = false;
  final List<NativeGameWebViewEvent> _pendingEvents =
      <NativeGameWebViewEvent>[];
  final List<NativeGameWebViewEvent> _initialEvents =
      <NativeGameWebViewEvent>[];
  bool _hasInitialEventsListener = false;

  Stream<NativeGameWebViewEvent> get events => _events.stream;

  Future<int> create() {
    if (_disposed) {
      return Future<int>.error(StateError('Native WebView has been disposed.'));
    }
    if (_generationId != null) {
      return Future<int>.error(
        StateError('Native WebView has already been created.'),
      );
    }
    final existing = _createFuture;
    if (existing != null) {
      return existing;
    }
    late final Future<int> createFuture;
    createFuture = _create().whenComplete(() {
      if (identical(_createFuture, createFuture)) {
        _createFuture = null;
      }
    });
    _createFuture = createFuture;
    return createFuture;
  }

  Future<int> _create() async {
    _startEventSubscription();
    Object? result;
    try {
      result = await _channel.invokeMethod<Object?>('create', <String, Object?>{
        'renderer': 'webgl',
      });
    } catch (error, stackTrace) {
      await _cancelIgnoringError();
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (result is! int || result < 0) {
      const error = NativeGameWebViewSchemaException(
        'create must return a non-negative generationId.',
      );
      await _cancelIgnoringError();
      throw error;
    }
    final generationId = result;
    if (_disposed) {
      final errors = _CleanupErrors();
      final eventCancellation = _eventCancellation;
      if (eventCancellation != null) {
        await errors.run(() => eventCancellation);
      }
      await errors.run(() => _destroy(generationId));
      if (errors.hasError) {
        errors.throwFirst();
      }
      throw StateError('Native WebView has been disposed.');
    }
    _generationId = generationId;
    for (final event in _pendingEvents) {
      if (event.generationId == generationId) {
        _emitEvent(event);
      }
    }
    _pendingEvents.clear();
    return generationId;
  }

  Future<void> _cancelIgnoringError() async {
    try {
      await _cancelEventSubscription();
    } catch (_) {
      // The create result remains the first meaningful error.
    }
  }

  Future<void> _destroy(int generationId) {
    return _channel.invokeMethod<void>('destroy', <String, Object?>{
      'generationId': generationId,
    });
  }

  void _emitEvent(NativeGameWebViewEvent event) {
    if (!_hasInitialEventsListener) {
      _initialEvents.add(event);
    }
    _events.add(event);
  }

  void _replayInitialEvents() {
    if (_hasInitialEventsListener) {
      return;
    }
    _hasInitialEventsListener = true;
    for (final event in _initialEvents) {
      _events.add(event);
    }
    _initialEvents.clear();
  }

  void _startEventSubscription() {
    _eventSubscription ??= _eventStream.listen(
      _onNativeEvent,
      onError: (Object error, StackTrace stackTrace) {
        _events.addError(error, stackTrace);
      },
    );
  }

  Future<void> _cancelEventSubscription() {
    final existing = _eventCancellation;
    if (existing != null) {
      return existing;
    }
    final subscription = _eventSubscription;
    if (subscription == null) {
      return Future<void>.value();
    }
    late final Future<void> cancellation;
    cancellation = subscription.cancel().whenComplete(() {
      if (identical(_eventCancellation, cancellation)) {
        _eventCancellation = null;
      }
      if (identical(_eventSubscription, subscription)) {
        _eventSubscription = null;
      }
    });
    _eventCancellation = cancellation;
    return cancellation;
  }

  Future<void> setBounds(NativeGameWebViewBounds bounds) {
    return _invoke('setBounds', <String, Object?>{'bounds': bounds.toMap()});
  }

  Future<void> setVisible(bool visible) {
    return _invoke('setVisible', <String, Object?>{'visible': visible});
  }

  @override
  Future<void> loadUri(Uri uri) async {
    final generationId = _requireGeneration();
    if (!SafePageAddress.canNavigate(uri)) {
      throw ArgumentError.value(uri, 'uri', 'must be a safe HTTP(S) page URI');
    }
    await _channel.invokeMethod<void>('loadUri', <String, Object?>{
      'generationId': generationId,
      'uri': uri.toString(),
    });
  }

  @override
  Future<void> showLocalHome() => _invoke('showLocalHome');

  @override
  Future<void> reload() => _invoke('reload');

  @override
  Future<bool> canGoBack() async {
    final result = await _invokeResult('canGoBack');
    if (result is! bool) {
      throw const NativeGameWebViewSchemaException(
        'canGoBack must return a bool.',
      );
    }
    return result;
  }

  @override
  Future<void> goBack() => _invoke('goBack');

  @override
  Future<void> runJavaScript(String javascript) {
    return _invoke('runJavaScript', <String, Object?>{
      'javascript': javascript,
    });
  }

  @override
  Future<void> fitGameScreen() => _invoke('fitGameScreen');

  @override
  Future<void> clearCache() => _invoke('clearCache');

  @override
  Future<void> clearSession() => _invoke('clearSession');

  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) {
      return existing;
    }
    _disposed = true;
    final future = _dispose();
    _disposeFuture = future;
    return future;
  }

  Future<void> _dispose() async {
    final errors = _CleanupErrors();
    await errors.run(_cancelEventSubscription);
    final generationId = _generationId;
    _generationId = null;
    if (generationId != null) {
      await errors.run(() => _destroy(generationId));
    } else {
      final createFuture = _createFuture;
      if (createFuture != null) {
        await errors.run(() async {
          try {
            await createFuture;
          } on StateError {
            // A create response received after disposal destroys itself.
          }
        });
      }
    }
    _pendingEvents.clear();
    _initialEvents.clear();
    _closeEvents(errors);
    if (errors.hasError) {
      errors.throwFirst();
    }
  }

  void _closeEvents(_CleanupErrors errors) {
    try {
      unawaited(_events.close());
    } catch (error, stackTrace) {
      errors.capture(error, stackTrace);
    }
  }

  void _onNativeEvent(Object? raw) {
    try {
      final event = NativeGameWebViewEvent.decode(raw);
      final generationId = _generationId;
      if (generationId == null && !_disposed) {
        _pendingEvents.add(event);
      } else if (event.generationId == generationId) {
        _emitEvent(event);
      }
    } on NativeGameWebViewSchemaException catch (error, stackTrace) {
      _events.addError(error, stackTrace);
    }
  }

  Future<void> _invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    await _channel.invokeMethod<void>(method, <String, Object?>{
      'generationId': _requireGeneration(),
      ...arguments,
    });
  }

  Future<Object?> _invokeResult(String method) async {
    return _channel.invokeMethod<Object?>(method, <String, Object?>{
      'generationId': _requireGeneration(),
    });
  }

  int _requireGeneration() {
    _throwIfDisposed();
    final generationId = _generationId;
    if (generationId == null) {
      throw StateError('Native WebView has not been created.');
    }
    return generationId;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('Native WebView has been disposed.');
    }
  }
}

final class _CleanupErrors {
  Object? _error;
  StackTrace? _stackTrace;

  bool get hasError => _error != null;

  Future<void> run(FutureOr<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      capture(error, stackTrace);
    }
  }

  void capture(Object error, StackTrace stackTrace) {
    _error ??= error;
    _stackTrace ??= stackTrace;
  }

  Never throwFirst() {
    Error.throwWithStackTrace(_error!, _stackTrace!);
  }
}
