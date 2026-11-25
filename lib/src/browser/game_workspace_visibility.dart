import 'package:flutter/material.dart';

/// Allows a platform surface to stay in its window under another workspace.
/// WebKit can defer media recovery when its view leaves the window.
class GameWorkspaceSurfacePolicy extends InheritedWidget {
  const GameWorkspaceSurfacePolicy({
    super.key,
    required this.keepInWindow,
    required super.child,
  });

  final bool keepInWindow;

  static bool keepInWindowOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GameWorkspaceSurfacePolicy>()
          ?.keepInWindow ??
      false;

  @override
  bool updateShouldNotify(GameWorkspaceSurfacePolicy oldWidget) =>
      keepInWindow != oldWidget.keepInWindow;
}

/// Hides the game while preserving the platform's media lifecycle policy.
class GameWorkspaceOffstage extends StatelessWidget {
  const GameWorkspaceOffstage({
    super.key,
    required this.offstage,
    required this.child,
  });

  final bool offstage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!GameWorkspaceSurfacePolicy.keepInWindowOf(context)) {
      return Offstage(offstage: offstage, child: child);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: offstage,
          child: ExcludeSemantics(
            excluding: offstage,
            child: IgnorePointer(ignoring: offstage, child: child),
          ),
        ),
        if (offstage)
          ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
      ],
    );
  }
}

/// Marks whether the game workspace is currently selected in the shell.
///
/// Native surface slots mirror this flag into their visibility state. An iOS
/// WebView can remain covered in its window for audio while this stays false.
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
