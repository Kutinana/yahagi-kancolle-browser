import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'catalog_platform_stub.dart'
    if (dart.library.ui) 'catalog_platform_flutter.dart'
    as catalog_platform;

import 'sortie_map_catalog_manifest.dart';
import 'sortie_map_models.dart';

final class SortieMapCatalogInstallExpectation {
  const SortieMapCatalogInstallExpectation({
    required this.version,
    required this.mapCount,
    required this.nodeCount,
    required this.formationCount,
    this.minimumAppVersion = '0.0.0',
  });

  final SortieMapCatalogVersion version;
  final int mapCount;
  final int nodeCount;
  final int formationCount;
  final String minimumAppVersion;
}

final class InstalledSortieMapCatalog {
  const InstalledSortieMapCatalog({required this.data, required this.root});

  final SortieMapCatalogData data;
  final Directory root;

  File resolve(String logicalPath) => File(path.join(root.path, logicalPath));
}

abstract interface class SortieMapCatalogInstaller {
  Future<InstalledSortieMapCatalog> installArchive(
    List<int> bytes, {
    SortieMapCatalogInstallExpectation? expected,
  });
}

final class FileSortieMapCatalogStore implements SortieMapCatalogInstaller {
  const FileSortieMapCatalogStore({
    required this.root,
    this.maximumArchiveBytes = 64 * 1024 * 1024,
    this.maximumFiles = 256,
    this.maximumUncompressedBytes = 96 * 1024 * 1024,
    this.currentAppVersion = '999.999.999',
    this.phaseHook,
    this.inflateProgress,
  });

  static Future<FileSortieMapCatalogStore> create({
    required String currentAppVersion,
  }) async {
    final support = await catalog_platform.getCatalogSupportDirectory();
    return FileSortieMapCatalogStore(
      root: Directory(path.join(support.path, 'sortie-catalog')),
      currentAppVersion: currentAppVersion,
    );
  }

  final Directory root;
  final int maximumArchiveBytes;
  final int maximumFiles;
  final int maximumUncompressedBytes;
  final String currentAppVersion;
  final Future<void> Function(String phase)? phaseHook;
  final void Function(int consumedBytes, int totalBytes)? inflateProgress;

  File get _activeFile => File(path.join(root.path, 'active.json'));

