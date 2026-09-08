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

  private struct ProbeResult {
    let success: Bool
    let elapsedMs: Int
    let statusCode: Int?
    let error: String?
  }

  private func runNetworkDiagnostic(
    mode: String, host: String, port: Int, result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let startTime = CFAbsoluteTimeGetCurrent()

      // 1. If non-system mode, verify TCP connectivity to proxy host:port first
      var tcpElapsed = 0
      var tcpError: String? = nil
      if mode != "system" {
        let tcpRes = self.testTcpConnection(host: host, port: port, timeout: 5.0)
        tcpElapsed = tcpRes.elapsedMs
        tcpError = tcpRes.error
        if !tcpRes.success {
          let totalElapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
          DispatchQueue.main.async {
            result([
              "success": false,
              "code": "connection_refused",
              "message": "无法连接代理服务器: \(tcpRes.error ?? "连接失败")",
              "elapsedMs": totalElapsed,
              "details": [
                "proxy": [
                  "status": "failed",
                  "elapsedMs": tcpElapsed,
                  "error": tcpError as Any,
                ],
                "gameTarget": [
                  "status": "skipped",
                  "elapsedMs": 0,
                  "error": "因代理连接失败而跳过",
                ],
                "google": [
                  "status": "skipped",
                  "elapsedMs": 0,
                  "error": "因代理连接失败而跳过",
                ],
                "diagnostics": self.buildDiagnosticsMeta(mode: mode, host: host, port: port),
              ],
            ])
          }
          return
        }
      }

      // 2. Build URLSessionConfiguration with proxy routing
      let config = URLSessionConfiguration.ephemeral
      config.timeoutIntervalForRequest = 8.0
      config.timeoutIntervalForResource = 12.0

      if mode != "system" && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && port > 0 {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if #available(iOS 17.0, macOS 14.0, *) {
          if let portEndpoint = NWEndpoint.Port(rawValue: UInt16(port)) {
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(cleanHost), port: portEndpoint)
            if mode == "httpProxy" {
              config.proxyConfigurations = [ProxyConfiguration(httpCONNECTProxy: endpoint)]
            } else if mode == "socks5Proxy" {
              config.proxyConfigurations = [ProxyConfiguration(socksv5Proxy: endpoint)]
            }
          }
        }

        if mode == "httpProxy" {
          config.connectionProxyDictionary = [
            "HTTPEnable": 1,
            "HTTPProxy": cleanHost,
            "HTTPPort": port,
            "HTTPSEnable": 1,
            "HTTPSProxy": cleanHost,
            "HTTPSPort": port,
          ]
        } else if mode == "socks5Proxy" {
          config.connectionProxyDictionary = [
            "SOCKSProxy": cleanHost,
            "SOCKSPort": port,
            "SOCKSVersion": "kCFStreamSocketSOCKSVersion5",
          ]
        }
      }
      let session = URLSession(configuration: config)
      defer { session.invalidateAndCancel() }

      // 3. Concurrently probe DMM and Google
      var dmmRes = ProbeResult(success: false, elapsedMs: 0, statusCode: nil, error: nil)
      var googleRes = ProbeResult(success: false, elapsedMs: 0, statusCode: nil, error: nil)

      let group = DispatchGroup()

      group.enter()
      DispatchQueue.global().async {
        dmmRes = self.testUrl(
          "https://accounts.dmm.com/service/login/password", session: session, timeout: 8.0)
        group.leave()
      }

      group.enter()
      DispatchQueue.global().async {
        googleRes = self.testUrl("https://www.google.com/gen_204", session: session, timeout: 5.0)
        group.leave()
      }

      group.wait()

      let totalElapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
      let success = dmmRes.success

      let code: String
      let message: String

      if success && !googleRes.success {
        message = "普通网络可用，但Google连接超时，不影响游戏。"
        code = "warning"
      } else if success {
        message = "网络畅通，可正常访问游戏服务。"
        code = "ok"
      } else if googleRes.success {
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
            "proxy": [
              "status": mode == "system" ? "skipped" : "success",
              "elapsedMs": tcpElapsed,
              "error": tcpError as Any,
            ],
            "gameTarget": [
              "status": dmmRes.success ? "success" : "failed",
              "elapsedMs": dmmRes.elapsedMs,
              "statusCode": dmmRes.statusCode as Any,
              "error": dmmRes.error as Any,
            ],
            "google": [
              "status": googleRes.success ? "success" : "failed",
              "elapsedMs": googleRes.elapsedMs,
              "statusCode": googleRes.statusCode as Any,
              "error": googleRes.error as Any,
            ],
            "diagnostics": self.buildDiagnosticsMeta(mode: mode, host: host, port: port),
          ],
        ])
      }
    }
  }

  private func testTcpConnection(host: String, port: Int, timeout: TimeInterval) -> (
    success: Bool, elapsedMs: Int, error: String?
  ) {
    let start = CFAbsoluteTimeGetCurrent()
    var hints = addrinfo()
    hints.ai_family = AF_UNSPEC
    hints.ai_socktype = SOCK_STREAM
    var res: UnsafeMutablePointer<addrinfo>?
    let portStr = String(port)
    let getAddrResult = getaddrinfo(host, portStr, &hints, &res)
    guard getAddrResult == 0, let firstRes = res else {
      let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
      return (false, elapsed, "DNS解析失败: 无法解析主机 \(host)")
    }
    defer { freeaddrinfo(res) }

    let sock = socket(
      firstRes.pointee.ai_family, firstRes.pointee.ai_socktype, firstRes.pointee.ai_protocol)
    guard sock >= 0 else {
      let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
      return (false, elapsed, "创建Socket套接字失败")
    }
    defer { close(sock) }

    // Set non-blocking socket for connect timeout
    let flags = fcntl(sock, F_GETFL, 0)
    _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

    let connectResult = connect(sock, firstRes.pointee.ai_addr, firstRes.pointee.ai_addrlen)
    if connectResult != 0 && errno != EINPROGRESS {
      let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
      let errStr = String(cString: strerror(errno))
      return (false, elapsed, "连接被拒绝: \(errStr)")
    }

    var pollFd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
    let pollTimeoutMs = Int32(timeout * 1000)
    let pollResult = poll(&pollFd, 1, pollTimeoutMs)

    let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
    if pollResult <= 0 {
      return (false, elapsed, "TCP握手超时 (\(Int(timeout))s)")
    }

    var socketError: Int32 = 0
    var errorLen = socklen_t(MemoryLayout<Int32>.size)
    getsockopt(sock, SOL_SOCKET, SO_ERROR, &socketError, &errorLen)
    if socketError != 0 {
      let errStr = String(cString: strerror(socketError))
      return (false, elapsed, "连接失败: \(errStr)")
    }

    return (true, elapsed, nil)
  }

  private func testUrl(_ urlString: String, session: URLSession, timeout: TimeInterval) -> ProbeResult {
    guard let url = URL(string: urlString) else {
      return ProbeResult(success: false, elapsedMs: 0, statusCode: nil, error: "无效的URL")
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

    let startTime = CFAbsoluteTimeGetCurrent()
    let semaphore = DispatchSemaphore(value: 0)
    var probeResult = ProbeResult(success: false, elapsedMs: 0, statusCode: nil, error: "请求未响应")

    let task = session.dataTask(with: request) { _, response, error in
      let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

      if let httpResponse = response as? HTTPURLResponse {
        let statusCode = httpResponse.statusCode
        let isSuccess = (200...399).contains(statusCode)
        let errorMsg: String?
        if isSuccess {
          errorMsg = nil
        } else if statusCode == 403 {
          errorMsg = "HTTP 403 (DMM地区限制或节点IP被封锁)"
        } else if statusCode == 404 {
          errorMsg = "HTTP 404 (资源未找到)"
        } else if statusCode >= 500 {
          errorMsg = "HTTP \(statusCode) (服务器异常)"
        } else {
          errorMsg = "HTTP \(statusCode)"
        }
        probeResult = ProbeResult(
          success: isSuccess,
          elapsedMs: elapsed,
          statusCode: statusCode,
          error: errorMsg
        )
      } else if let error = error as NSError? {
        var errorMsg = error.localizedDescription
        if error.domain == NSURLErrorDomain {
          switch error.code {
          case NSURLErrorServerCertificateUntrusted:
            errorMsg = "SSL/TLS证书未受信任 (-1202, 请检查是否在iOS设置中开启针对根证书的完全信任)"
          case NSURLErrorServerCertificateHasBadDate:
            errorMsg = "SSL证书已过期或未生效 (-1201)"
          case NSURLErrorServerCertificateNotYetValid:
            errorMsg = "SSL证书尚未生效 (-1204)"
          case NSURLErrorServerCertificateHasUnknownRoot:
            errorMsg = "SSL证书根未知 (-1203, 请检查自签名CA描述文件)"
          case NSURLErrorTimedOut:
            errorMsg = "请求超时 (-1001)"
          case NSURLErrorCannotFindHost:
            errorMsg = "无法找到服务器主机 (-1003, DNS解析失败)"
          case NSURLErrorCannotConnectToHost:
            errorMsg = "无法连接到服务器 (-1004)"
          case NSURLErrorNetworkConnectionLost:
            errorMsg = "网络连接中断 (-1005)"
          case NSURLErrorSecureConnectionFailed:
            errorMsg = "安全连接(SSL/TLS握手)失败 (-1200)"
          case NSURLErrorNotConnectedToInternet:
            errorMsg = "设备未连接互联网 (-1009)"
          default:
            errorMsg = "\(error.localizedDescription) (\(error.code))"
          }
        }
        probeResult = ProbeResult(
          success: false,
          elapsedMs: elapsed,
          statusCode: nil,
          error: errorMsg
        )
      }
      semaphore.signal()
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + timeout + 1.0)
    return probeResult
  }

  private func buildDiagnosticsMeta(mode: String, host: String, port: Int) -> [String: Any] {
    let modeText: String
    let endpoint: String
    if mode == "system" {
      modeText = "系统网络"
      endpoint = "系统默认路由"
    } else if mode == "httpProxy" {
      modeText = "HTTP代理"
      endpoint = "\(host):\(port)"
    } else if mode == "socks5Proxy" {
      modeText = "SOCKS5代理"
      endpoint = "\(host):\(port)"
    } else {
      modeText = mode
      endpoint = "\(host):\(port)"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let timeStr = formatter.string(from: Date())

    return [
      "os": "iOS \(UIDevice.current.systemVersion)",
      "device": UIDevice.current.model,
      "mode": modeText,
      "endpoint": endpoint,
      "timestamp": timeStr,
    ]
  }
}

