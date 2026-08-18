import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_visibility.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';

void main() {
  group('NativeGameSurfaceVisibility', () {
    test('combines route app and slot visibility before reporting', () async {
      final reports = <bool>[];
      final visibility = NativeGameSurfaceVisibility((visible) async {
        reports.add(visible);
      });

      await visibility.setSlotAttached(true);
      await visibility.setRouteVisible(false);
      await visibility.setRouteVisible(true);
      await visibility.setAppVisible(false);
      await visibility.setAppVisible(true);

      expect(reports, <bool>[true, false, true, false, true]);
    });

    test(
      'serializes rapid changes and recovers after callback failure',
      () async {
        final reports = <bool>[];
        final firstReport = Completer<void>();
        var calls = 0;
        final visibility = NativeGameSurfaceVisibility((visible) async {
          calls++;
          reports.add(visible);
          if (calls == 1) {
            await firstReport.future;
            throw StateError('expected failure');
          }
        });

        final attach = visibility.setSlotAttached(true);
        final hide = visibility.setRouteVisible(false);
        final show = visibility.setRouteVisible(true);
        firstReport.complete();

        await expectLater(attach, throwsStateError);
        await hide;
        await show;

        expect(reports, <bool>[true, false, true]);
      },
    );

    test('dispose requests false once', () async {
      final reports = <bool>[];
      final visibility = NativeGameSurfaceVisibility((visible) async {
        reports.add(visible);
      });

      await visibility.setSlotAttached(true);
      await visibility.dispose();
      await visibility.dispose();

      expect(reports, <bool>[true, false]);
    });
  });

  group('NativeGameSurfaceSlot', () {
    testWidgets(
      'reports logical bounds and the Flutter view DPR once attached',
      (tester) async {
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        final bounds = <NativeGameWebViewBounds>[];

        await tester.pumpWidget(
          _slotApp(
            width: 100,
            height: 50,
            onBoundsChanged: (value) async => bounds.add(value),
          ),
        );
        await tester.pump();

        expect(bounds, hasLength(1));
        expect(bounds.single.toMap(), <String, double>{
          'left': 0,
          'top': 0,
          'width': 100,
          'height': 50,
          'devicePixelRatio': 2,
        });
      },
    );

    testWidgets(
      'deduplicates equal bounds and reports changed size position and DPR',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        final bounds = <NativeGameWebViewBounds>[];

        await tester.pumpWidget(
          _slotApp(
            width: 100,
            height: 50,
            left: 10,
            top: 20,
            onBoundsChanged: (value) async => bounds.add(value),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(bounds, hasLength(1));

        await tester.pumpWidget(
          _slotApp(
            width: 120,
            height: 50,
            left: 15,
            top: 20,
            onBoundsChanged: (value) async => bounds.add(value),
          ),
        );
        await tester.pump();
        tester.view.devicePixelRatio = 2;
        await tester.pump();

        expect(bounds.map((value) => value.toMap()), <Map<String, double>>[
          <String, double>{
            'left': 10,
            'top': 20,
            'width': 100,
            'height': 50,
            'devicePixelRatio': 1,
          },
          <String, double>{
            'left': 15,
            'top': 20,
            'width': 120,
            'height': 50,
            'devicePixelRatio': 1,
          },
          <String, double>{
            'left': 15,
            'top': 20,
            'width': 120,
            'height': 50,
            'devicePixelRatio': 2,
          },
        ]);
      },
    );

    testWidgets(
      'does not construct invalid bounds and hides an attached zero-area slot',
      (tester) async {
        final bounds = <NativeGameWebViewBounds>[];
        final visibility = <bool>[];

        await tester.pumpWidget(
          _slotApp(
            width: 20,
            height: 10,
            onBoundsChanged: (value) async => bounds.add(value),
            onVisibilityChanged: (value) async => visibility.add(value),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          _slotApp(
            width: 0,
            height: 0,
            onBoundsChanged: (value) async => bounds.add(value),
            onVisibilityChanged: (value) async => visibility.add(value),
          ),
        );
        await tester.pump();

        expect(bounds, hasLength(1));
        expect(visibility, <bool>[true, false]);
      },
    );

    testWidgets('hides when a Navigator route covers it and restores on pop', (
      tester,
    ) async {
      final observer = RouteObserver<ModalRoute<dynamic>>();
      final navigatorKey = GlobalKey<NavigatorState>();
      final visibility = <bool>[];

      await tester.pumpWidget(
        _slotApp(
          navigatorKey: navigatorKey,
          observer: observer,
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      unawaited(
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(visibility, <bool>[true, false, true]);
    });

    testWidgets('maps non-resumed app lifecycle states to hidden', (
      tester,
    ) async {
      final visibility = <bool>[];
      await tester.pumpWidget(
        _slotApp(onVisibilityChanged: (value) async => visibility.add(value)),
      );
      await tester.pump();

      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      }

      expect(visibility, <bool>[
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
      ]);
    });

    testWidgets('hides once when disposed and contains no platform view', (
      tester,
    ) async {
      final visibility = <bool>[];
      await tester.pumpWidget(
        _slotApp(onVisibilityChanged: (value) async => visibility.add(value)),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString().contains('WebViewWidget') ||
              widget.runtimeType.toString().contains('AndroidView') ||
              widget.runtimeType.toString().contains('PlatformViewLink'),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();

      expect(visibility, <bool>[true, false]);
    });
  });
}

Widget _slotApp({
  double width = 100,
  double height = 50,
  double left = 0,
  double top = 0,
  Future<void> Function(NativeGameWebViewBounds)? onBoundsChanged,
  Future<void> Function(bool)? onVisibilityChanged,
  GlobalKey<NavigatorState>? navigatorKey,
  RouteObserver<ModalRoute<dynamic>>? observer,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    navigatorObservers: observer == null ? const [] : [observer],
    home: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(left: left, top: top),
        child: SizedBox(
          width: width,
          height: height,
          child: NativeGameSurfaceSlot(
            onBoundsChanged: onBoundsChanged ?? (_) async {},
            onVisibilityChanged: onVisibilityChanged ?? (_) async {},
            routeObserver: observer,
          ),
        ),
      ),
    ),
  );
}
