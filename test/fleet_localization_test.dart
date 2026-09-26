import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_view.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ui_strings.dart';

void main() {
  testWidgets('furniture coin label follows the active locale', (tester) async {
    final locale = ValueNotifier(const Locale('zh'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, value, _) => MaterialApp(
          locale: value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Text(fleetText(context, '家具コイン')),
          ),
        ),
      ),
    );

    expect(find.text('家具币'), findsOneWidget);
    locale.value = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    );
    await tester.pumpAndSettle();
    expect(find.text('家具幣'), findsOneWidget);
    locale.value = const Locale('ja');
    await tester.pumpAndSettle();
    expect(find.text('家具コイン'), findsOneWidget);
  });

  testWidgets('repair tabs update when the active locale changes', (
    tester,
  ) async {
    final locale = ValueNotifier(const Locale('zh'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, value, _) => MaterialApp(
          locale: value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RepairModeTabs(
              mode: RepairCenterMode.anchorage,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('野埼刷闪'), findsOneWidget);
    locale.value = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    );
    await tester.pumpAndSettle();
    expect(find.text('野埼刷閃'), findsOneWidget);
    expect(find.text('野埼刷闪'), findsNothing);
    locale.value = const Locale('ja');
    await tester.pumpAndSettle();
    expect(find.text('野埼キラ付け'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Japanese dynamic counts, model reasons, resources and mechanism descriptions',
    (tester) async {
      late BuildContext ui;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              ui = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(fleetText(ui, '12 分 (3次)'), '12分（3回）');
      expect(fleetText(ui, '4 艘（修理设施 X 2）'), '4隻（修理施設 × 2）');
      expect(fleetText(ui, '疲劳 49'), 'コンディション 49');
      expect(fleetText(ui, '未改野埼需疲劳≥49'), '未改造の野埼はCond≥49が必要');
      expect(fleetText(ui, '展开舰队'), '舰队を展開');
      expect(fleetText(ui, '喷2 75%'), '噴進改二 75%');
      expect(fleetText(ui, '雪風改二'), '雪風改二');
      expect(fleetText(ui, 'Event'), 'イベント海域');
      expect(fleetText(ui, 'Extra'), '拡張作戦');
      expect(fleetText(ui, '未知远征'), '不明な遠征');
      expect(fleetText(ui, '空闲'), '空き');
      expect(fleetText(ui, '建中'), '建造中');
      expect(fleetText(ui, '戦闘詳報'), '戦闘詳報');
      final description = fleetMechanismDescription(
        ui,
        '一齐射击（长门）\n\n长门改二旗舰的特殊攻击编成。 当前配装预估发动概率约为 75%。当前仅表示编成与耐久等静态条件匹配；实际发动还受阵型、联合舰队状态和本次出击中的使用次数限制。',
      );
      expect(description, contains('一斉射（長門）'));
      expect(description, contains('長門改二を旗艦とする特殊攻撃編成です。'));
      expect(description, contains('推定発動率は約75%です。'));
      expect(description, isNot(contains('当前')));
      expect(description, isNot(contains('实际')));
    },
  );
}
