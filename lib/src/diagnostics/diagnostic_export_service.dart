import 'dart:convert';
import 'dart:io';

import 'diagnostic_platform_port.dart';
import 'diagnostic_privacy_policy.dart';
import 'diagnostic_storage.dart';

final class DiagnosticExportPrivacyException implements Exception {
  const DiagnosticExportPrivacyException();
}

final class DiagnosticExportService {
  DiagnosticExportService({
    required this.storage,
    required this.exportDirectory,
    required this.platform,
    required this.appVersion,
    DateTime Function()? now,
    this.maxExportBytes = 10 * 1024 * 1024,
  }) : _now = now ?? DateTime.now;

  final DiagnosticStorage storage;
  final Directory exportDirectory;
  final DiagnosticPlatformPort platform;
  final String appVersion;
  final int maxExportBytes;
  final DateTime Function() _now;
  final DiagnosticPrivacyPolicy _policy = DiagnosticPrivacyPolicy.v1();

  Future<String?> save() async {
    final file = await _createAuditedExport();
    try {
      return await platform.saveJson(file.path);
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<File> exportAndShare() async {
    final file = await _createAuditedExport();
    try {
      await platform.shareJson(file.path);
      return file;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<File> _createAuditedExport() async {
    await exportDirectory.create(recursive: true);
    await _removeOldExports();
    final now = _now();
    final name = _fileName(now);
    final file = File('${exportDirectory.path}${Platform.pathSeparator}$name');
    try {
      final device = await platform.deviceSnapshot();
      _policy.validateRecord(device.toJson());
      final records = <Map<String, Object?>>[];
      var estimatedBytes = 2048;
      await for (final record in storage.readRecords(newestFirst: true)) {
        final encodedBytes = utf8.encode(jsonEncode(record)).length + 1;
        if (estimatedBytes + encodedBytes > maxExportBytes - 1024) break;
        records.add(record);
        estimatedBytes += encodedBytes;
      }
      records.sort(
        (first, second) => (first['occurredAt'] as String).compareTo(
          second['occurredAt'] as String,
        ),
      );
      final document = <String, Object?>{
        'formatVersion': 1,
        'exportedAt': now.toUtc().toIso8601String(),
        'application': <String, Object?>{'version': appVersion},
        'device': device.toJson(),
        'retention': <String, Object?>{
          'maxDays': 7,
          'maxBytes': 10 * 1024 * 1024,
          'truncated': estimatedBytes >= maxExportBytes - 1024,
        },
        'records': records,
        'privacy': <String, Object?>{
          'loginSecretsIncluded': false,
          'sessionDataIncluded': false,
          'fullApiBodiesIncluded': false,
          'screenshotsIncluded': false,
          'automaticUpload': false,
        },
      };
      await file.writeAsString(jsonEncode(document), flush: true);
      if (await file.length() > maxExportBytes) {
        throw const DiagnosticExportPrivacyException();
      }
      await _audit(file);
      return file;
    } on DiagnosticPrivacyViolation {
      if (await file.exists()) await file.delete();
      throw const DiagnosticExportPrivacyException();
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> _audit(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?> ||
          decoded.keys.toSet().difference(<String>{
            'formatVersion',
            'exportedAt',
            'application',
            'device',
            'retention',
            'records',
            'privacy',
          }).isNotEmpty) {
        throw const DiagnosticExportPrivacyException();
      }
      _policy.validateExportDocument(decoded);
    } on DiagnosticPrivacyViolation {
      throw const DiagnosticExportPrivacyException();
    } on FormatException {
      throw const DiagnosticExportPrivacyException();
    }
  }

  Future<void> _removeOldExports() async {
    final cutoff = _now().subtract(const Duration(hours: 24));
    await for (final entity in exportDirectory.list()) {
      if (entity is File && (await entity.lastModified()).isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }

  static String _fileName(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return 'Yahagi-Diagnostics-${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}.json';
  }
}
