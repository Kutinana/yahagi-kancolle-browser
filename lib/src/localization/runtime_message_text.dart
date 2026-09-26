import 'package:flutter/widgets.dart';

/// Localizes app-owned runtime messages at display time. Unrecognized native
/// error details, addresses, and exception type names are returned verbatim.
String runtimeMessageText(BuildContext context, String source) =>
    runtimeMessageForLocale(
      Localizations.maybeLocaleOf(context) ?? const Locale('zh'),
      source,
    );

String runtimeMessageForLocale(Locale locale, String source) {
  final japanese = locale.languageCode == 'ja';
  final traditional =
      locale.languageCode == 'zh' &&
      (locale.scriptCode == 'Hant' ||
          const ['TW', 'HK', 'MO'].contains(locale.countryCode));
  if (!japanese && !traditional) return source;
  final entry = runtimeMessageTranslations[source];
  if (entry != null) return japanese ? entry.$2 : entry.$1;
  final networkFailure = RegExp(
    r'^网络设置应用失败 \[([^\]]+)\]: (.*)$',
    dotAll: true,
  ).firstMatch(source);
  if (networkFailure != null) {
    final detail = runtimeMessageForLocale(locale, networkFailure[2]!);
    return japanese
        ? 'ネットワーク設定の適用に失敗 [${networkFailure[1]}]：$detail'
        : '網路設定套用失敗 [${networkFailure[1]}]：$detail';
  }
  for (final entry in _prefixes.entries) {
    if (source.startsWith(entry.key)) {
      final prefix = japanese ? entry.value.$2 : entry.value.$1;
      // The remainder is a raw exception, protocol, or technical stage.
      return prefix + source.substring(entry.key.length);
    }
  }
  return source;
}

