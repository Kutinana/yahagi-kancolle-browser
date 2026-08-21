import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _stripDartComments(String source) {
  final uncommented = StringBuffer();
  var index = 0;

  while (index < source.length) {
    if (source.startsWith('//', index)) {
      index = _replaceLineComment(source, index, uncommented);
    } else if (source.startsWith('/*', index)) {
      index = _replaceBlockComment(source, index, uncommented);
    } else if (_startsRawString(source, index)) {
      uncommented.write(source[index]);
      index = _copyString(source, index + 1, uncommented, raw: true);
    } else if (_isQuote(source[index])) {
      index = _copyString(source, index, uncommented, raw: false);
    } else {
      uncommented.write(source[index]);
      index++;
    }
  }

  return uncommented.toString();
}

int _replaceLineComment(String source, int start, StringBuffer output) {
  var index = start;
  while (index < source.length && source[index] != '\n') {
    output.write(source[index] == '\r' ? '\r' : ' ');
    index++;
  }
  return index;
}

int _replaceBlockComment(String source, int start, StringBuffer output) {
  var index = start;
  var depth = 0;
  while (index < source.length) {
    if (source.startsWith('/*', index)) {
      depth++;
      output.write('  ');
      index += 2;
    } else if (source.startsWith('*/', index)) {
      depth--;
      output.write('  ');
      index += 2;
      if (depth == 0) {
        return index;
      }
    } else {
      final character = source[index];
      output.write(character == '\n' || character == '\r' ? character : ' ');
      index++;
    }
  }
  return index;
}

int _copyString(
  String source,
  int start,
  StringBuffer output, {
  required bool raw,
}) {
  final quote = source[start];
  final tripleQuote = '$quote$quote$quote';
  final delimiter = source.startsWith(tripleQuote, start) ? tripleQuote : quote;
  output.write(delimiter);
  var index = start + delimiter.length;

  while (index < source.length) {
    if (source.startsWith(delimiter, index)) {
      output.write(delimiter);
      return index + delimiter.length;
    }
    if (!raw && source[index] == r'\' && index + 1 < source.length) {
      output
        ..write(source[index])
        ..write(source[index + 1]);
      index += 2;
    } else {
      output.write(source[index]);
      index++;
    }
  }
  return index;
}

bool _startsRawString(String source, int index) {
  return (source[index] == 'r' || source[index] == 'R') &&
      index + 1 < source.length &&
      _isQuote(source[index + 1]);
}

bool _isQuote(String character) => character == "'" || character == '"';

void main() {
  test('app mounts exactly one TopNoticeHost at MaterialApp home', () {
    final source = _stripDartComments(File('lib/main.dart').readAsStringSync());

    expect(RegExp(r'home:\s*TopNoticeHost\(').allMatches(source), hasLength(1));
    expect(RegExp(r'\bTopNoticeHost\s*\(').allMatches(source), hasLength(1));
  });

  test('comment scanner removes line and block comments', () {
    const source = '''
home: TopNoticeHost(
/* TopNoticeHost( */
// TopNoticeHost(
''';

    final uncommented = _stripDartComments(source);

    expect(
      RegExp(r'\bTopNoticeHost\s*\(').allMatches(uncommented),
      hasLength(1),
    );
  });

  test('comment scanner preserves comment markers in Dart strings', () {
    const source = r"""
final url = 'https://example.test/path';
final blockMarker = "/* literal */";
final rawMarker = r'// raw literal';
final escapedQuote = "quoted \"// marker";
final multiline = '''/* triple-quoted literal */''';
""";

    expect(_stripDartComments(source), source);
  });
}
