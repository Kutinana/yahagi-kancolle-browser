import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'development_snapshot_builder.dart';

const _repository = 'https://github.com/SkywalkerJi/kc-development-tools';
const _authorizedCommit = 'd065120';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseArguments(arguments);
    final sourceDirectory = Directory(options.sourceDirectory).absolute;
    final output = File(options.output).absolute;
    final developmentPool = File(
      '${sourceDirectory.path}${Platform.pathSeparator}public${Platform.pathSeparator}data${Platform.pathSeparator}DevelopmentPool.json',
    );
    final start2 = File(
      '${sourceDirectory.path}${Platform.pathSeparator}public${Platform.pathSeparator}data${Platform.pathSeparator}start2.json',
    );
    final ctype = File(
      '${sourceDirectory.path}${Platform.pathSeparator}public${Platform.pathSeparator}data${Platform.pathSeparator}ctype.json',
    );
    final poolNames = File(
      '${sourceDirectory.path}${Platform.pathSeparator}src${Platform.pathSeparator}i18n${Platform.pathSeparator}names${Platform.pathSeparator}poolNames.ts',
    );
    for (final file in [developmentPool, start2, ctype, poolNames]) {
      if (!await file.exists()) {
        throw StateError('Missing source file: ${file.path}');
      }
    }

    final commitResult = await Process.run('git', [
      '-C',
      sourceDirectory.path,
      'rev-parse',
      '--short',
      'HEAD',
    ]);
    if (commitResult.exitCode != 0) {
      throw StateError(
        'Unable to resolve Git commit in ${sourceDirectory.path}: ${commitResult.stderr}',
      );
    }
    final commit = '${commitResult.stdout}'.trim();
    if (commit.isEmpty) {
      throw StateError(
        'Git returned an empty commit for ${sourceDirectory.path}',
      );
    }
    if (commit != _authorizedCommit) {
      throw StateError(
        'Source commit $commit does not match authorized commit '
        '$_authorizedCommit',
      );
    }
    final timeResult = await Process.run('git', [
      '-C',
      sourceDirectory.path,
      'show',
      '-s',
      '--format=%cI',
      'HEAD',
    ]);
    if (timeResult.exitCode != 0) {
      throw StateError(
        'Unable to resolve source commit time: ${timeResult.stderr}',
      );
    }
    final generatedAt = DateTime.parse('${timeResult.stdout}'.trim()).toUtc();

    final sourceFiles = <String, File>{
      'DevelopmentPool.json': developmentPool,
      'start2.json': start2,
      'ctype.json': ctype,
      'poolNames.ts': poolNames,
    };
    final hashes = <String, String>{};
    for (final entry in sourceFiles.entries) {
      hashes[entry.key] = sha256
          .convert(await entry.value.readAsBytes())
          .toString();
    }

    final decodedPools = jsonDecode(await developmentPool.readAsString());
    final decodedStart2 = jsonDecode(await start2.readAsString());
    final decodedCtype = jsonDecode(await ctype.readAsString());
    if (decodedPools is! List ||
        decodedStart2 is! Map ||
        decodedCtype is! Map) {
      throw const FormatException('Source JSON root types are invalid');
    }
    final labels = _parsePoolLabels(await poolNames.readAsString());
    final snapshot = buildDevelopmentSnapshot(
      pools: decodedPools.cast<Object?>(),
      start2: decodedStart2.map((key, value) => MapEntry('$key', value)),
      ctypeNames: decodedCtype.map((key, value) => MapEntry('$key', '$value')),
      poolLabels: labels,
      source: DevelopmentSourceMetadata(
        repository: _repository,
        commit: commit,
        hashes: hashes,
      ),
      generatedAt: generatedAt,
    );
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(snapshot)}\n',
    );

    final summary = snapshot['summary']! as Map<String, Object?>;
    stdout.writeln(
      'Generated ${output.path}: '
      '${summary['pool_count']} pools, '
      '${summary['selectable_pool_count']} selectable pools, '
      '${summary['equipment_count']} equipment, '
      '${summary['negative_pool_count']} negative pools, '
      '${summary['minimum_resource_pool_count']} minimum-resource pools.',
    );
  } on Object catch (error) {
    stderr.writeln('development data sync failed: $error');
    exitCode = 64;
  }
}

_SyncOptions _parseArguments(List<String> arguments) {
  String? sourceDirectory;
  String? output;
  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--source-dir':
        if (++index >= arguments.length) {
          throw const FormatException('--source-dir requires a path');
        }
        sourceDirectory = arguments[index];
      case '--output':
        if (++index >= arguments.length) {
          throw const FormatException('--output requires a path');
        }
        output = arguments[index];
      default:
        throw FormatException('Unknown argument: ${arguments[index]}');
    }
  }
  if (sourceDirectory == null || output == null) {
    throw const FormatException(
      'Usage: sync.dart --source-dir PATH --output FILE',
    );
  }
  return _SyncOptions(sourceDirectory, output);
}

Map<String, Map<String, String>> _parsePoolLabels(String source) {
  final result = <String, Map<String, String>>{};
  final pattern = RegExp(
    r"^\s*'([^']+)':\s*\{\s*'zh-Hans':\s*'([^']*)',\s*'zh-Hant':\s*'([^']*)',\s*ja:\s*'([^']*)',",
    multiLine: true,
  );
  for (final match in pattern.allMatches(source)) {
    result[match.group(1)!] = <String, String>{
      'zh': match.group(2)!,
      'zh_Hant': match.group(3)!,
      'ja': match.group(4)!,
    };
  }
  if (result.isEmpty) {
    throw const FormatException('poolNames.ts contains no pool labels');
  }
  return result;
}

class _SyncOptions {
  const _SyncOptions(this.sourceDirectory, this.output);
  final String sourceDirectory;
  final String output;
}
