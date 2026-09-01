import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_damage_level.dart';

void main() {
  group('shipDamageLevel', () {
    test(
      'uses exact integer boundaries for minor moderate and heavy damage',
      () {
        expect(
          shipDamageLevel(currentHp: 76, maxHp: 100),
          ShipDamageLevel.healthy,
        );
        expect(
          shipDamageLevel(currentHp: 75, maxHp: 100),
          ShipDamageLevel.minor,
        );
        expect(
          shipDamageLevel(currentHp: 51, maxHp: 100),
          ShipDamageLevel.minor,
        );
        expect(
          shipDamageLevel(currentHp: 50, maxHp: 100),
          ShipDamageLevel.moderate,
        );
        expect(
          shipDamageLevel(currentHp: 26, maxHp: 100),
          ShipDamageLevel.moderate,
        );
        expect(
          shipDamageLevel(currentHp: 25, maxHp: 100),
          ShipDamageLevel.heavy,
        );
      },
    );

    test('keeps zero HP and invalid maximum HP outside damage effects', () {
      expect(shipDamageLevel(currentHp: 0, maxHp: 100), ShipDamageLevel.none);
      expect(shipDamageLevel(currentHp: -1, maxHp: 100), ShipDamageLevel.none);
      expect(shipDamageLevel(currentHp: 1, maxHp: 0), ShipDamageLevel.none);
    });

    test('avoids ratio rounding at uneven maximum HP boundaries', () {
      expect(shipDamageLevel(currentHp: 8, maxHp: 33), ShipDamageLevel.heavy);
      expect(
        shipDamageLevel(currentHp: 9, maxHp: 33),
        ShipDamageLevel.moderate,
      );
      expect(
        shipDamageLevel(currentHp: 16, maxHp: 33),
        ShipDamageLevel.moderate,
      );
      expect(shipDamageLevel(currentHp: 17, maxHp: 33), ShipDamageLevel.minor);
      expect(shipDamageLevel(currentHp: 24, maxHp: 33), ShipDamageLevel.minor);
      expect(
        shipDamageLevel(currentHp: 25, maxHp: 33),
        ShipDamageLevel.healthy,
      );
    });
  });
}
