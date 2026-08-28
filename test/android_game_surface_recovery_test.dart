import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android window lifecycle recovers only a ready game WebView', () {
    final source = File(
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('override fun onMultiWindowModeChanged('));
    expect(source, contains('override fun onPictureInPictureModeChanged('));
    expect(source, contains('override fun onConfigurationChanged('));
    expect(source, isNot(contains('holder.setSizeFromLayout()')));
    expect(source, isNot(contains('recoverSurfaceTree(')));
    expect(source, isNot(contains('longArrayOf(0L')));
    expect(source, contains('it.isAttachedToWindow'));
    expect(source, contains('it.width > 0 && it.height > 0'));
    expect(source, contains("window.dispatchEvent(new Event('resize'))"));
    expect(source, isNot(contains('reload()')));

    final pageStartedStart = source.indexOf('override fun onPageStarted() {');
    final pageStartedEnd = source.indexOf(
      'override fun onPageFinished()',
      pageStartedStart,
    );
    expect(pageStartedStart, greaterThanOrEqualTo(0));
    expect(pageStartedEnd, greaterThan(pageStartedStart));
    final pageStartedBody = source.substring(pageStartedStart, pageStartedEnd);
    expect(pageStartedBody, isNot(contains('releaseFixedCanvasScaling')));
  });
}
