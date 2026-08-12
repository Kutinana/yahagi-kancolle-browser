import 'dart:convert';
import 'dart:io';

import 'package:yahagi_kancolle_browser/src/improvement/improvement_raw_bundle.dart';

const _repository = 'auluu/PlannerRemoteRawData';

Future<void> main() async {
  final client = HttpClient()..userAgent = 'yahagi-kancolle-browser-data-sync';
  try {
    final commitResponse = await _get(
      client,
      Uri.https('api.github.com', '/repos/$_repository/commits/main'),
    );
    final commit = jsonDecode(commitResponse) as Map<String, Object?>;
    final sha = commit['sha']! as String;
    final names = <String>[
      'data_manifest.json',
      ...ImprovementRawBundle.dataFiles,
    ];
    final files = <String, String>{};
    for (final name in names) {
      files[name] = await _get(
        client,
        Uri.https('raw.githubusercontent.com', '/$_repository/$sha/$name'),
      );
    }
    final dataset = ImprovementRawBundle.parse(
      files,
      commitSha: sha,
    ).normalize();
    final output = File('assets/data/improvement/planner_snapshot.json');
    await output.parent.create(recursive: true);
    await output.writeAsString(dataset.encode(), flush: true);
    stdout.writeln(
      '${dataset.version.dataVersion} $sha ${dataset.entries.length} entries',
    );
  } finally {
    client.close(force: true);
  }
}

Future<String> _get(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('HTTP ${response.statusCode}', uri: uri);
  }
  return response.transform(utf8.decoder).join();
}
