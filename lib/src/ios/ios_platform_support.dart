import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../settings/settings_ui_helpers.dart';

bool get isIOSPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

String iosUnsupportedDescription(BuildContext context) =>
    switch (Localizations.localeOf(context).languageCode) {
      'en' =>
        'The public iOS APIs do not provide the access this feature requires.',
      'ko' => '이 기능에 필요한 접근 권한을 iOS 공개 API에서 제공하지 않습니다.',
      'ja' => 'この機能に必要な公開 API を iOS が提供していません。',
      'zh' when Localizations.localeOf(context).scriptCode == 'Hant' =>
        '受系統公開介面限制，iOS 暫不支援此功能。',
      _ => '受系统公开接口限制，iOS 暂不支持此功能。',
    };

class IOSUnavailableSetting extends StatelessWidget with SettingsUIHelpers {
  const IOSUnavailableSetting({
    super.key,
    required this.title,
    this.showSwitch = false,
    this.description,
  });

  final String title;
  final bool showSwitch;
  final String? description;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: showSwitch
        ? buildSwitchTile(
            title: title,
            subtitle: description ?? iosUnsupportedDescription(context),
            value: false,
            onChanged: null,
          )
        : buildActionTile(
            title: title,
            subtitle: description ?? iosUnsupportedDescription(context),
            enabled: false,
          ),
  );
}

String iosProxyUnavailableDescription(
  BuildContext context,
) => switch (Localizations.localeOf(context).languageCode) {
  'en' =>
    'In-app proxies require iOS 17 or later. Use the system network on this device.',
  'ko' => '앱 내 프록시는 iOS 17 이상이 필요합니다. 이 기기에서는 시스템 네트워크를 사용합니다.',
  'ja' => 'アプリ内プロキシには iOS 17 以降が必要です。この端末ではシステムのネットワークを使用します。',
  'zh' when Localizations.localeOf(context).scriptCode == 'Hant' =>
    '應用程式內代理需要 iOS 17 或更新版本。目前僅提供系統網路。',
  _ => '应用内代理需要 iOS 17 或更高版本。当前仅提供系统网络。',
};

String iosBackupFolderDescription(
  BuildContext context,
) => switch (Localizations.localeOf(context).languageCode) {
  'en' =>
    'Saved in the folder you choose in Files. Syncs automatically while the app is running.',
  'ko' => '파일 앱에서 선택한 폴더에 저장합니다. 앱이 실행 중일 때 자동으로 동기화합니다.',
  'ja' => '「ファイル」で選んだフォルダに保存し、アプリの実行中に自動同期します。',
  'zh' when Localizations.localeOf(context).scriptCode == 'Hant' =>
    '儲存在「檔案」中選擇的資料夾；應用程式執行時自動同步。',
  _ => '保存在“文件”中选择的文件夹；应用运行时自动同步。',
};

String iosNativeRendererDescription(BuildContext context) =>
    switch (Localizations.localeOf(context).languageCode) {
      'en' => 'WKWebView (system native)',
      'ko' => 'WKWebView (시스템 기본)',
      'ja' => 'WKWebView（システム標準）',
      'zh' when Localizations.localeOf(context).scriptCode == 'Hant' =>
        'WKWebView（系統原生）',
      _ => 'WKWebView（系统原生）',
    };

String iosFrameRateUnavailableDescription(
  BuildContext context,
) => switch (Localizations.localeOf(context).languageCode) {
  'en' =>
    'Waiting for initialization. If this persists, reload the game and try again.',
  'ko' => '초기화를 기다리는 중입니다. 이 상태가 계속되면 게임을 다시 불러와 재시도하세요.',
  'ja' => '初期化を待っています。この状態が続く場合は、ゲームを再読み込みして再試行してください。',
  'zh' when Localizations.localeOf(context).scriptCode == 'Hant' =>
    '正在等待初始化。若一直停留在此狀態，請重新載入遊戲後重試。',
  _ => '正在等待初始化。若一直停留在此状态，请刷新游戏后重试。',
};
