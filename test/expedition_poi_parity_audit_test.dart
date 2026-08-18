import 'package:flutter_test/flutter_test.dart';

import '../tool/expedition_poi_parity_audit.dart';

void main() {
  const referencePath = 'test/fixtures/poi_ezexped/expedition_rules.json';

  group('Poi EZ Exped differential audit', () {
    late ExpeditionPoiParityAudit audit;

    setUpAll(() {
      audit = ExpeditionPoiParityAudit.load(referencePath);
    });

    test('covers every Poi expedition exactly once', () {
      expect(audit.referenceCommit, hasLength(40));
      expect(audit.entries, hasLength(63));
      expect(audit.entries.map((entry) => entry.id).toSet(), hasLength(63));
      expect(audit.missingLocalIds, isEmpty);
      expect(audit.extraLocalIds, isEmpty);
    });

    test(
      'compares every normal-success rule and records exact differences',
      () {
        expect(
          audit.entries.where((entry) => entry.normalRuleMatchesPoi),
          hasLength(63),
        );
        expect(
          audit.entries.where((entry) => !entry.normalRuleMatchesPoi),
          isEmpty,
        );
      },
    );

    test('compares the great-success strategy for every expedition', () {
      expect(
        audit.entries.where((entry) => entry.greatSuccessStrategyMatchesPoi),
        hasLength(63),
      );
    });

    test('has no remaining known cross-cutting evaluator difference', () {
      expect(audit.issues, isEmpty);
    });

    test('renders one Markdown and CSV row per expedition', () {
      final markdown = audit.renderMarkdown();
      final csv = audit.renderCsv();

      expect(
        RegExp(r'^\| [A-E]?\d+ \|', multiLine: true).allMatches(markdown),
        hasLength(63),
      );
      expect(csv.trim().split('\n'), hasLength(64));
      for (final entry in audit.entries) {
        expect(markdown, contains('| ${entry.displayId} | ${entry.id} |'));
        expect(csv, contains('"${entry.displayId}","${entry.id}",'));
      }
    });
  });
}
