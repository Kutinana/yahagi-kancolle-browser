import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../notification/notification_port.dart';
import '../settings/notification_settings_controller.dart';
import '../settings/settings_ui_helpers.dart';
import '../theme/app_palette.dart';

String iosNotificationHapticsDescription(BuildContext context) => _text(
  context,
  '通知震动由系统触感策略控制，可在 iOS“设置 → 声音与触感”中调整。',
  '通知震動由系統觸覺回饋策略控制，可在 iOS「設定 → 聲音與觸覺回饋」中調整。',
  '通知の振動はシステムの触覚設定に従います。iOS の「設定 → サウンドと触覚」で調整できます。',
  '알림 진동은 시스템 햅틱 설정을 따릅니다. iOS의 “설정 → 사운드 및 햅틱”에서 조정할 수 있습니다.',
  'Notification vibration follows the system haptics policy. Adjust it in iOS Settings → Sounds & Haptics.',
);

String _text(
  BuildContext context,
  String zh,
  String hant,
  String ja,
  String ko,
  String en,
) => switch (Localizations.localeOf(context)) {
  Locale(languageCode: 'en') => en,
  Locale(languageCode: 'ja') => ja,
  Locale(languageCode: 'ko') => ko,
  Locale(languageCode: 'zh', scriptCode: 'Hant') => hant,
  _ => zh,
};

/// iOS preferences stay on the native bridge so the shared notification schema
/// and Android settings remain unchanged.
class IOSLiveActivitySettingsSection extends StatefulWidget {
  const IOSLiveActivitySettingsSection({
    super.key,
    required this.controller,
    required this.notificationPort,
  });

  final NotificationSettingsController controller;
  final NotificationPort notificationPort;

  @override
  State<IOSLiveActivitySettingsSection> createState() =>
      _IOSLiveActivitySettingsSectionState();
}

class _IOSLiveActivitySettingsSectionState
    extends State<IOSLiveActivitySettingsSection>
    with SettingsUIHelpers, WidgetsBindingObserver {
  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/notification',
  );
  bool _supported = false;
  bool _authorized = false;
  bool _enabled = false;
  bool _busy = true;
  String _kind = 'expedition';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() => _invoke('getLiveActivitySettings');

  Future<void> _invoke(String method, [Map<String, Object>? arguments]) async {
    if (mounted) setState(() => _busy = true);
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      if (!mounted) return;
      setState(() {
        _supported = result?['supported'] == true;
        _authorized = result?['authorized'] == true;
        _enabled = result?['enabled'] == true;
        _kind = result?['kind'] as String? ?? 'expedition';
        _error = result?['error'] as String?;
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } on MissingPluginException {
      if (mounted) setState(() => _supported = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool? enabled, String? kind}) => _invoke(
    'setLiveActivitySettings',
    {'enabled': enabled ?? _enabled, 'kind': kind ?? _kind},
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canChange = !_busy && _supported && widget.controller.settings.master;
    final divider = Divider(
      height: 1,
      color: appColor(context, const Color(0xff294052)),
    );
    final labels = {
      'expedition': l10n.notificationExpedition,
      'repair': l10n.notificationRepair,
      'construction': l10n.notificationConstruction,
    };
    return buildCard(
      child: Column(
        children: [
          buildSwitchTile(
            title: _text(
              context,
              '实时活动与灵动岛',
              '即時動態與動態島',
              'ライブアクティビティとDynamic Island',
              '실시간 현황 및 Dynamic Island',
              'Live Activities & Dynamic Island',
            ),
            subtitle: !_busy && !_supported
                ? _text(
                    context,
                    '需要 iPhone iOS 16.1 或 iPadOS 17 及以上；普通通知仍可使用。',
                    '需要 iPhone iOS 16.1 或 iPadOS 17 及以上；一般通知仍可使用。',
                    'iPhone は iOS 16.1、iPad は iPadOS 17 以降が必要です。通常の通知は引き続き利用できます。',
                    'iPhone은 iOS 16.1, iPad는 iPadOS 17 이상이 필요합니다. 일반 알림은 계속 사용할 수 있습니다.',
                    'Requires iOS 16.1 on iPhone or iPadOS 17. Regular notifications remain available.',
                  )
                : _text(
                    context,
                    '一次展示一种类型。灵动岛显示最近到期项，锁屏卡片分栏显示该类各项倒计时。',
                    '一次顯示一種類型。動態島顯示最近到期項，鎖定畫面卡片分欄顯示該類各項倒數計時。',
                    '一度に1種類を表示します。Dynamic Island は次の終了時刻、ロック画面は各項目の残り時間を列で表示します。',
                    '한 번에 한 종류를 표시합니다. Dynamic Island에는 가장 가까운 타이머, 잠금 화면에는 해당 종류의 타이머를 열로 표시합니다.',
                    'Track one type at a time. Dynamic Island shows the nearest timer; the Lock Screen shows its timers in columns.',
                  ),
            value: _enabled,
            onChanged: canChange ? (value) => _save(enabled: value) : null,
          ),
          divider,
          buildActionTile(
            title: _text(
              context,
              '展示类型',
              '顯示類型',
              '表示する種類',
              '표시 종류',
              'Timer type',
            ),
            trailing: PopupMenuButton<String>(
              initialValue: _kind,
              enabled: canChange,
              onSelected: (kind) => _save(kind: kind),
              itemBuilder: (_) => [
                for (final entry in labels.entries)
                  PopupMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(labels[_kind] ?? labels['expedition']!),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (_supported && !_authorized) ...[
            divider,
            buildActionTile(
              title: _text(
                context,
                '系统未允许实时活动',
                '系統未允許即時動態',
                'システムでライブアクティビティが無効です',
                '시스템에서 실시간 현황이 꺼져 있습니다',
                'Live Activities are disabled in system settings',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: widget.notificationPort.openSystemNotificationSettings,
            ),
          ],
          if (_error?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
