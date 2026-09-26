import 'package:flutter/widgets.dart';

/// Reviewed labels for account-scoped logbook and composition backups.
class RecordBackupStrings {
  const RecordBackupStrings(this.locale);
  factory RecordBackupStrings.of(BuildContext context) => RecordBackupStrings(
    Localizations.maybeLocaleOf(context) ?? const Locale('zh'),
  );
  final Locale locale;

  String _text(String zh, String hant, String ja) => locale.languageCode == 'ja'
      ? ja
      : locale.scriptCode == 'Hant' ||
            const ['TW', 'HK', 'MO'].contains(locale.countryCode)
      ? hant
      : zh;

  String get section => _text('记录备份与恢复', '記錄備份與復原', '記録のバックアップと復元');
  String get enabled => _text('启用记录备份与恢复', '啟用記錄備份與復原', '記録のバックアップと復元を有効にする');
  String get folder => _text('选择或更换备份文件夹', '選擇或更換備份資料夾', 'バックアップ先を選択・変更');
  String get folderHint => _text(
    '保存在本机文档文件夹；自动同步在后台进行',
    '保存在本機文件資料夾；自動同步在背景進行',
    'ドキュメントフォルダーに保存します。自動同期はバックグラウンドで行われます',
  );
  String get folderSelected => _text('已选择备份文件夹', '已選擇備份資料夾', 'バックアップ先を選択しました');
  String get sync => _text('立即同步', '立即同步', '今すぐ同期');
  String get syncDone => _text('同步完成', '同步完成', '同期が完了しました');
  String get syncPending => _text('等待同步', '等待同步', '同期待ち');
  String get neverSynced => _text('尚未同步', '尚未同步', '未同期');
  String syncFailed(Object error) =>
      _text('同步失败：$error', '同步失敗：$error', '同期失敗：$error');
  String lastSync(DateTime time) {
    final stamp = time.toString().split('.').first;
    return _text('上次同步：$stamp', '上次同步：$stamp', '最終同期：$stamp');
  }

