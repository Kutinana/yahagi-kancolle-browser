import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_models.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_strings.dart';

void main() {
  const condition = ExpeditionConditionResult(
    kind: ExpeditionConditionKind.flagshipType,
    label: '旗舰舰种为轻空母（CVL）',
    actual: '未满足',
    passed: false,
  );

  testWidgets('旗舰舰种具体要求保留在日文与繁体中文标签中', (tester) async {
    Future<String> labelFor(
      Locale locale, [
      ExpeditionConditionResult value = condition,
    ]) async {
      late String label;
      await tester.pumpWidget(
        Localizations(
          locale: locale,
          delegates: const <LocalizationsDelegate<dynamic>>[
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                label = ExpeditionStrings.of(context).conditionLabel(value);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return label;
    }

    expect(await labelFor(const Locale('ja')), '旗艦艦種：軽空母（CVL）');
    expect(
      await labelFor(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      '旗艦艦種為輕空母（CVL）',
    );

    const unknownCondition = ExpeditionConditionResult(
      kind: ExpeditionConditionKind.flagshipType,
      label: '旗舰舰种为舰种 999',
      actual: '未满足',
      passed: false,
    );
    expect(await labelFor(const Locale('ja'), unknownCondition), '旗艦艦種：艦種 999');
    expect(
      await labelFor(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        unknownCondition,
      ),
      '旗艦艦種為艦種 999',
    );
  });
}
