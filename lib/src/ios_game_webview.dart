/// iOS-specific [GameWebView] implementation.
///
/// This is a standalone widget that provides the same functionality as the
/// upstream [GameWebView] but adds iOS-specific enhancements:
/// - AppLifecycleListener for background audio control
/// - WebAudio AudioContext tracking & MediaSession clearing
/// - Generic WebView compatibility port (non-Android)
/// - Early capture preparation on page start
///
/// This file is intentionally independent from `game_webview.dart` to avoid
/// modifying upstream code. It re-uses shared utilities (alignment script,
/// capture script, compatibility, browser port) but owns its own State.
library;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'audio/game_audio_controller.dart';
import 'audio/game_audio_port.dart';
import 'bridge/native_game_capture_script.dart';
import 'browser/game_browser_controller.dart';
import 'browser/game_frame_reload_port.dart';

import 'browser/game_page_alignment_script.dart';
import 'browser/game_toolbar_controller.dart';
import 'browser/game_webview_compatibility.dart';
import 'browser/safe_page_address.dart';
import 'browser/game_launch_config.dart';
import 'capture/capture_mode.dart';
import 'capture/capture_mode_controller.dart';
import 'capture/android_game_capture_port.dart';
import 'capture/game_capture_controller.dart';
import 'capture/game_capture_port.dart';
import 'game_webview.dart' show GameStartupState, WebViewGameBrowserPort;
import 'prototype_status_controller.dart';
import 'settings/network_settings_controller.dart';
import 'settings/network_settings_store.dart';
import 'settings/network_settings_validator.dart';

import 'settings/safety_settings_controller.dart';

class IOSGameWebView extends StatefulWidget {
  const IOSGameWebView({
    super.key,
    required this.networkSettingsController,
    required this.safetySettingsController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameCaptureController,
  });

  final NetworkSettingsController networkSettingsController;
  final SafetySettingsController safetySettingsController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final GameCaptureController gameCaptureController;

  @override
  State<IOSGameWebView> createState() => _IOSGameWebViewState();
}

class _IOSGameWebViewState extends State<IOSGameWebView> {
  late final WebViewController _webViewController;
  late final Future<void> _compatibilityReady;
  late final GameCapturePort _gameCapturePort;

  late CaptureMode _activeCaptureMode;
  static const _scaleChannel = MethodChannel(
    'app.webview/fixed_canvas_scaling',
  );
  static const _audioChannel = MethodChannel(
    'app.yahagi.kancollebrowser/game_audio',
  );

  bool _audioPortAttached = false;
  bool _capturePortAttached = false;
  bool? _lastNativeBackgroundPlaybackEnabled;

  GameStartupState _startupState = GameStartupState.loadingSettings;
  String _startupErrorMessage = '';

  void _onNetworkSettingsChanged() {
    if (!mounted) return;
    if (_startupState == GameStartupState.error) {
      _executeStartupSequence();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.networkSettingsController.addListener(_onNetworkSettingsChanged);
    _activeCaptureMode = widget.captureModeController.mode;
    _gameCapturePort = MethodChannelGameCapturePort();
    widget.captureModeController.addListener(_onCaptureModeChanged);
    widget.audioController.addListener(_onAudioControllerChanged);

    _webViewController = WebViewController();
    _compatibilityReady = _configureCompatibility();
    widget.browserController.attachPort(
      WebViewGameBrowserPort(
        _webViewController,
        _prototypePage,
        gameFrameReloadPort: const _UnsupportedIOSGameFrameReloadPort(),
        compatibilityReady: _compatibilityReady,
        prepareForRealNavigation: _prepareCapture,
        synchronizeGamePresentation: _synchronizeGamePresentation,
      ),
    );

    _webViewController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xff000000))
      ..addJavaScriptChannel(
        'YahagiBridge',
        onMessageReceived: (message) {
          if (widget.browserController.mode == GameBrowserMode.localPrototype) {
            widget.controller.onJavaScriptMessage(message.message);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: (url) async {
            await _prepareCapture();
            await _injectAudioContextTracker();
            widget.controller.onPageStarted(url);
            widget.browserController.onPageStarted(url);
            widget.toolbarController.onStageChanged(
              widget.browserController.mode == GameBrowserMode.localPrototype
                  ? GameSurfaceStage.localPrototype
                  : GameSurfaceStage.login,
            );
            if (_startupState == GameStartupState.networkReady) {
              setState(() => _startupState = GameStartupState.loadingGame);
            }
          },
          onPageFinished: (url) async {
            widget.controller.onPageFinished(url);
            widget.browserController.onPageFinished(url);

            if (_webViewController.platform is AndroidWebViewController) {
              await _scaleChannel.invokeMethod<void>(
                'bindFixedCanvas',
                <String, Object>{'contentWidth': 1200, 'contentHeight': 720},
              );
            }

            // iOS-specific: inject AudioContext tracker again on page finish
            await _injectAudioContextTracker();
            await _synchronizeGamePresentation();
            await _prepareCapture();
            await _attachAudioPortOnce();

            if (_startupState == GameStartupState.loadingGame) {
              setState(() => _startupState = GameStartupState.ready);
            }
          },
          onWebResourceError: (error) {
            final isForMainFrame = error.isForMainFrame ?? true;
            if (isForMainFrame) {
              widget.controller.onWebResourceError(error.description);
              if (error.description.toLowerCase().contains('ssl') ||
                  error.description.toLowerCase().contains('cert')) {
                widget.browserController.onWebResourceError(
                  description: '安全证书错误：可能是岛风GO证书未受信任或网络被劫持。',
                  isForMainFrame: isForMainFrame,
                );
                return;
              }
            }
            widget.browserController.onWebResourceError(
              description: error.description,
              isForMainFrame: isForMainFrame,
            );
          },
        ),
      );

    _executeStartupSequence();
  }

