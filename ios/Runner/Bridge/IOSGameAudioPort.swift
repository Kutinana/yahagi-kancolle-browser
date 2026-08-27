import AVFoundation
import Flutter
import Foundation
import MediaPlayer
import WebKit

/// Swift native audio controller for WKWebView game audio.
@objc public class IOSGameAudioPort: NSObject {
  private weak var viewController: UIViewController?
  private weak var webView: WKWebView?
  private var isUserMuted: Bool = false
  private var isBackgrounded: Bool = false
  private var isBackgroundPlaybackEnabled: Bool = false

  @objc public init(viewController: UIViewController? = nil, webView: WKWebView? = nil) {
    self.viewController = viewController
    self.webView = webView
    super.init()
    setupNotificationObservers()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func setupNotificationObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func handleAppWillResignActive() {
    applyBackgroundState(true)
  }

  @objc private func handleAppDidEnterBackground() {
    applyBackgroundState(true)
  }

  @objc private func handleAppDidBecomeActive() {
    applyBackgroundState(false)
  }

  @objc public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "setMuted":
      guard let args = call.arguments as? [String: Any],
        let muted = args["muted"] as? Bool
      else {
        result(
          FlutterError(code: "invalid_argument", message: "muted must be a boolean", details: nil))
        return
      }
      self.isUserMuted = muted
      setMuted(muted, result: result)
    case "setBackground":
      guard let args = call.arguments as? [String: Any],
        let background = args["background"] as? Bool
      else {
        result(
          FlutterError(
            code: "invalid_argument", message: "background must be a boolean", details: nil))
        return
      }
      applyBackgroundState(background)
      result(nil)
    case "setBackgroundPlaybackEnabled":
      guard let args = call.arguments as? [String: Any],
        let enabled = args["enabled"] as? Bool
      else {
        result(
          FlutterError(code: "invalid_argument", message: "enabled must be a boolean", details: nil)
        )
        return
      }
      self.isBackgroundPlaybackEnabled = enabled
      if enabled {
        do {
          try AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .default, options: [.mixWithOthers])
          try AVAudioSession.sharedInstance().setActive(true)
        } catch {
          NSLog("[IOSGameAudioPort] Setting playback category failed: \(error)")
        }
      }
      applyBackgroundState(isBackgrounded)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func findWKWebView(in view: UIView) -> WKWebView? {
    if let wkWebView = view as? WKWebView {
      return wkWebView
    }
    for subview in view.subviews {
      if let found = findWKWebView(in: subview) {
        return found
      }
    }
    return nil
  }

