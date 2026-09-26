import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/localization/runtime_message_text.dart';

void main() {
  const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  const ja = Locale('ja');

  test(
    'runtime errors translate app framing and preserve technical details',
    () {
      const details = 'SocketException: 系统错误 https://example.test/中文?q=网络';
      expect(
        runtimeMessageForLocale(ja, '游戏页面启动失败：$details'),
        'ゲームページの起動に失敗：$details',
      );
      expect(
        runtimeMessageForLocale(hant, '游戏页面启动失败：$details'),
        '遊戲頁面啟動失敗：$details',
      );
      expect(runtimeMessageForLocale(ja, details), details);
      expect(
        runtimeMessageForLocale(
          ja,
          '原生 WebView 启动失败 [create/attach] (IllegalStateException)',
        ),
        'ネイティブ WebView の起動に失敗 [create/attach] (IllegalStateException)',
      );
    },
  );

  test(
    'network failures translate native app messages inside their wrapper',
    () {
      expect(
        runtimeMessageForLocale(ja, '网络设置应用失败 [proxy_apply_timeout]: 代理设置超时'),
        'ネットワーク設定の適用に失敗 [proxy_apply_timeout]：プロキシ設定がタイムアウトしました',
      );
      expect(
        runtimeMessageForLocale(hant, '网络设置应用失败 [unknown_error]: 系统原始错误'),
        '網路設定套用失敗 [unknown_error]：系统原始错误',
      );
      expect(runtimeMessageForLocale(ja, '代理设置成功'), 'プロキシを設定しました');
      expect(runtimeMessageForLocale(hant, '纯浏览模式'), '純瀏覽模式');
      expect(
        runtimeMessageForLocale(ja, '无法保存捕获模式，请重试'),
        'キャプチャモードを保存できません。再試行してください',
      );
    },
  );

  test(
    'Simplified Chinese source and unrecognized addresses remain unchanged',
    () {
      for (final source in runtimeMessageTranslations.keys) {
        expect(runtimeMessageForLocale(const Locale('zh'), source), source);
      }
      const url = 'https://例子.test/未知页面';
      expect(runtimeMessageForLocale(ja, url), url);
      expect(runtimeMessageForLocale(hant, url), url);
    },
  );
}
