import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_settings.dart';

void main() {
  test('missing preference keeps KCWiki reporting disabled', () async {
    final store = MemoryKcwikiReportSettingsStore();
    final controller = await KcwikiReportController.load(store);
    addTearDown(controller.dispose);

    expect(controller.enabled, isFalse);
  });

  test('enabled preference is restored', () async {
    final store = MemoryKcwikiReportSettingsStore(true);
    final controller = await KcwikiReportController.load(store);
    addTearDown(controller.dispose);

    expect(controller.enabled, isTrue);
  });

  test('disabling persists before notifying listeners', () async {
    final store = MemoryKcwikiReportSettingsStore(true);
    final controller = await KcwikiReportController.load(store);
    addTearDown(controller.dispose);
    final observations = <({bool stored, bool enabled})>[];
    controller.addListener(
      () => observations.add((
        stored: store.enabled,
        enabled: controller.enabled,
      )),
    );

    await controller.setEnabled(false);

    expect(store.enabled, isFalse);
    expect(observations, <({bool stored, bool enabled})>[
      (stored: false, enabled: false),
    ]);
  });

  test('status counters never retain a request body', () async {
    final controller = await KcwikiReportController.load(
      MemoryKcwikiReportSettingsStore(),
    );
    addTearDown(controller.dispose);

    controller.recordResult(
      module: 'quest',
      succeeded: false,
      occurredAt: DateTime.utc(2026, 8, 25),
      statusCode: 503,
    );

    expect(controller.status.failedCount, 1);
    expect(controller.status.succeededCount, 0);
    expect(controller.status.module, 'quest');
    expect(controller.status.statusCode, 503);
  });
}
