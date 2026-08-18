import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'expedition_poi_parity_audit.dart';

void main() {
  test('writes the human-review Markdown and CSV reports', () {
    final audit = ExpeditionPoiParityAudit.load(
      'test/fixtures/poi_ezexped/expedition_rules.json',
    );

    audit.writeReports(
      markdownPath: 'docs/internal/expedition-poi-parity-audit-post-fix.md',
      csvPath: 'docs/internal/expedition-poi-parity-audit-post-fix.csv',
    );

    final markdown = File(
      'docs/internal/expedition-poi-parity-audit-post-fix.md',
    ).readAsStringSync();
    final csv = File(
      'docs/internal/expedition-poi-parity-audit-post-fix.csv',
    ).readAsStringSync();
    expect(
      RegExp(r'^\| [A-E]?\d+ \|', multiLine: true).allMatches(markdown),
      hasLength(63),
    );
    expect(csv.trim().split('\n'), hasLength(64));
  });
}
