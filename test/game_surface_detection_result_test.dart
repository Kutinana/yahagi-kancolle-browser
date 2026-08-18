import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_detection_result.dart';

void main() {
  test('accepts boolean and WebView string true results', () {
    expect(isGameSurfaceDetectionResult(true), isTrue);
    expect(isGameSurfaceDetectionResult('true'), isTrue);
    expect(isGameSurfaceDetectionResult(' true '), isTrue);
  });

  test('rejects false, null, and unrelated JavaScript results', () {
    expect(isGameSurfaceDetectionResult(false), isFalse);
    expect(isGameSurfaceDetectionResult('false'), isFalse);
    expect(isGameSurfaceDetectionResult(null), isFalse);
    expect(isGameSurfaceDetectionResult(1), isFalse);
  });
}
