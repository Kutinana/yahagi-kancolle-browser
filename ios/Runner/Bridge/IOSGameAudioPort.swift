import AVFoundation
import Flutter
import Foundation
import MediaPlayer
import WebKit

/// Swift native audio controller for WKWebView game audio.
@objc public class IOSGameAudioPort: NSObject, WKScriptMessageHandler {
  private static let messageName = "YahagiGameAudioReady"
  private weak var viewController: UIViewController?
  private weak var webView: WKWebView?
  private var isUserMuted: Bool = false
  private var isBackgrounded: Bool = false
  private var isBackgroundPlaybackEnabled: Bool = false
  private weak var mediaPlaybackWebView: WKWebView?
  private var isMediaPlaybackSuspended = false
  private var isMediaPlaybackTransitionInFlight = false
  private var policyRevision = 0

  @objc public init(viewController: UIViewController? = nil, webView: WKWebView? = nil) {
    self.viewController = viewController
    self.webView = webView
    super.init()
    isBackgrounded = !isAppForeground
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
    // Flutter's window uses UIScene; scene activation can precede the legacy
    // UIApplication state update consumed by a Dart lifecycle callback.
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleAppWillResignActive),
      name: UIScene.willDeactivateNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleAppDidEnterBackground),
      name: UIScene.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleAppDidBecomeActive),
      name: UIScene.didActivateNotification, object: nil)
  }

  private var isAppForeground: Bool {
    if let scene = viewController?.viewIfLoaded?.window?.windowScene {
      return scene.activationState == .foregroundActive
    }
    return UIApplication.shared.applicationState == .active
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
      setMuted(muted, result: result)
    case "refreshPolicy":
      applyBackgroundState(!isAppForeground)
      result(nil)
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
    return nil
  }

  private weak var scriptWebView: WKWebView?
  private var userScript: WKUserScript?

  private func ensureUserScriptInjected(targetWebView: WKWebView) {
    guard scriptWebView !== targetWebView else { return }
    if let previous = scriptWebView {
      let content = previous.configuration.userContentController
      content.removeScriptMessageHandler(forName: Self.messageName)
      if let installed = userScript {
        let others = content.userScripts.filter { $0 !== installed }
        content.removeAllUserScripts()
        others.forEach { content.addUserScript($0) }
      }
    }
    scriptWebView = targetWebView
    let scriptSource = """
      (function() {
          if (window.__yahagiAudioScriptInjected) return;
          window.__yahagiAudioScriptInjected = true;
          var canRecoverAudio = false;
          var isUserMuted = true;
          var backgroundPlaybackEnabled = false;
          var revision = -1;
          var visibilityEpoch = 0;
          var contexts = new Map();
          var NativeAudioContext = window.AudioContext || window.webkitAudioContext;
          var nativeResume = NativeAudioContext && NativeAudioContext.prototype.resume;
          var nativeSuspend = NativeAudioContext && NativeAudioContext.prototype.suspend;
          var nativeConnect = window.AudioNode && AudioNode.prototype.connect;
          var nativeDisconnect = window.AudioNode && AudioNode.prototype.disconnect;
          var mediaMutes = new WeakMap();
          var mediaElements = new Set();
          var mediaPrototype = window.HTMLMediaElement && HTMLMediaElement.prototype;
          var nativeMediaMute = mediaPrototype && Object.getOwnPropertyDescriptor(mediaPrototype, 'muted');
          function trackMedia(media) {
              if (!mediaMutes.has(media)) {
                  mediaMutes.set(media, nativeMediaMute.get.call(media));
                  mediaElements.add(new WeakRef(media));
              }
              nativeMediaMute.set.call(media, isUserMuted || mediaMutes.get(media));
          }
          if (nativeMediaMute && nativeMediaMute.get && nativeMediaMute.set) {
              Object.defineProperty(mediaPrototype, 'muted', {
                  configurable: nativeMediaMute.configurable,
                  enumerable: nativeMediaMute.enumerable,
                  get: nativeMediaMute.get,
                  set: function(muted) {
                      trackMedia(this);
                      mediaMutes.set(this, !!muted);
                      nativeMediaMute.set.call(this, isUserMuted || !!muted);
                  }
              });
              var nativePlay = mediaPrototype.play;
              mediaPrototype.play = function() {
                  trackMedia(this);
                  return nativePlay.apply(this, arguments);
              };
              document.addEventListener('play', function(evt) {
                  if (evt.target instanceof HTMLMediaElement) trackMedia(evt.target);
              }, true);
          }
          function requestPolicy() {
              window.webkit.messageHandlers.YahagiGameAudioReady.postMessage({visibilityEpoch: visibilityEpoch});
          }
          function settle(ctx, state) {
              if (ctx.state === 'closed') {
                  var error = new DOMException('AudioContext is closed', 'InvalidStateError');
                  state.resumes.splice(0).forEach(function(waiter) { waiter.reject(error); });
                  state.suspends.splice(0).forEach(function(waiter) { waiter.reject(error); });
                  contexts.delete(ctx);
                  return;
              }
              var howler = window.Howler;
              if (!canRecoverAudio && ctx.state === 'suspended' && howler && howler.ctx === ctx && howler.state === 'running') {
                  // Native suspension bypasses Howler's idle suspension. Keep its
                  // state aligned so new sounds wait for resume instead of starting
                  // their end timers against a context that cannot render yet.
                  howler.state = 'suspended';
              }
              if (canRecoverAudio && ctx.state === 'running') {
                  state.resumes.splice(0).forEach(function(waiter) { waiter.resolve(); });
              }
              if (ctx.state === 'suspended' || ctx.state === 'interrupted') {
                  state.suspends.splice(0).forEach(function(waiter) { waiter.resolve(); });
              }
          }
          function track(ctx) {
              if (!contexts.has(ctx)) {
                  // Mute the output without stopping the audio clock. Login and
                  // scene transitions can depend on resume/play/end callbacks.
                  var output = ctx.state !== 'closed' ? ctx.createGain() : null;
                  if (output) {
                      output.gain.value = isUserMuted ? 0 : 1;
                      nativeConnect.call(output, ctx.destination);
                  }
                  contexts.set(ctx, {output: output, wanted: ctx.state === 'running', resumes: [], suspends: [], resumeRevision: -1, suspendRevision: -1});
                  ctx.addEventListener('statechange', function() {
                      var state = contexts.get(ctx);
                      if (!state) return;
                      if (ctx.state === 'running') {
                          state.resumeRevision = -1;
                          state.suspendRevision = -1;
                      }
                      if (ctx.state === 'interrupted' && document.hidden && !backgroundPlaybackEnabled) {
                          canRecoverAudio = false;
                          requestPolicy();
                      }
                      reconcile(ctx, state);
                  });
              }
              return contexts.get(ctx);
          }
          function reconcile(ctx, state) {
              settle(ctx, state);
              if (ctx.state === 'closed') return;
              if (!canRecoverAudio || !state.wanted) {
                  // An interrupted context is already stopped. Suspending it again
                  // can leave WebKit's promise pending indefinitely on real devices.
                  if (ctx.state === 'running' && state.suspendRevision !== revision) {
                      state.suspendRevision = revision;
                      nativeSuspend.call(ctx).then(function() { settle(ctx, state); }, function() { settle(ctx, state); });
                  }
                  return;
              }
              if (ctx.state !== 'running' && state.resumeRevision !== revision) {
                  state.resumeRevision = revision;
                  // State changes also settle the game's promises. Never serialize
                  // foreground recovery behind an earlier WebKit suspend/resume.
                  nativeResume.call(ctx).then(function() { settle(ctx, state); }, function() { settle(ctx, state); });
              }
          }
          if (NativeAudioContext) {
              AudioNode.prototype.connect = function(destination) {
                  if (this.context instanceof NativeAudioContext && destination === this.context.destination) {
                      var state = track(this.context);
                      if (state.output) {
                          var args = Array.prototype.slice.call(arguments);
                          args[0] = state.output;
                          nativeConnect.apply(this, args);
                          return destination;
                      }
                  }
                  return nativeConnect.apply(this, arguments);
              };
              AudioNode.prototype.disconnect = function(destination) {
                  var state = contexts.get(this.context);
                  if (state && state.output && destination === this.context.destination) {
                      var args = Array.prototype.slice.call(arguments);
                      args[0] = state.output;
                      return nativeDisconnect.apply(this, args);
                  }
                  return nativeDisconnect.apply(this, arguments);
              };
              NativeAudioContext.prototype.resume = function() {
                  var ctx = this;
                  var state = track(ctx);
                  state.wanted = true;
                  state.resumeRevision = -1;
                  return new Promise(function(resolve, reject) {
                      state.resumes.push({resolve: resolve, reject: reject});
                      reconcile(ctx, state);
                  });
              };
              NativeAudioContext.prototype.suspend = function() {
                  var ctx = this;
                  var state = track(ctx);
                  state.wanted = false;
                  state.suspendRevision = -1;
                  return new Promise(function(resolve, reject) {
                      state.suspends.push({resolve: resolve, reject: reject});
                      reconcile(ctx, state);
                  });
              };
              var GuardedAudioContext = new Proxy(NativeAudioContext, {
                  construct: function(target, args, newTarget) {
                      var ctx = Reflect.construct(target, args, newTarget);
                      reconcile(ctx, track(ctx));
                      return ctx;
                  }
              });
              if (window.AudioContext === NativeAudioContext) window.AudioContext = GuardedAudioContext;
              if (window.webkitAudioContext === NativeAudioContext) window.webkitAudioContext = GuardedAudioContext;
          }
          function applyPolicy(force) {
              contexts.forEach(function(state) {
                  if (state.output) state.output.gain.value = isUserMuted ? 0 : 1;
              });
              mediaElements.forEach(function(reference) {
                  var media = reference.deref();
                  if (media) trackMedia(media);
                  else mediaElements.delete(reference);
              });
              var howler = window.Howler;
              if (howler && howler.ctx) {
                  track(howler.ctx);
                  // Let Howler release its own play locks and queued voice/SFX.
                  // Resuming the context directly does not emit Howler's resume event.
                  if (canRecoverAudio && typeof howler._autoResume === 'function' && howler._howls && howler._howls.some(function(howl) {
                      return howl._webAudio && (howl.playing() || howl._playLock);
                  })) howler._autoResume();
              }
              contexts.forEach(function(state, ctx) {
                  if (force) state.resumeRevision = -1;
                  reconcile(ctx, state);
              });
          }
          window.addEventListener('message', function(evt) {
              if (!evt.data || evt.data.type !== 'YAHAGI_AUDIO_POLICY' || evt.data.revision < revision) return;
              revision = evt.data.revision;
              // Offstage games can be hidden while the app is in the foreground.
              if (evt.data.canRecoverAudio && document.hidden && !evt.data.backgroundPlaybackEnabled && evt.data.visibilityEpoch !== visibilityEpoch) {
                  requestPolicy();
                  return;
              }
              canRecoverAudio = !!evt.data.canRecoverAudio;
              isUserMuted = !!evt.data.isUserMuted;
              backgroundPlaybackEnabled = !!evt.data.backgroundPlaybackEnabled;
              try {
                  if (navigator.audioSession) {
                      var type = canRecoverAudio || backgroundPlaybackEnabled ? 'playback' : 'auto';
                      if (navigator.audioSession.type !== type) navigator.audioSession.type = type;
                  }
              } catch(e){}
              applyPolicy(true);
          });
          document.addEventListener('visibilitychange', function() {
              visibilityEpoch += 1;
              if (!backgroundPlaybackEnabled) canRecoverAudio = false;
              applyPolicy(false);
              requestPolicy();
          });
          window.addEventListener('pageshow', requestPolicy);
          ['pointerdown', 'touchend', 'keydown'].forEach(function(type) {
              window.addEventListener(type, function() { applyPolicy(true); }, {capture: true, passive: true});
          });
          requestPolicy();
      })();
      """
    let userScript = WKUserScript(
      source: scriptSource,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false
    )
    let content = targetWebView.configuration.userContentController
    content.add(self, name: Self.messageName)
    content.addUserScript(userScript)
    self.userScript = userScript
    targetWebView.evaluateJavaScript(scriptSource, completionHandler: nil)
  }

  public func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    guard message.name == Self.messageName,
      let body = message.body as? [String: Any],
      let visibilityEpoch = body["visibilityEpoch"] as? Int,
      let target = scriptWebView, message.webView === target
    else { return }
    target.callAsyncJavaScript(
      "window.postMessage({type: 'YAHAGI_AUDIO_POLICY', backgroundPlaybackEnabled: backgroundPlaybackEnabled, canRecoverAudio: canRecoverAudio, isUserMuted: isUserMuted, revision: revision, visibilityEpoch: visibilityEpoch}, '*');",
      arguments: [
        "backgroundPlaybackEnabled": isBackgroundPlaybackEnabled,
        "canRecoverAudio": canRecoverAudio,
        "isUserMuted": isUserMuted,
        "revision": policyRevision,
        "visibilityEpoch": visibilityEpoch,
      ], in: message.frameInfo, in: .page, completionHandler: nil)
  }

  public func applyBackgroundState(_ isBackground: Bool) {
    self.isBackgrounded = isBackground
    do {
      let session = AVAudioSession.sharedInstance()
      let category: AVAudioSession.Category =
        isBackground && !isBackgroundPlaybackEnabled ? .ambient : .playback
      // Foreground game audio uses media playback regardless of the background
      // preference. Only a blocked background session leaves that category.
      if session.category != category {
        try session.setCategory(category, mode: .default, options: [.mixWithOthers])
      }
      if !isBackgroundPlaybackEnabled {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      }
      // Activate the session before asking WebKit to resume. WebKit owns
      // playback suspension; separately deactivating the session adds a second
      // interruption that can outlive the page's suspension.
      if !isBackground || isBackgroundPlaybackEnabled {
        try session.setActive(true)
      }
    } catch {
      NSLog("[IOSGameAudioPort] Applying AVAudioSession policy failed: \(error)")
    }
    applyEffectiveMuteState()
  }

  private func setMuted(_ muted: Bool, result: @escaping FlutterResult) {
    self.isUserMuted = muted
    applyEffectiveMuteState()
    result(nil)
  }

  private var canRecoverAudio: Bool {
    !(isBackgrounded && !isBackgroundPlaybackEnabled)
      && !isMediaPlaybackSuspended && !isMediaPlaybackTransitionInFlight
  }

  private func applyEffectiveMuteState() {
    let targetWebView = findWKWebViewInApp()

    if let webViewInstance = targetWebView {
      ensureUserScriptInjected(targetWebView: webViewInstance)
      if mediaPlaybackWebView !== webViewInstance {
        mediaPlaybackWebView = webViewInstance
        isMediaPlaybackSuspended = false
        isMediaPlaybackTransitionInFlight = false
      }
      policyRevision += 1
      let broadcastJS = """
        (function() {
            function notifyFrame(win) {
                try { win.postMessage({ type: 'YAHAGI_AUDIO_POLICY', backgroundPlaybackEnabled: \(isBackgroundPlaybackEnabled ? "true" : "false"), canRecoverAudio: \(canRecoverAudio ? "true" : "false"), isUserMuted: \(isUserMuted ? "true" : "false"), revision: \(policyRevision) }, '*'); } catch(e){}
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

      // WebKit owns HTML media suspension; the frame hook separately gates
      // WebAudio contexts that can start new sources while this is suspended.
      // User mute must leave playback and its completion callbacks running.
      let shouldSuspend = isBackgrounded && !isBackgroundPlaybackEnabled
      guard !isMediaPlaybackTransitionInFlight, isMediaPlaybackSuspended != shouldSuspend else {
        return
      }
      isMediaPlaybackTransitionInFlight = true
      webViewInstance.setAllMediaPlaybackSuspended(shouldSuspend) { [weak self, weak webViewInstance] in
        guard let self = self, let target = webViewInstance,
          self.mediaPlaybackWebView === target
        else { return }
        self.isMediaPlaybackSuspended = shouldSuspend
        self.isMediaPlaybackTransitionInFlight = false
        // Lifecycle and Flutter mute changes can arrive while WebKit is still
        // completing the previous request. Reconcile the latest target now.
        self.applyEffectiveMuteState()
      }
    }
  }
}
