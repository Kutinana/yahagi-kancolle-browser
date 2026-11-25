import UIKit

/// One native document picker at a time across fonts and record backups.
final class IOSDocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
  private weak var viewController: UIViewController?
  private var completion: ((Result<URL?, Error>) -> Void)?

  init(viewController: UIViewController) { self.viewController = viewController }

  func present(
    _ picker: UIDocumentPickerViewController, completion: @escaping (Result<URL?, Error>) -> Void
  ) {
    guard self.completion == nil, let host = viewController,
      host.presentedViewController == nil
    else {
      completion(.failure(IOSDocumentError.message("Another document operation is already open.")))
      return
    }
    self.completion = completion
    picker.delegate = self
    picker.allowsMultipleSelection = false
    host.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
  {
    finish(controller, url: urls.first)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(controller, url: nil)
  }

  private func finish(_ picker: UIDocumentPickerViewController, url: URL?) {
    let reply = completion
    completion = nil
    picker.dismiss(animated: true) { reply?(.success(url)) }
  }
}

enum IOSDocumentError: LocalizedError {
  case message(String)
  var errorDescription: String? {
    switch self {
    case .message(let message): return message
    }
  }
}

enum IOSDocumentIO {
  static func withAccess<T>(_ url: URL, _ operation: () throws -> T) rethrows -> T {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    return try operation()
  }

  static func read(_ url: URL, limit: Int) throws -> Data {
    try withAccess(url) {
      var error: NSError?
      var outcome: Result<Data, Error>?
      NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) {
        coordinated in
        outcome = Result {
          let size = try coordinated.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
          guard size > 0, size <= limit else {
            throw IOSDocumentError.message("File size is invalid.")
          }
          let data = try Data(contentsOf: coordinated)
          guard data.count <= limit else { throw IOSDocumentError.message("File is too large.") }
          return data
        }
      }
      if let error = error { throw error }
      guard let outcome = outcome else { throw IOSDocumentError.message("File could not be read.") }
      return try outcome.get()
    }
  }

  static func fileName(_ name: String) throws -> String {
    guard !name.isEmpty, name.utf8.count <= 180, name != ".", name != "..",
      !name.contains("/"), !name.contains("\\"), !name.contains("\0")
    else { throw IOSDocumentError.message("Invalid file name.") }
    return name
  }

}
