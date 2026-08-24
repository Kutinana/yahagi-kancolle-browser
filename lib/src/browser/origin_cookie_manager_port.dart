import 'package:flutter/services.dart';

import 'game_launch_config.dart';

const originCookieManagerMethodChannelName =
    'app.yahagi.kancollebrowser/origin_cookies';

abstract interface class OriginCookieManagerPort {
  Future<void> clearCookiesForOrigin(Uri origin);
}

final class MethodChannelOriginCookieManagerPort
    implements OriginCookieManagerPort {
  const MethodChannelOriginCookieManagerPort({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(originCookieManagerMethodChannelName);

  final MethodChannel _channel;

  @override
  Future<void> clearCookiesForOrigin(Uri origin) {
    if (origin != GameLaunchConfig.ooiOrigin) {
      throw ArgumentError.value(
        origin,
        'origin',
        'only the exact OOI HTTPS origin can be cleared',
      );
    }
    return _channel.invokeMethod<void>(
      'clearCookiesForOrigin',
      <String, Object?>{'origin': origin.toString()},
    );
  }
}
