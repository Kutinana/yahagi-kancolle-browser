import Flutter
import UIKit
import WebKit

/// Runs the shared player/subtitle script in the game frame's page world.
final class IOSShipSubtitleBridge: NSObject, WKScriptMessageHandler {
  private weak var viewController: UIViewController?
  private weak var webView: WKWebView?
  private let channel: FlutterMethodChannel
  private var script: WKUserScript?
  private var boundsObserver: NSKeyValueObservation?
  private var documents: [String: WKFrameInfo] = [:]
  private var newestDocumentStartedAt = 0.0
  private var newestDocumentId = ""
  private var newestDocumentHost = ""
  private var configuration: [String: Any] = [
    "enabled": false, "locked": true, "fontSize": "medium", "x": 0.5, "y": 0.9,
  ]
  private var catalog: [String: Any] = ["kind": "catalog", "version": "", "quotes": [:]]
  private var ships: [String: Any] = ["kind": "ships", "ships": []]
  private static let objectName = "YahagiShipSubtitles"

  init(viewController: UIViewController, channel: FlutterMethodChannel) {
    self.viewController = viewController
    self.channel = channel
    super.init()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isSupported": result(true)
    case "ensureInstalled":
      ensureInstalled()
      result(nil)
    case "configure":
      for key in ["enabled", "locked", "fontSize", "x", "y"] {
        if let value = args[key] { configuration[key] = value }
      }
      ensureInstalled()
      broadcast(configPayload())
      result(nil)
    case "setCatalog":
      catalog = [
        "kind": "catalog", "version": args["version"] as? String ?? "",
        "quotes": args["quotes"] as? [String: Any] ?? [:],
      ]
      broadcast(catalog)
      result(nil)
    case "setShips":
      ships = ["kind": "ships", "ships": args["ships"] as? [[String: Any]] ?? []]
      broadcast(ships)
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  func ensureInstalled() {
    guard let root = viewController?.view, let target = findWebView(root), target !== webView else {
      return
    }
    if let previous = webView {
      previous.configuration.userContentController.removeScriptMessageHandler(
        forName: Self.objectName)
      if let script = script {
        let controller = previous.configuration.userContentController
        let others = controller.userScripts.filter { $0 !== script }
        controller.removeAllUserScripts()
        others.forEach { controller.addUserScript($0) }
      }
    }
    documents.removeAll()
    newestDocumentStartedAt = 0
    newestDocumentId = ""
    newestDocumentHost = ""
    let key = FlutterDartProject.lookupKey(forAsset: "assets/scripts/ship_subtitles.js")
    guard let url = Bundle.main.url(forResource: key, withExtension: nil),
      let source = try? String(contentsOf: url, encoding: .utf8)
    else { return }
    let adapter = """
      (function () {
      var host = location.hostname.toLowerCase();
      if (location.protocol !== 'https:' || (location.port && location.port !== '443') ||
          !(host === 'ooi.moe' || ['dmm.com', 'dmm.co.jp', 'kancolle-server.com'].some(function (root) {
            return host === root || host.endsWith('.' + root);
          }))) return;
      window.YahagiShipSubtitles = {postMessage: function(payload) {
        window.webkit.messageHandlers.YahagiShipSubtitles.postMessage(payload);
      }};
      """
    let installed = WKUserScript(
      source: adapter + "\n" + source + "\n})();", injectionTime: .atDocumentStart,
      forMainFrameOnly: false)
    let controller = target.configuration.userContentController
    controller.removeScriptMessageHandler(forName: Self.objectName)
    controller.add(self, name: Self.objectName)
    controller.addUserScript(installed)
    webView = target
    script = installed
    boundsObserver = target.observe(\.bounds, options: [.new]) { [weak self] _, _ in
      guard let self = self else { return }
      self.broadcast(self.configPayload())
    }
  }

  private func findWebView(_ view: UIView) -> WKWebView? {
    if let view = view as? WKWebView { return view }
    for child in view.subviews { if let found = findWebView(child) { return found } }
    return nil
  }

  private func configPayload() -> [String: Any] {
    var payload = configuration
    payload["kind"] = "config"
    if let bounds = webView?.bounds, bounds.width > 0, bounds.height > 0 {
      payload["displayScale"] = min(1, min(bounds.width / 1200, bounds.height / 720))
    }
    return payload
  }

  private func send(_ payload: [String: Any], frame: WKFrameInfo) {
    guard let view = webView, JSONSerialization.isValidJSONObject(payload),
      let data = try? JSONSerialization.data(withJSONObject: payload),
      let json = String(data: data, encoding: .utf8)
    else { return }
    view.callAsyncJavaScript(
      "window.YahagiShipSubtitles?.onmessage?.({data: payload});",
      arguments: ["payload": json], in: frame, in: .page, completionHandler: nil)
  }

  private func broadcast(_ payload: [String: Any]) {
    for frame in documents.values { send(payload, frame: frame) }
  }

  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    guard message.webView === webView, message.name == Self.objectName,
      let raw = message.body as? String, raw.utf8.count <= 8192,
      let data = raw.data(using: .utf8),
      let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      let id = payload["documentId"] as? String,
      id.range(of: "^[a-zA-Z0-9-]{8,128}$", options: .regularExpression) != nil
    else { return }
    let origin = message.frameInfo.securityOrigin
    let host = origin.host.lowercased()
    guard origin.protocol == "https", origin.port == 0 || origin.port == 443,
      host == "ooi.moe"
        || ["dmm.com", "dmm.co.jp", "kancolle-server.com"].contains(where: {
          host == $0 || host.hasSuffix("." + $0)
        })
    else { return }
    switch payload["kind"] as? String {
    case "ready":
      guard let rawURL = payload["url"] as? String, let url = URL(string: rawURL),
        url.scheme == "https", url.user == nil, url.password == nil,
        url.port == nil || url.port == 443,
        url.host?.lowercased() == host, url.path == "/kcs2" || url.path.hasPrefix("/kcs2/"),
        let startedAt = (payload["documentStartedAt"] as? NSNumber)?.doubleValue,
        startedAt.isFinite, startedAt > 0, startedAt >= newestDocumentStartedAt,
        startedAt != newestDocumentStartedAt
          || (id == newestDocumentId && host == newestDocumentHost)
      else { return }
      if documents[id] == nil {
        broadcast(["kind": "dispose"])
        documents.removeAll()
        newestDocumentStartedAt = startedAt
        newestDocumentId = id
        newestDocumentHost = host
      }
      documents[id] = message.frameInfo
      send(catalog, frame: message.frameInfo)
      send(ships, frame: message.frameInfo)
      send(configPayload(), frame: message.frameInfo)
    case "gone":
      guard id == newestDocumentId, host == newestDocumentHost else { return }
      documents.removeValue(forKey: id)
    case "position":
      guard id == newestDocumentId, host == newestDocumentHost, documents[id] != nil,
        configuration["enabled"] as? Bool == true,
        configuration["locked"] as? Bool == false,
        let x = (payload["x"] as? NSNumber)?.doubleValue,
        let y = (payload["y"] as? NSNumber)?.doubleValue,
        x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y)
      else { return }
      configuration["x"] = x
      configuration["y"] = y
      channel.invokeMethod("positionChanged", arguments: ["x": x, "y": y])
    default: break
    }
  }
}
