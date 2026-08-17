import 'game_frame_rate_runtime_controller.dart';

String gameFrameRateApplyScript(GameFrameRateTarget target) {
  final configuration = switch (target) {
    GameFrameRateTarget.fps30 =>
      '''
      if (typeof ticker.TIMEOUT !== 'undefined') ticker.timingMode=ticker.TIMEOUT;
      ticker.framerate=30;
    ''',
    GameFrameRateTarget.fps60 =>
      '''
      if (typeof ticker.RAF_SYNCHED !== 'undefined') {
        ticker.timingMode=ticker.RAF_SYNCHED;
      } else if (typeof ticker.TIMEOUT !== 'undefined') {
        ticker.timingMode=ticker.TIMEOUT;
      }
      ticker.framerate=60;
    ''',
    GameFrameRateTarget.highRefresh =>
      '''
      if (typeof ticker.RAF !== 'undefined') ticker.timingMode=ticker.RAF;
    ''',
  };
  return '''
    (() => {
      const ticker=globalThis.createjs && globalThis.createjs.Ticker;
      if (!ticker) return false;
      $configuration
      return true;
    })();
  ''';
}

const String gameFrameRateMeasurementScript = '''
  (() => {
    const ticker=globalThis.createjs && globalThis.createjs.Ticker;
    if (!ticker || typeof ticker.getMeasuredFPS !== 'function') return null;
    const value=Number(ticker.getMeasuredFPS());
    return Number.isFinite(value) && value >= 0 ? value : null;
  })();
''';
