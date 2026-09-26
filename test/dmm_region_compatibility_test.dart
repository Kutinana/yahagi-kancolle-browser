import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/dmm_region_compatibility.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';

import 'game_browser_controller_test.dart' show FakeGameBrowserPort;

void main() {
  test(
    'generated JavaScript writes cookies before recovery and guards stale pages',
    () {
      const url = 'https://special.dmm.com/not-available-in-your-region/?x=1';
      final script = DmmRegionCompatibility().scriptForPage(url)!;
      final success = executeScript(script, url);
      expect(success['cookies'], {
        'ckcy_remedied_check': '"ec_mrnhbtk"',
        'ckcy': '1',
      });
      expect(success['redirects'], [
        'https://play.games.dmm.com/game/kancolle',
      ]);
      expect(success['events'], ['cookie', 'cookie', 'redirect']);
      for (final options in [
        {'url': 'https://example.com/'},
        {'url': url, 'iframe': true},
      ]) {
        final ignored = executeScript(
          script,
          options['url']! as String,
          iframe: options['iframe'] == true,
        );
        expect(ignored['events'], isEmpty);
      }
      expect(
        executeScript(script, url, rejectCookies: true)['redirects'],
        isEmpty,
      );
      final login = DmmRegionCompatibility().scriptForPage(
        'https://accounts.dmm.com/service/login/password',
      )!;
      expect(
        executeScript(
          login,
          'https://accounts.dmm.com/service/login/password',
        )['events'],
        ['cookie', 'cookie'],
      );
    },
  );
  for (final url in [
    'https://www.dmm.com/my/-/login/',
    'https://accounts.dmm.com/service/login/password?return_url=test',
  ]) {
    test('DMM login prepares region cookies: $url', () {
      final port = FakeGameBrowserPort();
      final controller = GameBrowserController(port: port);
      addTearDown(controller.dispose);
      controller.onPageFinished(url);
      expect(port.lastRunJavaScript, contains('ckcy=1'));
      expect(
        port.lastRunJavaScript,
        contains('ckcy_remedied_check="ec_mrnhbtk"'),
      );
      expect(port.lastRunJavaScript, contains('domain=.dmm.com'));
      expect(port.lastRunJavaScript, isNot(contains('location.replace')));
    });
  }

  test('both region pages recover only once until a manual reload', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(port: port);
    addTearDown(controller.dispose);
    const blocked = 'https://special.dmm.com/not-available-in-your-region/';
    controller.onPageFinished(blocked);
    expect(port.lastRunJavaScript, contains('location.replace'));
    expect(
      port.lastRunJavaScript,
      contains('https://play.games.dmm.com/game/kancolle'),
    );
    port.lastRunJavaScript = null;
    controller.onPageFinished('https://www.dmm.com/netgame/foreign/');
    expect(port.lastRunJavaScript, isNot(contains('location.replace')));
    await controller.reload();
    controller.onPageFinished('https://www.dmm.com/netgame/foreign/');
    expect(port.lastRunJavaScript, contains('location.replace'));
  });

  test('unrelated pages, logout and spoofed addresses are untouched', () {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(port: port);
    addTearDown(controller.dispose);
    for (final url in [
      'https://ooi.moe/',
      'https://play.games.dmm.com/game/kancolle',
      'https://www.dmm.com/my/-/login/logout/',
      'https://special.dmm.com.evil.test/not-available-in-your-region',
      'https://evil.test/?next=https://www.dmm.com/netgame/foreign',
      'https://evil.test@www.dmm.com/netgame/foreign',
      'http://special.dmm.com/not-available-in-your-region',
    ]) {
      controller.onPageFinished(url);
      expect(port.lastRunJavaScript, isNull, reason: url);
    }
  });
}

Map<String, dynamic> executeScript(
  String script,
  String url, {
  bool iframe = false,
  bool rejectCookies = false,
}) {
  final result = Process.runSync('node', [
    '-e',
    r'''
const vm = require('node:vm');
const input = JSON.parse(process.argv[1]);
const cookies = {}, redirects = [], events = [];
const document = {};
Object.defineProperty(document, 'cookie', {
  get() { return Object.entries(cookies).map(([k,v]) => k + '=' + v).join('; '); },
  set(value) {
    events.push('cookie');
    if (input.rejectCookies) return;
    const pair = value.split(';')[0], split = pair.indexOf('=');
    cookies[pair.slice(0, split)] = pair.slice(split + 1);
  }
});
const self = {}, window = {self, top: input.iframe ? {} : self};
const location = {href: input.url, replace(url) { redirects.push(url); events.push('redirect'); }};
vm.runInNewContext(input.script, {window, location, document, URL, Date});
process.stdout.write(JSON.stringify({cookies, redirects, events}));
''',
    jsonEncode({
      'script': script,
      'url': url,
      'iframe': iframe,
      'rejectCookies': rejectCookies,
    }),
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}
