const headerSenkaId = 'senka';
const headerAnchorageTimerId = 'anchorage-timer';
const headerNosakiTimerId = 'nosaki-timer';
const headerShipCapacityId = 'ship-capacity';
const headerEquipmentCapacityId = 'equipment-capacity';

const allHeaderResourceIds = <String>[
  headerSenkaId,
  headerAnchorageTimerId,
  headerNosakiTimerId,
  'material-1',
  'material-2',
  headerShipCapacityId,
  headerEquipmentCapacityId,
  'material-3',
  'material-4',
  'material-5',
  'material-6',
  'material-7',
  'material-8',
  'useitem-10',
  'useitem-11',
  'useitem-12',
  'useitem-54',
  'useitem-57',
  'useitem-59',
  'useitem-61',
  'useitem-68',
  'useitem-70',
  'useitem-75',
  'useitem-77',
  'useitem-78',
  'useitem-94',
  'useitem-95',
  'useitem-100',
];

const defaultVisibleHeaderResourceIds = <String>[
  headerSenkaId,
  headerAnchorageTimerId,
  headerNosakiTimerId,
  'material-1',
  'material-2',
  headerShipCapacityId,
  headerEquipmentCapacityId,
  'material-3',
  'material-4',
  'material-5',
  'material-6',
  'material-7',
  'material-8',
];

List<String> normalizeHeaderResourceOrder(Iterable<String>? saved) {
  final result = <String>[];
  if (saved == null || !saved.contains(headerSenkaId)) {
    result.add(headerSenkaId);
  }
  if (saved == null || !saved.contains(headerAnchorageTimerId)) {
    result.add(headerAnchorageTimerId);
  }
  if (saved == null || !saved.contains(headerNosakiTimerId)) {
    result.add(headerNosakiTimerId);
  }
  for (final id in saved ?? const <String>[]) {
    if (allHeaderResourceIds.contains(id) && !result.contains(id)) {
      result.add(id);
    }
  }
  for (final id in allHeaderResourceIds) {
    if (result.contains(id)) continue;
    if (id == headerShipCapacityId) {
      final ammunitionIndex = result.indexOf('material-2');
      result.insert(
        ammunitionIndex < 0 ? result.length : ammunitionIndex + 1,
        id,
      );
      continue;
    }
    if (id == headerEquipmentCapacityId) {
      final shipCapacityIndex = result.indexOf(headerShipCapacityId);
      result.insert(
        shipCapacityIndex < 0 ? result.length : shipCapacityIndex + 1,
        id,
      );
      continue;
    }
    result.add(id);
  }
  return result;
}

List<String> normalizeVisibleHeaderResourceIds(Iterable<String>? saved) {
  if (saved == null) return List<String>.from(defaultVisibleHeaderResourceIds);
  return <String>[
    for (final id in saved)
      if (allHeaderResourceIds.contains(id)) id,
  ];
}