  /// iOS-specific: inject WebAudio AudioContext tracking and MediaSession clearing.
  Future<void> _injectAudioContextTracker() async {
    await _webViewController.runJavaScript('''
      (function() {
        if (window.__yahagiAudioTrackerInjected) return;
        window.__yahagiAudioTrackerInjected = true;
        window.__yahagiAudioContexts = window.__yahagiAudioContexts || [];
        var OrigAC = window.AudioContext || window.webkitAudioContext;
        if (OrigAC) {
          var WrappedAC = function(a, b, c) {
            var instance;
            if (arguments.length === 0) {
              instance = new OrigAC();
            } else if (arguments.length === 1) {
              instance = new OrigAC(a);
            } else if (arguments.length === 2) {
              instance = new OrigAC(a, b);
            } else {
              instance = new OrigAC(a, b, c);
            }
            window.__yahagiAudioContexts.push(instance);
            return instance;
          };
          WrappedAC.prototype = OrigAC.prototype;
          if (window.AudioContext) window.AudioContext = WrappedAC;
          if (window.webkitAudioContext) window.webkitAudioContext = WrappedAC;
        }
        try {
          if (navigator.mediaSession) {
            navigator.mediaSession.metadata = null;
            ['play', 'pause', 'stop', 'previoustrack', 'nexttrack', 'seekto', 'seekbackward', 'seekforward'].forEach(function(act) {
              try { navigator.mediaSession.setActionHandler(act, null); } catch(e){}
            });
          }
        } catch(e){}
      })();
    ''');
  }

  Future<void> _synchronizeGamePresentation() async {
    await _webViewController.runJavaScript(gamePageAlignmentScript);
    await _webViewController.runJavaScript(r'''
      (() => {
        const updateScale = () => {
          const width = window.visualViewport?.width ||
            document.documentElement.clientWidth;
          const height = window.visualViewport?.height ||
            document.documentElement.clientHeight;
          if (!width || !height) return;
          const scale = Math.min(width / 1200, height / 720);
          const left = Math.max(0, (width - 1200 * scale) / 2);
          const top = Math.max(0, (height - 720 * scale) / 2);
          const target = document.querySelector('#game_frame, #game-container');
          let style = document.getElementById('__yahagi_ios_scale__');
          if (!style) {
            style = document.createElement('style');
            style.id = '__yahagi_ios_scale__';
            document.head.appendChild(style);
          }
          style.textContent = `
            html body #game_frame, html body #game-container {
              transform: scale(${scale}) !important;
              left: ${left}px !important;
              top: ${top}px !important;
            }
          `;
          if (target) {
            target.style.setProperty('transform', `scale(${scale})`, 'important');
            target.style.setProperty('transform-origin', '0 0', 'important');
            target.style.setProperty('left', `${left}px`, 'important');
            target.style.setProperty('top', `${top}px`, 'important');
          }
        };
        if (window.__yahagiIOSResizeHandler) {
          window.removeEventListener('resize', window.__yahagiIOSResizeHandler);
        }
        window.__yahagiIOSResizeHandler = updateScale;
        window.addEventListener('resize', updateScale, { passive: true });
        window.__yahagiIOSTargetObserver?.disconnect();
        if (!document.querySelector('#game_frame, #game-container')) {
          window.__yahagiIOSTargetObserver = new MutationObserver(() => {
            if (!document.querySelector('#game_frame, #game-container')) return;
            updateScale();
            window.__yahagiIOSTargetObserver?.disconnect();
          });
          window.__yahagiIOSTargetObserver.observe(document.body, {
            childList: true,
            subtree: true,
          });
        }
        updateScale();
      })();
    ''');
  }

