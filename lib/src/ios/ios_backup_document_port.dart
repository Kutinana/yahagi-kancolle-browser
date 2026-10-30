import 'dart:typed_data';

import '../backup/record_backup.dart';

/// Reuses the shared channel codec and its archive/account recovery validation.
/// The method channel is implemented by IOSRecordBackupBridge on this platform.
final class IOSBackupDocumentPort implements BackupDocumentPort {
  const IOSBackupDocumentPort();
  static const _channelPort = AndroidBackupDocumentPort();

  @override
  Future<bool> hasDirectory() => _channelPort.hasDirectory();
  @override
  Future<bool> chooseDirectory() => _channelPort.chooseDirectory();
  @override
  Future<Uint8List?> readLive(int memberId, String name) =>
      _channelPort.readLive(memberId, name);
  @override
  Future<void> writeLive(int memberId, String name, Uint8List bytes) =>
      _channelPort.writeLive(memberId, name, bytes);
  @override
  Future<String> prepareShareFile(String name, Uint8List bytes) =>
      _channelPort.prepareShareFile(name, bytes);
  @override
  Future<String> launchShareFile(String token) =>
      _channelPort.launchShareFile(token);
  @override
  Future<void> discardShareFile(String token) =>
      _channelPort.discardShareFile(token);
  @override
  Future<String?> saveFile(String name, Uint8List bytes) =>
      _channelPort.saveFile(name, bytes);
  @override
  Future<void> completeSavedFile(String token) =>
      _channelPort.completeSavedFile(token);
  @override
  Future<void> discardSavedFile(String token) =>
      _channelPort.discardSavedFile(token);
  @override
  Future<Uint8List?> pickImport() => _channelPort.pickImport();
}
