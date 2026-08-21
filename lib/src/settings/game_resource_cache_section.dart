import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/game_resource_cache_channel.dart';
import '../browser/game_resource_cache_controller.dart';
import '../browser/game_resource_cache_store.dart';
import '../widgets/top_notice.dart';

class GameResourceCacheSection extends StatefulWidget {
  const GameResourceCacheSection({super.key, required this.controller});

  final GameResourceCacheController controller;

  @override
  State<GameResourceCacheSection> createState() =>
      _GameResourceCacheSectionState();
}

class _GameResourceCacheSectionState extends State<GameResourceCacheSection> {
  bool _integrityChecked = false;

  @override
  void initState() {
    super.initState();
    widget.controller.setPageVisible(true);
  }

  @override
  void didUpdateWidget(GameResourceCacheSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.setPageVisible(false);
    widget.controller.setPageVisible(true);
  }

  @override
  void dispose() {
    widget.controller.setPageVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final status = controller.status;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _modeTile(
              mode: GameResourceCacheMode.none,
              title: l10n.gameResourceCacheNone,
              subtitle: l10n.gameResourceCacheNoneDesc,
            ),
            const Divider(color: Color(0xff294052), height: 1),
            _modeTile(
              mode: GameResourceCacheMode.full,
              title: l10n.gameResourceCacheFull,
              subtitle: l10n.gameResourceCacheFullDesc,
            ),
            const Divider(color: Color(0xff294052), height: 1),
            if (status.capacityBlocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.gameResourceCacheCapacityBlocked,
                  style: const TextStyle(color: Color(0xffffb4a9)),
                ),
              ),
            if (status.waitingForWifi)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.gameResourceCacheWaitingForWifi,
                  style: const TextStyle(color: Color(0xff9bc7e4)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    controller.completenessLine,
                    key: const Key('cache-completeness-line'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (controller.mode != GameResourceCacheMode.none)
                    FilledButton.icon(
                      key: const Key('cache-download-toggle'),
                      onPressed: controller.busy
                          ? null
                          : () =>
                                status.state ==
                                    GameResourceCacheState.downloading
                                ? _run(controller.pauseDownload)
                                : _confirmDownload(l10n),
                      icon: Icon(
                        status.state == GameResourceCacheState.downloading
                            ? Icons.pause
                            : Icons.download,
                      ),
                      label: Text(switch (status.state) {
                        GameResourceCacheState.downloading =>
                          l10n.gameResourceCachePause,
                        GameResourceCacheState.paused =>
                          l10n.gameResourceCacheResume,
                        _ => l10n.gameResourceCacheStart,
                      }),
                    ),
                  OutlinedButton.icon(
                    key: const Key('cache-check-integrity'),
                    onPressed: controller.busy ? null : _checkIntegrity,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(l10n.gameResourceCacheCheck),
                  ),
                  if (_integrityChecked &&
                      (status.missingCount > 0 ||
                          status.damagedCount > 0 ||
                          status.outdatedCount > 0))
                    OutlinedButton.icon(
                      key: const Key('cache-repair'),
                      onPressed: controller.busy
                          ? null
                          : () => _confirmRepair(l10n),
                      icon: const Icon(Icons.build_outlined),
                      label: Text(l10n.gameResourceCacheRepair),
                    ),
                  TextButton.icon(
                    key: const Key('cache-clear'),
                    onPressed: controller.busy
                        ? null
                        : () => _confirmClear(l10n),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.gameResourceCacheClear),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _modeTile({
    required GameResourceCacheMode mode,
    required String title,
    required String subtitle,
  }) {
    final selected = widget.controller.mode == mode;
    return InkWell(
      key: Key('cache-mode-${mode.name}'),
      onTap: widget.controller.busy || selected
          ? null
          : () => widget.controller.setMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff8197a5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? const Color(0xff70c7bc)
                  : const Color(0xff8197a5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkIntegrity() async {
    await widget.controller.checkIntegrity();
    if (mounted) setState(() => _integrityChecked = true);
  }

  Future<void> _confirmDownload(AppLocalizations l10n) async {
    final isMetered = widget.controller.status.isMetered;
    final confirmed = await _confirm(
      title: l10n.gameResourceCacheDownloadConfirmTitle,
      description: isMetered
          ? l10n.gameResourceCacheMobileConfirmDesc
          : l10n.gameResourceCacheDownloadConfirmDesc,
      confirmLabel: l10n.confirm,
    );
    if (confirmed) {
      await _run(
        () => widget.controller.startDownload(allowMetered: isMetered),
      );
    }
  }

  Future<void> _confirmRepair(AppLocalizations l10n) async {
    final isMetered = widget.controller.status.isMetered;
    if (isMetered) {
      final confirmed = await _confirm(
        title: l10n.gameResourceCacheDownloadConfirmTitle,
        description: l10n.gameResourceCacheMobileConfirmDesc,
        confirmLabel: l10n.confirm,
      );
      if (!confirmed) return;
    }
    await _run(() => widget.controller.repair(allowMetered: isMetered));
  }

  Future<void> _confirmClear(AppLocalizations l10n) async {
    final confirmed = await _confirm(
      title: l10n.gameResourceCacheClearConfirmTitle,
      description: l10n.gameResourceCacheClearConfirmDesc,
      confirmLabel: l10n.gameResourceCacheClear,
    );
    if (confirmed) {
      await _run(widget.controller.clear);
      if (mounted) setState(() => _integrityChecked = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String description,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                (AppLocalizations.of(context) ??
                        lookupAppLocalizations(const Locale('zh')))
                    .cancel,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<bool> Function() action) async {
    final succeeded = await action();
    if (!succeeded && mounted) {
      final l10n =
          AppLocalizations.of(context) ??
          lookupAppLocalizations(const Locale('zh'));
      TopNotice.show(
        context,
        message: l10n.gameResourceCacheActionFailed,
        tone: TopNoticeTone.error,
      );
    }
  }
}
