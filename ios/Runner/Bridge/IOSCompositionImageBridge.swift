import Flutter
import Photos
import UIKit

/// Handles composition image exports and saves them to the iOS Photos library.
final class IOSCompositionImageBridge: NSObject {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "savePng":
      guard let args = call.arguments as? [String: Any],
            let flutterData = args["bytes"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "invalid_argument", message: "PNG bytes required", details: nil))
        return
      }

      let data = flutterData.data
      guard let image = UIImage(data: data) else {
        result(FlutterError(code: "invalid_image", message: "Failed to decode PNG bytes to image", details: nil))
        return
      }

      // Write to a temporary file first
      let tempDir = FileManager.default.temporaryDirectory
      let fileName = "composition_\(Int(Date().timeIntervalSince1970 * 1000)).png"
      let fileURL = tempDir.appendingPathComponent(fileName)
      do {
        try data.write(to: fileURL)
      } catch {
        result(FlutterError(code: "file_write_failed", message: error.localizedDescription, details: nil))
        return
      }

      // Save to photo library
      let performSave = {
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
          DispatchQueue.main.async {
            if success {
              result(fileURL.path)
            } else {
              result(FlutterError(
                code: "composition_save_failed",
                message: error?.localizedDescription ?? "Failed to save composition image to Photos library",
                details: nil
              ))
            }
          }
        }
      }

      if #available(iOS 14.0, *) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
          guard status == .authorized || status == .limited else {
            DispatchQueue.main.async {
              result(FlutterError(
                code: "storage_permission_denied",
                message: "Photo library access permission is required to save composition image",
                details: nil
              ))
            }
            return
          }
          performSave()
        }
      } else {
        PHPhotoLibrary.requestAuthorization { status in
          guard status == .authorized else {
            DispatchQueue.main.async {
              result(FlutterError(
                code: "storage_permission_denied",
                message: "Photo library access permission is required to save composition image",
                details: nil
              ))
            }
            return
          }
          performSave()
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
