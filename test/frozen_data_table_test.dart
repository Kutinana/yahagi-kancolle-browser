import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/widgets/frozen_data_table.dart';

void main() {
  test('uses the inventory table sizing contract', () {
    expect(FrozenDataTable.headerHeight, 34);
    expect(FrozenDataTable.minimumRowHeight, 44);
  });

  testWidgets(
    'renders multiple frozen columns with synchronized scroll areas',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 260,
              child: FrozenDataTable(
                frozenColumnWidths: const <double>[56, 180],
                frozenHeaders: const <Widget>[Text('收藏'), Text('装备名字')],
                frozenCells: (index) => <Widget>[
                  Text('★$index'),
                  Text('装备 $index'),
                ],
                scrollableColumnWidths: const <double>[160, 160, 160],
                scrollableHeaders: const <Widget>[
                  Text('基础消耗'),
                  Text('0 → +6'),
                  Text('+6 → MAX'),
                ],
                scrollableCells: (index) => <Widget>[
                  Text('资源 $index'),
                  Text('前段 $index'),
                  Text('后段 $index'),
                ],
                rowHeights: List<double>.filled(8, 44),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('frozen-table-horizontal-scroll')), findsOne);
      expect(find.byKey(const Key('frozen-table-frozen-scroll')), findsOne);
      expect(find.byKey(const Key('frozen-table-body-scroll')), findsOne);
      expect(find.text('收藏'), findsOne);
      expect(find.text('装备名字'), findsOne);
    },
  );
}
