import 'package:flutter/material.dart';
import '../capture/raw_data_server_controller.dart';
import '../widgets/top_notice.dart';

class RawDataSection extends StatelessWidget {
  const RawDataSection({super.key, required this.controller});

  final RawDataServerController controller;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff142735),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('删除原始图鉴数据？', style: TextStyle(fontSize: 17)),
        content: const Text(
          '删除后本地保存的 api_start2_raw.json 将被移除。后续在游戏中重新进入大厅可自动再次捕获。',
          style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xffa0b6c4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: Color(0xff8197a5))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await controller.deleteRawMasterData();
      if (context.mounted) {
        TopNotice.show(
          context,
          message: success ? '已删除本地 api_start2 原始数据' : '删除失败',
          tone: success ? TopNoticeTone.success : TopNoticeTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasFile = controller.fileSizeBytes > 0;
        final fileSize = controller.fileSizeFormatted;
        final lastTimeStr = controller.lastCapturedAt == null
            ? '暂无记录'
            : controller.lastCapturedAt!.toLocal().toString().split('.')[0];

        return Column(
          children: [
            ListTile(
              title: const Text('全量图鉴原始数据 (Master Data)', style: TextStyle(fontSize: 15)),
              subtitle: Text(
                hasFile
                    ? '已捕获 api_start2 ($fileSize)\n捕获时间: $lastTimeStr'
                    : '未捕获原始图鉴数据 (在开发者模式下登录游戏加载大厅时自动捕获)',
                style: const TextStyle(color: Color(0xff8197a5), height: 1.4),
              ),
              trailing: Icon(
                hasFile ? Icons.check_circle_outline : Icons.pending_outlined,
                color: hasFile
                    ? const Color(0xff4B9FD5)
                    : const Color(0xff8197a5),
              ),
            ),
            const Divider(color: Color(0xff294052), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    color: Color(0xffd4a85f),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '文件已保存在应用文档目录。\n可在 iOS【文件】App ->【在我的 iPhone】->【ヤハギ】中找到 api_start2_raw.json 文件直接拷贝或隔空投送。',
                      style: TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (hasFile) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      tooltip: '删除本地数据',
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ],
              ),
            ),
            if (controller.statusMessage case final msg?) ...[
              const Divider(color: Color(0xff294052), height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  msg,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