  Future<InstalledSortieMapCatalog?> loadCached() async {
    try {
      final pointer = await _readActivePointer();
      if (pointer == null) return null;
      final directory = Directory(path.join(root.path, 'versions', pointer));
      return await _readInstalled(
        directory,
        trustedParent: Directory(path.join(root.path, 'versions')),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<InstalledSortieMapCatalog> installArchive(
    List<int> bytes, {
    SortieMapCatalogInstallExpectation? expected,
  }) async {
    if (bytes.isEmpty) throw const FormatException('Sortie archive is empty.');
    if (bytes.length > maximumArchiveBytes) {
      throw const FormatException(
        'Sortie archive exceeds the safe input limit.',
      );
    }
    final files = _decodeArchiveSafely(
      bytes,
      maximumFiles: maximumFiles,
      maximumUncompressedBytes: maximumUncompressedBytes,
      inflateProgress: inflateProgress,
    );

    final rawCatalog = files['sortie_map_catalog.json'];
    if (rawCatalog == null) {
      throw const FormatException('Sortie archive has no catalog.');
    }
    final data = SortieMapCatalogData.fromJsonString(utf8.decode(rawCatalog));
    _validateCatalog(data, files);
    if (expected != null) _validateExpectation(data, expected);
    final effectiveExpectation = expected ?? _expectationFrom(data);
    final metadata = _buildInstallMetadata(effectiveExpectation, files);

    final versionName = data.revision.toString();
    final previousPointer = await _readActivePointer();
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
      await File(
        path.join(staging.path, '.install-metadata.json'),
      ).writeAsString(jsonEncode(metadata), flush: true);
      await _readInstalled(staging, trustedParent: root);
      final target = Directory(path.join(versions.path, versionName));
      final previous = Directory('${target.path}.previous');
      if (await previous.exists()) await previous.delete(recursive: true);
      if (await target.exists()) await target.rename(previous.path);
      var committed = false;
      try {
        await phaseHook?.call('beforeVersionRename');
        await staging.rename(target.path);
        final installed = await _readInstalled(target, trustedParent: versions);
        await _writeActivePointer(versionName);
        committed = true;
        try {
          await phaseHook?.call('beforeCleanup');
          if (await previous.exists()) await previous.delete(recursive: true);
          await _cleanupVersions(
            versions,
            keep: <String>{versionName, ?previousPointer},
          );
        } catch (_) {
          // Cleanup happens after the atomic commit and must never turn a
          // successful activation into a reported failure.
        }
        return installed;
      } catch (_) {
        if (!committed) {
          if (await target.exists()) await target.delete(recursive: true);
          if (await previous.exists()) await previous.rename(target.path);
        }
        rethrow;
      }
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<InstalledSortieMapCatalog> _readInstalled(
    Directory directory, {
    required Directory trustedParent,
  }) async {
    final canonicalStoreRoot = await root.resolveSymbolicLinks();
    final canonicalParent = await trustedParent.resolveSymbolicLinks();
    if (canonicalParent != canonicalStoreRoot &&
        !path.isWithin(canonicalStoreRoot, canonicalParent)) {
      throw const FormatException(
        'Cached sortie parent directory escapes the store root.',
      );
    }
    final canonicalRoot = await directory.resolveSymbolicLinks();
    if (!path.isWithin(canonicalParent, canonicalRoot)) {
      throw const FormatException(
        'Cached sortie version directory escapes its trusted parent.',
      );
    }
    final metadataFile = await _resolveContainedFile(
      canonicalRoot,
      File(path.join(directory.path, '.install-metadata.json')),
      '.install-metadata.json',
    );
    final metadata = _parseInstallMetadata(await metadataFile.readAsString());
    if (!SortieMapCatalogManifest.isVersionCompatible(
      currentAppVersion,
      metadata.minimumAppVersion,
    )) {
      throw const FormatException(
        'Cached sortie catalog requires a newer app version.',
      );
    }
    final catalogFile = await _resolveContainedFile(
      canonicalRoot,
      File(path.join(directory.path, 'sortie_map_catalog.json')),
      'sortie_map_catalog.json',
    );
    final catalogBytes = await catalogFile.readAsBytes();
    final expectedCatalog = metadata.files['sortie_map_catalog.json'];
    if (expectedCatalog == null ||
        catalogBytes.length != expectedCatalog.bytes ||
        sha256.convert(catalogBytes).toString() != expectedCatalog.sha256) {
      throw const FormatException('Cached sortie catalog was tampered with.');
    }
    final data = SortieMapCatalogData.fromJsonString(utf8.decode(catalogBytes));
    _validateCatalogStructure(data);
    _validateExpectation(data, metadata.expectation);
    final expectedPaths = <String>{'sortie_map_catalog.json'};
    for (final map in data.maps) {
      for (final logical in <String>[map.coverAsset, map.mapAsset]) {
        expectedPaths.add(logical);
        final file = await _resolveContainedFile(
          canonicalRoot,
          File(path.join(directory.path, logical)),
          logical,
        );
        final expectedFile = metadata.files[logical];
        if (expectedFile == null) {
          throw FormatException('Invalid sortie image: $logical');
        }
        final bytes = await file.readAsBytes();
        if (bytes.length != expectedFile.bytes ||
            sha256.convert(bytes).toString() != expectedFile.sha256) {
          throw FormatException('Tampered sortie image: $logical');
        }
      }
    }
    if (metadata.files.keys.toSet().difference(expectedPaths).isNotEmpty ||
        expectedPaths.difference(metadata.files.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'Cached sortie metadata has an unexpected file set.',
      );
    }
    return InstalledSortieMapCatalog(data: data, root: directory);
  }

  Future<File> _resolveContainedFile(
    String canonicalRoot,
    File file,
    String logicalPath,
  ) async {
    if (!await file.exists()) {
      throw FormatException('Missing cached sortie file: $logicalPath');
    }
    final canonicalFile = await file.resolveSymbolicLinks();
    if (!path.isWithin(canonicalRoot, canonicalFile)) {
      throw FormatException('Cached sortie file escapes root: $logicalPath');
    }
    return File(canonicalFile);
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
      await phaseHook?.call('beforePointerCommit');
      await temporary.rename(_activeFile.path);
    } catch (_) {
      if (await _activeFile.exists()) await _activeFile.delete();
      if (await backup.exists()) await backup.rename(_activeFile.path);
      rethrow;
    }
    try {
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      // The pointer rename above is the commit point. Backup cleanup is
      // best-effort and cannot change a successful result into a failure.
    }
  }

  Future<void> _cleanupVersions(
    Directory versions, {
    required Set<String> keep,
  }) async {
    await for (final entity in versions.list(followLinks: false)) {
      if (entity is Directory && !keep.contains(path.basename(entity.path))) {
        await entity.delete(recursive: true);
      }
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

Map<String, Uint8List> _decodeArchiveSafely(
  List<int> bytes, {
  required int maximumFiles,
  required int maximumUncompressedBytes,
  void Function(int consumedBytes, int totalBytes)? inflateProgress,
}) {
  try {
    final directory = ZipDirectory()
      ..read(InputMemoryStream(Uint8List.fromList(bytes)));
    final headers = directory.fileHeaders;
    if (headers.isEmpty || headers.length > maximumFiles) {
      throw const FormatException('Sortie archive file count is invalid.');
    }

    var declaredTotal = 0;
    final names = <String>{};
    for (final header in headers) {
      final name = header.filename.replaceAll('\\', '/');
      final unixMode = header.externalFileAttributes >> 16;
      final fileType = unixMode & 0xf000;
      final encrypted = header.generalPurposeBitFlag & 0x1 != 0;
      if (encrypted ||
          (header.compressionMethod != ZipFile.zipCompressionStore &&
              header.compressionMethod != ZipFile.zipCompressionDeflate) ||
          (fileType != 0 && fileType != 0x8000)) {
        throw const FormatException(
          'Sortie archive contains an unsupported entry.',
        );
      }
      if (!_isSafeArchivePath(name) || !_isAllowedArchivePath(name)) {
        throw FormatException('Unsafe sortie archive path: $name');
      }
      if (!names.add(name)) {
        throw FormatException('Duplicate sortie archive path: $name');
      }
      if (header.compressedSize < 0 ||
          header.compressedSize > bytes.length ||
          header.uncompressedSize < 0 ||
          declaredTotal + header.uncompressedSize > maximumUncompressedBytes) {
        throw const FormatException(
          'Sortie archive expands beyond the safe limit.',
        );
      }
      declaredTotal += header.uncompressedSize;
    }

    var actualTotal = 0;
    final files = <String, Uint8List>{};
    for (final header in headers) {
      final remaining = maximumUncompressedBytes - actualTotal;
      final output = _BoundedOutputMemoryStream(maximumBytes: remaining);
      final file = header.file;
      if (file == null) {
        throw FormatException(
          'Cannot read sortie archive path: ${header.filename}',
        );
      }
      final compressed = file.getRawContent();
      if (header.compressionMethod == ZipFile.zipCompressionDeflate) {
        _inflateRawDeflate(compressed, output, inflateProgress);
      } else {
        output.writeBytes(compressed);
      }
      final content = output.getBytes();
      if (content.length != header.uncompressedSize ||
          getCrc32(content) != header.crc32) {
        throw FormatException(
          'Sortie archive entry integrity check failed: ${header.filename}',
        );
      }
      actualTotal += content.length;
      files[header.filename.replaceAll('\\', '/')] = content;
    }
    return files;
  } on FormatException {
    rethrow;
  } on Object catch (error) {
    throw FormatException('Sortie archive cannot be decoded.', error);
  }
}

void _inflateRawDeflate(
  Uint8List compressed,
  _BoundedOutputMemoryStream output,
  void Function(int consumedBytes, int totalBytes)? progress,
) {
  final sink = _BoundedConversionSink(output);
  final decoder = ZLibCodec(raw: true).decoder.startChunkedConversion(sink);
  const inputChunkSize = 4096;
  for (var offset = 0; offset < compressed.length; offset += inputChunkSize) {
    final end = offset + inputChunkSize < compressed.length
        ? offset + inputChunkSize
        : compressed.length;
    progress?.call(end, compressed.length);
    decoder.add(Uint8List.sublistView(compressed, offset, end));
  }
  decoder.close();
}

final class _BoundedConversionSink implements Sink<List<int>> {
  _BoundedConversionSink(this.output);

  final _BoundedOutputMemoryStream output;
  bool _closed = false;

  @override
  void add(List<int> chunk) {
    if (_closed) throw StateError('Cannot add to a closed ZIP output sink.');
    output.writeBytes(chunk);
  }

  @override
  void close() {
    _closed = true;
  }
}

final class _BoundedOutputMemoryStream extends OutputStream {
  _BoundedOutputMemoryStream({required this.maximumBytes})
    : super(byteOrder: ByteOrder.littleEndian);

  final int maximumBytes;
  final BytesBuilder _builder = BytesBuilder(copy: false);

  @override
  int get length => _builder.length;

  void _reserve(int count) {
    if (count < 0 || length + count > maximumBytes) {
      throw const FormatException(
        'Sortie archive actual output exceeds the safe limit.',
      );
    }
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    _builder.addByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    _reserve(count);
    _builder.add(count == bytes.length ? bytes : bytes.take(count).toList());
  }

  @override
  void writeStream(InputStream stream) {
    while (!stream.isEOS) {
      final count = stream.length > 8192 ? 8192 : stream.length;
      writeBytes(stream.readBytes(count).toUint8List());
    }
  }

  @override
  Uint8List subset(int start, [int? end]) {
    final bytes = _builder.toBytes();
    final finish = end ?? bytes.length;
    return Uint8List.sublistView(bytes, start, finish);
  }

  @override
  void clear() => _builder.clear();

  @override
  void flush() {}
}

final class _CachedFileMetadata {
  const _CachedFileMetadata({required this.bytes, required this.sha256});

  final int bytes;
  final String sha256;
}

final class _InstallMetadata {
  const _InstallMetadata({
    required this.expectation,
    required this.minimumAppVersion,
    required this.files,
  });

  final SortieMapCatalogInstallExpectation expectation;
  final String minimumAppVersion;
  final Map<String, _CachedFileMetadata> files;
}

SortieMapCatalogInstallExpectation _expectationFrom(
  SortieMapCatalogData data,
) => SortieMapCatalogInstallExpectation(
  version: data.versionInfo,
  mapCount: data.maps.length,
  nodeCount: data.maps.fold<int>(0, (sum, map) => sum + map.nodes.length),
  formationCount: data.maps.fold<int>(
    0,
    (sum, map) =>
        sum +
        map.nodes.fold<int>(
          0,
          (nodeSum, node) => nodeSum + node.formations.length,
        ),
  ),
);

Map<String, Object?> _buildInstallMetadata(
  SortieMapCatalogInstallExpectation expectation,
  Map<String, Uint8List> files,
) => <String, Object?>{
  'schemaVersion': 1,
  'dataVersion': expectation.version.label,
  'revision': expectation.version.revision,
  'minimumAppVersion': expectation.minimumAppVersion,
  'counts': <String, int>{
    'maps': expectation.mapCount,
    'nodes': expectation.nodeCount,
    'formations': expectation.formationCount,
  },
  'files': <String, Object?>{
    for (final entry in files.entries)
      entry.key: <String, Object?>{
        'bytes': entry.value.length,
        'sha256': sha256.convert(entry.value).toString(),
      },
  },
};

_InstallMetadata _parseInstallMetadata(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
    throw const FormatException('Cached sortie metadata is invalid.');
  }
  final dataVersion = decoded['dataVersion'];
  final revision = decoded['revision'];
  final minimumAppVersion = decoded['minimumAppVersion'];
  final counts = decoded['counts'];
  final rawFiles = decoded['files'];
  if (dataVersion is! String ||
      dataVersion.isEmpty ||
      revision is! int ||
      revision <= 0 ||
      minimumAppVersion is! String ||
      counts is! Map<String, dynamic> ||
      rawFiles is! Map<String, dynamic>) {
    throw const FormatException('Cached sortie metadata fields are invalid.');
  }
  int count(String key) {
    final value = counts[key];
    if (value is! int || value < 0) {
      throw FormatException('Cached sortie count is invalid: $key');
    }
    return value;
  }

  final files = <String, _CachedFileMetadata>{};
  for (final entry in rawFiles.entries) {
    final value = entry.value;
    if (!_isAllowedArchivePath(entry.key) ||
        value is! Map<String, dynamic> ||
        value['bytes'] is! int ||
        (value['bytes'] as int) < 0 ||
        value['sha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['sha256'] as String)) {
      throw FormatException(
        'Cached sortie file metadata is invalid: ${entry.key}',
      );
    }
    files[entry.key] = _CachedFileMetadata(
      bytes: value['bytes'] as int,
      sha256: value['sha256'] as String,
    );
  }
  final expectation = SortieMapCatalogInstallExpectation(
    version: SortieMapCatalogVersion(label: dataVersion, revision: revision),
    mapCount: count('maps'),
    nodeCount: count('nodes'),
    formationCount: count('formations'),
    minimumAppVersion: minimumAppVersion,
  );
  return _InstallMetadata(
    expectation: expectation,
    minimumAppVersion: minimumAppVersion,
    files: files,
  );
}

void _validateCatalog(SortieMapCatalogData data, Map<String, Uint8List> files) {
  _validateCatalogStructure(data);
  final expected = <String>{'sortie_map_catalog.json'};
  for (final map in data.maps) {
    for (final logical in <String>[map.coverAsset, map.mapAsset]) {
      final content = files[logical];
      if (content == null ||
          !_hasPngSignature(content) ||
          !_hasSafePngDimensions(content)) {
        throw FormatException('Missing sortie image: $logical');
      }
      image.Image? decoded;
      try {
        decoded = image.decodePng(content);
      } on Object {
        decoded = null;
      }
      if (decoded == null ||
          decoded.width <= 0 ||
          decoded.height <= 0 ||
          decoded.width > 4096 ||
          decoded.height > 4096 ||
          decoded.width * decoded.height > 8 * 1000 * 1000) {
        throw FormatException('Invalid sortie PNG: $logical');
      }
      expected.add(logical);
    }
  }
  if (files.keys.toSet().difference(expected).isNotEmpty) {
    throw const FormatException('Sortie archive contains unreferenced files.');
  }
}

void _validateCatalogStructure(SortieMapCatalogData data) {
  if (data.schemaVersion != 1 ||
      data.revision <= 0 ||
      data.dataVersion.isEmpty ||
      data.maps.isEmpty) {
    throw const FormatException('Sortie catalog metadata is invalid.');
  }
  final mapIds = <String>{};
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
    }
    if (map.coverAsset != 'covers/${map.id}.png' ||
        map.mapAsset != 'maps/${map.id}.png') {
      throw FormatException(
        'Sortie image names do not match map id: ${map.id}',
      );
    }
  }
}

void _validateExpectation(
  SortieMapCatalogData data,
  SortieMapCatalogInstallExpectation expected,
) {
  final nodes = data.maps.fold<int>(0, (sum, map) => sum + map.nodes.length);
  final formations = data.maps.fold<int>(
    0,
    (sum, map) =>
        sum +
        map.nodes.fold<int>(
          0,
          (nodeSum, node) => nodeSum + node.formations.length,
        ),
  );
  if (data.versionInfo.compareTo(expected.version) != 0 ||
      data.dataVersion != expected.version.label ||
      data.maps.length != expected.mapCount ||
      nodes != expected.nodeCount ||
      formations != expected.formationCount) {
    throw const FormatException(
      'Sortie catalog metadata does not match the signed manifest.',
    );
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

bool _hasSafePngDimensions(List<int> bytes) {
  if (bytes.length < 24 ||
      ascii.decode(bytes.sublist(12, 16), allowInvalid: true) != 'IHDR') {
    return false;
  }
  int uint32(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  final width = uint32(16);
  final height = uint32(20);
  return width > 0 &&
      height > 0 &&
      width <= 4096 &&
      height <= 4096 &&
      width * height <= 8 * 1000 * 1000;
}
