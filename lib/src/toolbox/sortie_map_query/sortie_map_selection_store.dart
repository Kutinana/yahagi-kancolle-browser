import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SortieMapSelection {
  const SortieMapSelection({required this.mapId, required this.nodePoint});

  final String mapId;
  final String nodePoint;

  @override
  bool operator ==(Object other) =>
      other is SortieMapSelection &&
      other.mapId == mapId &&
      other.nodePoint == nodePoint;

  @override
  int get hashCode => Object.hash(mapId, nodePoint);
}

abstract interface class SortieMapSelectionStore {
  Future<SortieMapSelection?> load();

  Future<void> save(SortieMapSelection selection);
}

final class SharedPreferencesSortieMapSelectionStore
    implements SortieMapSelectionStore {
  const SharedPreferencesSortieMapSelectionStore();

  static const _key = 'toolbox.sortie_map.last_selection.v1';

  @override
  Future<SortieMapSelection?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final mapId = decoded['mapId'];
      final nodePoint = decoded['nodePoint'];
      if (mapId is! String ||
          mapId.isEmpty ||
          nodePoint is! String ||
          nodePoint.isEmpty) {
        return null;
      }
      return SortieMapSelection(mapId: mapId, nodePoint: nodePoint);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(SortieMapSelection selection) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({
          'mapId': selection.mapId,
          'nodePoint': selection.nodePoint,
        }),
      );
    } catch (_) {
      // Remembering the last query is optional and must not block the UI.
    }
  }
}
