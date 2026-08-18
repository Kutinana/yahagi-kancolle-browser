import 'safe_page_address.dart';

/// Limits third-party authentication to a DMM login session while keeping the
/// game WebView closed to unrelated external sites.
class GameNavigationPolicy {
  static const Set<String> _authenticationRoots = <String>{
    'accounts.google.com',
    'access.line.me',
    'api.twitter.com',
    'twitter.com',
    'x.com',
    'amazon.com',
    'amazon.co.jp',
    'facebook.com',
  };

  bool _authenticationFlowActive = false;

  bool canNavigate(Uri uri) {
    if (SafePageAddress.canNavigateInGameWebView(uri)) return true;
    return _authenticationFlowActive && isTrustedAuthenticationProvider(uri);
  }

  void onPageStarted(Uri? uri) {
    if (uri == null) {
      _authenticationFlowActive = false;
      return;
    }
    if (isTrustedAuthenticationProvider(uri)) return;
    if (_isDmmAuthenticationPage(uri)) {
      _authenticationFlowActive = true;
      return;
    }
    _authenticationFlowActive = false;
  }

  static bool isTrustedAuthenticationProvider(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return _authenticationRoots.any((root) => _matchesRoot(host, root));
  }

  static bool _isDmmAuthenticationPage(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host == 'accounts.dmm.com' || host == 'accounts.dmm.co.jp') {
      return true;
    }
    final isDmm =
        _matchesRoot(host, 'dmm.com') || _matchesRoot(host, 'dmm.co.jp');
    return isDmm && uri.path.toLowerCase().contains('login');
  }

  static bool _matchesRoot(String host, String root) =>
      host == root || host.endsWith('.$root');
}
