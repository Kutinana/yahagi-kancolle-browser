import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_privacy_policy.dart';

void main() {
  group('DiagnosticPrivacyPolicy', () {
    final policy = DiagnosticPrivacyPolicy.v1();

    test('rejects credential field names regardless of case', () {
      for (final key in <String>[
        'account',
        'UserName',
        'password',
        'passwd',
        'api_token',
        'api_starttime',
        'Cookie',
        'Set-Cookie',
        'Authorization',
      ]) {
        expect(
          () => policy.validateField(key, 'TEST_ONLY_SECRET_DO_NOT_USE'),
          throwsA(isA<DiagnosticPrivacyViolation>()),
          reason: key,
        );
      }
    });

    test('rejects URLs query strings and credential-shaped values', () {
      for (final value in <String>[
        'https://example.invalid/login',
        '/kcsapi/api_port/port?api_token=secret',
        'api_token=TEST_ONLY_SECRET_DO_NOT_USE',
        'Bearer TEST_ONLY_SECRET_DO_NOT_USE',
        'session=TEST_ONLY_SECRET_DO_NOT_USE',
      ]) {
        expect(
          () => policy.validateField('message', value),
          throwsA(isA<DiagnosticPrivacyViolation>()),
          reason: value,
        );
      }
    });

    test('accepts a normalized kcsapi path without query data', () {
      expect(
        policy.safeApiPath('/kcsapi/api_port/port'),
        '/kcsapi/api_port/port',
      );
      expect(
        () => policy.safeApiPath('/kcsapi/api_port/port?api_token=secret'),
        throwsA(isA<DiagnosticPrivacyViolation>()),
      );
    });

    test('safe stack keeps symbols but removes paths and arguments', () {
      final stack = StackTrace.fromString('''
#0      Login.submit (package:yahagi_kancolle_browser/src/login.dart:42:7)
#1      C:\\Users\\Player\\secret.dart:12:3
#2      _RootZone.run (dart:async/zone.dart:1400:13)
''');

      final safe = policy.safeStack(stack);

      expect(safe, contains('Login.submit'));
      expect(safe, contains('_RootZone.run'));
      expect(safe, isNot(contains('C:\\Users')));
      expect(safe, isNot(contains('src/login.dart')));
    });
  });
}
