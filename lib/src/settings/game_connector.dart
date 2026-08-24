import '../browser/game_launch_config.dart';

enum GameConnector { yahagi, ooi }

extension GameConnectorDefinition on GameConnector {
  String get storageName => name;

  Uri get entryUri => switch (this) {
    GameConnector.yahagi => GameLaunchConfig.dmmGameEntry,
    GameConnector.ooi => GameLaunchConfig.ooiEntry,
  };

  Uri get entryOrigin => Uri.parse(entryUri.origin);

  bool ownsLoginPage(Uri uri) =>
      this == GameConnector.ooi &&
      uri.scheme == 'https' &&
      uri.host.toLowerCase() == 'ooi.moe' &&
      !uri.hasPort &&
      uri.userInfo.isEmpty;
}

abstract final class GameConnectorCodec {
  static GameConnector decode(String? value) {
    for (final connector in GameConnector.values) {
      if (connector.storageName == value) return connector;
    }
    return GameConnector.yahagi;
  }
}
