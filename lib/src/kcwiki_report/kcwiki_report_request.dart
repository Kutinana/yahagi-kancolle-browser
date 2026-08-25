import 'dart:convert';

enum KcwikiReportEncoding { form, json }

enum KcwikiReportModule {
  friendlyInfo('friendly_info', KcwikiReportEncoding.json),
  airBaseAttack('air_base_attack', KcwikiReportEncoding.form),
  nextWayV2('next_way_v2', KcwikiReportEncoding.form),
  quest('quest', KcwikiReportEncoding.form),
  battle('battle', KcwikiReportEncoding.json),
  remodel('remodel', KcwikiReportEncoding.json);

  const KcwikiReportModule(this.wireName, this.encoding);

  final String wireName;
  final KcwikiReportEncoding encoding;

  String get path => '/api/report/$wireName';
}

final class KcwikiReportRequest {
  KcwikiReportRequest._(this.module, this.fields, this.encoding)
    : encodedBody = encoding == KcwikiReportEncoding.json
          ? jsonEncode(fields)
          : _encodeForm(fields);

  factory KcwikiReportRequest.form(
    KcwikiReportModule module,
    Map<String, Object?> fields,
  ) {
    assert(module.encoding == KcwikiReportEncoding.form);
    return KcwikiReportRequest._(
      module,
      _freezeMap(fields),
      KcwikiReportEncoding.form,
    );
  }

  factory KcwikiReportRequest.json(
    KcwikiReportModule module,
    Map<String, Object?> fields,
  ) {
    assert(module.encoding == KcwikiReportEncoding.json);
    return KcwikiReportRequest._(
      module,
      _freezeMap(fields),
      KcwikiReportEncoding.json,
    );
  }

  factory KcwikiReportRequest.forModule(
    KcwikiReportModule module,
    Map<String, Object?> fields,
  ) => module.encoding == KcwikiReportEncoding.json
      ? KcwikiReportRequest.json(module, fields)
      : KcwikiReportRequest.form(module, fields);

  final KcwikiReportModule module;
  final Map<String, Object?> fields;
  final KcwikiReportEncoding encoding;
  final String encodedBody;

  int get byteLength => utf8.encode(encodedBody).length;

  String get contentType => switch (encoding) {
    KcwikiReportEncoding.form =>
      'application/x-www-form-urlencoded; charset=UTF-8',
    KcwikiReportEncoding.json => 'application/json; charset=UTF-8',
  };
}

Map<String, Object?> _freezeMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final entry in source.entries) entry.key: _freeze(entry.value),
    });

Object? _freeze(Object? value) {
  if (value is Map) {
    return _freezeMap(<String, Object?>{
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freeze));
  }
  return value;
}

String _encodeForm(Map<String, Object?> fields) {
  final pairs = <MapEntry<String, String>>[];
  final keys = fields.keys.toList(growable: false)..sort();
  for (final key in keys) {
    _flattenForm(key, fields[key], pairs);
  }
  return pairs
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
}

void _flattenForm(
  String key,
  Object? value,
  List<MapEntry<String, String>> output,
) {
  if (value is Map) {
    final keys = value.keys.whereType<String>().toList(growable: false)..sort();
    for (final childKey in keys) {
      _flattenForm('$key[$childKey]', value[childKey], output);
    }
    return;
  }
  if (value is List) {
    for (var index = 0; index < value.length; index++) {
      _flattenForm('$key[$index]', value[index], output);
    }
    return;
  }
  output.add(MapEntry<String, String>(key, value?.toString() ?? ''));
}
