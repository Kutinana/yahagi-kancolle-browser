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

  test('network failure clears a stale HTTP status code', () async {
    final controller = await KcwikiReportController.load(
      MemoryKcwikiReportSettingsStore(),
    );
    addTearDown(controller.dispose);
    controller.recordResult(
      module: 'quest',
      succeeded: true,
      occurredAt: DateTime.utc(2026, 8, 25),
      statusCode: 204,
    );

    controller.recordResult(
      module: 'battle',
      succeeded: false,
      occurredAt: DateTime.utc(2026, 8, 25, 1),
    );

    expect(controller.status.statusCode, isNull);
    expect(controller.status.succeededCount, 1);
    expect(controller.status.failedCount, 1);
  });

  test('upload status and counters survive controller reload', () async {
    final store = MemoryKcwikiReportSettingsStore(true);
    final first = await KcwikiReportController.load(store);
    first.recordQueued(module: 'battle', occurredAt: DateTime.utc(2026, 8, 26));
    first.recordResult(
      module: 'battle',
      succeeded: true,
      occurredAt: DateTime.utc(2026, 8, 26, 1),
      statusCode: 200,
    );
    await first.settled;
    first.dispose();

    final restored = await KcwikiReportController.load(store);
    addTearDown(restored.dispose);
    expect(restored.status.activity, KcwikiReportActivity.succeeded);
    expect(restored.status.module, 'battle');
    expect(restored.status.succeededCount, 1);
    expect(restored.status.occurredAt, DateTime.utc(2026, 8, 26, 1));
  });

  test('parse recovery is visible but does not count as an upload', () async {
    final controller = await KcwikiReportController.load(
      MemoryKcwikiReportSettingsStore(true),
    );
    addTearDown(controller.dispose);

    controller.recordParseRecovered(
      path: '/kcsapi/api_start2/getData',
      occurredAt: DateTime.utc(2026, 8, 26),
    );

    expect(controller.status.activity, KcwikiReportActivity.parseRecovered);
    expect(controller.status.path, '/kcsapi/api_start2/getData');
    expect(controller.status.succeededCount, 0);
    expect(controller.status.failedCount, 0);
  });
}
