import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug and release builds use the 1.0.8-beta.5 version contract', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      pubspec,
      contains(RegExp(r'^version: 1\.0\.8-beta\.5\+19$', multiLine: true)),
    );
  });
}
