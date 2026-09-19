import 'package:flutter/material.dart';

import '../toolbox/sortie_map_query/enemy_catalog_controller.dart';
import '../toolbox/sortie_map_query/enemy_catalog_update_service.dart';

final class EnemyCatalogUpdateSection extends StatelessWidget {
  const EnemyCatalogUpdateSection({super.key, required this.controller});

  final EnemyCatalogController controller;

  @override
  Widget build(BuildContext context) {
    final japanese = Localizations.localeOf(context).languageCode == 'ja';
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    japanese ? '敵艦資料' : '敌舰资料',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${japanese ? 'バージョン' : '版本'}：${controller.data.dataVersion} · '
                    '${controller.data.ships.length}${japanese ? '件' : ' 条配置'} · '
                    '${controller.usesCachedData ? (japanese ? '更新済み' : '已更新') : (japanese ? '内蔵' : '内置')}',
                    style: const TextStyle(color: Color(0xff8197a5)),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('enemy-catalog-check-button'),
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
      EnemyCatalogUpToDate() =>
        japanese ? '敵艦資料は最新版です。\nバージョン：$after' : '敌舰资料已是最新版本。\n版本：$after',
      EnemyCatalogUpdated() =>
        japanese
            ? '敵艦資料を更新しました。\n$before → $after'
            : '敌舰资料更新成功。\n$before → $after',
      EnemyCatalogUpdateFailed(kind: EnemyCatalogUpdateFailure.incompatible) =>
        japanese ? 'アプリを更新してから再試行してください。' : '当前应用版本过低，请先更新应用。',
      EnemyCatalogUpdateFailed(kind: EnemyCatalogUpdateFailure.storage) =>
        japanese ? '更新データを保存できませんでした。' : '无法保存更新资料。',
      EnemyCatalogUpdateFailed(kind: EnemyCatalogUpdateFailure.validation) =>
        japanese ? '更新データの検証に失敗しました。' : '更新资料校验失败，已继续使用当前资料。',
      EnemyCatalogUpdateFailed() =>
        japanese ? 'ネットワーク更新に失敗しました。' : '网络更新失败，请稍后重试。',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(japanese ? '敵艦資料' : '敌舰资料'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(japanese ? '確認' : '确定'),
          ),
        ],
      ),
    );
  }
}
