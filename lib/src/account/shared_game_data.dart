import '../game_state/game_state.dart';

/// Only account-independent game definitions survive logout or cold startup.
GameState sharedGameData(GameState state) => GameState(
  masterShipTypes: state.masterShipTypes,
  masterShips: state.masterShips,
  masterSlotItems: state.masterSlotItems,
  masterSlotItemTypes: state.masterSlotItemTypes,
  expansionSlotEquipmentTypeIds: state.expansionSlotEquipmentTypeIds,
  expansionSlotSpecialRules: state.expansionSlotSpecialRules,
  expansionSlotLimitsByShipId: state.expansionSlotLimitsByShipId,
  hasEquipmentCompatibilityData: state.hasEquipmentCompatibilityData,
  masterMissions: state.masterMissions,
  masterMapInfos: state.masterMapInfos,
  masterMapAreas: state.masterMapAreas,
  hasMasterData: state.hasMasterData || state.masterShips.isNotEmpty,
);
