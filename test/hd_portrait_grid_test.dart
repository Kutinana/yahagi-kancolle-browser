import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/dashboard_card.dart';
import 'package:yahagi_kancolle_browser/src/settings/hd_layout_settings.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_portrait_grid.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  testWidgets('one animated card does not repaint neighboring cards', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final repaint = ValueNotifier<int>(0);
    addTearDown(controller.dispose);
    addTearDown(repaint.dispose);
    final paints = <String, int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HdPortraitGrid(
            controller: controller,
            editing: false,
            onEditingChanged: (_) {},
            cardBuilder: (id) => CustomPaint(
              painter: _PaintCounter(
                () => paints[id] = (paints[id] ?? 0) + 1,
                id == 'battle' ? repaint : null,
              ),
              child: const SizedBox(height: 60),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = Map<String, int>.of(paints);
    expect(before['fleet'], greaterThan(0));
    repaint.value++;
    await tester.pump();
    expect(paints['battle'], greaterThan(before['battle']!));
    expect(paints['fleet'], before['fleet']);
  });
  test('legacy fixed-height coordinates migrate to width-only layout', () {
    final settings = HdLayoutSettings(
      portraitModules: const [
        HdBottomModule('fleet', 1, rows: 2, row: 2, column: 1),
      ],
    );
    final restored = HdLayoutSettings.decode(settings.encode());
    expect(restored.portrait.first.row, isNull);
    expect(restored.portrait.first.column, isNull);
    expect(restored.portrait.first.rows, 1);
  });
  for (final reverse in [false, true]) {
    testWidgets(
      'customization preserves visible three-card grouping after collapse',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(controller.dispose);
        var editing = false;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => HdPortraitGrid(
                  controller: controller,
                  editing: editing,
                  onEditingChanged: (value) => setState(() => editing = value),
                  cardBuilder: (id) => DashboardCard(
                    title: id,
                    icon: const Icon(Icons.info),
                    collapsed: editing,
                    onToggleCollapse: () {},
                    child: SizedBox(height: id == 'battle' ? 350 : 40),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Rect rect(String id) =>
            tester.getRect(find.byKey(ValueKey('hd-portrait-cell-$id')));
        final normalGroupHeight = rect('battle').height;
        final offsets = {
          for (final id in ['battle', 'fleet', 'land_base', 'expedition'])
            id: rect(id).topLeft - rect('battle').topLeft,
        };
        expect(rect('expedition').left, rect('fleet').left);
        expect(rect('expedition').bottom, rect('battle').bottom);
        await tester.longPress(
          find.byKey(const ValueKey('hd-portrait-cell-battle')),
        );
        await tester.pumpAndSettle();
        expect(rect('battle').height, lessThan(normalGroupHeight * .65));
        expect(rect('fleet').top, rect('battle').top);
        expect(rect('expedition').left, rect('fleet').left);
        expect(rect('expedition').top, rect('fleet').bottom + 8);
        expect(rect('land_base').top, rect('battle').bottom + 8);
        expect(rect('expedition').bottom, rect('battle').bottom);
        await tester.tap(find.byKey(const Key('dashboard-edit-done')));
        await tester.pumpAndSettle();
        for (final id in offsets.keys) {
          expect(rect(id).topLeft - rect('battle').topLeft, offsets[id]);
        }
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'short side stacks one card and aligns group (reverse: $reverse)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HdPortraitGrid(
                controller: controller,
                editing: false,
                onEditingChanged: (_) {},
                cardBuilder: (id) => DashboardCard(
                  key: ValueKey('group-$id'),
                  title: id,
                  icon: const Icon(Icons.info),
                  collapsed: false,
                  onToggleCollapse: () {},
                  child: SizedBox(
                    key: ValueKey('content-$id'),
                    height: id == (reverse ? 'fleet' : 'battle')
                        ? 300
                        : (id == (reverse ? 'battle' : 'fleet') ? 190 : 30),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Rect rect(String id) =>
            tester.getRect(find.byKey(ValueKey('hd-portrait-cell-$id')));
        final tall = reverse ? 'fleet' : 'battle';
        final short = reverse ? 'battle' : 'fleet';
        expect(rect(tall).top, rect(short).top);
        final stacked = reverse ? 'land_base' : 'expedition';
        final following = reverse ? 'expedition' : 'land_base';
        expect(rect(stacked).left, rect(short).left);
        expect(rect(stacked).top, rect(short).bottom + 8);
        expect(rect(stacked).bottom, rect(tall).bottom);
        expect(rect(following).top, rect(tall).bottom + 8);
        expect(
          tester.getSize(find.byKey(ValueKey('content-$short'))).height,
          190,
        );
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'full-width long content expands and scrolls only with dashboard',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(controller.dispose);
      await controller.setHdPortraitSpan('battle', 2);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HdPortraitGrid(
              controller: controller,
              editing: false,
              onEditingChanged: (_) {},
              cardBuilder: (id) => DashboardCard(
                title: id,
                icon: const Icon(Icons.info),
                collapsed: false,
                onToggleCollapse: () {},
                child: SizedBox(
                  height: id == 'battle' ? 900 : 30,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text('end-$id'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('hd-portrait-cell-battle'));
      expect(tester.getSize(card).height, greaterThan(900));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -650),
      );
      await tester.pumpAndSettle();
      expect(find.text('end-battle').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'portrait cards pack into two columns, resize, reorder and restore independently',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(controller.dispose);
      final landscape = controller.hdSettings.bottom
          .map((e) => '${e.id}:${e.span}')
          .toList();
      var editing = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HdPortraitGrid(
                controller: controller,
                editing: editing,
                onEditingChanged: (v) => setState(() => editing = v),
                cardBuilder: (id) => DashboardCard(
                  key: ValueKey('card-$id'),
                  title: id,
                  icon: const Icon(Icons.info),
                  collapsed: editing,
                  onToggleCollapse: () {},
                  child: SizedBox(
                    key: ValueKey('body-$id'),
                    height: id == 'battle' ? 50 : 30,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('可放置功能区'), findsNothing);
      final battle = find.byKey(const ValueKey('card-battle'));
      final fleet = find.byKey(const ValueKey('card-fleet'));
      expect(tester.getRect(battle).top, tester.getRect(fleet).top);
      final fleetCell = find.byKey(const ValueKey('hd-portrait-cell-fleet'));
      final battleCell = find.byKey(const ValueKey('hd-portrait-cell-battle'));
      expect(
        tester.getSize(fleetCell).height,
        tester.getSize(battleCell).height,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('body-fleet'))).height,
        30,
      );
      final land = find.byKey(const ValueKey('card-land_base'));
      expect(tester.getRect(land).left, tester.getRect(battle).left);
      expect(tester.getRect(land).top, tester.getRect(fleetCell).bottom + 8);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final halfWidth = tester.getSize(battle).width;
      await tester.longPress(battle);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hd-portrait-width-battle')));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(CheckedPopupMenuItem<int>, '2×1'),
        findsNothing,
      );
      expect(
        find.widgetWithText(CheckedPopupMenuItem<int>, '2×2'),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(CheckedPopupMenuItem<int>, '1×2'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const Key('hd-portrait-target-battle')))
            .width,
        closeTo(halfWidth * 2 + 8, .01),
      );
      expect(
        tester.getRect(fleet).top,
        greaterThan(tester.getRect(battle).bottom),
      );
      final gesture = await tester.startGesture(tester.getCenter(fleet));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getTopLeft(battle) + const Offset(30, 5));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.hdSettings.portrait.first.id, 'fleet');
      await controller.toggleHdPortraitHidden('repair');
      final reloaded = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(reloaded.dispose);
      expect(reloaded.hdSettings.portrait.first.id, 'fleet');
      expect(
        reloaded.hdSettings.portrait.firstWhere((e) => e.id == 'battle').span,
        2,
      );
      expect(reloaded.hdSettings.portraitHidden, contains('repair'));
      await controller.resetHdLayout();
      expect(controller.hdSettings.portrait.first.id, 'fleet');
      await tester.tap(find.byKey(const Key('dashboard-edit-reset')));
      await tester.pumpAndSettle();
      expect(
        controller.hdSettings.portrait.map((e) => e.id),
        LayoutSettingsStore.defaultDashboardCardOrder,
      );
      expect(controller.hdSettings.portrait.every((e) => e.span == 2), isTrue);
      expect(controller.hdSettings.portraitHidden, isEmpty);
      final restoredReset = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(restoredReset.dispose);
      expect(
        restoredReset.hdSettings.portrait.map((e) => e.id),
        LayoutSettingsStore.defaultDashboardCardOrder,
      );
      expect(
        restoredReset.hdSettings.portrait.every((e) => e.span == 2),
        isTrue,
      );

      // Restore original landscape and verify portrait-only actions leave it untouched.
      await controller.setHdSplit(true);
      expect(
        controller.hdSettings.bottom.map((e) => '${e.id}:${e.span}'),
        landscape,
      );
      await tester.tap(find.byKey(const Key('dashboard-edit-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hd-portrait-width-battle')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PaintCounter extends CustomPainter {
  _PaintCounter(this.onPaint, Listenable? repaint) : super(repaint: repaint);
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) => onPaint();
  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => true;
}
