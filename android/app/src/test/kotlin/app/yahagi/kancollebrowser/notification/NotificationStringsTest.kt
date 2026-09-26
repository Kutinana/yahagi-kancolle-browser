package app.yahagi.kancollebrowser.notification

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationStringsTest {
    @Test
    fun usesPersistedAppLocaleForNativeNotificationText() {
        assertEquals("远征通知", NotificationStrings().channelNames["expedition"])
        assertEquals("遠征通知", NotificationStrings("zh_Hant").channelNames["expedition"])
        assertEquals("入渠修理", NotificationStrings("ja").channelNames["repair"])
        assertEquals("完了", NotificationStrings("ja").completed)
        assertEquals("矢矧 · 母港の進行状況（3件）", NotificationStrings("ja").ongoingTitle(3))
        assertEquals("另有 2 項進行中或已完成任務", NotificationStrings("zh_Hant").overflow(2))
        assertEquals("遠征通知 · 音あり · 振動なし", NotificationStrings("ja").channelVariant("遠征通知", true, false))
    }
}
