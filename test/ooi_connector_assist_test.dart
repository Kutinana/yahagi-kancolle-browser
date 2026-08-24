import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/ooi_connector_assist.dart';

void main() {
  test('runs only on the exact OOI HTTPS origin', () {
    expect(OoiConnectorAssist.shouldRun('https://ooi.moe/'), isTrue);
    expect(
      OoiConnectorAssist.shouldRun('https://ooi.moe/login?next=connector'),
      isTrue,
    );
    expect(OoiConnectorAssist.shouldRun('http://ooi.moe/'), isFalse);
    expect(OoiConnectorAssist.shouldRun('https://sub.ooi.moe/'), isFalse);
    expect(OoiConnectorAssist.shouldRun('https://ooi.moe.evil.test/'), isFalse);
    expect(OoiConnectorAssist.shouldRun('https://ooi.moe:444/'), isFalse);
  });

  test('selects mode 4 without reading credentials or submitting', () {
    expect(
      OoiConnectorAssist.script,
      contains('input[name="mode"][value="4"]'),
    );
    expect(OoiConnectorAssist.script, contains('target.checked = true'));
    expect(OoiConnectorAssist.script, isNot(contains('.submit(')));
    expect(OoiConnectorAssist.script, isNot(contains('password')));
    expect(OoiConnectorAssist.script, isNot(contains('click()')));
  });
}
