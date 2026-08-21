import 'dart:async';

import 'package:flutter/material.dart';

enum TopNoticeTone { neutral, success, error }

const topNoticeKey = Key('top-notice');
const topNoticeTextKey = Key('top-notice-text');

@immutable
class TopNoticeData {
  const TopNoticeData({
    required this.id,
    required this.message,
    required this.tone,
  });

  final int id;
  final String message;
  final TopNoticeTone tone;
}

class TopNoticeController extends ChangeNotifier {
  TopNoticeData? get current => _current;

  TopNoticeData? _current;
  Timer? _timer;
  int _nextId = 0;

  void show({
    required String message,
    TopNoticeTone tone = TopNoticeTone.neutral,
    Duration duration = const Duration(seconds: 4),
  }) {
    _timer?.cancel();
    final id = _nextId++;
    _current = TopNoticeData(id: id, message: message, tone: tone);
    notifyListeners();
    _timer = Timer(duration, () {
      if (_current?.id != id) {
        return;
      }
      _timer = null;
      _current = null;
      notifyListeners();
    });
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    if (_current == null) {
      return;
    }
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

abstract final class TopNotice {
  static void show(
    BuildContext context, {
    required String message,
    TopNoticeTone tone = TopNoticeTone.neutral,
    Duration duration = const Duration(seconds: 4),
  }) {
    _controllerOf(
      context,
    )?.show(message: message, tone: tone, duration: duration);
  }

  static void hide(BuildContext context) {
    _controllerOf(context)?.hide();
  }

  static TopNoticeController? _controllerOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_TopNoticeScope>();
    assert(
      scope != null,
      'TopNotice requires a TopNoticeHost above the supplied BuildContext.',
    );
    return scope?.notifier;
  }
}

class TopNoticeHost extends StatefulWidget {
  const TopNoticeHost({super.key, required this.child});

  final Widget child;

  @override
  State<TopNoticeHost> createState() => _TopNoticeHostState();
}

class _TopNoticeHostState extends State<TopNoticeHost> {
  late final TopNoticeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TopNoticeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TopNoticeScope(
      notifier: _controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final notice = _controller.current;
              return Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 720,
                        minHeight: 36,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        reverseDuration: const Duration(milliseconds: 140),
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: notice == null
                                ? [...previousChildren, ?currentChild]
                                : [?currentChild],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            alwaysIncludeSemantics: true,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -0.25),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: notice == null
                            ? const SizedBox.shrink(
                                key: ValueKey('top-notice-empty'),
                              )
                            : _NoticeCapsule(
                                key: const ValueKey('top-notice-visible'),
                                notice: notice,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopNoticeScope extends InheritedNotifier<TopNoticeController> {
  const _TopNoticeScope({required super.notifier, required super.child});
}

class _NoticeCapsule extends StatelessWidget {
  const _NoticeCapsule({super.key, required this.notice});

  final TopNoticeData notice;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(notice.tone);
    return Semantics(
      key: topNoticeKey,
      container: true,
      liveRegion: true,
      label: notice.message,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(palette.icon, size: 20, color: palette.foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    notice.message,
                    key: topNoticeTextKey,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

_TopNoticePalette _paletteFor(TopNoticeTone tone) {
  return switch (tone) {
    TopNoticeTone.neutral => const _TopNoticePalette(
      background: Color(0xff1a3447),
      border: Color(0xff3c586b),
      foreground: Colors.white,
      icon: Icons.info_outline_rounded,
    ),
    TopNoticeTone.success => const _TopNoticePalette(
      background: Color(0xff173d3b),
      border: Color(0xff4fa79b),
      foreground: Color(0xffb9f1e8),
      icon: Icons.check_circle_outline_rounded,
    ),
    TopNoticeTone.error => const _TopNoticePalette(
      background: Color(0xff54292d),
      border: Color(0xff9b464c),
      foreground: Color(0xffffaaa4),
      icon: Icons.error_outline_rounded,
    ),
  };
}

@immutable
class _TopNoticePalette {
  const _TopNoticePalette({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}
