import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  test(
    'fleet morale metric mode defaults and persists across reloads',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(
        controller.fleetMoraleMetricMode,
        FleetMoraleMetricMode.minimumCondition,
      );

      await controller.toggleFleetMoraleMetricMode();
      expect(
        controller.fleetMoraleMetricMode,
        FleetMoraleMetricMode.recoveryCountdown,
      );
      expect(notifications, 1);

      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(
        controller.fleetMoraleMetricMode,
        FleetMoraleMetricMode.recoveryCountdown,
      );
    },
  );

  test('workspace menu defaults left and persists moving right', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.workspaceMenuOnRight, isFalse);

    await controller.setWorkspaceMenuOnRight(true);
    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.workspaceMenuOnRight, isTrue);
  });

  test(
    'workspace menu order persists and restores the current default',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      expect(
        controller.workspaceMenuOrder,
        LayoutSettingsStore.defaultWorkspaceMenuOrder,
      );
      expect(
        controller.workspaceMenuOrder,
        containsAllInOrder(<String>['owned-inventory', 'tools', 'settings']),
      );

      await controller.reorderWorkspaceMenu(0, 1);
      expect(controller.workspaceMenuOrder.take(2), <String>['fleet', 'game']);

      final custom = <String>[
        'settings',
        ...LayoutSettingsStore.defaultWorkspaceMenuOrder.where(
          (id) => id != 'settings',
        ),
      ];
      await controller.setWorkspaceMenuOrder(custom);
      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.workspaceMenuOrder, custom);

      await controller.resetWorkspaceMenuOrder();
      expect(
        controller.workspaceMenuOrder,
        LayoutSettingsStore.defaultWorkspaceMenuOrder,
      );
    },
  );

  test(
    'workspace menu order drops unknowns and appends missing entries',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_workspace_menu_order': <String>[
          'quests',
          'unknown',
          'game',
          'quests',
        ],
      });

      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      expect(controller.workspaceMenuOrder.take(2), <String>['quests', 'game']);
      expect(
        controller.workspaceMenuOrder.toSet(),
        LayoutSettingsStore.defaultWorkspaceMenuOrder.toSet(),
      );
      expect(
        controller.workspaceMenuOrder,
        hasLength(LayoutSettingsStore.defaultWorkspaceMenuOrder.length),
      );
      expect(controller.workspaceMenuOrder, contains('tools'));
    },
  );

  test(
    'legacy complete menu inserts tools immediately before settings',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_workspace_menu_order': <String>[
          'game',
          'fleet',
          'expedition',
          'repair',
          'construction',
          'quests',
          'senka',
          'battle-records',
          'owned-inventory',
          'settings',
        ],
      });

      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      final toolsIndex = controller.workspaceMenuOrder.indexOf('tools');
      expect(toolsIndex, controller.workspaceMenuOrder.indexOf('settings') - 1);
      expect(controller.workspaceMenuOrder[toolsIndex - 1], 'owned-inventory');
    },
  );

  test('enhanced damage pulse defaults on and persists changes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.enhancedDamagePulse, isTrue);

    await controller.setEnhancedDamagePulse(false);
    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.enhancedDamagePulse, isFalse);
  });

  test('land-base card follows fleet in defaults and legacy orders', () async {
    expect(
      LayoutSettingsStore.defaultDashboardCardOrder,
      containsAllInOrder(<String>['fleet', 'land_base', 'expedition']),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'layout_dashboard_card_order': <String>[
        'battle',
        'fleet',
        'expedition',
        'repair',
        'construction',
        'quests',
        'pre_sortie',
      ],
    });
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(
      controller.dashboardCardOrder,
      containsAllInOrder(<String>['fleet', 'land_base', 'expedition']),
    );
  });

  test('recommended ratio locks the information panel at 35 percent', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'layout_game_area_ratio': 0.58,
      'layout_auto_zoom': true,
    });
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.effectiveInformationPanelRatio, 0.35);
    expect(controller.canAdjustInformationPanelRatio, isFalse);

    await controller.setAutoZoom(false);

    expect(controller.effectiveInformationPanelRatio, closeTo(0.42, 0.0001));
    expect(controller.canAdjustInformationPanelRatio, isTrue);
    expect(controller.gameAreaRatio, 0.58);
  });

  test('reorder can move a middle dashboard card after the final card', () {
    expect(reorderDashboardCards(<String>['a', 'b', 'c', 'd'], 1, 3), <String>[
      'a',
      'c',
      'd',
      'b',
    ]);
  });

  test('reorder can move the final dashboard card upward', () {
    expect(reorderDashboardCards(<String>['a', 'b', 'c', 'd'], 3, 1), <String>[
      'a',
      'd',
      'b',
      'c',
    ]);
  });

  test(
    'header resources default to senka followed by eight materials',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      expect(controller.headerResourceOrder, hasLength(28));
      expect(controller.headerResourceOrder.first, headerSenkaId);
      expect(controller.visibleHeaderResourceIds, <String>[
        headerSenkaId,
        'anchorage-timer',
        'nosaki-timer',
        headerShipCapacityId,
        headerEquipmentCapacityId,
        'material-1',
        'material-2',
        'material-3',
        'material-4',
        'material-5',
        'material-6',
        'material-7',
        'material-8',
      ]);
    },
  );

  test(
    'legacy header order adds senka first without reordering resources',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_header_resource_order': <String>['material-2', 'material-1'],
        'layout_visible_header_resource_ids': <String>['material-2'],
      });

      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      expect(controller.headerResourceOrder.take(7), <String>[
        headerSenkaId,
        'anchorage-timer',
        'nosaki-timer',
        headerShipCapacityId,
        headerEquipmentCapacityId,
        'material-2',
        'material-1',
      ]);
      expect(controller.visibleHeaderResourceIds, <String>[
        headerSenkaId,
        'anchorage-timer',
        'nosaki-timer',
        'material-2',
        headerShipCapacityId,
        headerEquipmentCapacityId,
      ]);
    },
  );

  test(
    'complete legacy header order inserts capacities after timers',
    () async {
      final legacyOrder = <String>[
        for (final id in allHeaderResourceIds)
          if (id != headerShipCapacityId && id != headerEquipmentCapacityId) id,
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_header_resource_order': legacyOrder,
        'layout_visible_header_resource_ids': <String>[
          headerSenkaId,
          headerAnchorageTimerId,
          headerNosakiTimerId,
          'material-1',
          'material-2',
        ],
      });

      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final nosakiIndex = controller.headerResourceOrder.indexOf(
        headerNosakiTimerId,
      );
      expect(
        controller.headerResourceOrder.sublist(
          nosakiIndex + 1,
          nosakiIndex + 3,
        ),
        <String>[headerShipCapacityId, headerEquipmentCapacityId],
      );
      expect(
        controller.headerResourceOrder.where(legacyOrder.contains),
        legacyOrder,
      );
    },
  );

  test('header resource order and visibility persist', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    await controller.setHeaderResourceOrder(<String>[
      'useitem-68',
      ...controller.headerResourceOrder.where((id) => id != 'useitem-68'),
    ]);
    await controller.toggleHeaderResourceVisible('useitem-68');
    await controller.toggleHeaderResourceVisible('material-1');

    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.headerResourceOrder.first, 'useitem-68');
    expect(controller.visibleHeaderResourceIds, contains('useitem-68'));
    expect(controller.visibleHeaderResourceIds, isNot(contains('material-1')));

    await controller.toggleHeaderResourceVisible(headerShipCapacityId);
    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(
      controller.visibleHeaderResourceIds,
      isNot(contains(headerShipCapacityId)),
    );
  });

  test('capacity capsule order persists after customization', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    await controller.setHeaderResourceOrder(<String>[
      headerEquipmentCapacityId,
      ...controller.headerResourceOrder.where(
        (id) => id != headerEquipmentCapacityId,
      ),
    ]);
    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.headerResourceOrder.first, headerEquipmentCapacityId);
  });
}
