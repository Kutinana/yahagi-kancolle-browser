import 'fleet_ui_strings.dart';

const _shipTypeAbbreviations = <int, String>{
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
};

String fleetShipTypeAbbreviation(int shipTypeId, {String? fallback}) =>
    _shipTypeAbbreviations[shipTypeId] ??
    fallback ??
    FleetUiKeys.unknownShipType;
