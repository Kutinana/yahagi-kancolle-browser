import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_composition_formatter.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_rule_catalog.dart';

void main() {
  group('formatExpeditionComposition', () {
    test('formats every A3 alternative in compact Poi-style notation', () {
      final composition = expeditionRules[102]!.requirements
          .firstWhere(
            (requirement) =>
                requirement.type == ExpeditionRequirementType.composition,
          )
          .compositions;

      expect(
        formatExpeditionComposition(composition),
        '1CL+3DD/DE or 1CL+2DE or 1DD+3DE or 1CT+2DE or '
        '1CVE+2DD or 1CVE+2DE',
      );
    });

    test('formats a single composition without spaces', () {
      expect(
        formatExpeditionComposition(const <Map<String, int>>[
          <String, int>{'CL': 1, 'DD': 2},
        ]),
        '1CL+2DD',
      );
    });

    test('maps every internal aggregate ship type to player notation', () {
      expect(
        formatExpeditionComposition(const <Map<String, int>>[
          <String, int>{'DDorDE': 3},
          <String, int>{'SSLike': 3},
          <String, int>{'CVLike': 2},
        ]),
        '3DD/DE or 3SS/SSV or 2CV/CVL/AV/CVB',
      );
    });
  });

  test('expedition 42 keeps DD and DE escort alternatives separate', () {
    final composition = expeditionRules[42]!.requirements
        .firstWhere(
          (requirement) =>
              requirement.type == ExpeditionRequirementType.composition,
        )
        .compositions;

    expect(composition, anyElement(equals(<String, int>{'CL': 1, 'DD': 2})));
    expect(composition, anyElement(equals(<String, int>{'CL': 1, 'DE': 2})));
    expect(
      composition,
      isNot(anyElement(equals(<String, int>{'CL': 1, 'DDorDE': 2}))),
    );
  });
}
