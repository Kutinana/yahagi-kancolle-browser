import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_composition_formatter.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_models.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_rule_catalog.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_strings.dart';

void main() {
  for (final locale in [
    const Locale('zh'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    const Locale('ja'),
  ]) {
    testWidgets('composition alternatives survive localization for $locale', (
      tester,
    ) async {
      late ExpeditionStrings strings;
      await tester.pumpWidget(
        Localizations(
          locale: locale,
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              strings = ExpeditionStrings.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      for (final rule in expeditionRules.values) {
        for (final requirement in rule.requirements.where(
          (r) => r.type == ExpeditionRequirementType.composition,
        )) {
          final composition = formatExpeditionComposition(
            requirement.compositions,
          );
          for (final passed in [true, false]) {
            final result = ExpeditionConditionResult(
              kind: ExpeditionConditionKind.composition,
              label: '舰队构成：$composition',
              actual: '',
              passed: passed,
            );
            final label = strings.conditionLabel(result);
            expect(label, contains(composition));
            expect(
              label,
              startsWith(
                locale.languageCode == 'ja'
                    ? '艦隊編成：'
                    : locale.scriptCode == 'Hant'
                    ? '艦隊構成：'
                    : '舰队构成：',
              ),
            );
          }
        }
      }
    });
  }
}
