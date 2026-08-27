import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../capture/raw_data_server_controller.dart';

class RawDataSection extends StatelessWidget {
  const RawDataSection({super.key, required this.controller});

  final RawDataServerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isRunning = controller.isRunning;
        final serverUrl = controller.serverUrl;
        final hasFile = controller.fileSizeBytes > 0;
        final fileSize = controller.fileSizeFormatted;
        final lastTimeStr = controller.lastCapturedAt == null
            ? '暂无记录'
            : controller.lastCapturedAt!.toLocal().toString().split('.')[0];

        return Column(
          children: [
            ListTile(
              title: const Text('全量图鉴原始数据', style: TextStyle(fontSize: 15)),
              subtitle: Text(
                hasFile
                    ? '已捕获 api_start2 ($fileSize)\n捕获时间: $lastTimeStr'
                    : '未捕获原始图鉴数据 (请登录游戏加载大厅自动捕获)',
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
            SwitchListTile(
              title: const Text('开启局域网下载服务', style: TextStyle(fontSize: 15)),
              subtitle: Text(
                isRunning
                    ? '局域网服务运行中 (端口 ${controller.port})'
                    : '在局域网内开放 8080 端口，供电脑/其他设备下载 JSON',
                style: TextStyle(
                  color: isRunning
                      ? const Color(0xff4B9FD5)
                      : const Color(0xff8197a5),
                ),
              ),
              value: isRunning,
              onChanged: (_) => controller.toggleServer(),
            ),
            if (isRunning && serverUrl != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff0d1a26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xff294052)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '下载服务器访问地址：',
                      style: TextStyle(color: Color(0xff8197a5), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            serverUrl,
                            style: const TextStyle(
                              color: Color(0xffd4a85f),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Color(0xffd4a85f),
                            size: 20,
                          ),
                          tooltip: '复制链接',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: serverUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已复制局域网下载链接到剪贴板'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '在同一 Wi-Fi 下的电脑或设备打开浏览器访问该链接，即可直接下载 api_start2_raw.json 原始文件。',
                      style: TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (controller.statusMessage case final msg?) ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  msg,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
            const Divider(color: Color(0xff294052), height: 1),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_special_outlined,
                    color: Color(0xff8197a5),
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'iOS 用户亦可在【文件】App -> 在我的 iPhone -> ヤハギ 目录下直接找到 api_start2_raw.json 文件。',
                      style: TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
