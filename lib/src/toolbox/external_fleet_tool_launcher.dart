import 'package:url_launcher/url_launcher.dart';

enum ExternalFleetTool { noro6, jervis }

typedef FleetToolLaunchCallback = Future<bool> Function(Uri uri);

Uri externalFleetToolUri(ExternalFleetTool tool, String deckBuilderJson) {
  final baseUri = switch (tool) {
    ExternalFleetTool.noro6 => Uri.parse('https://noro6.github.io/kc-web/'),
    ExternalFleetTool.jervis => Uri.parse(
      'https://fleethub.madonoharu.workers.dev/',
    ),
  };
  return baseUri.replace(
    queryParameters: <String, String>{'predeck': deckBuilderJson},
  );
}

class ExternalFleetToolLauncher {
  const ExternalFleetToolLauncher({FleetToolLaunchCallback? launch})
    : _launch = launch ?? _launchInExternalApplication;

  final FleetToolLaunchCallback _launch;

  Future<bool> open(ExternalFleetTool tool, String deckBuilderJson) =>
      _launch(externalFleetToolUri(tool, deckBuilderJson));

  static Future<bool> _launchInExternalApplication(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