const runtimeMessageTranslations = <String, (String, String)>{
  '模拟数据': ('模擬資料', 'テストデータ'),
  'proxy_operation_busy': ('代理設定正在套用中', 'プロキシ設定を適用中です'),
  'unknown_mode': ('未知的代理模式', '不明なプロキシモード'),
  '游戏模式（默认）': ('遊戲模式（預設）', 'ゲームモード（既定）'),
  '纯浏览模式': ('純瀏覽模式', 'ブラウズ専用モード'),
  '只读解析游戏接口，用于舰队、任务和战斗信息；不会替你操作。': (
    '唯讀解析遊戲介面，用於艦隊、任務和戰鬥資訊；不會代替你操作。',
    'ゲームAPIを読み取り専用で解析し、艦隊・任務・戦闘情報を表示します。操作の代行はしません。',
  ),
  '不读取游戏接口，仅显示游戏网页；信息功能将暂停更新。': (
    '不讀取遊戲介面，僅顯示遊戲網頁；資訊功能將暫停更新。',
    'ゲームAPIを読み取らず、ゲームページのみ表示します。情報機能の更新は一時停止します。',
  ),
  '游戏模式将在重新载入页面后启用只读捕获。': (
    '遊戲模式將在重新載入頁面後啟用唯讀擷取。',
    'ページ再読み込み後、ゲームモードで読み取り専用のキャプチャを有効にします。',
  ),
  '纯浏览模式将在重新载入页面后停止数据捕获。': (
    '純瀏覽模式將在重新載入頁面後停止資料擷取。',
    'ページ再読み込み後、ブラウズ専用モードでデータキャプチャを停止します。',
  ),
  '无法读取捕获模式，已使用游戏模式': ('無法讀取擷取模式，已使用遊戲模式', 'キャプチャモードを読み込めないため、ゲームモードを使用します'),
  '无法保存捕获模式，请重试': ('無法儲存擷取模式，請重試', 'キャプチャモードを保存できません。再試行してください'),
  '当前设备不支持应用内代理': ('目前裝置不支援應用程式內代理', 'この端末はアプリ内プロキシに対応していません'),
  '代理设置操作进行中，请稍后': ('正在套用代理設定，請稍候', 'プロキシ設定の操作中です。しばらくお待ちください'),
  '代理设置成功': ('代理設定成功', 'プロキシを設定しました'),
  '代理设置超时': ('代理設定逾時', 'プロキシ設定がタイムアウトしました'),
  '无需清除代理': ('無需清除代理', '解除するプロキシ設定はありません'),
  '系统网络已恢复': ('系統網路已恢復', 'システムのネットワークに戻しました'),
  '清除代理超时': ('清除代理逾時', 'プロキシ解除がタイムアウトしました'),
  '未知错误': ('未知錯誤', '不明なエラー'),
  'Unknown error': ('未知錯誤', '不明なエラー'),
  'TCP连接失败': ('TCP 連線失敗', 'TCP接続に失敗しました'),
  '普通网络可用，但Google连接超时，不影响游戏。': (
    '一般網路可用，但 Google 連線逾時，不影響遊戲。',
    '通常のネットワークは利用できますが、Googleへの接続がタイムアウトしました。ゲームには影響しません。',
  ),
  '网络畅通，可正常访问游戏服务。': ('網路暢通，可正常存取遊戲服務。', 'ネットワークは正常で、ゲームサービスに接続できます。'),
  '外网可用，但游戏相关服务无法访问 (可能被墙或被拦截)。': (
    '外部網路可用，但無法存取遊戲相關服務（可能遭網路封鎖或攔截）。',
    '外部ネットワークは利用できますが、ゲーム関連サービスに接続できません（ネットワーク上で遮断されている可能性があります）。',
  ),
  '当前网络连接失败或代理无法正常工作。': (
    '目前網路連線失敗或代理無法正常運作。',
    'ネットワーク接続に失敗したか、プロキシが正常に動作していません。',
  ),
  'No result returned from native platform': (
    '原生平台未傳回結果',
    'ネイティブ側から結果が返されませんでした',
  ),
  'Platform exception occurred': ('原生平台發生例外', 'ネイティブ側で例外が発生しました'),
  '原生 Activity WebView 仅支持 Android。': (
    '原生 Activity WebView 僅支援 Android。',
    'ネイティブ Activity WebView は Android のみに対応しています。',
  ),
  '游戏渲染进程已退出。': ('遊戲渲染程序已結束。', 'ゲームの描画プロセスが終了しました。'),
  '原生 WebView 已销毁。': ('原生 WebView 已銷毀。', 'ネイティブ WebView は破棄されました。'),
  '原生 WebView 事件通道异常。': (
    '原生 WebView 事件通道異常。',
    'ネイティブ WebView のイベントチャネルでエラーが発生しました。',
  ),
  '原生 WebView 事件通道已关闭。': (
    '原生 WebView 事件通道已關閉。',
    'ネイティブ WebView のイベントチャネルが閉じられました。',
  ),
  '原生 WebView 无法安全隐藏，已终止该模式。': (
    '原生 WebView 無法安全隱藏，已終止此模式。',
    'ネイティブ WebView を安全に非表示にできないため、このモードを終了しました。',
  ),
  '安全证书错误：可能是岛风GO证书未受信任或网络被劫持。': (
    '安全憑證錯誤：可能是岛风GO憑證未受信任或網路遭到劫持。',
    'セキュリティ証明書エラー：岛风GOの証明書が信頼されていないか、通信が傍受されている可能性があります。',
  ),
  '正在读取配置...': ('正在讀取設定...', '設定を読み込み中...'),
  '正在应用网络设置...': ('正在套用網路設定...', 'ネットワーク設定を適用中...'),
  '网络配置完毕，准备加载游戏...': ('網路設定完畢，準備載入遊戲...', 'ネットワーク設定完了、ゲームの読み込みを準備中...'),
  '正在加载游戏页面...': ('正在載入遊戲頁面...', 'ゲームページを読み込み中...'),
  '准备就绪...': ('準備就緒...', '準備完了...'),
  '暂不支持的外部跳转：未知协议': ('暫不支援的外部跳轉：未知通訊協定', '未対応の外部ページへの遷移：不明なプロトコル'),
  'WebView 尚未就绪': ('WebView 尚未就緒', 'WebView の準備ができていません'),
  '本地模拟页': ('本機模擬頁', 'ローカルテストページ'),
  '未知页面': ('未知頁面', '不明なページ'),
};

const _prefixes = <String, (String, String)>{
  '游戏页面启动失败：': ('遊戲頁面啟動失敗：', 'ゲームページの起動に失敗：'),
  '游戏页面准备失败：': ('遊戲頁面準備失敗：', 'ゲームページの準備に失敗：'),
  '抓包模式更新失败：': ('擷取模式更新失敗：', 'キャプチャモードの更新に失敗：'),
  '网络重试失败：': ('網路重試失敗：', 'ネットワークの再試行に失敗：'),
  '网络重载失败：': ('網路重新載入失敗：', 'ネットワークの再読み込みに失敗：'),
  '捕获模式切换失败：': ('擷取模式切換失敗：', 'キャプチャモードの切り替えに失敗：'),
  '捕获配置失败（': ('擷取設定失敗（', 'キャプチャ設定に失敗（'),
  '原生 WebView 启动失败：': ('原生 WebView 啟動失敗：', 'ネイティブ WebView の起動に失敗：'),
  '原生 WebView 启动失败 [': ('原生 WebView 啟動失敗 [', 'ネイティブ WebView の起動に失敗 ['),
  '原生 WebView 显示失败：': ('原生 WebView 顯示失敗：', 'ネイティブ WebView の表示に失敗：'),
  '暂不支持的外部跳转：': ('暫不支援的外部跳轉：', '未対応の外部ページへの遷移：'),
};
