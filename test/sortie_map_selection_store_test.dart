import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_selection_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves and restores the last map and node together', () async {
    const store = SharedPreferencesSortieMapSelectionStore();

    await store.save(const SortieMapSelection(mapId: '6-5', nodePoint: 'M'));

    expect(
      await store.load(),
      const SortieMapSelection(mapId: '6-5', nodePoint: 'M'),
    );
  });
}
