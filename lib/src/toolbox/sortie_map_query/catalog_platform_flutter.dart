import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<Directory> getCatalogSupportDirectory() =>
    getApplicationSupportDirectory();

Future<String> loadEnemyCatalogAsset() async {
  final data = await rootBundle.load('assets/data/enemy_catalog.json');
  return utf8.decode(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}
