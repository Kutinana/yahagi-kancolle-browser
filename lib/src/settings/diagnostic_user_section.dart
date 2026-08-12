import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../diagnostics/diagnostic_controller.dart';

class DiagnosticUserSection extends StatelessWidget {
  const DiagnosticUserSection({super.key, required this.controller});

  final DiagnosticController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  controller.enabled ? Icons.shield_outlined : Icons.shield,
                  color: const Color(0xffd4a85f),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.enabled
                        ? l10n.diagnosticStatusEnabled
                        : l10n.diagnosticStatusDisabled,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.diagnosticPrivacyDesc,
              style: const TextStyle(color: Color(0xff9bb0bd), height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.diagnosticStorageUsage(
                _formatBytes(controller.storageBytes),
              ),
              style: const TextStyle(color: Color(0xff8197a5)),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('exportDiagnosticFileButton'),
              onPressed: controller.exporting
                  ? null
                  : () => _confirmExport(context, l10n),
              icon: controller.exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_outlined),
              label: Text(l10n.exportDiagnosticFile),
            ),
            TextButton.icon(
              key: const Key('clearDiagnosticDataButton'),
              onPressed: () => _confirmClear(context, l10n),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.clearDiagnosticData),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExport(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diagnosticExportConfirmTitle),
        content: Text(l10n.diagnosticExportConfirmDesc),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.diagnosticExportAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.export();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.diagnosticExportFailed)));
      }
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diagnosticClearConfirmTitle),
        content: Text(l10n.diagnosticClearConfirmDesc),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.clearDiagnosticData),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clear();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
