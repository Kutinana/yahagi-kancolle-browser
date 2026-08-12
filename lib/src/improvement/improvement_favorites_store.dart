import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ImprovementFavoritesStore {
  Future<Set<int>> load();
  Future<void> save(Set<int> equipmentIds);
}

final class SharedPreferencesImprovementFavoritesStore
    implements ImprovementFavoritesStore {
  static const _key = 'improvement.favorite-equipment-ids.v1';

  @override
  Future<Set<int>> load() async =>
      (await SharedPreferences.getInstance())
          .getStringList(_key)
          ?.map(int.tryParse)
          .whereType<int>()
          .toSet() ??
      <int>{};

  @override
  Future<void> save(Set<int> equipmentIds) async {
    final values = equipmentIds.toList()..sort();
    final saved = await (await SharedPreferences.getInstance()).setStringList(
      _key,
      values.map((value) => '$value').toList(),
    );
    if (!saved) throw StateError('无法保存改修收藏');
  }
}
