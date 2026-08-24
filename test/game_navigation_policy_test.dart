import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_navigation_policy.dart';

void main() {
  final providers = <String, Uri>{
    'Google': Uri.parse('https://accounts.google.com/o/oauth2/v2/auth'),
    'LINE': Uri.parse('https://access.line.me/oauth2/v2.1/authorize'),
    'X': Uri.parse('https://api.twitter.com/oauth/authenticate'),
    'Amazon': Uri.parse('https://www.amazon.com/ap/oa'),
    'Facebook': Uri.parse('https://www.facebook.com/dialog/oauth'),
  };

  test('allows all five providers only during DMM authentication', () {
    final policy = GameNavigationPolicy();

    for (final provider in providers.entries) {
      expect(
        policy.canNavigate(provider.value),
        isFalse,
        reason: '${provider.key} must be closed outside the login flow',
      );
    }

    policy.onPageStarted(
      Uri.parse('https://accounts.dmm.com/service/login/password'),
    );

    for (final provider in providers.entries) {
      expect(
        policy.canNavigate(provider.value),
        isTrue,
        reason: '${provider.key} must open from the DMM login page',
      );
    }
  });

  test('keeps redirects scoped and closes providers after entering game', () {
    final policy = GameNavigationPolicy()
      ..onPageStarted(Uri.parse('https://accounts.dmm.com/service/login'));

    policy.onPageStarted(
      Uri.parse('https://accounts.google.com/o/oauth2/v2/auth'),
    );
    expect(
      policy.canNavigate(Uri.parse('https://accounts.google.com/signin')),
      isTrue,
    );
    expect(
      policy.canNavigate(Uri.parse('https://phishing.example/signin')),
      isFalse,
    );
    expect(
      policy.canNavigate(Uri.parse('https://accounts.google.com.evil.test')),
      isFalse,
    );

    policy.onPageStarted(Uri.parse('https://play.games.dmm.com/game/kancolle'));
    expect(
      policy.canNavigate(Uri.parse('https://accounts.google.com/signin')),
      isFalse,
    );
  });

  test('continues to require trusted HTTPS game origins', () {
    final policy = GameNavigationPolicy();

    expect(
      policy.canNavigate(Uri.parse('https://accounts.dmm.com/login')),
      isTrue,
    );
    expect(
      policy.canNavigate(Uri.parse('http://accounts.dmm.com/login')),
      isFalse,
    );
    expect(
      policy.canNavigate(Uri.parse('https://dmm.com.attacker.example/login')),
      isFalse,
    );
  });

  test('allows only the exact OOI HTTPS origin', () {
    final policy = GameNavigationPolicy();

    expect(policy.canNavigate(Uri.parse('https://ooi.moe/')), isTrue);
    expect(policy.canNavigate(Uri.parse('http://ooi.moe/')), isFalse);
    expect(policy.canNavigate(Uri.parse('https://login.ooi.moe/')), isFalse);
    expect(
      policy.canNavigate(Uri.parse('https://ooi.moe.evil.test/')),
      isFalse,
    );
    expect(policy.canNavigate(Uri.parse('https://ooi.moe:444/')), isFalse);
  });
}
