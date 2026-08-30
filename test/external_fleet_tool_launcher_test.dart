import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/external_fleet_tool_launcher.dart';

void main() {
  const json = '{"version":4,"name":"长门 & 陆奥"}';

  group('externalFleetToolUri', () {
    test('builds a noro6 URI with a lossless predeck parameter', () {
      final uri = externalFleetToolUri(ExternalFleetTool.noro6, json);

      expect(uri.scheme, 'https');
      expect(uri.host, 'noro6.github.io');
      expect(uri.path, '/kc-web/');
      expect(uri.queryParameters['predeck'], json);
    });

    test(
      'builds a Jervis-compatible URI with a lossless predeck parameter',
      () {
        final uri = externalFleetToolUri(ExternalFleetTool.jervis, json);

        expect(uri.scheme, 'https');
        expect(uri.host, 'fleethub.madonoharu.workers.dev');
        expect(uri.path, '/');
        expect(uri.queryParameters['predeck'], json);
      },
    );
  });

  test('launcher forwards the generated URI and result', () async {
    Uri? received;
    final launcher = ExternalFleetToolLauncher(
      launch: (uri) async {
        received = uri;
        return false;
      },
    );

    final launched = await launcher.open(ExternalFleetTool.noro6, json);

    expect(launched, isFalse);
    expect(received?.queryParameters['predeck'], json);
  });
}