  Future<void> _executeStartupSequence() async {
    setState(() => _startupState = GameStartupState.applyingNetwork);

    await _compatibilityReady;

    final netSettings = widget.networkSettingsController.settings;
    final formattedHost = NetworkSettingsValidator.formatProxyHost(
      netSettings.host,
    );
    final result = await widget.networkSettingsController.applySettings(
      netSettings.mode,
      formattedHost,
      netSettings.port,
    );

    if (!mounted) return;

    if (!result.success && netSettings.mode != NetworkMode.system) {
      setState(() {
        _startupState = GameStartupState.error;
        _startupErrorMessage = '网络设置应用失败 [${result.code}]: ${result.message}';
      });
      return;
    }

    setState(() => _startupState = GameStartupState.networkReady);

    // iOS-specific: prepare capture before initial navigation
    await _prepareCapture();

    final displayAddress = widget.browserController.displayAddress;
    final address = Uri.tryParse(displayAddress);
    if (address != null &&
        SafePageAddress.canNavigate(address) &&
        widget.browserController.mode != GameBrowserMode.localPrototype) {
      _webViewController.loadRequest(address);
    } else {
      _webViewController.loadRequest(GameLaunchConfig.dmmGameEntry);
    }
  }

  Future<void> _attachAudioPortOnce() async {
    if (_audioPortAttached) {
      return;
    }
    _audioPortAttached = true;
    await widget.audioController.attachPort(MethodChannelGameAudioPort());
    await _syncNativeBackgroundPlaybackSetting();
  }

  void _onAudioControllerChanged() {
    _syncNativeBackgroundPlaybackSetting();
  }

  Future<void> _syncNativeBackgroundPlaybackSetting() async {
    if (!_audioPortAttached) return;
    final enabled = widget.audioController.backgroundPlaybackEnabled;
    if (_lastNativeBackgroundPlaybackEnabled == enabled) return;
    try {
      await _audioChannel.invokeMethod<void>(
        'setBackgroundPlaybackEnabled',
        <String, Object>{'enabled': enabled},
      );
      _lastNativeBackgroundPlaybackEnabled = enabled;
    } on PlatformException catch (error) {
      debugPrint('同步 iOS 后台声音设置失败：$error');
    }
  }

  Future<void> _onCaptureModeChanged() async {
    final nextMode = widget.captureModeController.mode;
    if (nextMode == _activeCaptureMode) {
      return;
    }
    _activeCaptureMode = nextMode;
    await _prepareCapture();
    await _webViewController.reload();
  }

  /// iOS-enhanced: wrap capture preparation in try-catch for resilience.
  Future<void> _prepareCapture() async {
    try {
      if (!_capturePortAttached) {
        await widget.gameCaptureController.attach(
          _gameCapturePort,
          enabled: widget.captureModeController.mode.installsGameBridge,
          script: nativeGameCaptureScript,
        );
        _capturePortAttached = true;
        return;
      }
      await widget.gameCaptureController.configure(
        enabled: widget.captureModeController.mode.installsGameBridge,
        script: nativeGameCaptureScript,
      );
    } catch (_) {
      // Ignore capture preparation errors on iOS.
    }
  }

