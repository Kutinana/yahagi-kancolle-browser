import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class RawDataServerController extends ChangeNotifier {
  RawDataServerController() {
    _initStorage();
  }

  static const String _developerModeKey = 'yahagi_developer_mode';

  bool _developerMode = false;
  bool _isRunning = false;
  HttpServer? _server;
  int _port = 8080;
  String? _localIp;
  DateTime? _lastCapturedAt;
  int _fileSizeBytes = 0;
  String? _statusMessage;
  String? _documentsDirPath;

  bool get developerMode => _developerMode;
  bool get isRunning => _isRunning;
  int get port => _port;
  String? get localIp => _localIp;
  DateTime? get lastCapturedAt => _lastCapturedAt;
  int get fileSizeBytes => _fileSizeBytes;
  String? get statusMessage => _statusMessage;

  String? get serverUrl =>
      _isRunning && _localIp != null ? 'http://$_localIp:$_port' : null;

  String get fileSizeFormatted {
    if (_fileSizeBytes <= 0) return '0 B';
    if (_fileSizeBytes < 1024) return '$_fileSizeBytes B';
    if (_fileSizeBytes < 1024 * 1024) {
      return '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _initStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _developerMode = prefs.getBool(_developerModeKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('读取开发者模式配置失败: $e');
    }
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _documentsDirPath = docDir.path;
      await checkExistingFile();
    } catch (e) {
      debugPrint('初始化原始数据存储路径失败: $e');
    }
  }

  Future<void> setDeveloperMode(bool enabled) async {
    if (_developerMode == enabled) return;
    _developerMode = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_developerModeKey, enabled);
    } catch (e) {
      debugPrint('保存开发者模式配置失败: $e');
    }
  }

  Future<File?> get _targetFile async {
    final baseDirPath =
        _documentsDirPath ?? (await getApplicationDocumentsDirectory()).path;
    final dir = Directory(p.join(baseDirPath, 'raw_data'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'api_start2_raw.json'));
  }

  Future<void> checkExistingFile() async {
    try {
      final file = await _targetFile;
      if (file != null && await file.exists()) {
        final stat = await file.stat();
        _fileSizeBytes = stat.size;
        _lastCapturedAt = stat.modified;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('检查原始数据文件状态失败: $e');
    }
  }

  Future<void> saveRawMasterData(String jsonBody) async {
    if (!_developerMode) return;
    try {
      final file = await _targetFile;
      if (file == null) return;
      await file.writeAsString(jsonBody);
      final stat = await file.stat();
      _fileSizeBytes = stat.size;
      _lastCapturedAt = DateTime.now().toUtc();
      notifyListeners();
    } catch (e) {
      debugPrint('保存 api_start2 原始数据失败: $e');
    }
  }

  Future<String?> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
            return address.address;
          }
        }
      }
    } catch (e) {
      debugPrint('获取局域网 IP 失败: $e');
    }
    return null;
  }

  Future<bool> startServer({int port = 8080}) async {
    if (_isRunning) return true;

    try {
      _localIp = await _findLocalIp() ?? '127.0.0.1';
      _port = port;

      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;
      _statusMessage = null;

      _server!.listen(
        _handleRequest,
        onError: (error) {
          _statusMessage = '服务运行错误: $error';
          _isRunning = false;
          notifyListeners();
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      _isRunning = false;
      _statusMessage = '无法启动下载服务器 (端口 $_port 可能已被占用): $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;

    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _isRunning = false;
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> toggleServer() async {
    if (_isRunning) {
      await stopServer();
    } else {
      await startServer();
    }
  }

  void _handleRequest(HttpRequest request) async {
    final response = request.response;
    final path = request.uri.path;

    try {
      if (path == '/' || path == '/index.html') {
        _sendHtmlDashboard(response);
      } else if (path == '/download/api_start2' ||
          path == '/api_start2_raw.json') {
        await _sendFileDownload(response);
      } else {
        response.statusCode = HttpStatus.notFound;
        response.headers.contentType = ContentType.html;
        response.write('<h1>404 Not Found</h1>');
        await response.close();
      }
    } catch (e) {
      debugPrint('处理 HTTP 请求异常: $e');
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {}
    }
  }

  void _sendHtmlDashboard(HttpResponse response) {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.html;

    final hasFile = _fileSizeBytes > 0;
    final lastTimeStr = _lastCapturedAt == null
        ? '暂未捕获'
        : _lastCapturedAt!.toLocal().toString().split('.')[0];

    final html =
        '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>矢矧 - 全量原始图鉴下载服务</title>
  <style>
    :root {
      --bg-color: #0d1a26;
      --card-bg: #142735;
      --border-color: #294052;
      --accent-color: #d4a85f;
      --text-main: #e6eff5;
      --text-sub: #8197a5;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background-color: var(--bg-color);
      color: var(--text-main);
      margin: 0;
      padding: 24px;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      box-sizing: border-box;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 32px;
      max-width: 480px;
      width: 100%;
      box-shadow: 0 8px 24px rgba(0,0,0,0.4);
    }
    h1 {
      font-size: 20px;
      margin-top: 0;
      margin-bottom: 8px;
      color: var(--accent-color);
    }
    p.subtitle {
      color: var(--text-sub);
      font-size: 14px;
      margin-bottom: 24px;
      line-height: 1.5;
    }
    .info-box {
      background: #09121a;
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 16px;
      margin-bottom: 24px;
    }
    .info-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 10px;
      font-size: 14px;
    }
    .info-row:last-child {
      margin-bottom: 0;
    }
    .label { color: var(--text-sub); }
    .value { font-weight: 600; }
    .btn {
      display: block;
      width: 100%;
      text-align: center;
      background-color: var(--accent-color);
      color: #0d1a26;
      font-weight: 700;
      padding: 14px 0;
      border-radius: 10px;
      text-decoration: none;
      font-size: 16px;
      transition: opacity 0.2s;
      box-sizing: border-box;
    }
    .btn.disabled {
      background-color: var(--border-color);
      color: var(--text-sub);
      pointer-events: none;
    }
    .btn:hover {
      opacity: 0.9;
    }
    .footer {
      margin-top: 24px;
      font-size: 12px;
      color: var(--text-sub);
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>矢矧 · 原始全量图鉴数据服务</h1>
    <p class="subtitle">舰娘服务器全量 Master 数据库原始 JSON (api_start2/getData)</p>

    <div class="info-box">
      <div class="info-row">
        <span class="label">文件名称</span>
        <span class="value">api_start2_raw.json</span>
      </div>
      <div class="info-row">
        <span class="label">文件大小</span>
        <span class="value">$fileSizeFormatted</span>
      </div>
      <div class="info-row">
        <span class="label">最近捕获时间</span>
        <span class="value">$lastTimeStr</span>
      </div>
    </div>

    ${hasFile ? '<a class="btn" href="/download/api_start2">直接下载 JSON 文件</a>' : '<a class="btn disabled" href="#">暂未捕获数据 (请先在手机打开游戏登录)</a>'}

    <div class="footer">
      Powered by Yahagi KanColle Browser
    </div>
  </div>
</body>
</html>
''';

    response.write(html);
    response.close();
  }

  Future<void> _sendFileDownload(HttpResponse response) async {
    final file = await _targetFile;
    if (file == null || !await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      response.headers.contentType = ContentType.html;
      response.write('<h1>404 File Not Found</h1><p>暂未捕获到 api_start2 原始数据</p>');
      await response.close();
      return;
    }

    final length = await file.length();
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType(
      'application',
      'json',
      charset: 'utf-8',
    );
    response.headers.set('Content-Length', length.toString());
    response.headers.set(
      'Content-Disposition',
      'attachment; filename="api_start2_raw.json"',
    );

    await file.openRead().pipe(response);
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
