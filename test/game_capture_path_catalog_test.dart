import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_path_catalog.dart';

void main() {
  test('capture allowlist is the union of every event consumer', () {
    expect(GameCapturePathCatalog.all, <String>{
      ...GameCapturePathCatalog.gameState,
      ...GameCapturePathCatalog.battle,
      ...GameCapturePathCatalog.senka,
      ...GameCapturePathCatalog.logbook,
    });
    expect(
      GameCapturePathCatalog.all.every((path) => path.startsWith('/kcsapi/')),
      isTrue,
    );
  });

  test(
    'capture allowlist includes critical state, battle, senka and log paths',
    () {
      expect(
        GameCapturePathCatalog.all,
        containsAll(<String>{
          '/kcsapi/api_start2/getData',
          '/kcsapi/api_port/port',
          '/kcsapi/api_req_combined_battle/ec_night_to_day',
          '/kcsapi/api_req_ranking/mxltvkpyuklh',
          '/kcsapi/api_req_kousyou/destroyship',
        }),
      );
    },
  );
}
