// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get diagnosticLoggingSection => 'クライアント診断ログ';

  @override
  String get diagnosticLoggingTitle => 'クライアント診断ログを記録';

  @override
  String get diagnosticLoggingDesc =>
      '性能とエラーの概要のみを記録し、アカウント、パスワード、ログイン情報は含みません';

  @override
  String get diagnosticPrivacyTitle => 'プライバシー保護診断';

  @override
  String get diagnosticPrivacyDesc =>
      'エクスポート前に内容を再検査します。アカウント、パスワード、Cookie、トークン、通信本文、チャット、スクリーンショットは記録せず、自動送信もしません。';

  @override
  String get diagnosticStatusEnabled => '記録中';

  @override
  String get diagnosticStatusDisabled => '記録停止中';

  @override
  String diagnosticStorageUsage(String size) {
    return 'ローカルログ使用量：$size';
  }

  @override
  String get exportDiagnosticFile => '診断ファイルを書き出す';

  @override
  String get saveDiagnosticFile => '端末に保存';

  @override
  String get shareDiagnosticFile => '診断ファイルを共有';

  @override
  String get diagnosticSaveConfirmTitle => '診断ファイルを保存しますか？';

  @override
  String get diagnosticSaveConfirmDesc =>
      'プライバシーチェック済みの JSON ファイルを作成します。保存先フォルダーのみを選択してください。ファイル名は自動生成され、変更できません。';

  @override
  String get diagnosticSaveAction => 'フォルダーを選択';

  @override
  String diagnosticSaveSucceeded(String fileName) {
    return '保存しました：$fileName';
  }

  @override
  String get diagnosticSaveFailed => '診断ファイルの保存に失敗しました';

  @override
  String get diagnosticShareConfirmTitle => '診断ファイルを共有しますか？';

  @override
  String get diagnosticShareConfirmDesc =>
      'プライバシーチェック済みの JSON ファイルを作成し、システムの共有画面を開きます。送信先をご確認ください。';

  @override
  String get diagnosticShareAction => '共有';

  @override
  String get diagnosticShareFailed => '診断ファイルの共有に失敗しました';

  @override
  String get clearDiagnosticData => '診断ログを削除';

  @override
  String get diagnosticExportConfirmTitle => '診断ファイルを書き出しますか？';

  @override
  String get diagnosticExportConfirmDesc =>
      '1つの JSON ファイルを作成し、システムの共有画面を開きます。ファイルにはクライアント性能、エラー概要、匿名の端末実行情報のみが含まれます。送信先をご確認ください。';

  @override
  String get diagnosticExportAction => '書き出す';

  @override
  String get diagnosticClearConfirmTitle => '診断ログを削除しますか？';

  @override
  String get diagnosticClearConfirmDesc => '端末上の診断ログを完全に削除します。';

  @override
  String get diagnosticExportFailed => '診断ファイルの書き出しに失敗しました';

  @override
  String get appTitle => 'ヤハギ';

  @override
  String get game => 'ゲーム';

  @override
  String get fleet => '艦隊';

  @override
  String get expedition => '遠征';

  @override
  String get repair => '入渠';

  @override
  String get construction => '建造';

  @override
  String get quests => '任務';

  @override
  String get battleRecords => '航海日誌';

  @override
  String get settings => '設定';

  @override
  String get settingsTitle => '設定';

  @override
  String get layoutSettings => 'UIとレイアウト';

  @override
  String get gameAreaRatio => 'ゲーム画面の比率';

  @override
  String get infoPanelWidth => '情報パネルの幅';

  @override
  String get autoZoom => '推奨表示比率を適用（ゲームとメニューの比率 65:35）';

  @override
  String get enhancedDamagePulse => '損傷パルス表示を強化';

  @override
  String get enhancedDamagePulseDesc =>
      '小破・中破・大破に応じて色、速度、艦娘画像内の光を強調します。オフにすると通常表示になります。';

  @override
  String get workspaceMenuOnRight => 'メニューバーを右側に表示';

  @override
  String get workspaceMenuOnRightDesc => 'オフの場合はメニューバーを左側に表示します。';

  @override
  String get language => '言語 (Language)';

  @override
  String get networkSettings => 'ネットワーク設定';

  @override
  String get networkStatus => 'ネットワーク状態';

  @override
  String get proxyNotSupported =>
      'この端末の Android System WebView はアプリ内プロキシをサポートしていません。\nシステムネットワークまたはVPNを使用してください。';

  @override
  String get systemNetwork => 'システムネットワーク / VPN';

  @override
  String get systemNetworkDesc => 'アプリ内プロキシを使用せず、システムのネットワークに従います。';

  @override
  String get httpProxy => 'HTTP プロキシ';

  @override
  String get httpProxyDesc => 'カスタム HTTP プロキシに接続します。';

  @override
  String get socks5Proxy => 'SOCKS5 プロキシ';

  @override
  String get socks5ProxyDesc => 'カスタム SOCKS5 プロキシに接続します。';

  @override
  String get hostAddress => 'ホストアドレス (IP またはドメイン)';

  @override
  String get hostHint => '例: 192.168.1.10';

  @override
  String get port => 'ポート';

  @override
  String get currentSavedMode => '現在の保存モード';

  @override
  String get vpnStatus => 'VPN 状態';

  @override
  String get vpnActive => 'VPNが検出されました';

  @override
  String get vpnInactive => 'VPNは検出されていません';

  @override
  String get testConnection => '接続テスト';

  @override
  String get applySettings => '適用して再読み込み';

  @override
  String get restoreSystemNetwork => 'システムネットワークに戻す';

  @override
  String get gameSafety => '大破警告';

  @override
  String get blockSortieTitle => '大破進撃ストッパー';

  @override
  String get blockSortieDesc =>
      '艦隊に大破した艦娘（旗艦以外・ダメコン未装備）がいる場合、出撃・進撃をブロックして警告を表示します。オンにすることを強く推奨します。';

  @override
  String get storageAndCache => 'ストレージとキャッシュ';

  @override
  String get logoutAndClear => 'ログアウト / アカウント情報の消去';

  @override
  String get logoutAndClearDesc => 'ゲームのログイン状態をクリアします。次回起動時に再ログインが必要です。';

  @override
  String get clearQuestCache => '任務データのキャッシュを消去';

  @override
  String get clearQuestCacheDesc =>
      'ローカルにキャッシュされた任務データを消去します。アプリ再起動後にゲーム内の任務画面で再取得する必要があります。';

  @override
  String get clearWebCache => 'ブラウザのWebキャッシュを消去';

  @override
  String get clearWebCacheDesc => 'WebView エンジンが保持する一時的なページやスクリプトデータを消去します。';

  @override
  String get baseSenkaResetTitle => '素戦果をリセット';

  @override
  String get baseSenkaResetDesc =>
      '今月の累計素戦果を 0.00 にします。EO・任務・その他の戦果データには影響しません。';

  @override
  String get baseSenkaResetConfirmTitle => '素戦果をリセット';

  @override
  String get baseSenkaResetConfirmDesc =>
      '今月の累計素戦果をリセットしますか？日別の EO・任務報酬は保持され、以後の経験値増分は 0.00 から加算されます。';

  @override
  String get baseSenkaResetSuccess => '今月の累計素戦果をリセットしました';

  @override
  String get baseSenkaManualTitle => '素戦果を手動入力';

  @override
  String baseSenkaCurrentValue(String value) {
    return '今月の累計：$value 戦果';
  }

  @override
  String get baseSenkaManualDialogTitle => '今月の累計素戦果を入力';

  @override
  String get baseSenkaManualInputLabel => '今月の累計素戦果';

  @override
  String get baseSenkaManualInvalid => '0 以上の数値を小数点以下 2 桁まで入力してください';

  @override
  String baseSenkaSetSuccess(String value) {
    return '今月の累計素戦果を $value に設定しました';
  }

  @override
  String get baseSenkaSaveFailed => '素戦果を保存できませんでした。もう一度お試しください';

  @override
  String get fleetBrief => '編成情報';

  @override
  String get expeditionBrief => '遠征情報';

  @override
  String get repairBrief => '修理概要';

  @override
  String get repairDockMode => '入渠';

  @override
  String get anchorageRepairMode => '泊地';

  @override
  String get idle => '空き';

  @override
  String get inactive => '待機';

  @override
  String get repairing => '修理中';

  @override
  String get outOfRepairRange => '修理範囲外';

  @override
  String get unableToRepair => '修理不可';

  @override
  String get constructionBrief => '建造情報';

  @override
  String get questBrief => '任務情報';

  @override
  String get preSortieCheck => '出撃前検査';

  @override
  String get sortieCheckShipsMode => '艦娘';

  @override
  String get sortieCheckMapsMode => '海域';

  @override
  String get mapHpGauges => '海域ゲージ';

  @override
  String get noMapGaugeData => '海域ゲージデータがありません';

  @override
  String get noMapGaugeDataHint => 'ゲーム内で出撃海域を開いて同期してください';

  @override
  String get showClearedMaps => '攻略済みを表示';

  @override
  String get allMapsCleared => 'すべての海域を攻略済みです';

  @override
  String get forecast => '戦闘予測';

  @override
  String get waitingForSortieData => '出撃待機中';

  @override
  String get standby => '待機';

  @override
  String get compact => '簡潔';

  @override
  String get detailed => '詳細';

  @override
  String get questDesc => '任務詳細';

  @override
  String get baseReward => '基本報酬';

  @override
  String get accepted => '受注済';

  @override
  String get completed => '完了';

  @override
  String get updatedAt => '更新';

  @override
  String get questDaily => 'デイリー';

  @override
  String get questWeekly => 'ウィークリー';

  @override
  String get questMonthly => 'マンスリー';

  @override
  String get questOneTime => '単発';

  @override
  String get questOther => '他';

  @override
  String get questUnknown => '不明';

  @override
  String get inProgress => '進行中';

  @override
  String get clearWebCacheConfirmTitle => 'ブラウザのWebキャッシュを消去';

  @override
  String get clearWebCacheConfirmDesc =>
      'ブラウザのWebキャッシュを消去しますか？WebView が保持する一時データを削除します。ダウンロード済みのローカルリソースには影響しません。';

  @override
  String get confirmClear => '消去する';

  @override
  String get captureMode => 'データキャプチャモード';

  @override
  String get gameAndSound => 'ゲームとサウンド';

  @override
  String get gameSound => 'ゲームのサウンド';

  @override
  String get aboutApp => 'ヤハギ について';

  @override
  String get aboutSubtitle => 'バージョン 學習版 1.0.2 · 免責事項 · 更新の確認';

  @override
  String get version => 'バージョン 學習版 1.0.2';

  @override
  String get disclaimerTitle => '免責事項 (DISCLAIMER)';

  @override
  String get disclaimerP1 =>
      '本プロジェクトは、プログラミング技術の交流と学習を目的として開発された、完全非営利かつ非公式のサードパーティ製汎用ブラウザツールです。「艦隊これくしょん -艦これ-」の公式や関連権利者とは一切関係ありません。';

  @override
  String get disclaimerP2 =>
      '本ソフトウェアは、ゲームサーバーとの通信を妨害、再送、改ざんせず、プレイヤーに代わってゲーム操作を実行しません。原作者はソフトウェアの品質（バグの有無、適用性、安定性を含む）について、明示的にも暗示的にもいかなる保証も行いません。';

  @override
  String get disclaimerP3 =>
      '本ソフトウェアの使用、または使用できないことによって生じた端末の破損、データ喪失、アカウント停止のリスク、その他の直接的または間接的な利益の損失について、原作者はいかなる法的・連帯責任も負いません。「技術学習」以外の目的で使用した場合に生じる著作権の争いや利用規約違反などのリスクは、すべて利用者の自己責任となります。';

  @override
  String get viewOnGitHub => 'GitHubを見る';

  @override
  String get checkForUpdates => '更新を確認';

  @override
  String get openSourceLicense => 'ライセンス: MIT License';

  @override
  String get newVersionFound => '🚀 新しいバージョンが見つかりました！';

  @override
  String get currentVersionLabel => '現在のバージョン';

  @override
  String get latestVersionLabel => '最新バージョン';

  @override
  String get updateContent => '更新内容:';

  @override
  String get later => '後で';

  @override
  String get goDownload => 'ダウンロードへ';

  @override
  String get alreadyLatest => '最新版です';

  @override
  String get alreadyLatestDesc => '現在のバージョンは最新です。';

  @override
  String get noRelease => 'リリースなし';

  @override
  String get noReleaseDesc => 'GitHub リポジトリにはまだリリースがありません。';

  @override
  String get checkFailed => '確認に失敗しました';

  @override
  String get networkError => 'ネットワークエラー';

  @override
  String get networkErrorDesc => '更新の確認中にエラーが発生しました。後でもう一度お試しください。';

  @override
  String get externalLinkOpenFailed => 'リンクを開けません。ブラウザがインストールされているか確認してください。';

  @override
  String get noUpdateLog => '更新ログなし';

  @override
  String get battleWarningOff => 'オフ';

  @override
  String get battleWarningConfirm => '確認ダイアログ';

  @override
  String get logoutSnackbar => 'ログアウトしてアカウント情報を消去しました。';

  @override
  String get logoutConfirmTitle => 'ログアウトしてアカウント情報を消去';

  @override
  String get logoutConfirmDesc =>
      'アプリ内ゲームページの Cookie、ローカルストレージ、キャッシュを消去してログイン画面へ戻ります。続行しますか？';

  @override
  String get logoutSucceeded => 'ログアウトしました。再度ログインしてください。';

  @override
  String get logoutFailed => 'ログアウトに失敗しました。しばらくしてからもう一度お試しください。';

  @override
  String get questCacheCleared => '任務データのローカルキャッシュを消去しました';

  @override
  String get webCacheCleared => 'ブラウザのWebキャッシュを消去しました';

  @override
  String get clearLogbook => '航海日誌データの消去';

  @override
  String get clearLogbookDesc =>
      'ローカルに保存された出撃、遠征、建造、開発、除籍、資源記録を消去します。この操作は元に戻せません。';

  @override
  String get clearLogbookConfirmTitle => '航海日誌データの消去';

  @override
  String get clearLogbookConfirmDesc =>
      '航海日誌のデータをすべて消去しますか？出撃、遠征、建造、開発、除籍、資源記録が削除されます。この操作は元に戻せません。';

  @override
  String get logbookCleared => '航海日誌データをすべて消去しました';

  @override
  String get antiCatbomb => '通信エラー保護 (防猫)';

  @override
  String get antiCatbombDesc =>
      '有効にすると、通信エラーでゲームのAPIが失敗した場合、エラー画面 (猫) を出さずに自動で再試行します。';

  @override
  String get close => '閉じる';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String get waitingForData => 'データ待機中';

  @override
  String get fleetNoShips => '現在の艦隊に艦娘がいません';

  @override
  String get unorganized => '未編成';

  @override
  String get speed => '速力';

  @override
  String get totalLevel => '合計Lv';

  @override
  String get firepower => '火力';

  @override
  String get torpedo => '雷装';

  @override
  String get antiAir => '対空';

  @override
  String get antiSub => '対潜';

  @override
  String get airPower => '制空';

  @override
  String get los => '索敵';

  @override
  String get avgCondition => '最低疲労';

  @override
  String get losDetail => '索敵詳細';

  @override
  String get totalLos => '索敵合計';

  @override
  String get specialAttack => '特殊攻撃';

  @override
  String get unknownShip => '未知の艦娘';

  @override
  String get unknownClass => '未知の艦種';

  @override
  String get needsResupply => '補給が必要';

  @override
  String get fuel => '燃料';

  @override
  String get ammo => '弾薬';

  @override
  String get hp => '耐久';

  @override
  String get waitingForEquip => '装備データ待機中';

  @override
  String get fastSpeed => '高速';

  @override
  String get slowSpeed => '低速';

  @override
  String get gotIt => 'OK';

  @override
  String get unknownEquip => '未知の装備';

  @override
  String get noBonusStats => 'ボーナスステータスなし';

  @override
  String get condition => '疲労';

  @override
  String get noExpeditionFleet => '遠征中の艦隊はありません';

  @override
  String get expeditionInProgress => '遠征中';

  @override
  String get progress => '進行度';

  @override
  String get unlocked => '未開放';

  @override
  String get notRepairing => '入渠していません';

  @override
  String get repairProgress => '修理進行度';

  @override
  String get cost => '消費';

  @override
  String get notConstructing => '建造していません';

  @override
  String get lsc => '大型艦建造';

  @override
  String get normalConstruct => '通常建造';

  @override
  String get constructing => '建造中';

  @override
  String get constructProgress => '建造進行度';

  @override
  String get constructComplete => '建造完了';

  @override
  String get allRatings => 'すべての評価';

  @override
  String get noBattleRecords => '戦闘記録がありません';

  @override
  String get autoRecordHint => '出撃後自動で記録されます';

  @override
  String get enemyFleet => '敵艦隊';

  @override
  String get thisSortie => '今回の出撃';

  @override
  String get historicalRecords => '歴史戦果';

  @override
  String get resourceTrend => '資源推移';

  @override
  String get expeditionIncome => '遠征収益';

  @override
  String get noHistoricalRecords => '歴史戦果がありません';

  @override
  String get none => 'なし';

  @override
  String get unknownNode => '未知のマス';

  @override
  String get noResourceRecords => '資源記録がありません';

  @override
  String get resourceTrend24h => '24時間';

  @override
  String get resourceTrend7d => '7日';

  @override
  String get resourceTrend30d => '30日';

  @override
  String get resourceTrendAll => 'すべての記録';

  @override
  String get resourceTrendMainGroup => '主要資源';

  @override
  String get resourceTrendAuxGroup => '補助資源';

  @override
  String get gadgetBypass => 'ゲームクライアント資源迂回（実験的）';

  @override
  String get gadgetBypassDesc =>
      '静的クライアント資源サーバーが制限された場合のみミラーを使用します。DMMログイン、Cookie、ゲームデータAPIは変更せず、無効時は完全に迂回します。';

  @override
  String get gadgetBypassEnable => '迂回を有効にする';

  @override
  String get gadgetBypassEndpoint => 'ミラーエンドポイント';

  @override
  String get endpointCustom => 'カスタム';

  @override
  String get gadgetBypassStatusOn => '有効';

  @override
  String get gadgetBypassStatusOff => '無効';

  @override
  String get gadgetBypassUnsupported => 'この端末では非対応（Android 8.0+ が必要）';

  @override
  String get gadgetBypassClearCache => 'キャッシュをクリア';

  @override
  String get gadgetBypassError => '迂回設定に失敗しました';

  @override
  String get gadgetBypassDiagnose => '403 とミラー接続を確認';

  @override
  String get gadgetBypassDiagnosing => '診断中...';

  @override
  String get gadgetBypassW00g => 'クライアントサーバー (w00g)';

  @override
  String get gadgetBypassEndpointProbe => 'ミラーエンドポイント';

  @override
  String get gadgetBypassKcsapi => 'ゲームデータAPI (kcsapi)';

  @override
  String get gadgetBypassReachable => '接続OK';

  @override
  String get gadgetBypassUnreachable => '接続不可';

  @override
  String get resourceTrendChart => '資源推移 (直近 100 件)';

  @override
  String get steel => '鋼材';

  @override
  String get bauxite => 'ボーキ';

  @override
  String get noExpeditionRecords => '遠征記録がありません';

  @override
  String get expeditionIncomeChart => '遠征収益統計 (直近 7 日間)';

  @override
  String get langZh => '简体中文';

  @override
  String get langZhHant => '繁體中文';

  @override
  String get langJa => '日本語';

  @override
  String get node => 'マス';

  @override
  String get friend => '自軍';

  @override
  String get enemy => '敵軍';

  @override
  String get drop => 'ドロップ';

  @override
  String get inExpedition => '遠征中';

  @override
  String get unknownProgress => '進行度不明';

  @override
  String get waitingForPortData => '母港データ待機中';

  @override
  String get waitingForPortDataDescription => '母港に移動するかリロードすると更新されます';

  @override
  String get fleetNotFormed => '未編成';

  @override
  String get fleetStandby => '母港待機';

  @override
  String get shipsCount => '隻';

  @override
  String get noValue => 'なし';

  @override
  String get lineOfSight => '索敵';

  @override
  String get averageCondition => '最低疲労';

  @override
  String get moraleRecoveryCountdown => '回復カウントダウン';

  @override
  String get moraleRecovered => '回復済み';

  @override
  String get toggleMoraleMetric => '最低疲労と回復カウントダウンを切り替える';

  @override
  String get losDetails => '索敵詳細';

  @override
  String get airPowerDetails => '制空詳細';

  @override
  String get minimumValue => '最小';

  @override
  String get maximumValue => '最大';

  @override
  String get withoutBonus => '熟練度補正なし';

  @override
  String get showAirPowerDetails => '制空詳細を表示';

  @override
  String get unknownShipType => '未知の艦種';

  @override
  String get needsSupply => '補給が必要';

  @override
  String get equipmentDataWaiting => '装備データ待機中';

  @override
  String get highSpeed => '高速';

  @override
  String get lowSpeed => '低速';

  @override
  String get unknownEquipment => '未知の装備';

  @override
  String get noAdditionalStats => 'ボーナスステータスなし';

  @override
  String get fatigue => '疲労';

  @override
  String get startupUpdateTitle => '新しいバージョン';

  @override
  String get backgroundAudio => 'バックグラウンドで音声を再生';

  @override
  String get backgroundAudioDesc => 'オンにすると、アプリがバックグラウンドに移動してもゲーム音声を再生します。';

  @override
  String get screenAwake => '画面を常にオン';

  @override
  String get screenAwakeDesc => 'オンにすると、アプリの使用中は画面が自動消灯しません。電池消費が増える場合があります。';

  @override
  String get gameToolbar => 'ゲームツールバー';

  @override
  String get toolbarAutoHide => '自動的に隠す';

  @override
  String get toolbarPersistent => '常に表示';

  @override
  String get back => '戻る';

  @override
  String get reload => '再読み込み';

  @override
  String get home => 'ホームに戻る';

  @override
  String get enterDmm => 'DMM ログインへ';

  @override
  String get enableGameAudio => 'ゲーム音声をオン';

  @override
  String get disableGameAudio => 'ゲーム音声をオフ';

  @override
  String get takeScreenshot => 'スクリーンショット';

  @override
  String get screenshotSaving => 'ゲーム画面を保存しています…';

  @override
  String get fitGameScreen => '表示を画面に合わせる';

  @override
  String get collapseToolbar => 'ツールバーを閉じる';

  @override
  String get editDone => '編集を完了';

  @override
  String get retryWithSystemNetwork => 'システムネットワークで再試行';

  @override
  String get displayMode => '表示モード';

  @override
  String get displayAuto => '自動';

  @override
  String get displayLandscape => '横画面';

  @override
  String get displayPortrait => '縦画面';

  @override
  String get allRanks => 'すべての評価';

  @override
  String battleFleetSummary(
    int friendAlive,
    int friendTotal,
    int enemyAlive,
    int enemyTotal,
  ) {
    return '味方 $friendAlive/$friendTotal　敵 $enemyAlive/$enemyTotal';
  }

  @override
  String dropLabel(String name) {
    return 'ドロップ：$name';
  }

  @override
  String get item => 'アイテム';

  @override
  String get friendFinalStatus => '味方艦隊の最終状態';

  @override
  String get enemyFinalStatus => '敵艦隊の最終状態';

  @override
  String airStateLabel(String label) {
    return '制空：$label';
  }

  @override
  String get postBattleWarningTitle => '戦闘後の安全警告';

  @override
  String get postBattleWarningHeadline => '出撃艦隊に大破艦がいます！';

  @override
  String get postBattleWarningBody =>
      '次の選択画面では必ず「撤退」を選んでください。轟沈を防ぐため、進撃しないでください！';

  @override
  String get acknowledgeAndRetreat => '確認して撤退';

  @override
  String get postBattleWarningBanner => '戦闘後の安全警告：出撃艦隊に大破艦がいます。撤退してください！';

  @override
  String get noActiveExpedition => '遠征中の艦隊はありません';

  @override
  String get noSortieWarnings => '出撃警告はありません';

  @override
  String preSortieCriticalWarning(String fleetName) {
    return '$fleetName に大破艦がいます。出撃を中止してください！';
  }

  @override
  String preSortieSupplyWarning(String fleetName) {
    return '$fleetName に未補給の艦娘があります';
  }

  @override
  String preSortieFatigueWarning(String fleetName) {
    return '$fleetName に疲労が回復していない艦娘がいます';
  }

  @override
  String preSortieMainEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 装備不足（主スロット）：$shipNames';
  }

  @override
  String preSortieExtraEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 装備不足（補強増設スロット）：$shipNames';
  }

  @override
  String get noPinnedQuests => '現在進行中の任務はありません';

  @override
  String get questsNeedSync => '任務画面を開いて情報を同期してください';

  @override
  String get waitingQuestData => '任務データ待機中';

  @override
  String get waitingQuestDataDesc => 'ゲーム内の任務一覧を開くと、受注中の任務が自動的に同期されます';

  @override
  String get diagnosticsAndAbout => '診断とアプリ情報';

  @override
  String get safetyBoundary => '安全上の制限';

  @override
  String get applyingNetworkSettings => 'ネットワーク設定を適用しています…';

  @override
  String networkSettingsApplied(String message) {
    return 'ネットワーク設定を適用しました：$message';
  }

  @override
  String get clearingProxy => 'アプリ内プロキシを解除しています…';

  @override
  String get systemNetworkRestored => 'システムネットワークに戻しました。';

  @override
  String screenshotSaved(String path) {
    return 'ゲーム画面をギャラリーに保存しました：$path';
  }

  @override
  String get screenshotFailed => 'ゲーム画面の保存に失敗しました。しばらくしてからもう一度お試しください。';

  @override
  String startupUpdateMessage(String version) {
    return 'ヤハギ $version がリリースされました。';
  }

  @override
  String get gameStatusError => 'ゲーム状態エラー';

  @override
  String get gameStatusErrorDesc => 'Web ページまたは取得状態に異常があります。設定の診断情報を確認してください。';

  @override
  String get browserOnlyCaptureOff => '閲覧専用モード · データ取得オフ';

  @override
  String get browserOnlyCaptureOffDesc => 'ゲームは動作を続けますが、艦隊・任務・戦闘情報の更新は停止します。';

  @override
  String capturedCount(int count) {
    return '$count 件取得済み';
  }

  @override
  String get waitingKcsapi => '/kcsapi/ の応答を待機中';

  @override
  String get ignoredNonTargetMessage => '対象外メッセージを無視しました';

  @override
  String get readOnlyNoActions => '読み取り専用';

  @override
  String get readOnlyNoActionsDesc => 'クリック、補給、編成、出撃、任務受領を自動実行しません。';

  @override
  String get noCookieRead => 'Cookie を読み取りません';

  @override
  String get noCookieReadDesc => 'JS ブリッジのメッセージは API パス、応答本文、時刻のみを含みます。';

  @override
  String get browserIdle => 'Web ページ待機中';

  @override
  String get browserLoading => 'Web ページ読み込み中';

  @override
  String get browserReady => 'Web ページ準備完了';

  @override
  String get browserFailed => 'Web ページ読み込み失敗';

  @override
  String get capturePreparing => 'ゲーム API 取得を準備中';

  @override
  String get captureReady => '取得準備完了';

  @override
  String get captureActive => 'ゲーム API を取得中';

  @override
  String get captureUnsupported => '現在の WebView はフレーム間取得に対応していません';

  @override
  String get captureFailed => 'ゲーム API 取得の起動に失敗しました';

  @override
  String get captureCheckingDesc => 'Android WebView の取得能力を確認しています。';

  @override
  String get captureReadyDesc => '/kcsapi/ の応答待機中です。ゲームは通常どおり操作できます。';

  @override
  String get portCaptureVerified => '母港 API の確認に成功しました';

  @override
  String get captureReceived => 'ゲーム API を受信しました。';

  @override
  String captureLatest(String path) {
    return '最新の取得：$path';
  }

  @override
  String get captureUnsupportedDesc => 'ゲームは動作しますが、現在の端末では Web 閲覧のみ利用できます。';

  @override
  String get captureFailedDesc => 'ゲームは動作します。ページを再読み込みして再試行できます。';

  @override
  String networkApplyFailed(String code, String message) {
    return '設定に失敗しました [$code]：$message';
  }

  @override
  String networkRestoreFailed(String code, String message) {
    return '復元に失敗しました [$code]：$message';
  }

  @override
  String get tcpConnection => 'TCP 接続';

  @override
  String get gameService => 'ゲームサービス';

  @override
  String get externalNetwork => 'Google（外部ネットワーク）';

  @override
  String get statusUnknown => '不明';

  @override
  String get statusSuccess => '成功';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusSkipped => 'スキップ';

  @override
  String get formula33 => '33式';

  @override
  String fatigueValue(int value) {
    return '疲労 $value';
  }

  @override
  String get fcdMapSectionTitle => 'データ更新';

  @override
  String get fcdMapDataTitle => '予知マップデータ';

  @override
  String fcdMapDataVersion(String version) {
    return 'データバージョン：$version';
  }

  @override
  String fcdMapLastChecked(String time) {
    return '最終確認：$time';
  }

  @override
  String get fcdMapNeverChecked => '最終確認：未確認';

  @override
  String fcdMapSource(String source) {
    return '更新元：$source';
  }

  @override
  String get fcdMapAttribution => 'データ提供：poi FCD（MIT）';

  @override
  String get fcdMapCheckUpdates => '予知マップデータを更新';

  @override
  String get fcdMapUpToDate => '予知マップデータは最新です。';

  @override
  String fcdMapUpdated(String oldVersion, String newVersion) {
    return '予知マップデータを $oldVersion から $newVersion に更新し、すぐに適用しました。';
  }

  @override
  String get fcdMapNetworkError => 'データ更新元に接続できません。しばらくしてから再試行してください。';

  @override
  String get fcdMapValidationError => 'ダウンロードしたデータを検証できなかったため、現在のバージョンを保持しました。';

  @override
  String get fcdMapStorageError => 'データを保存できなかったため、現在のバージョンを保持しました。';

  @override
  String get questCatalogDataTitle => '任務データ';

  @override
  String questCatalogDataVersion(String version) {
    return 'データバージョン：$version';
  }

  @override
  String get questCatalogNeverChecked => '最終確認：未確認';

  @override
  String questCatalogLastChecked(String time) {
    return '最終確認：$time';
  }

  @override
  String get questCatalogCheckUpdates => '任務データの更新を確認';

  @override
  String get questCatalogUpToDate => '任務データは最新です。';

  @override
  String questCatalogUpdated(String oldVersion, String newVersion) {
    return '任務データを $oldVersion から $newVersion に更新し、すぐに適用しました。';
  }

  @override
  String get questCatalogNetworkError => '任務データの更新元に接続できません。後でもう一度お試しください。';

  @override
  String get questCatalogValidationError =>
      'ダウンロードした任務データを検証できませんでした。現在のバージョンを保持します。';

  @override
  String get questCatalogStorageError => '任務データを保存できませんでした。現在のバージョンを保持します。';

  @override
  String get gameFrameRateTitle => 'ゲームフレームレート';

  @override
  String get gameFrameRateAutomatic => '自動';

  @override
  String get gameFrameRatePowerSaving => '省電';

  @override
  String get gameFrameRateHighRefresh => '高リフレッシュレート';

  @override
  String get gameFrameRateAutomaticDesc =>
      '上限を 60 FPS とし、動作が不安定な場合や省電力モード、端末の発熱時には自動的に 30 FPS へ下げます。';

  @override
  String get gameFrameRatePowerSavingDesc => '30 FPS に固定し、発熱と消費電力の低減を優先します。';

  @override
  String get gameFrameRateHighRefreshDesc =>
      '端末のリフレッシュレートに追従し、90/120 FPS に達する場合があります。発熱と消費電力が大きく増加します。';

  @override
  String get gameFrameRateUnsupported =>
      '現在の Android WebView はフレームレート調整に対応していないため、ゲーム本来の動作を維持します。';

  @override
  String get gameRenderingModeTitle => 'ゲーム描画モード';

  @override
  String get gameRenderingModeStandard => '軽量モード';

  @override
  String get gameRenderingModeStandardDesc =>
      'Flutter PlatformView + Texture Layer + WebGL。一部の合成負荷を軽減しますが、一部の端末で表示やタッチの互換性問題が発生する場合があります。';

  @override
  String get gameRenderingModeCompatibility => '均衡モード';

  @override
  String get gameRenderingModeCompatibilityDesc =>
      'Flutter PlatformView + Hybrid Composition + WebGL。ゲーム性能と端末互換性を両立します。';

  @override
  String get gameRenderingModeCanvas => '互換モード';

  @override
  String get gameRenderingModeCanvasDesc =>
      'Flutter PlatformView + Hybrid Composition + Canvas。WebGL を回避し、GPU / WebGL の互換性問題を優先的に解決します。描画性能が低下する場合があります。';

  @override
  String get gameRenderingModeNativeActivity => 'ネイティブ直結（推奨）';

  @override
  String get gameRenderingModeNativeActivityDesc =>
      'Activity Direct WebView + WebGL。理論上、合成負荷が低く、ネイティブ互換性に優れています。';

  @override
  String get gameRenderingModeConfirmTitle => 'ゲーム描画モードを切り替えますか？';

  @override
  String get gameRenderingModeConfirmMessage =>
      '描画モードを切り替えるとアプリが自動的に再起動し、ゲームページが再読み込みされます。進行中の操作を終了してから切り替えてください。';

  @override
  String get gameRenderingModeBattleWarning =>
      '戦闘中の可能性があります。今切り替えると戦闘画面が中断されるため、戦闘終了後の変更を推奨します。';

  @override
  String get gameRenderingModeChanging => 'ゲームページを再構築しています…';

  @override
  String get gameRenderingModeApplied => '描画モードを切り替えました。';

  @override
  String get gameRenderingModeFailed => '切り替えに失敗しました。現在の設定を維持するか、安全なモードへ戻しました。';

  @override
  String get nativeGameSurfaceSwitchRenderingModeHint =>
      '現在の端末ではこのモードに対応していない可能性があります。【設定 - 画面と音声】から描画モードを変更してください';

  @override
  String get senka => '戦果';

  @override
  String get ownedInventory => '保有一覧';

  @override
  String get improvement => '改修';

  @override
  String get briefing => '概要';

  @override
  String get check => 'チェック';

  @override
  String get restoreDefaultOrder => '既定の並び順に戻す';

  @override
  String get sortAscending => '昇順';

  @override
  String get sortDescending => '降順';

  @override
  String sortPriority(int priority) {
    return '第$priority優先';
  }

  @override
  String get sortLockedState => 'ロック済み';

  @override
  String get sortTemporaryState => '一時ソート';

  @override
  String get sortHeaderHint => '選択で並び順を切替。長押しまたは Shift+Enter でロック';

  @override
  String get sortHeaderLockedHint => '選択で昇順・降順を切替。長押しまたは Shift+Enter でロック解除';

  @override
  String get sortLockAction => '次の優先順位としてロック';

  @override
  String get sortUnlockAction => '現在のソートロックを解除';

  @override
  String get settingsTabScreen => '画面と音声';

  @override
  String get settingsTabSound => 'サウンド';

  @override
  String get settingsTabBattle => '戦闘';

  @override
  String get settingsTabNotification => '通知';

  @override
  String get settingsTabNetwork => 'ネットワーク';

  @override
  String get settingsTabData => 'データ';

  @override
  String get settingsTabAboutSupport => '情報';

  @override
  String get notificationSectionSystem => 'システム通知の状態';

  @override
  String get notificationSectionSystemDesc =>
      '通知と正確なアラーム権限を許可することで、画面消灯時やバックグラウンドでも遠征・入渠通知を遅延なく確実に受信できます。未許可の項目をタップすると設定画面を開きます。';

  @override
  String get notificationPermissionGranted => '通知権限は許可されています';

  @override
  String get notificationPermissionDenied => '通知権限が許可されていません';

  @override
  String get notificationExactAlarmGranted => '正確なアラームは許可されています';

  @override
  String get notificationExactAlarmDenied => '正確なアラームは未許可です。省電力互換モードを使用します';

  @override
  String get notificationChannelsEnabled => '通知チャンネルは利用可能です';

  @override
  String get notificationChannelsDisabled => '通知チャンネルがシステムで無効です';

  @override
  String get notificationSectionGeneral => '全体通知サービス';

  @override
  String get notificationEnableMaster => '通知サービスを有効化';

  @override
  String get notificationSound => '通知音';

  @override
  String get notificationVibration => '振動通知';

  @override
  String get notificationSectionOngoing => 'バックグラウンド進行中常駐';

  @override
  String get notificationOngoingLive => '常駐リアルタイム進行状況カード';

  @override
  String get notificationProgress => '進捗バー';

  @override
  String get notificationPercent => '割合(%)';

  @override
  String get notificationCountdown => 'カウントダウン';

  @override
  String get notificationSectionTypes => '通知種別とタイミング';

  @override
  String get notificationExpedition => '遠征';

  @override
  String get notificationRepair => '入渠';

  @override
  String get notificationAnchorage => '泊地';

  @override
  String get notificationConstruction => '建造';

  @override
  String get notificationMorale => '疲労 / キラ付け';

  @override
  String get notificationPunctual => '定刻';

  @override
  String get notificationPreempt30s => '30秒前';

  @override
  String get notificationPreempt60s => '60秒前';

  @override
  String get notificationPreempt120s => '2分前';

  @override
  String get notificationRepairPunctual => '定刻';

  @override
  String get notificationAnchorage20m => '20分初回';

  @override
  String get notificationAnchorageFull => '全回復';

  @override
  String get notificationAnchorageBoth => '両方通知';

  @override
  String get frameRateSettingsSection => 'フレームレート設定';

  @override
  String get battleAlertsSection => '戦闘通知';

  @override
  String get battleDamageVibration => '戦闘損傷時の振動通知';

  @override
  String get battleDamageVibrationDesc => '味方艦娘が戦闘中に中破または大破になったとき振動で通知します。';

  @override
  String get battlePredictionSection => '戦闘予測';

  @override
  String get battlePredictionEngine => '戦闘予測エンジン';

  @override
  String get battlePredictionRecommendation => 'より詳細な予測結果を得るには高精度モードを推奨します。';

  @override
  String get battlePredictionHighAccuracy => '高精度モード';

  @override
  String get battlePredictionLightweight => '軽量モード';

  @override
  String get battlePredictionHighAccuracyDesc =>
      '戦闘シミュレーションの規則に沿って再現するため高精度ですが、処理負荷が高くなります。';

  @override
  String get battlePredictionLightweightDesc => '簡易予測ロジックを使用し、処理負荷を抑えます。';

  @override
  String get battlePredictionNextBattle => '変更は次の戦闘から反映されます。';

  @override
  String get battleEnemyPreviewPortraits => '戦闘前の敵艦画像';

  @override
  String get battleEnemyPreviewPortraitsDesc => '戦闘予測の詳細モードでのみ表示します。';

  @override
  String get improvementDatasetTitle => '改修計画データ';

  @override
  String improvementDatasetVersion(String version) {
    return 'データバージョン $version';
  }

  @override
  String get improvementDatasetNeverChecked => '手動確認はまだ行われていません';

  @override
  String improvementDatasetLastChecked(String time) {
    return '最終確認 $time';
  }

  @override
  String get improvementDatasetManualUpdate => '改修データを手動更新';

  @override
  String improvementDatasetUpToDate(String version) {
    return '最新のデータです（$version）';
  }

  @override
  String improvementDatasetUpdated(String oldVersion, String newVersion) {
    return '改修データを $oldVersion から $newVersion に更新し、画面へ反映しました。';
  }

  @override
  String improvementDatasetNetworkError(String version) {
    return 'ネットワーク接続に失敗したため、ローカルデータ（$version）を使用します。';
  }

  @override
  String improvementDatasetValidationError(String version) {
    return 'リモートデータの検証に失敗したため、ローカルデータ（$version）を維持しました。';
  }

  @override
  String improvementDatasetStorageError(String version) {
    return 'データの保存に失敗したため、ローカルデータ（$version）を維持しました。';
  }

  @override
  String get networkValidationHostEmpty => 'アドレスを入力してください';

  @override
  String get networkValidationControlCharacter => '改行や制御文字は使用できません';

  @override
  String get networkValidationHttpScheme => 'http:// は入力せず、サーバーアドレスのみ入力してください。';

  @override
  String get networkValidationSocksScheme =>
      'socks:// は入力せず、サーバーアドレスのみ入力してください。';

  @override
  String get networkValidationScheme => 'プロトコル名は入力できません';

  @override
  String get networkValidationPath => 'パスは入力できません';

  @override
  String get networkValidationCredentials => 'ユーザー名やパスワードは入力できません';

  @override
  String get networkValidationIpv6 => 'IPv6 アドレスの形式が正しくありません（使用できない文字が含まれています）';

  @override
  String get networkValidationPortEmpty => 'ポート番号を入力してください';

  @override
  String get networkValidationPortDecimal => 'ポート番号に小数は使用できません';

  @override
  String get networkValidationPortNegative => 'ポート番号に負数は使用できません';

  @override
  String get networkValidationPortZero => 'ポート番号に 0 は使用できません';

  @override
  String get networkValidationPortInteger => 'ポート番号は整数で入力してください';

  @override
  String get networkValidationPortRange => 'ポート番号は 1～65535 の範囲で入力してください';

  @override
  String get gadgetBypassRestricted => '制限あり';

  @override
  String get networkProxyOperationBusy => 'プロキシ設定を適用中です';

  @override
  String get networkUnknownProxyMode => '不明なプロキシモードです';

  @override
  String get shipGirl => '艦娘';

  @override
  String get equipment => '装備';

  @override
  String get inventoryTypeSuffix => ' 種類';

  @override
  String get inventoryFilterResults => '絞り込み結果 ';

  @override
  String get shipName => '艦名';

  @override
  String get shipType => '艦種';

  @override
  String get level => 'レベル';

  @override
  String get armor => '装甲';

  @override
  String get luck => '運';

  @override
  String get evasion => '回避';

  @override
  String get lockedStatus => 'ロック';

  @override
  String get equipmentName => '装備名';

  @override
  String get equipmentTotalRemaining => '合計（残り）';

  @override
  String get equipmentImprovementProficiency => '改修／熟練度';

  @override
  String get equipmentOfficialId => '公式ID';

  @override
  String get equipmentInstanceId => 'インスタンスID';

  @override
  String get equipmentUsage => '装備状況';

  @override
  String get highSpeedPlus => '高速+';

  @override
  String get all => 'すべて';

  @override
  String get equipmentMainGun => '主砲';

  @override
  String get equipmentSecondaryGun => '副砲／高角砲';

  @override
  String get equipmentMachineGun => '機銃';

  @override
  String get equipmentTorpedo => '魚雷／甲標的';

  @override
  String get equipmentCarrierAircraft => '艦載機';

  @override
  String get equipmentSeaplane => '水上機';

  @override
  String get equipmentLandBasedAircraft => '陸上機';

  @override
  String get equipmentRadar => '電探';

  @override
  String get equipmentLandingTransport => '上陸／輸送';

  @override
  String get equipmentSupport => '補助／その他';

  @override
  String get questAll => '全任務';

  @override
  String get chineseTranslation => '中国語訳';

  @override
  String get searchQuest => '任務を検索';

  @override
  String get filterQuest => '任務を絞り込む';

  @override
  String get searchQuestHint => '番号、任務名、説明を検索';

  @override
  String get clear => 'クリア';

  @override
  String get done => '完了';

  @override
  String get clearAll => 'すべてクリア';

  @override
  String get questType => '任務種別';

  @override
  String get allTypes => 'すべての種別';

  @override
  String get questFormation => '編成';

  @override
  String get questSortie => '出撃';

  @override
  String get questExercise => '演習';

  @override
  String get questSupplyRepair => '補給/入渠';

  @override
  String get questFactory => '工廠';

  @override
  String get questRemodeling => '改装';

  @override
  String get questPeriod => '任務周期';

  @override
  String get allPeriods => 'すべての周期';

  @override
  String get questSeasonal => '季節';

  @override
  String get questYearly => '年間';

  @override
  String get unlockStatus => '解放状態';

  @override
  String get allStatuses => 'すべての状態';

  @override
  String get questUnlocked => '解放済み';

  @override
  String get questLocked => '未解放';

  @override
  String get noDescription => '説明はありません';

  @override
  String get completionConditions => '達成条件';

  @override
  String get questRelations => '関連任務';

  @override
  String get prerequisiteQuests => '前提任務';

  @override
  String get followingQuests => '後続任務';

  @override
  String get notCompleted => '未達成';

  @override
  String get gameResourceCacheTitle => 'ゲームリソースのローカルキャッシュ';

  @override
  String get gameResourceCacheDesc =>
      '艦隊これくしょんの公式サーバーから取得します。モードを切り替えても既存キャッシュは残ります。';

  @override
  String get gameResourceCacheNone => 'ローカルキャッシュなし';

  @override
  String get gameResourceCacheNoneDesc => '事前ダウンロードを行いません。既存のキャッシュは保持します。';

  @override
  String get gameResourceCacheLight => '軽量キャッシュ';

  @override
  String get gameResourceCacheLightDesc => '起動ファイル、主要 UI、保有艦娘と装備のリソースを保存します。';

  @override
  String get gameResourceCacheFull => 'ローカルキャッシュ';

  @override
  String get gameResourceCacheFullDesc =>
      '固定の基本リソース一覧（約 5.49 GB）を事前取得します。新しい内容はプレイ中に自動保存されます。';

  @override
  String get gameResourceCacheStart => 'ダウンロード開始';

  @override
  String get gameResourceCachePause => '一時停止';

  @override
  String get gameResourceCacheResume => '再開';

  @override
  String get gameResourceCacheCheck => '整合性を確認';

  @override
  String get gameResourceCacheRepair => '不足・破損を修復';

  @override
  String get gameResourceCacheClear => 'ローカルキャッシュを削除';

  @override
  String get gameResourceCacheIntegrityComplete => '現在のキャッシュは完全です';

  @override
  String get gameResourceCacheMissing => '不足';

  @override
  String get gameResourceCacheDamaged => '破損';

  @override
  String get gameResourceCacheOutdated => '確認待ち';

  @override
  String get gameResourceCacheItems => '件';

  @override
  String gameResourceCacheStoredSize(String size) {
    return 'キャッシュ済み $size';
  }

  @override
  String gameResourceCacheIntegritySummary(
    int missing,
    int damaged,
    int pending,
  ) {
    return '不足 $missing 件・破損 $damaged 件・確認待ち $pending 件';
  }

  @override
  String get gameResourceCachePendingRetained =>
      '確認待ちのリソースは端末内に保持され、自動的には削除されません。';

  @override
  String get gameResourceCacheDownloadConfirmTitle => 'キャッシュをダウンロードしますか？';

  @override
  String get gameResourceCacheDownloadConfirmDesc =>
      '選択したモードのリソースを公式サーバーから一括取得します。いつでも一時停止・再開できます。';

  @override
  String get gameResourceCacheMobileConfirmDesc =>
      '現在モバイル回線を使用しています。通信量を消費して今回のダウンロードを続けますか？';

  @override
  String get gameResourceCacheWaitingForWifi => 'Wi-Fi を待機しています。接続後に自動で再開します。';

  @override
  String get gameResourceCacheClearConfirmTitle => 'ゲームリソースキャッシュを削除しますか？';

  @override
  String get gameResourceCacheClearConfirmDesc =>
      'ダウンロード済みリソースを削除します。モード設定は保持されます。';

  @override
  String get gameResourceCacheCapacityBlocked =>
      '空き容量が不足しているか、ゲームリソースキャッシュが 50 GB の上限に達しています。';

  @override
  String get gameResourceCacheActionFailed =>
      'キャッシュ操作を完了できませんでした。しばらくしてからお試しください。';

  @override
  String get confirmGameRefreshTitle => 'ゲームを更新しますか？';

  @override
  String get gameRefreshDialogDescription =>
      'ゲームを更新しますか？\n\n「ゲームページを更新」はブラウザーの更新と同じです。\n「ゲームを再読み込み」はゲームフレームだけを再読み込みするため通常は高速ですが、猫や通信エラーが発生する可能性があります。自己責任で使用してください。';

  @override
  String get refreshGamePage => 'ゲームページを更新';

  @override
  String get reloadGame => 'ゲームを再読み込み';

  @override
  String get gameFrameNotFound => 'ゲームフレームが見つかりません。ゲームに入ってから再試行してください。';

  @override
  String get gameHtmlWrapNotFound => 'ゲーム本体が見つかりません。読み込みを待ってから再試行してください。';

  @override
  String get gameFrameReloadBlocked =>
      'ゲームフレームを再読み込みできませんでした。しばらくしてから再試行してください。';

  @override
  String get gameFrameReloadUnsupported =>
      '現在の端末の Android WebView は古いため、子フレームへのスクリプト注入に対応していません。';

  @override
  String get logbookResourceDrop => '資源ドロップ';

  @override
  String get logbookItemDrop => 'アイテムドロップ';

  @override
  String get logbookResourceNode => '資源マス';

  @override
  String get gameConnectorTitle => 'ゲーム接続';

  @override
  String get gameConnectorYahagi => 'Yahagi 接続';

  @override
  String get gameConnectorYahagiDesc => '現在の DMM 公式ログイン入口を使用します。';

  @override
  String get gameConnectorOoi => 'OOI 接続（実験的）';

  @override
  String get gameConnectorOoiDesc =>
      'ooi.moe のログイン画面をそのまま開き、モード 1・3・4 を選択できます。';

  @override
  String get gameConnectorConfirmTitle => 'ゲーム接続を切り替えますか？';

  @override
  String get gameConnectorOoiRisk =>
      'アカウント情報は第三者サイト ooi.moe に送信されます。Yahagi はアカウント名やパスワードを読み取り、保存、自動入力しません。';

  @override
  String get gameConnectorActiveWarning =>
      '切り替えると現在のゲーム画面が中断され、対象のログイン入口へ戻ります。';

  @override
  String get gameConnectorApplied => 'ゲーム接続を切り替えました。';

  @override
  String get gameConnectorSaveFailed => '接続設定を保存できなかったため、現在の接続を維持します。';

  @override
  String get gameConnectorNavigationFailed =>
      '接続設定は保存されましたが、ログイン画面を開けませんでした。もう一度お試しください。';

  @override
  String get kcwikiReportSection => 'KCWiki データ提供';

  @override
  String get kcwikiReportTitle => 'KCWiki のデータ収集に協力する';

  @override
  String get kcwikiReportDisabledDesc =>
      '初期設定はオフです。オフの間は収集・整形・通信を行わず、ゲームやローカル機能に影響しません。';

  @override
  String get kcwikiReportEnabledDesc =>
      'オンです。進路、任務前提、戦闘、友軍、基地航空／空襲、改修データのみ送信します。';

  @override
  String get kcwikiReportConfirmTitle => 'KCWiki データ提供を有効にしますか？';

  @override
  String get kcwikiReportConfirmDesc =>
      '有効にすると、進路、任務前提、戦闘、友軍、基地航空／空襲、改修記録を KCWiki の report2 サーバーへ送信します。このサーバーは現在、暗号化されていない HTTP を使用します。ログイントークン、Cookie、リクエストヘッダーは送信せず、送信失敗でゲーム機能が停止することもありません。';

  @override
  String get kcwikiReportEnable => '任意で有効化';

  @override
  String get kcwikiReportSaveFailed =>
      'KCWiki データ提供の設定を保存できませんでした。もう一度お試しください。';

  @override
  String kcwikiReportCaptureFailed(String error) {
    return 'KCWiki データ収集の切り替えに失敗しました：$error';
  }

  @override
  String get kcwikiReportWaiting => '有効です。提供できるデータを待っています。';

  @override
  String kcwikiReportLastSuccess(
    String module,
    int succeeded,
    int failed,
    int dropped,
  ) {
    return '直近の送信成功：$module · 成功 $succeeded · 失敗 $failed · 破棄 $dropped';
  }

  @override
  String kcwikiReportLastFailure(
    String module,
    String status,
    int succeeded,
    int failed,
    int dropped,
  ) {
    return '直近の送信失敗：$module（状態 $status）· 成功 $succeeded · 失敗 $failed · 破棄 $dropped';
  }
}
