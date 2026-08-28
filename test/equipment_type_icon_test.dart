import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_type_icon.dart';

void main() {
  test('night scout icon falls back to the POI PNG numbering scheme', () {
    expect(slotItemIconAssetCandidates(50), <String>[
      'assets/images/slotitem/50.png',
      'assets/images/slotitem/150.png',
      'assets/images/slotitem/-1.png',
    ]);
  });

  test('existing direct icons keep their current appearance first', () {
    expect(
      slotItemIconAssetCandidates(1).first,
      'assets/images/slotitem/1.png',
    );
  });

  testWidgets('night scout renders the available POI fallback asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EquipmentTypeIconImage(
          iconId: 50,
          imageKey: Key('night-scout-icon'),
          width: 16,
          height: 16,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(
      assetNames,
      anyOf(
        contains('assets/images/slotitem/50.png'),
        contains('assets/images/slotitem/150.png'),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final entry in <int, String>{
    59: 'assets/images/slotitem/159.png',
    60: 'assets/images/slotitem/160.png',
  }.entries) {
    testWidgets('equipment icon ${entry.key} renders its bundled POI asset', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentTypeIconImage(
            iconId: entry.key,
            width: 16,
            height: 16,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final assetNames = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as AssetImage).assetName);
      expect(assetNames, contains(entry.value));
      expect(assetNames, isNot(contains('assets/images/slotitem/-1.png')));
      expect(tester.takeException(), isNull);
    });
  }
}
