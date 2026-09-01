import 'dart:convert';

import 'package:flutter/services.dart';

import 'development_dataset.dart';

typedef DevelopmentAssetLoader = Future<String> Function(String path);

class DevelopmentRepository {
  DevelopmentRepository({DevelopmentAssetLoader? loadString})
    : loadString = loadString ?? rootBundle.loadString;

  static const assetPath = 'assets/data/development/development_snapshot.json';

  final DevelopmentAssetLoader loadString;
  Future<DevelopmentDataset>? _load;

  Future<DevelopmentDataset> load() =>
      _load ??= _loadOnce().catchError((Object error, StackTrace stackTrace) {
        _load = null;
        Error.throwWithStackTrace(error, stackTrace);
      });

  Future<DevelopmentDataset> _loadOnce() async {
    final source = await loadString(assetPath);
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Development snapshot root must be an object',
      );
    }
    return DevelopmentDataset.fromJson(
      decoded.map((key, value) => MapEntry('$key', value)),
    );
  }
}
