import '../fleet/fleet_ui_strings.dart';

enum FleetShipTypeLabelMode { localizedName, abbreviation }

enum FleetSelectorLabelMode { customName, number }

FleetSelectorLabelMode _fleetSelectorLabelMode =
    FleetSelectorLabelMode.customName;

FleetSelectorLabelMode get fleetSelectorLabelModeSetting =>
    _fleetSelectorLabelMode;

void setFleetSelectorLabelModeSetting(FleetSelectorLabelMode mode) {
  _fleetSelectorLabelMode = mode;
}

const displayGroups = FleetUiKeys.displayGroups;
const defaultFields = <String>{
  'portrait',
  'equipment',
  'hp',
  'fuel',
  'ammo',
  'bars',
  'level',
  'type',
  'shipSpeed',
  'morale',
  'mechanisms',
  'speed',
  'total-level',
  'air-power',
  'line-of-sight',
  'minimum-condition',
};
Set<String> get compactFields => defaultFields.difference({
  'portrait',
  'type',
  'shipSpeed',
  'bars',
  'total-level',
});

final summaryFields = displayGroups[FleetUiKeys.summaryGroup]!.keys.toSet();
Set<String> get allFields =>
    displayGroups.values.expand((group) => group.keys).toSet();
const maximumSummaryFields = 5;

Set<String> normalizeDisplayFields(Iterable<String> saved) {
  final migrated = saved.toSet();
  if (migrated.any({'asw', 'aaci', 'rocket', 'night', 'special'}.contains)) {
    migrated.add('mechanisms');
  }
  final valid = migrated.intersection(allFields);
  final overflow = summaryFields
      .where(valid.contains)
      .skip(maximumSummaryFields);
  return valid.difference(overflow.toSet());
}
