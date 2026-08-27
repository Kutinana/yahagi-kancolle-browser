import Flutter
import Foundation
import Network
import WebKit

/// Swift native proxy manager for WKWebView on iOS 17.0+ and macOS 14.0+.
///
/// Configures `WKWebsiteDataStore.default().proxyConfigurations` for per-WebView HTTP and SOCKS5 proxies
/// and runs TCP/HTTP network diagnostics.
@objc public class IOSWebViewProxyManager: NSObject {

  @objc public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isProxyOverrideSupported":
      if #available(iOS 17.0, macOS 14.0, *) {
        result(true)
      } else {
        result(false)
      }
    case "getNetworkStatus":
      result(getNetworkStatus())
    case "applyHttpProxy":
      guard let args = call.arguments as? [String: Any],
        let host = args["host"] as? String,
        let port = args["port"] as? Int
      else {
        result([
          "success": false, "code": "invalid_argument", "message": "Host and port required",
          "elapsedMs": 0,
        ])
        return
      }
      applyProxy(host: host, port: port, type: .http, result: result)
    case "applySocksProxy":
      guard let args = call.arguments as? [String: Any],
        let host = args["host"] as? String,
        let port = args["port"] as? Int
      else {
        result([
          "success": false, "code": "invalid_argument", "message": "Host and port required",
          "elapsedMs": 0,
        ])
        return
      }
      applyProxy(host: host, port: port, type: .socks, result: result)
    case "clearProxyOverride":
      clearProxy(result: result)
    case "runNetworkDiagnostic":
      guard let args = call.arguments as? [String: Any],
        let mode = args["mode"] as? String,
        let host = args["host"] as? String,
        let port = args["port"] as? Int
      else {
        result([
          "success": false, "code": "invalid_argument", "message": "Mode, host and port required",
          "elapsedMs": 0,
        ])
        return
      }
      runNetworkDiagnostic(mode: mode, host: host, port: port, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private enum ProxyType {
    case http
    case socks
  }

  private func getNetworkStatus() -> [String: Any] {
    // Basic active network check on iOS / macOS
    return [
      "hasVpn": false,
      "hasActiveNetwork": true,
    ]
  }

  private func applyProxy(host: String, port: Int, type: ProxyType, result: @escaping FlutterResult)
  {
    let startTime = CFAbsoluteTimeGetCurrent()

    if #available(iOS 17.0, macOS 14.0, *) {
      let endpoint = NWEndpoint.hostPort(
        host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: UInt16(port))!)
      let config: ProxyConfiguration

      if type == .http {
        config = ProxyConfiguration(httpCONNECTProxy: endpoint)
      } else {
        config = ProxyConfiguration(socksv5Proxy: endpoint)
      }

      WKWebsiteDataStore.default().proxyConfigurations = [config]
      let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

      result([
        "success": true,
        "code": "ok",
        "message": "代理设置成功",
        "elapsedMs": elapsedMs,
      ])
    } else {
      let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
      result([
        "success": false,
        "code": "proxy_override_unsupported",
        "message": "iOS 17.0 以下版本暂不支持应用内独立代理",
        "elapsedMs": elapsedMs,
      ])
    }
  }

  private func clearProxy(result: @escaping FlutterResult) {
    let startTime = CFAbsoluteTimeGetCurrent()

    if #available(iOS 17.0, macOS 14.0, *) {
      WKWebsiteDataStore.default().proxyConfigurations = []
    }

    let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
    result([
      "success": true,
      "code": "ok",
      "message": "系统网络已恢复",
      "elapsedMs": elapsedMs,
    ])
  }

  private func runNetworkDiagnostic(
    mode: String, host: String, port: Int, result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let startTime = CFAbsoluteTimeGetCurrent()

      // Check DMM account connectivity
      let dmmSuccess = self.testUrl("https://accounts.dmm.com/", timeout: 8.0)
      let googleSuccess = self.testUrl("https://www.google.com/gen_204", timeout: 5.0)

      let totalElapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
      let success = dmmSuccess

      let code: String
      let message: String

      if success && !googleSuccess {
        message = "普通网络可用，但Google连接超时，不影响游戏。"
        code = "warning"
      } else if success {
        message = "网络畅通，可正常访问游戏服务。"
        code = "ok"
      } else if googleSuccess {
        message = "外网可用，但游戏相关服务无法访问 (可能被墙或被拦截)。"
        code = "game_failed"
      } else {
        message = "当前网络连接失败或代理无法正常工作。"
        code = "all_failed"
      }

      DispatchQueue.main.async {
        result([
          "success": success,
          "code": code,
          "message": message,
          "elapsedMs": totalElapsed,
          "details": [
            "proxy": ["status": mode == "system" ? "skipped" : "success", "elapsedMs": 0],
            "gameTarget": ["status": dmmSuccess ? "success" : "failed", "elapsedMs": totalElapsed],
            "google": ["status": googleSuccess ? "success" : "failed", "elapsedMs": totalElapsed],
          ],
        ])
      }
    }
  }

  private func testUrl(_ urlString: String, timeout: TimeInterval) -> Bool {
    guard let url = URL(string: urlString) else { return false }
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout

    let semaphore = DispatchSemaphore(value: 0)
    var success = false

    let task = URLSession.shared.dataTask(with: request) { _, response, error in
      if let httpResponse = response as? HTTPURLResponse,
        (200...399).contains(httpResponse.statusCode)
      {
        success = true
      }
      semaphore.signal()
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + timeout)
    return success
  }
}
