import CoreText
import CryptoKit
import Flutter
import UIKit
import UniformTypeIdentifiers

final class IOSCustomFontBridge {
  private let picker: IOSDocumentPickerCoordinator
  private let queue = DispatchQueue(label: "app.yahagi.custom-fonts", qos: .userInitiated)

  init(picker: IOSDocumentPickerCoordinator) { self.picker = picker }

  private func directory() throws -> URL {
    let root = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let directory = root.appendingPathComponent("custom_fonts", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func fontURL(_ id: String) throws -> URL {
    guard id.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else {
      throw IOSDocumentError.message("Invalid font identifier.")
    }
    return try directory().appendingPathComponent(id + ".otf")
  }

  private func perform(_ result: @escaping FlutterResult, _ operation: @escaping () throws -> Any?)
  {
    queue.async {
      do {
        let value = try operation()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "custom_font_operation_failed", message: error.localizedDescription,
              details: nil))
        }
      }
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "importFont":
      picker.present(UIDocumentPickerViewController(forOpeningContentTypes: [.font], asCopy: true))
      { outcome in
        switch outcome {
        case .success(nil): result(nil)
        case .success(let url?): self.perform(result) { try self.importFont(url) }
        case .failure(let error):
          result(
            FlutterError(
              code: "font_picker_failed", message: error.localizedDescription, details: nil))
        }
      }
    case "resolveFont":
      perform(result) {
        let id = args["id"] as? String ?? ""
        let url = try self.fontURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return ["id": id, "name": args["name"] as? String ?? "Custom font", "path": url.path]
      }
    case "removeFont":
      perform(result) {
        let url = try self.fontURL(args["id"] as? String ?? "")
        if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.removeItem(at: url)
        }
        return nil
      }
    case "pruneFonts":
      perform(result) {
        let ids = Set(args["ids"] as? [String] ?? [])
        for url in try FileManager.default.contentsOfDirectory(
          at: self.directory(), includingPropertiesForKeys: nil)
        {
          if url.pathExtension == "otf"
            && !ids.contains(url.deletingPathExtension().lastPathComponent)
          {
            try FileManager.default.removeItem(at: url)
          }
        }
        return nil
      }
    case "renderPreview":
      perform(result) { FlutterStandardTypedData(bytes: try self.preview(args)) }
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func importFont(_ source: URL) throws -> [String: String] {
    let data = try IOSDocumentIO.read(source, limit: 32 * 1024 * 1024)
    guard data.count >= 12 else { throw IOSDocumentError.message("Font file is truncated.") }
    let signature = data.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    guard [UInt32(0x0001_0000), 0x4f54_544f, 0x7472_7565].contains(signature),
      let descriptors = CTFontManagerCreateFontDescriptorsFromData(data as CFData)
        as? [CTFontDescriptor],
      let descriptor = descriptors.first,
      let provider = CGDataProvider(data: data as CFData), CGFont(provider) != nil
    else {
      throw IOSDocumentError.message(
        "The selected file is not a supported TrueType or OpenType font.")
    }
    let id = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    let url = try fontURL(id)
    try data.write(to: url, options: .atomic)
    let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontDisplayNameAttribute) as? String
    return [
      "id": id, "name": name ?? source.deletingPathExtension().lastPathComponent, "path": url.path,
    ]
  }

  private func preview(_ args: [String: Any]) throws -> Data {
    let data = try IOSDocumentIO.read(fontURL(args["id"] as? String ?? ""), limit: 32 * 1024 * 1024)
    guard let provider = CGDataProvider(data: data as CFData), let graphicsFont = CGFont(provider)
    else {
      throw IOSDocumentError.message("Font preview is unavailable.")
    }
    let width = CGFloat(max(64, min(2048, (args["width"] as? NSNumber)?.doubleValue ?? 640)))
    let size = CGFloat(max(8, min(128, (args["fontSize"] as? NSNumber)?.doubleValue ?? 28)))
    let font = CTFontCreateWithGraphicsFont(graphicsFont, size, nil, nil)
    let argb = UInt32(truncatingIfNeeded: (args["color"] as? NSNumber)?.int64Value ?? 0xff00_0000)
    let color = UIColor(
      red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255,
      blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
    let text = String((args["text"] as? String ?? "").prefix(8192))
    let attributed = NSAttributedString(
      string: text,
      attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        NSAttributedString.Key(kCTLanguageAttributeName as String):
          (args["locale"] as? String ?? "en").replacingOccurrences(of: "_", with: "-"),
      ])
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let measured = CTFramesetterSuggestFrameSizeWithConstraints(
      framesetter, CFRange(), nil, CGSize(width: width, height: 4096), nil)
    let height = max(size * 2, min(4096, ceil(measured.height) + size))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
      .image { renderer in
        let context = renderer.cgContext
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: height), transform: nil)
        CTFrameDraw(CTFramesetterCreateFrame(framesetter, CFRange(), path, nil), context)
      }
    guard let png = image.pngData(), png.count <= 3 * 1024 * 1024 else {
      throw IOSDocumentError.message("Font preview image is too large.")
    }
    return png
  }
}
