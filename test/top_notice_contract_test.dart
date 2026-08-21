import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app mounts exactly one TopNoticeHost at MaterialApp home', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(RegExp(r'home:\s*TopNoticeHost\(').allMatches(source), hasLength(1));
  });
}
