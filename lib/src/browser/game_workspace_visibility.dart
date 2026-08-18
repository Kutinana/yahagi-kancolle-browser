import 'package:flutter/widgets.dart';

/// Marks whether the game workspace is currently selected in the shell.
///
/// Native platform views live outside Flutter's render tree, so [Offstage]
/// alone cannot hide them. The native surface slot observes this inherited
/// flag and mirrors it into the native WebView visibility state.
class GameWorkspaceActive extends InheritedWidget {
  const GameWorkspaceActive({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GameWorkspaceActive>()
          ?.active ??
      true;

  @override
  bool updateShouldNotify(GameWorkspaceActive oldWidget) =>
      active != oldWidget.active;
}
