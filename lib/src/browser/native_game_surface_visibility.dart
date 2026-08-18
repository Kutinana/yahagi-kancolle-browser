import 'dart:async';

/// Coordinates all conditions that determine whether the native game surface
/// may be displayed.
final class NativeGameSurfaceVisibility {
  NativeGameSurfaceVisibility(this._onVisibilityChanged);

  final Future<void> Function(bool visible) _onVisibilityChanged;

  bool _routeVisible = true;
  bool _appVisible = true;
  bool _slotAttached = false;
  bool _lastSentVisible = false;
  Future<void> _tail = Future<void>.value();

  Future<void> setRouteVisible(bool visible) {
    _routeVisible = visible;
    return _reportIfChanged();
  }

  Future<void> setAppVisible(bool visible) {
    _appVisible = visible;
    return _reportIfChanged();
  }

  Future<void> setSlotAttached(bool attached) {
    _slotAttached = attached;
    return _reportIfChanged();
  }

  Future<void> dispose() => setSlotAttached(false);

  Future<void> _reportIfChanged() {
    final visible = _routeVisible && _appVisible && _slotAttached;
    if (visible == _lastSentVisible) {
      return _tail;
    }
    _lastSentVisible = visible;
    final report = _tail
        .catchError((Object _) {})
        .then<void>((_) => _onVisibilityChanged(visible));
    _tail = report.catchError((Object _) {});
    return report;
  }
}
