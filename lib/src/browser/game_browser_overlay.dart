import 'package:flutter/material.dart';

import 'game_toolbar_controller.dart';

class GameBrowserOverlay extends StatefulWidget {
  const GameBrowserOverlay({
    super.key,
    required this.controller,
    required this.gameSurface,
    required this.toolbar,
    this.persistent = false,
  });

  final GameToolbarController controller;
  final Widget gameSurface;
  final Widget toolbar;
  final bool persistent;

  @override
  State<GameBrowserOverlay> createState() => _GameBrowserOverlayState();
}

class _GameBrowserOverlayState extends State<GameBrowserOverlay> {
  static const _minimumVerticalDrag = 36.0;
  static const _maximumHorizontalDrag = 48.0;
  static const _revealGestureEdgeHeight = 48.0;

  double _verticalDrag = 0;
  double _horizontalDrag = 0;
  int? _activePointer;
  bool _gestureRejected = false;
  bool _gestureCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('game-browser-overlay'),
      children: [
        Positioned(
          left: 0,
          top: widget.persistent ? 42 : 0,
          right: 0,
          bottom: 0,
          child: Listener(
            key: const Key('game-toolbar-gesture-surface'),
            behavior: HitTestBehavior.deferToChild,
            onPointerDown: widget.persistent ? null : _onPointerDown,
            onPointerMove: widget.persistent ? null : _onPointerMove,
            onPointerUp: widget.persistent ? null : _onPointerFinished,
            onPointerCancel: widget.persistent ? null : _onPointerFinished,
            child: ColoredBox(
              color: const Color(0xff102431),
              child: widget.gameSurface,
            ),
          ),
        ),
        if (widget.persistent)
          Positioned(
            key: const Key('persistent-game-toolbar-layout'),
            left: 0,
            top: 0,
            right: 0,
            height: 42,
            child: widget.toolbar,
          )
        else
          Positioned.fill(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final isVisible = widget.controller.isVisible;
                return IgnorePointer(
                  key: const Key('game-toolbar-panel'),
                  ignoring: !isVisible,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        top: 8,
                        right: 12,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        reverseDuration: const Duration(milliseconds: 240),
                        transitionBuilder: (child, animation) {
                          final position =
                              Tween<Offset>(
                                begin: const Offset(0, -1.4),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              );
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: position,
                              child: child,
                            ),
                          );
                        },
                        child: isVisible
                            ? ConstrainedBox(
                                key: const Key('game-toolbar-visible'),
                                constraints: const BoxConstraints(
                                  maxWidth: 700,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Listener(
                                    onPointerDown: (_) =>
                                        widget.controller.beginInteraction(),
                                    onPointerUp: (_) =>
                                        widget.controller.endInteraction(),
                                    onPointerCancel: (_) =>
                                        widget.controller.endInteraction(),
                                    child: widget.toolbar,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: Key('game-toolbar-hidden'),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _resetGesture();
    _activePointer = event.pointer;
    _gestureRejected = event.localPosition.dy > _revealGestureEdgeHeight;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (widget.controller.isVisible) return;
    if (_activePointer != event.pointer) return;
    if (_gestureRejected || _gestureCompleted) {
      return;
    }
    _verticalDrag += event.delta.dy;
    _horizontalDrag += event.delta.dx.abs();
    if (_horizontalDrag > _maximumHorizontalDrag) {
      _gestureRejected = true;
      return;
    }
    if (_verticalDrag >= _minimumVerticalDrag) {
      _gestureCompleted = true;
      widget.controller.reveal();
    }
  }

  void _onPointerFinished(PointerEvent event) {
    if (_activePointer != event.pointer) return;
    _resetGesture();
  }

  void _resetGesture() {
    _activePointer = null;
    _verticalDrag = 0;
    _horizontalDrag = 0;
    _gestureRejected = false;
    _gestureCompleted = false;
  }
}
