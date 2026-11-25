import CryptoKit
import Flutter
import UIKit
import UniformTypeIdentifiers

/// File-provider access only. Archive and account validation remain in Dart.
final class IOSRecordBackupBridge {
  private let picker: IOSDocumentPickerCoordinator
  private weak var viewController: UIViewController?
  private let queue = DispatchQueue(label: "app.yahagi.record-backup", qos: .utility)
  private let bookmarkKey = "record_backup.directory.ios.v1"
  private let limit = 100 * 1024 * 1024
  private var exports: [String: URL] = [:]
  private var saved: [String: (URL, Data)] = [:]

  init(viewController: UIViewController, picker: IOSDocumentPickerCoordinator) {
    self.viewController = viewController
    self.picker = picker
  }

  private func perform(
    _ result: @escaping FlutterResult, _ operation: @escaping () throws -> Any?
  ) {
    DispatchQueue.main.async {
      // Give an in-flight sync time to reach its verified checkpoint when the
      // app backgrounds. Atomic pending/main copies cover task expiration.
      var task = UIBackgroundTaskIdentifier.invalid
      task = UIApplication.shared.beginBackgroundTask(withName: "Yahagi record backup") {
        if task != .invalid {
          UIApplication.shared.endBackgroundTask(task)
          task = .invalid
        }
      }
      self.queue.async {
        let outcome = Result { try operation() }
        DispatchQueue.main.async {
          defer { if task != .invalid { UIApplication.shared.endBackgroundTask(task) } }
          switch outcome {
          case .success(let value): result(value)
          case .failure(let error):
            result(
              FlutterError(
                code: "record_backup_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  private func folder() throws -> URL? {
    guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
    var stale = false
    let url = try URL(
      resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil,
      bookmarkDataIsStale: &stale)
    if stale {
      try IOSDocumentIO.withAccess(url) {
        UserDefaults.standard.set(
          try url.bookmarkData(
            options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil),
          forKey: bookmarkKey)
      }
    }
    return url
  }

  private func inFolder(_ write: Bool, operation: @escaping (URL) throws -> Any?) throws -> Any? {
    guard let root = try folder() else {
      throw IOSDocumentError.message("Choose a backup folder first.")
    }
    return try IOSDocumentIO.withAccess(root) {
      var error: NSError?
      var outcome: Result<Any?, Error>?
      let accessor: (URL) -> Void = { coordinated in outcome = Result { try operation(coordinated) }
      }
      let coordinator = NSFileCoordinator()
      if write {
        coordinator.coordinate(
          writingItemAt: root, options: .forMerging, error: &error, byAccessor: accessor)
      } else {
        coordinator.coordinate(
          readingItemAt: root, options: [], error: &error, byAccessor: accessor)
      }
      if let error = error { throw error }
      guard let outcome = outcome else {
        throw IOSDocumentError.message("Backup folder is unavailable.")
      }
      return try outcome.get()
    }
  }

  private func bytes(_ args: [String: Any]) throws -> Data {
    guard let typed = args["bytes"] as? FlutterStandardTypedData, !typed.data.isEmpty,
      typed.data.count <= limit
    else {
      throw IOSDocumentError.message("Backup size is invalid.")
    }
    return typed.data
  }

  private func name(_ args: [String: Any]) throws -> String {
    let memberId = (args["memberId"] as? NSNumber)?.intValue ?? 0
    guard memberId > 0 else { throw IOSDocumentError.message("Invalid backup account.") }
    // A stable account key survives admiral/server renames and avoids collisions.
    return "yahagi-member-\(memberId).yhb"
  }

  private func candidate(_ root: URL, name: String, slot: String) throws -> URL {
    guard ["main", "pending", "previous"].contains(slot) else {
      throw IOSDocumentError.message("Invalid backup slot.")
    }
    return root.appendingPathComponent(name + (slot == "main" ? "" : "." + slot))
  }

  private func read(_ url: URL) throws -> Data {
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size >= 0, size <= limit else {
      throw IOSDocumentError.message("Backup size is invalid.")
    }
    let data = try Data(contentsOf: url)
    guard data.count <= limit else { throw IOSDocumentError.message("Backup is too large.") }
    return data
  }

  private func install(_ data: Data, root: URL, name: String) throws {
    let pending = try candidate(root, name: name, slot: "pending")
    let main = try candidate(root, name: name, slot: "main")
    let previous = try candidate(root, name: name, slot: "previous")
    try data.write(to: pending, options: .atomic)
    guard try read(pending) == data else {
      throw IOSDocumentError.message("Pending backup verification failed.")
    }
    if FileManager.default.fileExists(atPath: main.path) {
      // Preserve the old main even when it is corrupt. A valid pending copy
      // must remain available until the replacement has passed readback.
      let old = try read(main)
      try old.write(to: previous, options: .atomic)
      guard try read(previous) == old else {
        throw IOSDocumentError.message("Previous backup verification failed.")
      }
    }
    try data.write(to: main, options: .atomic)
    guard try read(main) == data else {
      throw IOSDocumentError.message("Backup verification failed.")
    }
    try FileManager.default.removeItem(at: pending)
  }

  private func selectFolder(_ destination: URL) throws {
    try IOSDocumentIO.withAccess(destination) {
      let bookmark = try destination.bookmarkData(
        options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
      if let source = try? folder(), source.standardizedFileURL != destination.standardizedFileURL {
        try IOSDocumentIO.withAccess(source) {
          // Revoked or removed folders must not prevent recovery into a new one.
          if (try? source.checkResourceIsReachable()) == true {
            try migrate(from: source, to: destination)
          }
        }
      }
      // Switch only after every account's files have been verified at destination.
      UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    }
  }

  private func migrate(from source: URL, to destination: URL) throws {
    var coordinationError: NSError?
    var migrationError: Error?
    NSFileCoordinator().coordinate(
      readingItemAt: source, options: [], writingItemAt: destination, options: .forMerging,
      error: &coordinationError
    ) { source, destination in
      do {
        let documents = try FileManager.default.contentsOfDirectory(
          at: source, includingPropertiesForKeys: [.isRegularFileKey]
        ).filter {
          $0.lastPathComponent.hasSuffix(".yhb") || $0.lastPathComponent.hasSuffix(".yhb.pending")
            || $0.lastPathComponent.hasSuffix(".yhb.previous")
        }
        // Check conflicts before copying; keep the source directory untouched.
        for document in documents {
          let target = destination.appendingPathComponent(
            try IOSDocumentIO.fileName(document.lastPathComponent))
          let data = try read(document)
          if FileManager.default.fileExists(atPath: target.path), try read(target) != data {
            throw IOSDocumentError.message(
              "The selected folder contains a conflicting backup: \(target.lastPathComponent)")
          }
        }
        for document in documents {
          let target = destination.appendingPathComponent(document.lastPathComponent)
          let data = try read(document)
          if !FileManager.default.fileExists(atPath: target.path) {
            try data.write(to: target, options: .atomic)
          }
          guard try read(target) == data else {
            throw IOSDocumentError.message("Migrated backup verification failed.")
          }
        }
      } catch { migrationError = error }
    }
    if let error = coordinationError { throw error }
    if let error = migrationError { throw error }
  }

  private func stage(_ name: String, bytes: Data) throws -> (String, URL) {
    let token = UUID().uuidString
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "record-backup-exports", isDirectory: true
    ).appendingPathComponent(token, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let url = root.appendingPathComponent(try IOSDocumentIO.fileName(name))
    try bytes.write(to: url, options: .atomic)
    exports[token] = url
    return (token, url)
  }

  private func discard(_ token: String) throws {
    if let url = exports[token],
      FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path)
    {
      try FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
    exports.removeValue(forKey: token)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "hasDirectory":
      perform(result) {
        guard let root = try self.folder() else { return false }
        return IOSDocumentIO.withAccess(root) {
          (try? root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
      }
    case "chooseDirectory":
      picker.present(
        UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
      ) { outcome in
        switch outcome {
        case .success(nil): result(false)
        case .success(let url?):
          self.perform(result) {
            try self.selectFolder(url)
            return true
          }
        case .failure(let error):
          result(
            FlutterError(
              code: "folder_picker_failed", message: error.localizedDescription, details: nil))
        }
      }
    case "readCandidate":
      perform(result) {
        let name = try self.name(args)
        return try self.inFolder(false) { root in
          let url = try self.candidate(root, name: name, slot: args["slot"] as? String ?? "main")
          guard FileManager.default.fileExists(atPath: url.path) else { return nil }
          return FlutterStandardTypedData(bytes: try self.read(url))
        }
      }
    case "writeLive", "promoteCandidate":
      perform(result) {
        let name = try self.name(args)
        let data = try self.bytes(args)
        return try self.inFolder(true) { root in
          if call.method == "promoteCandidate" {
            let slot = args["slot"] as? String ?? ""
            guard slot == "pending" || slot == "previous",
              try self.read(self.candidate(root, name: name, slot: slot)) == data
            else {
              throw IOSDocumentError.message("Backup changed during recovery.")
            }
          }
          try self.install(data, root: root, name: name)
          return nil
        }
      }
    case "prepareShareFile":
      perform(result) { try self.stage(args["name"] as? String ?? "", bytes: self.bytes(args)).0 }
    case "launchShareFile":
      let token = args["token"] as? String ?? ""
      queue.async {
        let url = self.exports[token]
        DispatchQueue.main.async {
          guard let url = url, let host = self.viewController, host.presentedViewController == nil
          else {
            result(
              FlutterError(
                code: "share_unavailable", message: "Share file is unavailable.", details: nil))
            return
          }
          let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
          activity.popoverPresentationController?.sourceView = host.view
          activity.popoverPresentationController?.sourceRect = CGRect(
            x: host.view.bounds.midX, y: host.view.bounds.midY, width: 1, height: 1)
          activity.completionWithItemsHandler = { type, completed, _, error in
            self.perform(result) {
              try self.discard(token)
              if let error = error { throw error }
              return completed ? type?.rawValue ?? "shared" : "cancelled"
            }
          }
          host.present(activity, animated: true)
        }
      }
    case "discardShareFile":
      perform(result) {
        try self.discard(args["token"] as? String ?? "")
        return nil
      }
    case "saveFile":
      perform({ value in
        if let error = value as? FlutterError {
          result(error)
          return
        }
        guard let value = value as? [String: String], let token = value["token"],
          let path = value["path"]
        else {
          result(nil)
          return
        }
        let source = URL(fileURLWithPath: path)
        self.picker.present(UIDocumentPickerViewController(forExporting: [source], asCopy: true)) {
          outcome in
          switch outcome {
          case .success(nil):
            self.perform(result) {
              try self.discard(token)
              return nil
            }
          case .success(let destination?):
            self.perform(result) {
              do {
                let data = try self.read(source)
                guard try IOSDocumentIO.read(destination, limit: self.limit) == data else {
                  throw IOSDocumentError.message("Saved backup verification failed.")
                }
                self.saved[token] = (destination, Data(SHA256.hash(data: data)))
                return token
              } catch {
                try? self.discard(token)
                throw error
              }
            }
          case .failure(let error):
            self.perform(result) {
              try self.discard(token)
              throw error
            }
          }
        }
      }) {
        let (token, url) = try self.stage(args["name"] as? String ?? "", bytes: self.bytes(args))
        return ["token": token, "path": url.path]
      }
    case "completeSavedFile", "discardSavedFile":
      perform(result) {
        let token = args["token"] as? String ?? ""
        if let (url, digest) = self.saved[token],
          call.method == "discardSavedFile"
        {
          try IOSDocumentIO.withAccess(url) {
            var error: NSError?
            var deletionError: Error?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &error)
            { target in
              do {
                guard Data(SHA256.hash(data: try self.read(target))) == digest else {
                  throw IOSDocumentError.message("Export changed before cancellation.")
                }
                try FileManager.default.removeItem(at: target)
              } catch { deletionError = error }
            }
            if let error = error { throw error }
            if let error = deletionError { throw error }
          }
        }
        self.saved.removeValue(forKey: token)
        if call.method == "completeSavedFile" {
          // A cache cleanup failure must not turn a verified export into a
          // failed save and trigger deletion of the user's completed document.
          try? self.discard(token)
        } else {
          try self.discard(token)
        }
        return nil
      }
    case "pickImport":
      picker.present(UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true))
      { outcome in
        switch outcome {
        case .success(nil): result(nil)
        case .success(let url?):
          self.perform(result) {
            FlutterStandardTypedData(bytes: try IOSDocumentIO.read(url, limit: self.limit))
          }
        case .failure(let error):
          result(
            FlutterError(
              code: "import_picker_failed", message: error.localizedDescription, details: nil))
        }
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
}
