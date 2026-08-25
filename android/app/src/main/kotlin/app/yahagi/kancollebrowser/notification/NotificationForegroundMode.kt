package app.yahagi.kancollebrowser.notification

enum class NotificationForegroundMode {
    STOP,
    SESSION,
    PROGRESS,
    ;

    companion object {
        fun resolve(
            sessionRetentionRequested: Boolean,
            hasOngoingItems: Boolean,
        ): NotificationForegroundMode = when {
            hasOngoingItems -> PROGRESS
            sessionRetentionRequested -> SESSION
            else -> STOP
        }
    }
}
