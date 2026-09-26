import 'dart:convert';

/// DMM region-cookie compatibility, following GotoBrowser's login handling.
/// Each explicit navigation allows at most one automatic recovery.
final class DmmRegionCompatibility {
  static const _recoveryUrl = 'https://play.games.dmm.com/game/kancolle';
  bool _recoveryAttempted = false;

  void reset() => _recoveryAttempted = false;

  String? scriptForPage(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443) {
      return null;
    }
    final host = uri.host.toLowerCase();
    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    final isLogin =
        (host == 'www.dmm.com' &&
            (path == '/my/-/login' || path.startsWith('/my/-/login/=/'))) ||
        (host == 'accounts.dmm.com' && path == '/service/login/password');
    final isBlocked =
        (host == 'www.dmm.com' && path == '/netgame/foreign') ||
        (host == 'special.dmm.com' && path == '/not-available-in-your-region');
    if (!isLogin && !isBlocked) return null;
    final recover = isBlocked && !_recoveryAttempted;
    if (recover) _recoveryAttempted = true;
    return '''
(function () {
  // Ignore callbacks for a document that has already navigated away.
  if (window.top !== window.self ||
      location.href !== new URL(${jsonEncode(url)}).href) return;
  var expires = new Date(Date.now() + 5 * 365 * 24 * 60 * 60 * 1000).toUTCString();
  var attributes = ';path=/;domain=.dmm.com;expires=' + expires + ';Secure';
  document.cookie = 'ckcy_remedied_check="ec_mrnhbtk"' + attributes;
  document.cookie = 'ckcy=1' + attributes;
  ${recover ? '''
  // Retry only after the browser has accepted both cookies.
  var cookies = document.cookie.split(';').map(function (value) { return value.trim(); });
  if (cookies.indexOf('ckcy=1') >= 0 &&
      cookies.indexOf('ckcy_remedied_check="ec_mrnhbtk"') >= 0) {
    location.replace(${jsonEncode(_recoveryUrl)});
  }
  ''' : ''}
})();
''';
  }
}
