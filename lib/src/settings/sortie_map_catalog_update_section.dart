import 'package:flutter/material.dart';

import 'data_update_metadata.dart';

import '../toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import '../toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';

final class SortieMapCatalogUpdateSection extends StatelessWidget {
  const SortieMapCatalogUpdateSection({super.key, required this.controller});

  final SortieMapCatalogController controller;

  @override
  Widget build(BuildContext context) {
    final japanese = Localizations.localeOf(context).languageCode == 'ja';
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    japanese ? '海域資料' : '海域资料',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DataUpdateMetadata(
                    version: controller.data.dataVersion,
                    lastCheckedAt: controller.lastCheckedAt,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              key: const Key('sortie-map-catalog-check-button'),
              tooltip: japanese ? '更新を確認' : '检查更新',
              onPressed: controller.isChecking
                  ? null
                  : () => _check(context, japanese),
              icon: controller.isChecking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, color: Color(0xffd4a85f)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _check(BuildContext context, bool japanese) async {
    final before = controller.data.dataVersion;
    final result = await controller.checkForUpdates();
    if (!context.mounted) return;
    final after = controller.data.dataVersion;
    final message = switch (result) {
      SortieMapCatalogUpToDate() =>
        japanese ? '海域資料は最新版です。\nバージョン：$after' : '海域资料已是最新版本。\n版本：$after',
      SortieMapCatalogUpdated() =>
        japanese
            ? '海域資料を更新しました。\n$before → $after'
            : '海域资料更新成功。\n$before → $after',
      SortieMapCatalogUpdateFailed(
        kind: SortieMapCatalogUpdateFailure.incompatible,
      ) =>
        japanese ? 'アプリを更新してから、もう一度お試しください。' : '当前应用版本过低，请先更新应用。',
      SortieMapCatalogUpdateFailed(
        kind: SortieMapCatalogUpdateFailure.validation,
      ) =>
        japanese ? '更新データの検証に失敗しました。現在のデータを継続使用します。' : '更新资料校验失败，已继续使用当前资料。',
      SortieMapCatalogUpdateFailed(
        kind: SortieMapCatalogUpdateFailure.storage,
      ) =>
        japanese ? '更新データを保存できませんでした。' : '无法保存更新资料。',
      SortieMapCatalogUpdateFailed() =>
        japanese ? 'ネットワーク更新に失敗しました。' : '网络更新失败，请稍后重试。',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(japanese ? '海域資料' : '海域资料'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(japanese ? '確認' : '确定'),
          ),
        ],
      ),
    );
  }
}
