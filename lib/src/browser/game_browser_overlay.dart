import 'package:flutter/material.dart';

import 'game_toolbar_controller.dart';

class GameBrowserOverlay extends StatelessWidget {
  const GameBrowserOverlay({
    super.key,
    required this.controller,
    required this.gameSurface,
    this.toolbar,
    this.persistent = false,
  });

  final GameToolbarController controller;
  final Widget gameSurface;
  final Widget? toolbar;
  final bool persistent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('game-browser-overlay'),
      color: const Color(0xff102431),
      child: gameSurface,
    );
  }
}
