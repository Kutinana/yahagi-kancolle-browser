import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';

void main() {
  group('NativeGameWebViewBounds', () {
    test('serializes the exact native bounds schema', () {
      final bounds = NativeGameWebViewBounds(
        left: 1.5,
        top: 2.5,
        width: 3.5,
        height: 4.5,
        devicePixelRatio: 2,
      );

      expect(bounds.toMap(), <String, double>{
        'left': 1.5,
        'top': 2.5,
        'width': 3.5,
        'height': 4.5,
        'devicePixelRatio': 2,
      });
    });

    test('rejects every non-finite and non-positive bound value', () {
      for (final invalid in <double>[double.nan, double.infinity]) {
        expect(
          () => NativeGameWebViewBounds(
            left: invalid,
            top: 0,
            width: 1,
            height: 1,
            devicePixelRatio: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => NativeGameWebViewBounds(
            left: 0,
            top: invalid,
            width: 1,
            height: 1,
            devicePixelRatio: 1,
          ),
          throwsArgumentError,
        );
      }
      for (final invalid in <double>[0, -1, double.nan, double.infinity]) {
        expect(
          () => NativeGameWebViewBounds(
            left: 0,
            top: 0,
            width: invalid,
            height: 1,
            devicePixelRatio: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => NativeGameWebViewBounds(
            left: 0,
            top: 0,
            width: 1,
            height: invalid,
            devicePixelRatio: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => NativeGameWebViewBounds(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            devicePixelRatio: invalid,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('NativeGameWebViewEvent.decode', () {
    test('decodes every event schema and sanitizes page URLs', () {
      final created = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'created',
        'generationId': 0,
      });
      final started = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'pageStarted',
        'generationId': 1,
        'url': 'https://www.dmm.com/game?token=secret#fragment',
      });
      final finished = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'pageFinished',
        'generationId': 1,
        'url': 'https://www.dmm.com/game',
      });
      final error = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'mainFrameError',
        'generationId': 1,
        'errorCode': -2,
        'description': 'network error',
      });
      final blocked = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'navigationBlocked',
        'generationId': 1,
        'scheme': 'intent+app',
      });
      final gone = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'renderProcessGone',
        'generationId': 1,
        'didCrash': true,
      });
      final destroyed = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'destroyed',
        'generationId': 1,
      });

      expect(created.type, NativeGameWebViewEventType.created);
      expect(started.type, NativeGameWebViewEventType.pageStarted);
      expect(started.url, 'https://www.dmm.com/game');
      expect(finished.type, NativeGameWebViewEventType.pageFinished);
      expect(error.errorCode, -2);
      expect(error.description, 'network error');
      expect(blocked.scheme, 'intent+app');
      expect(gone.didCrash, isTrue);
      expect(destroyed.type, NativeGameWebViewEventType.destroyed);
    });

    test('rejects malformed event data and unsafe values', () {
      final invalidEvents = <Object?>[
        'not a map',
        <String, Object?>{'type': 'created'},
        <String, Object?>{'type': 'created', 'generationId': 0, 'extra': true},
        <String, Object?>{'type': 'unknown', 'generationId': 0},
        <String, Object?>{'type': 'created', 'generationId': -1},
        <String, Object?>{'type': 'created', 'generationId': '0'},
        <String, Object?>{
          'type': 'pageStarted',
          'generationId': 0,
          'url': 'intent://private',
        },
        <String, Object?>{
          'type': 'navigationBlocked',
          'generationId': 0,
          'scheme': 'not valid!',
        },
        <String, Object?>{
          'type': 'mainFrameError',
          'generationId': 0,
          'errorCode': 'bad',
          'description': 'x',
        },
        <String, Object?>{
          'type': 'renderProcessGone',
          'generationId': 0,
          'didCrash': 'true',
        },
        <String, Object?>{
          'type': 'pageFinished',
          'generationId': 0,
          'url': 'https://www.dmm.com/${'a' * 2049}',
        },
        <String, Object?>{
          'type': 'mainFrameError',
          'generationId': 0,
          'errorCode': 1,
          'description': 'a' * 257,
        },
      ];

      for (final event in invalidEvents) {
        expect(
          () => NativeGameWebViewEvent.decode(event),
          throwsA(isA<NativeGameWebViewSchemaException>()),
        );
      }
    });
  });
}
