import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_type_label.dart';

void main() {
  test('maps every player ship type id to its English abbreviation', () {
    expect(
      {for (var id = 1; id <= 22; id++) id: fleetShipTypeAbbreviation(id)},
      {
        1: 'DE',
        2: 'DD',
        3: 'CL',
        4: 'CLT',
        5: 'CA',
        6: 'CAV',
        7: 'CVL',
        8: 'FBB',
        9: 'BB',
        10: 'BBV',
        11: 'CV',
        12: 'BB',
        13: 'SS',
        14: 'SSV',
        15: 'AO',
        16: 'AV',
        17: 'LHA',
        18: 'CVB',
        19: 'AR',
        20: 'AS',
        21: 'CT',
        22: 'AO',
      },
    );
  });

  test('unknown ship type id falls back to the localized master-data name', () {
    expect(fleetShipTypeAbbreviation(999, fallback: '特殊舰種'), '特殊舰種');
  });
}
