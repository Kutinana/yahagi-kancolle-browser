enum GamePresentationState { game, web, pending }

enum GamePresentationPlatformAction { bind, release, none }

extension GamePresentationStateAction on GamePresentationState {
  GamePresentationPlatformAction get platformAction => switch (this) {
    GamePresentationState.game => GamePresentationPlatformAction.bind,
    GamePresentationState.web => GamePresentationPlatformAction.release,
    GamePresentationState.pending => GamePresentationPlatformAction.none,
  };
}

GamePresentationState? decodeGamePresentationState(Object? result) {
  if (result is bool) {
    return result ? GamePresentationState.game : GamePresentationState.web;
  }
  if (result is! String) return null;

  var value = result.trim().toLowerCase();
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    value = value.substring(1, value.length - 1).trim();
  }
  return switch (value) {
    'game' || 'true' => GamePresentationState.game,
    'web' || 'false' => GamePresentationState.web,
    'pending' => GamePresentationState.pending,
    _ => null,
  };
}
