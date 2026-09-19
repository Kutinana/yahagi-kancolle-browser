import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'sortie_map_models.dart';

final class InstalledSortieMapCatalog {
  const InstalledSortieMapCatalog({required this.data, required this.root});

  final SortieMapCatalogData data;
  final Directory root;

  File resolve(String logicalPath) => File(path.join(root.path, logicalPath));
}

abstract interface class SortieMapCatalogInstaller {
  Future<InstalledSortieMapCatalog> installArchive(List<int> bytes);
}

final class FileSortieMapCatalogStore implements SortieMapCatalogInstaller {
  const FileSortieMapCatalogStore({
    required this.root,
    this.maximumFiles = 256,
    this.maximumUncompressedBytes = 96 * 1024 * 1024,
  });

  static Future<FileSortieMapCatalogStore> create() async {
    final support = await getApplicationSupportDirectory();
    return FileSortieMapCatalogStore(
      root: Directory(path.join(support.path, 'sortie-catalog')),
    );
  }

  final Directory root;
  final int maximumFiles;
  final int maximumUncompressedBytes;

  File get _activeFile => File(path.join(root.path, 'active.json'));

  Future<InstalledSortieMapCatalog?> loadCached() async {
    try {
      final pointer = await _readActivePointer();
      if (pointer == null) return null;
      final directory = Directory(path.join(root.path, 'versions', pointer));
      return await _readInstalled(directory);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<InstalledSortieMapCatalog> installArchive(List<int> bytes) async {
    if (bytes.isEmpty) throw const FormatException('Sortie archive is empty.');
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.isEmpty || archive.length > maximumFiles) {
      throw const FormatException('Sortie archive file count is invalid.');
    }

    var totalBytes = 0;
    final files = <String, Uint8List>{};
    for (final item in archive) {
      if (!item.isFile || item.isSymbolicLink) {
        throw const FormatException(
          'Sortie archive contains an unsupported entry.',
        );
      }
      final name = item.name.replaceAll('\\', '/');
      if (!_isSafeArchivePath(name) || !_isAllowedArchivePath(name)) {
        throw FormatException('Unsafe sortie archive path: $name');
      }
      if (files.containsKey(name)) {
        throw FormatException('Duplicate sortie archive path: $name');
      }
      final content = item.readBytes();
      if (content == null) {
        throw FormatException('Cannot read sortie archive path: $name');
      }
      totalBytes += content.length;
      if (totalBytes > maximumUncompressedBytes) {
        throw const FormatException(
          'Sortie archive expands beyond the safe limit.',
        );
      }
      files[name] = content;
    }

    final rawCatalog = files['sortie_map_catalog.json'];
    if (rawCatalog == null) {
      throw const FormatException('Sortie archive has no catalog.');
    }
    final data = SortieMapCatalogData.fromJsonString(utf8.decode(rawCatalog));
    _validateCatalog(data, files);

    final versionName = data.revision.toString();
    await root.create(recursive: true);
    final versions = Directory(path.join(root.path, 'versions'));
    await versions.create(recursive: true);
    final staging = Directory(path.join(root.path, '.staging-$versionName'));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    try {
      for (final entry in files.entries) {
        final target = File(path.join(staging.path, entry.key));
        await target.parent.create(recursive: true);
        await target.writeAsBytes(entry.value, flush: true);
      }
      await _readInstalled(staging);
      final target = Directory(path.join(versions.path, versionName));
      final previous = Directory('${target.path}.previous');
      if (await previous.exists()) await previous.delete(recursive: true);
      if (await target.exists()) await target.rename(previous.path);
      try {
        await staging.rename(target.path);
      } catch (_) {
        if (await previous.exists()) await previous.rename(target.path);
        rethrow;
      }
      await _writeActivePointer(versionName);
      if (await previous.exists()) await previous.delete(recursive: true);
      return _readInstalled(target);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<InstalledSortieMapCatalog> _readInstalled(Directory directory) async {
    final catalogFile = File(
      path.join(directory.path, 'sortie_map_catalog.json'),
    );
    final data = SortieMapCatalogData.fromJsonString(
      await catalogFile.readAsString(),
    );
    for (final map in data.maps) {
      for (final logical in <String>[map.coverAsset, map.mapAsset]) {
        final file = File(path.join(directory.path, logical));
        if (!await file.exists() ||
            !_hasPngSignature(
              await file.openRead(0, 8).fold(<int>[], (a, b) => a..addAll(b)),
            )) {
          throw FormatException('Invalid sortie image: $logical');
        }
      }
    }
    return InstalledSortieMapCatalog(data: data, root: directory);
  }

  Future<String?> _readActivePointer() async {
    final backup = File('${_activeFile.path}.bak');
    if (!await _activeFile.exists() && await backup.exists()) {
      await backup.rename(_activeFile.path);
    }
    if (!await _activeFile.exists()) return null;
    final decoded = jsonDecode(await _activeFile.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['revision'] is! String) {
      throw const FormatException('Sortie active pointer is invalid.');
    }
    final value = decoded['revision'] as String;
    if (!RegExp(r'^\d{1,20}$').hasMatch(value)) {
      throw const FormatException('Sortie active revision is invalid.');
    }
    return value;
  }

  Future<void> _writeActivePointer(String value) async {
    final temporary = File('${_activeFile.path}.tmp');
    final backup = File('${_activeFile.path}.bak');
    await temporary.writeAsString(
      jsonEncode(<String, String>{'revision': value}),
      flush: true,
    );
    if (await backup.exists()) await backup.delete();
    if (await _activeFile.exists()) await _activeFile.rename(backup.path);
    try {
      await temporary.rename(_activeFile.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await _activeFile.exists()) await _activeFile.delete();
      if (await backup.exists()) await backup.rename(_activeFile.path);
      rethrow;
    }
  }
}

bool _isSafeArchivePath(String value) {
  if (value.isEmpty ||
      value.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(value)) {
    return false;
  }
  final segments = value.split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
}

bool _isAllowedArchivePath(String value) =>
    value == 'sortie_map_catalog.json' ||
    RegExp(r'^(covers|maps)/[A-Za-z0-9-]+\.png$').hasMatch(value);

void _validateCatalog(SortieMapCatalogData data, Map<String, Uint8List> files) {
  if (data.schemaVersion != 1 || data.maps.isEmpty) {
    throw const FormatException('Sortie catalog metadata is invalid.');
  }
  final mapIds = <String>{};
  final expected = <String>{'sortie_map_catalog.json'};
  for (final map in data.maps) {
    if (!mapIds.add(map.id)) {
      throw FormatException('Duplicate sortie map id: ${map.id}');
    }
    final points = <String>{};
    for (final node in map.nodes) {
      if (!points.add(node.point)) {
        throw FormatException('Duplicate sortie node: ${map.id}/${node.point}');
      }
    }
    for (final image in <String>[map.coverAsset, map.mapAsset]) {
      if (!_isAllowedArchivePath(image)) {
        throw FormatException('Unsafe sortie image path: $image');
      }
      final content = files[image];
      if (content == null || !_hasPngSignature(content)) {
        throw FormatException('Missing sortie image: $image');
      }
      expected.add(image);
    }
  }
  if (files.keys.toSet().difference(expected).isNotEmpty) {
    throw const FormatException('Sortie archive contains unreferenced files.');
  }
}

bool _hasPngSignature(List<int> bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 137 &&
    bytes[1] == 80 &&
    bytes[2] == 78 &&
    bytes[3] == 71 &&
    bytes[4] == 13 &&
    bytes[5] == 10 &&
    bytes[6] == 26 &&
    bytes[7] == 10;
