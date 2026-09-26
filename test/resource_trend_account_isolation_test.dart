import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_chart.dart';

import 'resource_trend_page_test.dart' show row, wrap;

void main() {
  testWidgets('account switch closes the previous account fullscreen history', (
    tester,
  ) async {
    final session = AccountSession.shared;
    session.selectMember(1001);
    final now = DateTime.utc(2026, 9, 12);
    await tester.pumpWidget(
      wrap((_) async => [row(now, session.current.memberId)], now: () => now),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ResourceTrendChart>(find.byType(ResourceTrendChart))
        .onExpand
        .call();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resource-trend-fullscreen')),
      findsOneWidget,
    );

    session.selectMember(2002);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resource-trend-fullscreen')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.reset();
  });
}
