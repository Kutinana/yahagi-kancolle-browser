import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'improvement_dataset.dart';
import 'improvement_dataset_store.dart';
import 'improvement_raw_bundle.dart';

sealed class ImprovementUpdateResult {
  const ImprovementUpdateResult();
}

class ImprovementUpToDate extends ImprovementUpdateResult {
  const ImprovementUpToDate();
}

class ImprovementUpdated extends ImprovementUpdateResult {
  const ImprovementUpdated(this.dataset);
  final ImprovementDataset dataset;
}

enum ImprovementUpdateFailure { network, validation, storage }

class ImprovementUpdateFailed extends ImprovementUpdateResult {
  const ImprovementUpdateFailed(this.kind, this.error);
  final ImprovementUpdateFailure kind;
  final Object error;
}

abstract interface class ImprovementUpdateClient {
  Future<ImprovementUpdateResult> checkAndUpdate(ImprovementDataset current);
}

class ImprovementDatasetUpdateService implements ImprovementUpdateClient {
  const ImprovementDatasetUpdateService({
    required this.client,
    required this.store,
    this.timeout = const Duration(seconds: 10),
    this.maximumFileBytes = 2 * 1024 * 1024,
    this.maximumTotalBytes = 8 * 1024 * 1024,
  });
  static const repository = 'auluu/PlannerRemoteRawData';
  static final commitUri = Uri.https(
    'api.github.com',
    '/repos/$repository/commits/main',
  );
  final http.Client client;
  final ImprovementDatasetStore store;
  final Duration timeout;
  final int maximumFileBytes;
  final int maximumTotalBytes;

  @override
  Future<ImprovementUpdateResult> checkAndUpdate(
    ImprovementDataset current,
  ) async {
    try {
      final metadata = jsonDecode(
        utf8.decode(await _get(commitUri, 64 * 1024)),
      );
      if (metadata is! Map || metadata['sha'] is! String) {
        throw const FormatException('提交信息无效');
      }
      final sha = metadata['sha'] as String;
      if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sha)) {
        throw const FormatException('提交号无效');
      }
      if (sha == current.version.commitSha) return const ImprovementUpToDate();
      final names = <String>[
        'data_manifest.json',
        ...ImprovementRawBundle.dataFiles,
      ];
      final files = <String, String>{};
      var total = 0;
      for (final name in names) {
        final downloaded = await _download(sha, name);
        total += downloaded.length;
        if (total > maximumTotalBytes) {
          throw const FormatException('改修资料总体积超限');
        }
        files[name] = utf8.decode(downloaded);
      }
      final dataset = ImprovementRawBundle.parse(
        files,
        commitSha: sha,
      ).normalize();
      if (dataset.version.dataVersion.compareTo(current.version.dataVersion) <
          0) {
        throw const FormatException('拒绝回退改修资料版本');
      }
      try {
        await store.save(dataset);
      } on IOException catch (error) {
        return ImprovementUpdateFailed(ImprovementUpdateFailure.storage, error);
      }
      return ImprovementUpdated(dataset);
    } on FormatException catch (error) {
      return ImprovementUpdateFailed(
        ImprovementUpdateFailure.validation,
        error,
      );
    } on Object catch (error) {
      return ImprovementUpdateFailed(ImprovementUpdateFailure.network, error);
    }
  }

  Future<List<int>> _download(String sha, String name) async {
    Object? lastError;
    for (final uri in <Uri>[
      Uri.https('raw.githubusercontent.com', '/$repository/$sha/$name'),
      Uri.https('cdn.jsdelivr.net', '/gh/$repository@$sha/$name'),
    ]) {
      try {
        return await _get(uri, maximumFileBytes);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? const HttpException('没有可用的改修资料源');
  }

  Future<List<int>> _get(Uri uri, int limit) async {
    final allowed =
        uri == commitUri ||
        uri.host == 'raw.githubusercontent.com' ||
        uri.host == 'cdn.jsdelivr.net';
    if (uri.scheme != 'https' || !allowed) {
      throw FormatException('不允许的更新地址: $uri');
    }
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['User-Agent'] = 'Yahagi-Kancolle-Browser';
    final response = await client.send(request).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(timeout)) {
      if (bytes.length + chunk.length > limit) {
        throw const FormatException('改修资料文件体积超限');
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }
}
