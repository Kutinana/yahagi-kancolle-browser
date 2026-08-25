import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/slot_item_portrait.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  test('builds the official item_up resource URI with version', () {
    final uri = SlotItemPortraitUriBuilder.build(
      item: const MasterSlotItem(id: 168, name: '九六式陸攻', resourceVersion: '2'),
      serverOrigin: 'https://example.test/game/',
    );

    expect(uri, isNotNull);
    expect(
      uri.toString(),
      startsWith('https://example.test/kcs2/resources/slot/item_up/0168_'),
    );
    expect(uri?.queryParameters['version'], '2');
  });

  test('rejects an invalid resource origin', () {
    expect(
      SlotItemPortraitUriBuilder.build(
        item: const MasterSlotItem(id: 168, name: '九六式陸攻'),
        serverOrigin: 'not a server',
      ),
      isNull,
    );
  });
}
