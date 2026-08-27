import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

void main() {
  test('新舰提醒正文包含舰名和上锁提示', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    expect(l10n.newShipAlertBody('雪风'), '雪风，请不要忘记上锁');
    expect(
      l10n.newShipAlertBody('雪风、岛风'),
      '雪风、岛风，请不要忘记上锁',
    );
  });

  test('繁体中文和日文提供对应的上锁提示', () {
    expect(
      lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ).newShipAlertBody('雪風'),
      '雪風，請不要忘記上鎖',
    );
    expect(
      lookupAppLocalizations(const Locale('ja')).newShipAlertBody('雪風'),
      '雪風、ロックをお忘れなく',
    );
  });
}
