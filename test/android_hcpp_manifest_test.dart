import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not enable HCPP globally for the standard rendering mode', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      isNot(contains('io.flutter.embedding.android.EnableHcpp')),
    );
  });

  test('disabled HCPP is omitted from engine startup arguments', () {
    final activity = File(
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt',
    ).readAsStringSync();
    final policy = File(
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/GameRenderingModeHcppPolicy.kt',
    ).readAsStringSync();

    expect(activity, contains('override fun getFlutterShellArgs()'));
    expect(policy, contains('flutter.game.renderingMode'));
    expect(activity, contains('ARG_ENABLE_HCPP_AND_SURFACE_CONTROL'));
    expect(
      activity,
      isNot(contains('ARG_DISABLE_HCPP_AND_SURFACE_CONTROL')),
      reason: 'Flutter treats the presence of this option as enabling HCPP',
    );
  });

  test('restarts the activity after a rendering mode change', () {
    final activity = File(
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, contains('app.yahagi.kancollebrowser/game_environment'));
    expect(activity, contains('"restartActivity"'));
    expect(activity, contains('recreate()'));
  });
}
