import Flutter
import UIKit
import Darwin

/// Bridge for system diagnostics, device snapshots, memory statistics, and report sharing on iOS.
final class IOSDiagnosticsBridge: NSObject {
  private weak var viewController: UIViewController?

  init(viewController: UIViewController?) {
    self.viewController = viewController
    super.init()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "deviceSnapshot":
      let bounds = UIScreen.main.bounds
      let scale = UIScreen.main.scale
      let physicalMemMb = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
      let snapshot: [String: Any] = [
        "manufacturer": "Apple",
        "model": UIDevice.current.model,
        "androidSdk": 0,
        "androidRelease": UIDevice.current.systemVersion,
        "supportedAbi": "arm64",
        "memoryClassMb": physicalMemMb,
        "screenWidthPx": Int(bounds.width * scale),
        "screenHeightPx": Int(bounds.height * scale),
        "webViewVersion": "WebKit (iOS \(UIDevice.current.systemVersion))",
        "previousExitReason": 0,
        "previousExitStatus": 0,
        "previousExitImportance": 0,
        "previousExitPssKb": 0,
        "previousExitRssKb": 0,
        "previousExitTimestampMs": 0
      ]
      result(snapshot)

    case "runtimeSnapshot":
      var info = mach_task_basic_info()
      var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
      let kerr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
          task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
      }
      let residentKb = (kerr == KERN_SUCCESS) ? Int(info.resident_size / 1024) : 0
      let snapshot: [String: Any] = [
        "pssKb": residentKb,
        "javaHeapKb": 0,
        "nativeHeapKb": residentKb,
        "graphicsKb": 0,
        "privateOtherKb": 0,
        "systemAvailableKb": 0,
        "lowMemory": false
      ]
      result(snapshot)

    case "saveJson":
      let pathString: String? = {
        if let args = call.arguments as? [String: Any] {
          return args["path"] as? String
        }
        return call.arguments as? String
      }()

      guard let path = pathString, !path.isEmpty else {
        result(FlutterError(code: "invalid_argument", message: "Path required", details: nil))
        return
      }

      let fileManager = FileManager.default
      let srcURL = URL(fileURLWithPath: path)
      if let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
        let destURL = docsDir.appendingPathComponent(srcURL.lastPathComponent)
        try? fileManager.removeItem(at: destURL)
        do {
          try fileManager.copyItem(at: srcURL, to: destURL)
          result(destURL.path)
        } catch {
          result(path)
        }
      } else {
        result(path)
      }

    case "shareJson":
      let pathString: String? = {
        if let args = call.arguments as? [String: Any] {
          return args["path"] as? String
        }
        return call.arguments as? String
      }()

      guard let path = pathString, !path.isEmpty else {
        result(FlutterError(code: "invalid_argument", message: "Path required", details: nil))
        return
      }

      let fileURL = URL(fileURLWithPath: path)
      DispatchQueue.main.async { [weak self] in
        guard let rootVC = self?.viewController ?? UIApplication.shared.windows.first?.rootViewController else {
          result(FlutterError(code: "no_view_controller", message: "Root view controller not found", details: nil))
          return
        }

        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
          popover.sourceView = rootVC.view
          popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
          popover.permittedArrowDirections = []
        }
        rootVC.present(activityVC, animated: true) {
          result(nil)
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