  String get export => _text('导出备份文件', '匯出備份檔案', 'バックアップを書き出す');
  String get exportHint => _text('导出前会先同步并校验', '匯出前會先同步並驗證', '書き出し前に同期・検証します');
  String get saveToDevice => _text('保存到本机', '儲存到本機', '端末に保存');
  String get shareWithApps => _text('分享给其他应用', '分享給其他應用程式', '他のアプリと共有');
  String get savedToDevice => _text('备份文件已保存', '備份檔案已儲存', 'バックアップファイルを保存しました');
  String get accountChanged =>
      _text('游戏账号已切换，请重新操作', '遊戲帳號已切換，請重新操作', 'ゲームアカウントが切り替わりました。もう一度お試しください');
  String get import => _text('从备份文件恢复', '從備份檔案復原', 'バックアップから復元');
  String get importHint =>
      _text('导入备份文件恢复游戏记录', '匯入備份檔案復原遊戲記錄', 'バックアップファイルを読み込んでゲーム記録を復元します');
  String get restoreTitle =>
      _text('覆盖当前账号记录？', '覆蓋目前帳號記錄？', '現在のアカウントの記録を上書きしますか？');
  String restoreDescription(int logs, int compositions) => _text(
    '将用备份中的 $logs 条航海日志和 $compositions 条编成记录覆盖当前账号主数据。',
    '將以備份中的 $logs 筆航海日誌及 $compositions 筆編成記錄覆蓋目前帳號主資料。',
    '航海日誌 $logs 件と編成記録 $compositions 件で現在のデータを上書きします。',
  );
  String get cancel => _text('取消', '取消', 'キャンセル');
  String get restoreConfirm => _text('覆盖并恢复', '覆蓋並復原', '上書きして復元');
  String get restoreDone => _text('恢复完成', '復原完成', '復元が完了しました');
  String get recoveryPending => _text(
    '上次数据恢复尚未完成，请先完成恢复再进入游戏。',
    '上次資料復原尚未完成，請先完成復原再進入遊戲。',
    '前回のデータ復元が完了していません。復元を完了してからゲームを開始してください。',
  );
  String get recoveryCorruptAdvice => _text(
    '内部恢复文件可能损坏。重新授权文件夹无法修复此问题。请保留应用数据并联系支持；若已确认文档文件夹中有可用备份，可重装后导入。',
    '內部復原檔案可能損壞。重新授權資料夾無法修復此問題。請保留應用程式資料並聯絡支援；若已確認文件資料夾中有可用備份，可重新安裝後匯入。',
    '内部の復元ファイルが破損している可能性があります。フォルダーを再選択しても修復できません。アプリのデータを保持し、サポートにお問い合わせください。ドキュメントフォルダーに使用可能なバックアップがあることを確認できた場合は、再インストール後に読み込めます。',
  );
  String get recoveryRetryAdvice => _text(
    '若反复失败，请保留应用数据和文档备份文件，重新授权备份文件夹后再试。',
    '若反覆失敗，請保留應用程式資料及文件備份檔案，重新授權備份資料夾後再試。',
    '繰り返し失敗する場合は、アプリのデータとバックアップファイルを保持し、バックアップ先を再選択してお試しください。',
  );
  String get retryRestore => _text('重试恢复', '重試復原', '復元を再試行');
  String get reselectFolder =>
      _text('重新选择文档备份文件夹', '重新選擇文件備份資料夾', 'ドキュメントのバックアップ先を再選択');
  String get restoring =>
      _text('正在安全恢复记录，请稍候…', '正在安全復原記錄，請稍候…', '記録を安全に復元しています。しばらくお待ちください…');
  String get loginRequired =>
      _text('请先登录游戏并确认账号', '請先登入遊戲並確認帳號', 'ゲームにログインしてアカウントを確認してください');
  String get clearLogbook => _text('清理航海日志主数据', '清理航海日誌主資料', '航海日誌の本体データを削除');
  String get clearLogbookHint => _text(
    '只清理当前账号的本机主数据，保留备份文件',
    '只清理目前帳號的本機主資料，保留備份檔案',
    '現在のアカウントの端末データのみ削除し、バックアップは残します',
  );
  String get clearComposition => _text('清理编成记录', '清理編成記錄', '編成記録を削除');
  String get clearCompositionHint => _text(
    '清理当前账号的所有编成记录，保留备份文件',
    '清理目前帳號的所有編成記錄，保留備份檔案',
    '現在のアカウントの編成記録を削除し、バックアップは残します',
  );
  String get clearLogbookTitle =>
      _text('清理航海日志主数据？', '清理航海日誌主資料？', '航海日誌の本体データを削除しますか？');
  String get clearCompositionTitle =>
      _text('清理编成记录？', '清理編成記錄？', '編成記録を削除しますか？');
  String clearLogbookDescription(int count, bool backedUp) => backedUp
      ? _text(
          '将清理当前账号的 $count 条本机航海日志，备份文件不受影响。清理前会先同步。',
          '將清理目前帳號的 $count 筆本機航海日誌，備份檔案不受影響。清理前會先同步。',
          '現在のアカウントの航海日誌 $count 件を削除します。バックアップは残り、削除前に同期します。',
        )
      : _text(
          '将清理当前账号的 $count 条本机航海日志。备份未启用或未设置文件夹，清理前不会同步，请确认已有可恢复的备份。',
          '將清理目前帳號的 $count 筆本機航海日誌。備份未啟用或未設定資料夾，清理前不會同步，請確認已有可復原的備份。',
          '現在のアカウントの航海日誌 $count 件を削除します。バックアップが無効または未設定のため、削除前に同期しません。復元可能なバックアップをご確認ください。',
        );
  String clearCompositionDescription(int count, bool backedUp) => backedUp
      ? _text(
          '将清理当前账号的 $count 条本机编成记录，备份文件不受影响。清理前会先同步。',
          '將清理目前帳號的 $count 筆本機編成記錄，備份檔案不受影響。清理前會先同步。',
          '現在のアカウントの編成記録 $count 件を削除します。バックアップは残り、削除前に同期します。',
        )
      : _text(
          '将清理当前账号的 $count 条本机编成记录。备份未启用或未设置文件夹，清理前不会同步，请确认已有可恢复的备份。',
          '將清理目前帳號的 $count 筆本機編成記錄。備份未啟用或未設定資料夾，清理前不會同步，請確認已有可復原的備份。',
          '現在のアカウントの編成記録 $count 件を削除します。バックアップが無効または未設定のため、削除前に同期しません。復元可能なバックアップをご確認ください。',
        );
  String clearFailed(Object error) =>
      _text('清理失败：$error', '清理失敗：$error', '削除失敗：$error');
  String compositionCleared(int count) =>
      _text('已清理 $count 条编成记录', '已清理 $count 筆編成記錄', '編成記録 $count 件を削除しました');
}
