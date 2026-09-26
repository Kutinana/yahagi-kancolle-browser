import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import 'game_fullscreen_exit_dialog.dart';

const fullscreenExitSize = Size(34, 34);
const _positionKey = 'game_fullscreen_exit_position';

/// Range of allowed top-left positions, expanding near screen edges.
Rect fullscreenExitArea(Size size, [EdgeInsets insets = EdgeInsets.zero]) {
  final left = insets.left;
  final top = insets.top;
  return Rect.fromLTRB(
    left,
    top,
    math.max(left, size.width - insets.right - fullscreenExitSize.width),
    math.max(top, size.height - insets.bottom - fullscreenExitSize.height),
  );
}

Rect fullscreenExitRect(Rect area, Offset? anchor) => Rect.fromLTWH(
  area.left + area.width * (anchor?.dx ?? 1).clamp(0.0, 1.0),
  area.top + area.height * (anchor?.dy ?? 0).clamp(0.0, 1.0),
  fullscreenExitSize.width,
  fullscreenExitSize.height,
);

Offset snapFullscreenExit(Rect area, Offset position) {
  var x = position.dx.clamp(area.left, area.right).toDouble();
  var y = position.dy.clamp(area.top, area.bottom).toDouble();
  final distances = [
    x - area.left,
    area.right - x,
    y - area.top,
    area.bottom - y,
  ];
  switch (distances.indexOf(distances.reduce(math.min))) {
    case 0:
      x = area.left;
    case 1:
      x = area.right;
    case 2:
      y = area.top;
    case 3:
      y = area.bottom;
  }
  return Offset(
    area.width == 0 ? 1 : (x - area.left) / area.width,
    area.height == 0 ? 0 : (y - area.top) / area.height,
  );
}

/// Android needs a native control above the Activity-owned WebView. Other
/// platforms use the same geometry and gestures in Flutter.
class GameFullscreenControls extends StatefulWidget {
  const GameFullscreenControls({
    super.key,
    required this.active,
    required this.onExit,
    required this.child,
    this.useNativeOverlay = false,
    this.onUnavailable,
    this.confirmExit,
  });

  final bool active;
  final VoidCallback onExit;
  final Widget child;
  final bool useNativeOverlay;
  final VoidCallback? onUnavailable;
  final Future<bool> Function(BuildContext context)? confirmExit;

  @override
  State<GameFullscreenControls> createState() => _GameFullscreenControlsState();
}

