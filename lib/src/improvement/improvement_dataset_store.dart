import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'improvement_dataset.dart';

abstract interface class ImprovementDatasetStorage {
  Future<String> readBundled();
  Future<String?> readCached();
  Future<void> writeCached(String source);
}

class ImprovementDatasetStore {
  const ImprovementDatasetStore(this.storage);
  final ImprovementDatasetStorage storage;

  Future<ImprovementDataset> loadBestAvailable() async {
    final bundled = ImprovementDataset.parse(await storage.readBundled());
    try {
      final source = await storage.readCached();
      if (source == null) return bundled;
      final cached = ImprovementDataset.parse(source);
      final dataVersionComparison = cached.version.dataVersion.compareTo(
        bundled.version.dataVersion,
      );
      if (dataVersionComparison != 0) {
        return dataVersionComparison > 0 ? cached : bundled;
      }
      return cached.schemaVersion >= bundled.schemaVersion ? cached : bundled;
    } catch (_) {
      return bundled;
    }
  }

  Future<void> save(ImprovementDataset dataset) async {
    final source = dataset.encode();
    ImprovementDataset.parse(source);
    await storage.writeCached(source);
  }
}

class BundledOnlyImprovementDatasetStorage
    implements ImprovementDatasetStorage {
  const BundledOnlyImprovementDatasetStorage();
  @override
  Future<String> readBundled() =>
      rootBundle.loadString(ApplicationImprovementDatasetStorage.bundledPath);
  @override
  Future<String?> readCached() async => null;
  @override
  Future<void> writeCached(String source) => Future<void>.error(
    const FileSystemException('Application support directory is unavailable'),
  );
}

class ApplicationImprovementDatasetStorage
    implements ImprovementDatasetStorage {
  const ApplicationImprovementDatasetStorage(this.cacheFile);
  static const bundledPath = 'assets/data/improvement/planner_snapshot.json';
  final File cacheFile;

  static Future<ApplicationImprovementDatasetStorage> create() async {
    final directory = await getApplicationSupportDirectory();
    return ApplicationImprovementDatasetStorage(
      File(path.join(directory.path, 'improvement-planner.json')),
    );
  }

  @override
  Future<String> readBundled() => rootBundle.loadString(bundledPath);
  @override
  Future<String?> readCached() async =>
      await cacheFile.exists() ? cacheFile.readAsString() : null;
  @override
  Future<void> writeCached(String source) async {
    await cacheFile.parent.create(recursive: true);
    final temporary = File('${cacheFile.path}.tmp');
    final backup = File('${cacheFile.path}.bak');
    await temporary.writeAsString(source, flush: true);
    if (await backup.exists()) await backup.delete();
    if (await cacheFile.exists()) await cacheFile.rename(backup.path);
    try {
      await temporary.rename(cacheFile.path);
      ImprovementDataset.parse(await cacheFile.readAsString());
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await cacheFile.exists()) await cacheFile.delete();
      if (await backup.exists()) await backup.rename(cacheFile.path);
      rethrow;
    }
  }
}
