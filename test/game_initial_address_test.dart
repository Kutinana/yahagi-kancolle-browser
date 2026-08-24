import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_initial_address.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_connector.dart';

void main() {
  test('cold start uses the selected OOI connector', () {
    final browser = GameBrowserController(homeUri: GameConnector.ooi.entryUri);

    expect(resolveInitialGameAddress(browser), GameConnector.ooi.entryUri);
  });

  test('cold start defaults to the Yahagi connector', () {
    final browser = GameBrowserController();

    expect(resolveInitialGameAddress(browser), GameConnector.yahagi.entryUri);
  });
}
