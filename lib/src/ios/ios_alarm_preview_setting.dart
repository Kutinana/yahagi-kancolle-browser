import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/settings_ui_helpers.dart';

class IOSAlarmPreviewSetting extends StatefulWidget {
  const IOSAlarmPreviewSetting({super.key, required this.audible});

  final bool audible;

  @override
  State<IOSAlarmPreviewSetting> createState() => _IOSAlarmPreviewSettingState();
}

class _IOSAlarmPreviewSettingState extends State<IOSAlarmPreviewSetting>
    with SettingsUIHelpers, WidgetsBindingObserver {
  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/notification',
  );
  bool _supported = false;
  bool _enabled = false;
  bool _denied = false;
  bool _saving = false;
  bool _failed = false;
  bool? _retryEnabled;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _read();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_saving) _read();
  }

  Future<void> _read({bool? enabled}) async {
    final revision = ++_revision;
    _retryEnabled = enabled;
    if (enabled != null) setState(() => _saving = true);
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        enabled == null ? 'getAlarmPreview' : 'setAlarmPreview',
        enabled,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _supported = result?['supported'] == true;
        _enabled = result?['enabled'] == true;
        _denied = result?['denied'] == true;
        _failed = result?['syncFailed'] == true;
      });
    } on PlatformException {
      if (mounted && revision == _revision) setState(() => _failed = true);
    } finally {
      if (mounted && revision == _revision && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    final (title, detail, permission, retry) = switch (Localizations.localeOf(
      context,
    )) {
      Locale(languageCode: 'en') => (
        'System alarms (preview)',
        'Ring when expeditions, dock repairs, or construction finish, even in Silent mode or Focus. Requires reminder sound. Early reminders use notifications.',
        'Allow alarms in iOS Settings',
        'Couldn’t update system alarms. Try again.',
      ),
      Locale(languageCode: 'ja') => (
        'システムアラーム（プレビュー）',
        '遠征・入渠・建造の完了時に、消音・集中モード中でも鳴ります。通知音をオンにしてください。事前のお知らせは通常の通知で届きます。',
        'iOS の設定でアラームを許可',
        '設定を更新できませんでした。もう一度お試しください。',
      ),
      Locale(languageCode: 'ko') => (
        '시스템 알람 (미리보기)',
        '원정·입거 수리·건조가 끝나면 무음 또는 집중 모드에서도 울립니다. 알림 소리를 켜야 합니다. 사전 알림은 일반 알림으로 전달됩니다.',
        'iOS 설정에서 알람 허용',
        '알람 설정을 변경하지 못했습니다. 다시 시도하세요.',
      ),
      Locale(languageCode: 'zh', scriptCode: 'Hant') => (
        '系統鬧鐘（預覽）',
        '遠征、入渠或建造完成時響鈴，靜音及專注模式下也會響。需要開啟通知聲音。提前提醒仍使用一般通知。',
        '前往 iOS 設定允許鬧鐘',
        '無法更新系統鬧鐘，請重試。',
      ),
      _ => (
        '系统闹钟（预览）',
        '远征、入渠或建造完成时响铃，静音和专注模式下也会响。需要开启通知声音。提前提醒仍使用普通通知。',
        '前往 iOS 设置允许闹钟',
        '无法更新系统闹钟，请重试。',
      ),
    };
    return Column(
      children: [
        const Divider(height: 1),
        buildSwitchTile(
          title: title,
          subtitle: detail,
          value: _enabled,
          onChanged: !_saving && !_denied && (widget.audible || _enabled)
              ? (value) => _read(enabled: value)
              : null,
        ),
        if (_denied)
          buildActionTile(
            title: permission,
            trailing: const Icon(Icons.open_in_new),
            onTap: () =>
                _channel.invokeMethod<void>('openAlarmPreviewSettings'),
          ),
        if (_failed)
          buildActionTile(
            title: retry,
            onTap: _saving ? null : () => _read(enabled: _retryEnabled),
          ),
      ],
    );
  }
}
