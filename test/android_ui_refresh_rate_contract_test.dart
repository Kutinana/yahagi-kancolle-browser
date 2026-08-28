import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final activityPath =
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt';
  final managerPath =
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/'
      'GameFrameRateManager.kt';

  test('activity requests the current display highest refresh rate', () {
    final activity = File(activityPath).readAsStringSync();

    expect(activity, contains('UiRefreshRatePolicy.highestSupported'));
    expect(activity, contains('supportedModes'));
    expect(activity, contains('override fun onResume()'));
    expect(activity, contains('override fun onConfigurationChanged('));
    expect(
      RegExp(r'applyPreferredUiRefreshRate\(\)').allMatches(activity),
      hasLength(4),
    );
    expect(activity, isNot(contains('preferredRefreshRate = 60f')));
  });

  test('game frame rate manager cannot change the activity refresh rate', () {
    final activity = File(activityPath).readAsStringSync();
    final manager = File(managerPath).readAsStringSync();

    expect(activity, isNot(contains('GameFrameRateManager.Host')));
    expect(activity, isNot(contains('onFrameRateModeChanged')));
    expect(manager, isNot(contains('interface Host')));
    expect(manager, isNot(contains('host.onFrameRateModeChanged')));
  });
}