class _GameFullscreenControlsState extends State<GameFullscreenControls> {
  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/game_fullscreen',
  );
  Offset? _anchor;
  Offset? _dragPosition;
  Rect _area = Rect.zero;
  bool _positionChanged = false;
  bool _hintShown = false;
  bool _showHint = false;
  Timer? _hintTimer;
  Map<String, Object>? _lastNativeConfig;
  Future<void> _nativeQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    unawaited(_loadPosition());
    if (widget.useNativeOverlay) _channel.setMethodCallHandler(_onNativeEvent);
    _startHint();
  }

  Future<void> _loadPosition() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getStringList(
        _positionKey,
      );
      if (!mounted || _positionChanged || saved == null || saved.length != 2) {
        return;
      }
      final x = double.tryParse(saved[0]);
      final y = double.tryParse(saved[1]);
      if (x == null || y == null || !x.isFinite || !y.isFinite) return;
      setState(() => _anchor = Offset(x.clamp(0, 1), y.clamp(0, 1)));
    } catch (_) {
      // A settings read failure must never prevent exiting fullscreen.
    }
  }

  Future<void> _savePosition(Offset anchor) async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(
        _positionKey,
        ['${anchor.dx}', '${anchor.dy}'],
      );
    } catch (_) {
      // Keep the new position for this session when persistence is unavailable.
    }
  }

  void _finishDrag(Offset position) {
    final anchor = snapFullscreenExit(_area, position);
    setState(() {
      _positionChanged = true;
      _anchor = anchor;
      _dragPosition = null;
    });
    unawaited(_savePosition(anchor));
  }

  bool _confirmingExit = false;

  Future<void> _handleExit() async {
    if (!mounted || !widget.active || _confirmingExit) return;
    _confirmingExit = true;
    try {
      final confirm =
          widget.confirmExit ??
          (ctx) => confirmGameFullscreenExit(context: ctx);
      final confirmed = await confirm(context);
      if (confirmed && mounted && widget.active) {
        widget.onExit();
      }
    } finally {
      if (mounted) {
        setState(() => _confirmingExit = false);
      } else {
        _confirmingExit = false;
      }
    }
  }

  Future<void> _onNativeEvent(MethodCall call) async {
    if (!mounted || !widget.active) return;
    if (call.method == 'exit') {
      unawaited(_handleExit());
    } else if (call.method == 'moved') {
      final args = call.arguments;
      if (args is Map && args['x'] is num && args['y'] is num) {
        final position = Offset(
          (args['x'] as num).toDouble(),
          (args['y'] as num).toDouble(),
        );
        if (position.dx.isFinite && position.dy.isFinite) _finishDrag(position);
      }
    }
  }

  void _startHint() {
    if (!widget.active || _hintShown) return;
    _hintShown = true;
    _showHint = true;
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void didUpdateWidget(GameFullscreenControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      _dragPosition = null;
      _showHint = false;
      _hintTimer?.cancel();
    }
    _startHint();
  }

  void _syncNative(Map<String, Object> config) {
    if (mapEquals(config, _lastNativeConfig)) return;
    _lastNativeConfig = config;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nativeQueue = _nativeQueue.then((_) async {
        if (!mounted) return;
        try {
          await _channel.invokeMethod<void>('update', config);
        } catch (_) {
          if (mounted &&
              widget.active &&
              identical(config, _lastNativeConfig)) {
            // Do not leave the player fullscreen with an inaccessible control.
            (widget.onUnavailable ?? widget.onExit)();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    if (widget.useNativeOverlay) {
      _channel.setMethodCallHandler(null);
      unawaited(
        _nativeQueue
            .then(
              (_) => _channel.invokeMethod<void>('update', {'active': false}),
            )
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final media = MediaQuery.of(context);
    final insets = EdgeInsets.fromLTRB(
      media.viewPadding.left,
      media.viewPadding.top,
      media.viewPadding.right,
      math.max(media.viewPadding.bottom, media.viewInsets.bottom),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        _area = fullscreenExitArea(constraints.biggest, insets);
        final rect = fullscreenExitRect(_area, _anchor);
        final clampedDrag = _dragPosition != null
            ? Offset(
                _dragPosition!.dx.clamp(_area.left, _area.right),
                _dragPosition!.dy.clamp(_area.top, _area.bottom),
              )
            : null;
        final position = clampedDrag ?? rect.topLeft;
        if (widget.useNativeOverlay) {
          _syncNative({
            'active': widget.active,
            'x': position.dx,
            'y': position.dy,
            'width': rect.width,
            'height': rect.height,
            'minX': _area.left,
            'maxX': _area.right,
            'minY': _area.top,
            'maxY': _area.bottom,
            'scale': media.devicePixelRatio,
            'label': l10n.exitFullscreenShort,
            'description': l10n.exitGameFullscreen,
            'hint': _showHint ? l10n.gameFullscreenHint : '',
          });
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (widget.active && !widget.useNativeOverlay) ...[
              if (_showHint)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 64,
                  child: IgnorePointer(
                    child: Center(
                      child: Material(
                        color: const Color(0xe6122431),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            l10n.gameFullscreenHint,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: position.dx,
                top: position.dy,
                width: rect.width,
                height: rect.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) =>
                      setState(() => _dragPosition = rect.topLeft),
                  onPanUpdate: (details) => setState(() {
                    final next =
                        (_dragPosition ?? rect.topLeft) + details.delta;
                    _dragPosition = Offset(
                      next.dx.clamp(_area.left, _area.right),
                      next.dy.clamp(_area.top, _area.bottom),
                    );
                  }),
                  onPanEnd: (_) => _finishDrag(_dragPosition ?? rect.topLeft),
                  onPanCancel: () => setState(() => _dragPosition = null),
                  child: Tooltip(
                    message: l10n.exitGameFullscreen,
                    child: Material(
                      color: const Color(0xcc122431),
                      shape: const CircleBorder(
                        side: BorderSide(color: Color(0x668197a5)),
                      ),
                      child: InkWell(
                        key: const Key('game-exit-fullscreen'),
                        customBorder: const CircleBorder(),
                        onTap: _handleExit,
                        child: Semantics(
                          label: l10n.exitGameFullscreen,
                          button: true,
                          excludeSemantics: true,
                          child: const Center(
                            child: Icon(
                              Icons.fullscreen_exit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
