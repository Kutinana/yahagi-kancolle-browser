import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ExpeditionSelectionStore {
  Future<int?> loadMissionId(int fleetId);

  Future<void> saveMissionId(int fleetId, int missionId);
}

final class SharedPreferencesExpeditionSelectionStore
    implements ExpeditionSelectionStore {
  const SharedPreferencesExpeditionSelectionStore();

  static String _missionKey(int fleetId) =>
      'expedition.selected_mission.fleet_$fleetId';

  @override
  Future<int?> loadMissionId(int fleetId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getInt(_missionKey(fleetId));
    } catch (_) {
      // The expedition checker still works if local preferences are unavailable.
      return null;
    }
  }

  @override
  Future<void> saveMissionId(int fleetId, int missionId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_missionKey(fleetId), missionId);
    } catch (_) {
      // Remembering the selection is optional and must not block evaluation.
    }
  }
}
