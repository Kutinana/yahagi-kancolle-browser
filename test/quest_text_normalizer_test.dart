import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/quest_text_normalizer.dart';

void main() {
  test('removes attributed HTML breaks and adjacent line separators', () {
    expect(
      normalizeQuestDetail(
        '前半<br class="quest-break">\r\n后半<BR data-kind="api" />\u2028结尾',
      ),
      '前半后半结尾',
    );
  });
}