  /// iOS-enhanced: supports both Android and generic (WKWebView) compatibility.
  Future<void> _configureCompatibility() async {
    final platformController = _webViewController.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setUseWideViewPort(false);

      final currentUserAgent = await platformController.getUserAgent();
      if (currentUserAgent != null && currentUserAgent.isNotEmpty) {
        final cookieManager = WebViewCookieManager().platform;
        if (cookieManager is AndroidWebViewCookieManager) {
          await GameWebViewCompatibility.configure(
            _AndroidWebViewCompatibilityPort(
              controller: platformController,
              cookieManager: cookieManager,
            ),
            currentUserAgent: currentUserAgent,
          );
        }
      }
    } else {
      await _webViewController.setUserAgent(_iosDesktopUserAgent);
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    final isLocalDocument =
        widget.browserController.mode == GameBrowserMode.localPrototype &&
        (uri?.scheme == 'about' || uri?.scheme == 'data');
    if (isLocalDocument ||
        (uri != null && SafePageAddress.canNavigateInGameWebView(uri))) {
      return NavigationDecision.navigate;
    }

    widget.browserController.onBlockedNavigation(uri ?? Uri(scheme: 'invalid'));
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(
          key: const Key('game-webview'),
          controller: _webViewController,
        ),
        if (_startupState != GameStartupState.ready)
          Container(
            color: const Color(0xff102431),
            child: Center(child: _buildStartupOverlay()),
          ),
      ],
    );
  }

  Widget _buildStartupOverlay() {
    if (_startupState == GameStartupState.error) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              _startupErrorMessage,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              widget.networkSettingsController
                  .applySettings(NetworkMode.system, '', 8099)
                  .then((_) {
                    _executeStartupSequence();
                  });
            },
            icon: const Icon(Icons.public),
            label: Text(
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('zh')))
                  .retryWithSystemNetwork,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff183631),
              foregroundColor: const Color(0xff80c8bd),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Color(0xffd4a85f)),
        const SizedBox(height: 24),
        Text(
          _getStartupStatusText(),
          style: const TextStyle(color: Color(0xff8197a5), fontSize: 14),
        ),
      ],
    );
  }

  String _getStartupStatusText() {
    switch (_startupState) {
      case GameStartupState.loadingSettings:
        return '正在读取配置...';
      case GameStartupState.applyingNetwork:
        return '正在应用网络设置...';
      case GameStartupState.networkReady:
        return '网络配置完毕，准备加载游戏...';
      case GameStartupState.loadingGame:
        return '正在加载游戏页面...';
      default:
        return '准备就绪...';
    }
  }

  @override
  void dispose() {
    widget.audioController.removeListener(_onAudioControllerChanged);
    widget.captureModeController.removeListener(_onCaptureModeChanged);
    widget.networkSettingsController.removeListener(_onNetworkSettingsChanged);
    _webViewController.setJavaScriptMode(JavaScriptMode.disabled);
    _webViewController.loadHtmlString(
      '<!DOCTYPE html><html><body></body></html>',
    );
    _gameCapturePort.dispose();
    super.dispose();
  }
}

/// Compatibility port for non-Android WebViews (iOS WKWebView, macOS).
///
/// Third-party cookies are managed at the OS level on iOS/macOS,
/// so [allowThirdPartyCookies] is a no-op.
/// Android-specific compatibility port (same as upstream).
final class _AndroidWebViewCompatibilityPort
    implements GameWebViewCompatibilityPort {
  const _AndroidWebViewCompatibilityPort({
    required this.controller,
    required this.cookieManager,
  });

  final AndroidWebViewController controller;
  final AndroidWebViewCookieManager cookieManager;

  @override
  Future<void> allowThirdPartyCookies() {
    return cookieManager.setAcceptThirdPartyCookies(controller, true);
  }

  @override
  Future<void> setUserAgent(String userAgent) {
    return controller.setUserAgent(userAgent);
  }
}

const String _prototypePage = '''
<!doctype html>
<html lang="zh-CN">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{height:100%;margin:0;background:#102431;color:#c7d5dc;font-family:sans-serif}
body{display:flex;align-items:center;justify-content:center}
main{text-align:center;padding:28px}h2{color:#d4a85f}p{color:#8299a5;line-height:1.6}
button{border:1px solid #5d786f;border-radius:8px;background:#183631;color:#80c8bd;padding:10px 14px}
</style>
<main>
  <h2>游戏 WebView 测试首页</h2>
  <p>这里不会连接真实账号，<br>使用上方"DMM 登录测试"主动进入真实网页。</p>
  <button onclick="YahagiBridge.postMessage(JSON.stringify({
    kind:'kcsapi-response',
    path:'/kcsapi/api_port/port',
    body:'svdata={&quot;api_result&quot;:1}',
    source:'manual',
    capturedAt:new Date().toISOString()
  }))">发送模拟舰队数据</button>
</main>
</html>
''';

const String _iosDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'Chrome/128.0.0.0 Safari/605.1.15';

final class _UnsupportedIOSGameFrameReloadPort implements GameFrameReloadPort {
  const _UnsupportedIOSGameFrameReloadPort();

  @override
  Future<void> configure() async {}

  @override
  Future<GameFrameReloadResult> reload() async =>
      GameFrameReloadResult.unsupported;
}
