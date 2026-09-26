package app.yahagi.kancollebrowser.notification

/** Uses the app locale persisted with the snapshot, including background work. */
internal class NotificationStrings(private val localeCode: String = "zh") {
    private fun text(zh: String, hant: String, ja: String): String = when (localeCode) {
        "ja" -> ja
        "zh_Hant" -> hant
        else -> zh
    }

    val channelNames: Map<String, String> get() = mapOf(
        "expedition" to text("远征通知", "遠征通知", "遠征通知"),
        "repair" to text("入渠修复", "入渠修復", "入渠修理"),
        "anchorage" to text("泊地修理", "泊地修理", "泊地修理"),
        "construction" to text("工厂建造", "工廠建造", "工廠建造"),
        "morale" to text("士气与刷闪", "士氣與刷閃", "士気・キラ付け"),
        "newShip" to text("新舰提醒", "新艦提醒", "未所持艦の通知"),
    )
    val ongoingChannelName get() = text("母港实时进行中概览", "母港即時進行中概覽", "母港の進行状況")
    val completed get() = text("已完成", "已完成", "完了")
    val fallbackTitle get() = text("矢矧通知", "矢矧通知", "矢矧の通知")
    val retentionTitle get() = text("矢矧正在后台运行", "矢矧正在背景執行", "矢矧はバックグラウンドで動作中")
    val retentionBody get() = text("游戏会话保持中 · 点击返回游戏", "遊戲工作階段保持中 · 點擊返回遊戲", "ゲームセッションを維持中 · タップしてゲームに戻る")
    fun channelVariant(name: String, sound: Boolean, vibration: Boolean): String =
        "$name · ${if (sound) text("有声", "有聲", "音あり") else text("静音", "靜音", "消音")} · " +
            if (vibration) text("振动", "震動", "振動あり") else text("无振动", "無震動", "振動なし")

    fun ongoingTitle(count: Int) = text(
        "矢矧 · 母港实时进行中 ($count 项)",
        "矢矧 · 母港即時進行中（$count 項）",
        "矢矧 · 母港の進行状況（${count}件）",
    )
    fun overflow(count: Int) = text(
        "另有 $count 项进行中或已完成任务",
        "另有 $count 項進行中或已完成任務",
        "ほかに進行中・完了済みのタスクが${count}件",
    )
}
