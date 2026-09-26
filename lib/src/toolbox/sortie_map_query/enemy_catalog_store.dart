import 'dart:io';

import 'package:path/path.dart' as path;

import 'catalog_platform_stub.dart'
    if (dart.library.ui) 'catalog_platform_flutter.dart'
    as catalog_platform;

import 'enemy_catalog.dart';

final class FileEnemyCatalogStore {
  const FileEnemyCatalogStore({
    required this.cacheFile,
    required this.bundledReader,
  });

  static Future<FileEnemyCatalogStore> create() async {
    final support = await catalog_platform.getCatalogSupportDirectory();
    return FileEnemyCatalogStore(
      cacheFile: File(path.join(support.path, 'enemy-catalog.json')),
      bundledReader: catalog_platform.loadEnemyCatalogAsset,
    );
  }

  final File cacheFile;
  final Future<String> Function() bundledReader;

  Future<EnemyCatalogData> loadBestAvailable() async {
    final bundled = EnemyCatalogData.fromJsonString(await bundledReader());
    final backup = File('${cacheFile.path}.bak');
    try {
      if (!await cacheFile.exists() && await backup.exists()) {
        await cacheFile.parent.create(recursive: true);
        await backup.rename(cacheFile.path);
      }
      if (!await cacheFile.exists()) return bundled;
      EnemyCatalogData cached;
      try {
        cached = EnemyCatalogData.fromJsonString(
          await cacheFile.readAsString(),
        );
        if (await backup.exists()) await backup.delete();
      } on Object {
        if (!await backup.exists()) rethrow;
        cached = EnemyCatalogData.fromJsonString(await backup.readAsString());
        await cacheFile.delete();
        await backup.rename(cacheFile.path);
      }
      return cached.revision >= bundled.revision ? cached : bundled;
    } on Object {
      return bundled;
    }
  }

  Future<void> save(EnemyCatalogData catalog) async {
    EnemyCatalogData.fromJsonString(catalog.rawJson);
    await cacheFile.parent.create(recursive: true);
    final temporary = File('${cacheFile.path}.tmp');
    final backup = File('${cacheFile.path}.bak');
    try {
      await temporary.writeAsString(catalog.rawJson, flush: true);
      if (await backup.exists()) await backup.delete();
      if (await cacheFile.exists()) await cacheFile.rename(backup.path);
      try {
        await temporary.rename(cacheFile.path);
        EnemyCatalogData.fromJsonString(await cacheFile.readAsString());
        if (await backup.exists()) await backup.delete();
      } on Object {
        if (await cacheFile.exists()) await cacheFile.delete();
        if (await backup.exists()) await backup.rename(cacheFile.path);
        rethrow;
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
