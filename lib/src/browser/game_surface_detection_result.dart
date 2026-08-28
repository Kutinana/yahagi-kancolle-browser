import 'game_presentation_state.dart';

@Deprecated('Use decodeGamePresentationState instead.')
bool isGameSurfaceDetectionResult(Object? result) =>
    decodeGamePresentationState(result) == GamePresentationState.game;
