package app.yahagi.kancollebrowser

enum class GameSurfaceRecoveryReason {
    MULTI_WINDOW_ENTER,
    MULTI_WINDOW_EXIT,
    PICTURE_IN_PICTURE_ENTER,
    PICTURE_IN_PICTURE_EXIT,
    CONFIGURATION_CHANGED,
}

class GameSurfaceRecoveryTrigger(
    private val recover: (GameSurfaceRecoveryReason) -> Unit,
) {
    fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        recover(
            if (isInMultiWindowMode) {
                GameSurfaceRecoveryReason.MULTI_WINDOW_ENTER
            } else {
                GameSurfaceRecoveryReason.MULTI_WINDOW_EXIT
            },
        )
    }

    fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        recover(
            if (isInPictureInPictureMode) {
                GameSurfaceRecoveryReason.PICTURE_IN_PICTURE_ENTER
            } else {
                GameSurfaceRecoveryReason.PICTURE_IN_PICTURE_EXIT
            },
        )
    }

    fun onConfigurationChanged() {
        recover(GameSurfaceRecoveryReason.CONFIGURATION_CHANGED)
    }
}