  private func findWKWebViewInApp() -> WKWebView? {
    if let target = webView {
      return target
    }
    if let root = viewController?.view, let found = findWKWebView(in: root) {
      self.webView = found
      return found
    }
    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes {
        if let windowScene = scene as? UIWindowScene {
          for window in windowScene.windows {
            if let found = findWKWebView(in: window) {
              self.webView = found
              return found
            }
          }
        }
      }
    }
    for window in UIApplication.shared.windows {
      if let found = findWKWebView(in: window) {
        self.webView = found
        return found
      }
    }
    return nil
  }

  private var isUserScriptInjected = false

  private func ensureUserScriptInjected(targetWebView: WKWebView) {
    guard !isUserScriptInjected else { return }
    isUserScriptInjected = true
    let scriptSource = """
      (function() {
          if (window.__yahagiAudioScriptInjected) return;
          window.__yahagiAudioScriptInjected = true;

          window.__yahagiAudioContexts = window.__yahagiAudioContexts || [];
          var OrigAC = window.AudioContext || window.webkitAudioContext;
          if (OrigAC) {
              var WrappedAC = function(a, b, c) {
                  var instance;
                  if (arguments.length === 0) instance = new OrigAC();
                  else if (arguments.length === 1) instance = new OrigAC(a);
                  else if (arguments.length === 2) instance = new OrigAC(a, b);
                  else instance = new OrigAC(a, b, c);
                  window.__yahagiAudioContexts.push(instance);
                  return instance;
              };
              WrappedAC.prototype = OrigAC.prototype;
              if (window.AudioContext) window.AudioContext = WrappedAC;
              if (window.webkitAudioContext) window.webkitAudioContext = WrappedAC;
          }

          window.__yahagiPausedSoundInstances =
              window.__yahagiPausedSoundInstances || new WeakSet();
          window.__yahagiPausedMediaElements =
              window.__yahagiPausedMediaElements || new WeakSet();

          function setSoundInstancePaused(instance, paused) {
              try {
                  if ('paused' in instance) {
                      instance.paused = paused;
                      return true;
                  }
                  if (typeof instance.setPaused === 'function') {
                      instance.setPaused(paused);
                      return true;
                  }
                  if (paused && typeof instance.pause === 'function') {
                      instance.pause();
                      return true;
                  }
                  if (!paused && typeof instance.resume === 'function') {
                      instance.resume();
                      return true;
                  }
              } catch(e) {}
              return false;
          }

          window.addEventListener('message', function(evt) {
              if (evt.data && evt.data.type === 'YAHAGI_AUDIO_CONTROL') {
                  var isBg = evt.data.isBackground;
                  try {
                      if (window.createjs && window.createjs.Sound) {
                          window.createjs.Sound.muted = isBg;
                          if (typeof window.createjs.Sound.setMuted === 'function') window.createjs.Sound.setMuted(isBg);
                          if (typeof window.createjs.Sound.setVolume === 'function') {
                              if (isBg) {
                                  try { window.createjs.Sound._savedVol = window.createjs.Sound.getVolume ? window.createjs.Sound.getVolume() : 1; } catch(e){}
                                  window.createjs.Sound.setVolume(0);
                              } else {
                                  var vol = window.createjs.Sound._savedVol !== undefined ? window.createjs.Sound._savedVol : 1;
                                  window.createjs.Sound.setVolume(vol);
                              }
                          }
                          if (window.createjs.Sound._instances && Array.isArray(window.createjs.Sound._instances)) {
                              window.createjs.Sound._instances.forEach(function(inst) {
                                  if (inst) {
                                      try { inst.muted = isBg; } catch(e){}
                                      if (isBg) {
                                          if (!inst.paused && setSoundInstancePaused(inst, true)) {
                                              window.__yahagiPausedSoundInstances.add(inst);
                                          }
                                      } else if (window.__yahagiPausedSoundInstances.has(inst)) {
                                          setSoundInstancePaused(inst, false);
                                          window.__yahagiPausedSoundInstances.delete(inst);
                                      }
                                  }
                              });
                          }
                      }
                  } catch(e){}
                  try {
                      if (window.createjs && window.createjs.WebAudioPlugin) {
                          if (window.createjs.WebAudioPlugin.context && typeof window.createjs.WebAudioPlugin.context[isBg ? 'suspend' : 'resume'] === 'function') {
                              window.createjs.WebAudioPlugin.context[isBg ? 'suspend' : 'resume']();
                          }
                          if (window.createjs.WebAudioPlugin._masterGainNode && window.createjs.WebAudioPlugin._masterGainNode.gain) {
                              window.createjs.WebAudioPlugin._masterGainNode.gain.value = isBg ? 0 : 1;
                          }
                      }
                  } catch(e){}
                  try {
                      if (window.Howler) {
                          window.Howler.mute(isBg);
                          if (window.Howler.ctx && typeof window.Howler.ctx[isBg ? 'suspend' : 'resume'] === 'function') {
                              window.Howler.ctx[isBg ? 'suspend' : 'resume']();
                          }
                      }
                  } catch(e){}
                  try {
                      var ctxList = window.__yahagiAudioContexts || [];
                      for (var k in window) {
                          try {
                              if (window[k] && (window[k] instanceof AudioContext || (window.webkitAudioContext && window[k] instanceof webkitAudioContext))) {
                                  if (ctxList.indexOf(window[k]) === -1) ctxList.push(window[k]);
                              }
                          } catch(e){}
                      }
                      ctxList.forEach(function(ctx) {
                          if (ctx && typeof ctx[isBg ? 'suspend' : 'resume'] === 'function') {
                              ctx[isBg ? 'suspend' : 'resume']();
                          }
                      });
                  } catch(e){}
                  try {
                      var media = document.querySelectorAll('audio, video');
                      media.forEach(function(m) {
                          m.muted = isBg;
                          if (isBg) {
                              if (!m.paused && !m.ended) {
                                  window.__yahagiPausedMediaElements.add(m);
                                  try { m.pause(); } catch(e){}
                              }
                          } else if (window.__yahagiPausedMediaElements.has(m)) {
                              window.__yahagiPausedMediaElements.delete(m);
                              try { m.play().catch(function(){}); } catch(e){}
                          }
                      });
                  } catch(e){}
              }
          });
      })();
      """
    let userScript = WKUserScript(
      source: scriptSource,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false
    )
    targetWebView.configuration.userContentController.addUserScript(userScript)
    targetWebView.evaluateJavaScript(scriptSource, completionHandler: nil)
  }

  public func applyBackgroundState(_ isBackground: Bool) {
    self.isBackgrounded = isBackground
    let targetWebView = findWKWebViewInApp()

    if isBackgroundPlaybackEnabled {
      do {
        try AVAudioSession.sharedInstance().setCategory(
          .playback, mode: .default, options: [.mixWithOthers])
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        NSLog("[IOSGameAudioPort] Activating playback AVAudioSession failed: \(error)")
      }
    } else {
      if isBackground {
        do {
          MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
          try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
          NSLog("[IOSGameAudioPort] Deactivating AVAudioSession failed: \(error)")
        }
      } else {
        do {
          MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
          try AVAudioSession.sharedInstance().setCategory(
            .ambient, mode: .default, options: [.mixWithOthers])
          try AVAudioSession.sharedInstance().setActive(true)
        } catch {
          NSLog("[IOSGameAudioPort] Activating AVAudioSession failed: \(error)")
        }
      }
    }

    if let webViewInstance = targetWebView {
      ensureUserScriptInjected(targetWebView: webViewInstance)

      let effectiveBg = isBackground && !isBackgroundPlaybackEnabled
      let broadcastJS = """
        (function() {
            var isBg = \(effectiveBg ? "true" : "false");

            function notifyFrame(win) {
                try {
                    win.postMessage({ type: 'YAHAGI_AUDIO_CONTROL', isBackground: isBg }, '*');
                } catch(e){}
                try {
                    for (var i = 0; i < win.frames.length; i++) {
                        try { notifyFrame(win.frames[i]); } catch(e){}
                    }
                } catch(e){}
            }

            notifyFrame(window);
        })();
        """
      webViewInstance.evaluateJavaScript(broadcastJS, completionHandler: nil)
    }
  }

  private func setMuted(_ muted: Bool, result: @escaping FlutterResult) {
    self.isUserMuted = muted
    let targetWebView = findWKWebViewInApp()

    if let webViewInstance = targetWebView {
      ensureUserScriptInjected(targetWebView: webViewInstance)
      let effectiveMuteState = muted || (isBackgrounded && !isBackgroundPlaybackEnabled)
      let broadcastJS = """
        (function() {
            var isBg = \(effectiveMuteState ? "true" : "false");
            function notifyFrame(win) {
                try { win.postMessage({ type: 'YAHAGI_AUDIO_CONTROL', isBackground: isBg }, '*'); } catch(e){}
                try {
                    for (var i = 0; i < win.frames.length; i++) {
                        try { notifyFrame(win.frames[i]); } catch(e){}
                    }
                } catch(e){}
            }
            notifyFrame(window);
        })();
        """
      webViewInstance.evaluateJavaScript(broadcastJS, completionHandler: nil)
    }

    result(nil)
  }
}
