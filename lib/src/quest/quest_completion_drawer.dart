import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/top_notice.dart';

/// Shares completion notices between the workspace and its header slot.
class QuestCompletionDrawerHost extends StatefulWidget {
  const QuestCompletionDrawerHost({
    super.key,
    required this.child,
    this.controller,
    this.fullscreen = false,
    this.nativeQuestOverlay = false,
  });
  final Widget child;
  final TopNoticeController? controller;
  final bool fullscreen;
  final bool nativeQuestOverlay;

  static void show(
    BuildContext context,
    String message, {
    TopNoticeTone tone = TopNoticeTone.quest,
    IconData? icon,
    Color? color,
    Duration? duration,
    Duration appendWithin = Duration.zero,
  }) {
    context.getInheritedWidgetOfExactType<_DrawerScope>()?.notifier?.show(
      message: message,
      tone: tone,
      customIcon: icon,
      customColor: color,
      duration: duration ?? const Duration(seconds: 5),
      appendWithin: appendWithin,
    );
  }

  static void hide(BuildContext context) {
    context.getInheritedWidgetOfExactType<_DrawerScope>()?.notifier?.hide();
  }

  static void removeQuestNotices(BuildContext context) {
    context
        .getInheritedWidgetOfExactType<_DrawerScope>()
        ?.notifier
        ?.removeByTone(TopNoticeTone.quest);
  }

  @override
  State<QuestCompletionDrawerHost> createState() =>
      _QuestCompletionDrawerHostState();
}

class _QuestCompletionDrawerHostState extends State<QuestCompletionDrawerHost> {
  static const _nativeChannel = MethodChannel(
    'app.yahagi.kancollebrowser/game_fullscreen',
  );
  late final TopNoticeController _controller;
  bool _ownsController = false;
  Future<void> _nativeNoticeQueue = Future<void>.value();
  String? _lastNativeMessage;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TopNoticeController();
      _ownsController = true;
    }
    _controller.addListener(_syncNativeNotice);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncNativeNotice());
  }

  @override
  void didUpdateWidget(QuestCompletionDrawerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullscreen != widget.fullscreen ||
        oldWidget.nativeQuestOverlay != widget.nativeQuestOverlay) {
      _syncNativeNotice();
    }
  }

  void _syncNativeNotice() {
    if (!widget.nativeQuestOverlay) return;
    final message = widget.fullscreen
        ? _controller.notices
              .where((notice) => notice.tone == TopNoticeTone.quest)
              .map((notice) => notice.message)
              .join('\n')
        : '';
    if (message == _lastNativeMessage) return;
    _lastNativeMessage = message;
    _nativeNoticeQueue = _nativeNoticeQueue.then((_) async {
      try {
        await _nativeChannel.invokeMethod<void>('questNotice', {
          'message': message,
        });
      } catch (_) {
        // Flutter's notice remains available outside the native game overlay.
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_syncNativeNotice);
    if (widget.nativeQuestOverlay) {
      unawaited(
        _nativeNoticeQueue.then((_) async {
          try {
            await _nativeChannel.invokeMethod<void>('questNotice', {
              'message': '',
            });
          } catch (_) {}
        }),
      );
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DrawerScope(
    notifier: _controller,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.fullscreen && !widget.nativeQuestOverlay)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 44,
            child: QuestCompletionHeaderSlot(child: SizedBox.shrink()),
          ),
      ],
    ),
  );
}

/// Uses the same header space as the toolbar beside the Yahagi brand button.
/// Task completion stays visible even while the game toolbar is expanded.
class QuestCompletionHeaderSlot extends StatelessWidget {
  const QuestCompletionHeaderSlot({
    super.key,
    required this.child,
    this.toolbarVisible = false,
  });
  final Widget child;
  final bool toolbarVisible;

  static IconData iconFor(TopNoticeData notice) {
    if (notice.customIcon != null) return notice.customIcon!;
    return switch (notice.tone) {
      TopNoticeTone.neutral => Icons.info_outline_rounded,
      TopNoticeTone.success => Icons.check_circle_outline_rounded,
      TopNoticeTone.error => Icons.error_outline_rounded,
      TopNoticeTone.warning => Icons.warning_amber_rounded,
      TopNoticeTone.info => Icons.insights_rounded,
      TopNoticeTone.quest => Icons.assignment_turned_in_outlined,
      TopNoticeTone.marriage => Icons.favorite_rounded,
    };
  }

  static Color colorFor(TopNoticeData notice) {
    if (notice.customColor != null) return notice.customColor!;
    return switch (notice.tone) {
      TopNoticeTone.neutral => const Color(0xff8da4b5),
      TopNoticeTone.success => const Color(0xff34d399),
      TopNoticeTone.error => const Color(0xfff87171),
      TopNoticeTone.warning => const Color(0xfffbbf24),
      TopNoticeTone.info => const Color(0xff38bdf8),
      TopNoticeTone.quest => const Color(0xffd4a85f),
      TopNoticeTone.marriage => const Color(0xfff472b6),
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = context
        .dependOnInheritedWidgetOfExactType<_DrawerScope>()
        ?.notifier;
    final notices = controller?.notices ?? const <TopNoticeData>[];
    final visible =
        notices.isNotEmpty &&
        (!toolbarVisible ||
            notices.any((notice) => notice.tone == TopNoticeTone.quest));

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        IgnorePointer(
          ignoring: visible,
          child: AnimatedOpacity(
            opacity: visible ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: child,
          ),
        ),
        IgnorePointer(
          ignoring: !visible,
          child: !visible
              ? const SizedBox.shrink()
              : ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    reverseDuration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(-0.2, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                    child: Semantics(
                      key: const Key('quest-completion-drawer'),
                      liveRegion: true,
                      button: true,
                      child: KeyedSubtree(
                        // Appending preserves position; a new batch starts at
                        // its first message instead of inheriting old offset.
                        key: ValueKey(notices.first.id),
                        child: SingleChildScrollView(
                          key: const Key('header-notice-scroll'),
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var index = 0;
                                index < notices.length;
                                index++
                              ) ...[
                                if (index > 0) const SizedBox(width: 6),
                                _HeaderNoticeCapsule(
                                  notice: notices[index],
                                  onTap: controller?.hide,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _HeaderNoticeCapsule extends StatelessWidget {
  const _HeaderNoticeCapsule({required this.notice, this.onTap});

  final TopNoticeData notice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = QuestCompletionHeaderSlot.colorFor(notice);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xff0a1622).withValues(alpha: 0.92),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              QuestCompletionHeaderSlot.iconFor(notice),
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              notice.message,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xffe0e6e9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerScope extends InheritedNotifier<TopNoticeController> {
  const _DrawerScope({required super.notifier, required super.child});
}
