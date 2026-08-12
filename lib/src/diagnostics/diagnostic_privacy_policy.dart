final class DiagnosticPrivacyViolation implements Exception {
  const DiagnosticPrivacyViolation(this.reason);

  final String reason;

  @override
  String toString() => 'DiagnosticPrivacyViolation($reason)';
}

final class DiagnosticPrivacyPolicy {
  const DiagnosticPrivacyPolicy._();

  factory DiagnosticPrivacyPolicy.v1() => const DiagnosticPrivacyPolicy._();

  static final RegExp _safeKey = RegExp(r'^[A-Za-z][A-Za-z0-9]{0,63}$');
  static final RegExp _safeApiPath = RegExp(
    r'^/kcsapi/[A-Za-z0-9_./-]{1,180}$',
  );
  static final RegExp _credentialValue = RegExp(
    r'(api[_-]?token|api[_-]?starttime|authorization|bearer\s+|cookie|session\s*=|password|passwd)',
    caseSensitive: false,
  );
  static final RegExp _urlValue = RegExp(
    r'(?:https?|file|content)://',
    caseSensitive: false,
  );
  static const Set<String> _forbiddenKeyParts = <String>{
    'account',
    'username',
    'password',
    'passwd',
    'token',
    'cookie',
    'authorization',
    'apistarttime',
    'androidid',
    'advertisingid',
    'imei',
    'serial',
    'macaddress',
  };

  void validateField(String key, Object? value) {
    if (!_safeKey.hasMatch(key)) {
      throw const DiagnosticPrivacyViolation('invalid-field-name');
    }
    final normalized = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    if (_forbiddenKeyParts.any(normalized.contains)) {
      throw const DiagnosticPrivacyViolation('forbidden-field-name');
    }
    _validateValue(value);
  }

  void validateRecord(Map<String, Object?> record) {
    for (final entry in record.entries) {
      validateField(entry.key, entry.value);
    }
  }

  String safeApiPath(String value) {
    if (!_safeApiPath.hasMatch(value) ||
        value.contains('?') ||
        value.contains('#')) {
      throw const DiagnosticPrivacyViolation('unsafe-api-path');
    }
    return value;
  }

  List<String> safeStack(StackTrace? stack, {int maxFrames = 24}) {
    if (stack == null) return const <String>[];
    final result = <String>[];
    final symbolPattern = RegExp(r'^#\d+\s+([^\s(]+)');
    for (final rawLine in stack.toString().split(RegExp(r'\r?\n'))) {
      if (result.length >= maxFrames) break;
      final line = rawLine.trim();
      final isProject = line.contains('package:yahagi_kancolle_browser/');
      final isDart = line.contains('(dart:') || line.contains(' dart:');
      if (!isProject && !isDart) continue;
      final symbol = symbolPattern.firstMatch(line)?.group(1);
      if (symbol == null || symbol.isEmpty) continue;
      final safeSymbol = symbol.length <= 120
          ? symbol
          : symbol.substring(0, 120);
      result.add(safeSymbol);
    }
    return List<String>.unmodifiable(result);
  }

  void _validateValue(Object? value) {
    if (value == null || value is num || value is bool) return;
    if (value is String) {
      if (value.length > 256 || value.contains('\n') || value.contains('\r')) {
        throw const DiagnosticPrivacyViolation('unsafe-text-shape');
      }
      if (_urlValue.hasMatch(value) ||
          _credentialValue.hasMatch(value) ||
          value.contains('?')) {
        throw const DiagnosticPrivacyViolation('sensitive-text');
      }
      return;
    }
    if (value is List<Object?>) {
      if (value.length > 64) {
        throw const DiagnosticPrivacyViolation('oversized-list');
      }
      for (final child in value) {
        _validateValue(child);
      }
      return;
    }
    if (value is Map<String, Object?>) {
      validateRecord(value);
      return;
    }
    throw const DiagnosticPrivacyViolation('unsupported-value-type');
  }
}
