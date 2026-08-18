import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production UI uses only centralized HarmonyOS font families', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    List<String> filesContaining(String token) => dartFiles
        .where((file) => file.readAsStringSync().contains(token))
        .map((file) => file.path)
        .toList();

    expect(filesContaining('monospace'), isEmpty);
    expect(filesContaining('NotoSansJP'), isEmpty);
    expect(pubspec, isNot(contains('NotoSansJP')));
    expect(pubspec, isNot(contains('NotoSansJP-wght.ttf')));

    final localFontDeclarations = <String>[];
    for (final file in dartFiles) {
      if (file.path.replaceAll('\\', '/').endsWith('/theme/app_fonts.dart')) {
        continue;
      }
      if (RegExp(
        r'''fontFamily\s*:\s*['"]''',
      ).hasMatch(file.readAsStringSync())) {
        localFontDeclarations.add(file.path);
      }
    }
    expect(localFontDeclarations, isEmpty);

    final appTheme = File('lib/main.dart').readAsStringSync();
    expect(
      appTheme,
      contains('fontFamily: layoutSettingsController.fontFamily'),
    );
    expect(
      appTheme,
      contains(
        'fontFamilyFallback: layoutSettingsController.fontFamilyFallback',
      ),
    );
  });
}
