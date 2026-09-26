import 'package:flutter/widgets.dart';

/// Canonical game difficulty codes; these are stored as data across locales.
const compositionDifficultyCodes = <String>['甲', '乙', '丙', '丁'];

/// Labels owned by the composition image feature; game-provided names stay intact.
class CompositionImageStrings {
  const CompositionImageStrings(this.locale);

  factory CompositionImageStrings.of(BuildContext context) =>
      CompositionImageStrings(
        Localizations.maybeLocaleOf(context) ?? const Locale('zh'),
      );

  final Locale locale;
  String _text(String zh, String hant, String ja) => locale.languageCode == 'ja'
      ? ja
      : locale.scriptCode == 'Hant' ||
            const ['TW', 'HK', 'MO'].contains(locale.countryCode)
      ? hant
      : zh;

  String get title => _text('编成记录', '編成記錄', '編成記録');
  String get luck => _text('运', '運', '運');
  String get savedTab => _text('已保存', '已儲存', '保存済み');
  String get currentTab => _text('当前编成', '目前編成', '現在の編成');
  String get newRecord => _text('新建记录', '新增記錄', '新規記録');
  String get recordSave => _text('保存编队记录', '儲存編隊記錄', '編成記録を保存');
  String get recordSaved => _text('编队记录已保存。', '編隊記錄已儲存。', '編成記録を保存しました。');
  String get recordLimitReached =>
      _text('已经达到最大记录数量', '已達到記錄數量上限', '記録件数の上限に達しました');
  String get exportImage => _text('导出图片', '匯出圖片', '画像を書き出す');
  String get fleetForm => _text('编队形式', '編隊形式', '編成形式');
  String get targetMap => _text('目标海域', '目標海域', '目標海域');
  String get noTargetMap => _text('无目标海域', '無目標海域', '目標海域なし');
  String get normalMap => _text('常规海域', '通常海域', '通常海域');
  String get eventMap => _text('活动海域', '活動海域', 'イベント海域');
  String get chooseMap => _text('请选择常规海域', '請選擇通常海域', '通常海域を選択');
  String get eventMapHint =>
      _text('例如：2026 夏活 E3-3', '例如：2026 夏活 E3-3', '例：2026 夏 E3-3');
  String get difficulty => _text('难度（可选）', '難度（可選）', '難易度（任意）');
  String get recordName => _text('编队名称', '編隊名稱', '編成名');
  String get recordNameHint => _text('自由填写编队名称', '自由填寫編隊名稱', '編成名を自由に入力');
  String get normalNameHint => _text('例如：任务编队', '例如：任務編隊', '例：任務編成');
  String get eventNameHint => _text('例如：斩杀编队', '例如：斬殺編隊', '例：最終編成');
  String get finalRecordName => _text('保存后名称', '儲存後名稱', '保存後の名前');
  String get nameRequired => _text('请填写编队名称。', '請填寫編隊名稱。', '編成名を入力してください。');
  String get search => _text('搜索编队名称或海域', '搜尋編隊名稱或海域', '編成名・海域を検索');
  String get compactSearch => _text('搜索记录', '搜尋記錄', '記録を検索');
  String get searchShort => _text('搜索', '搜尋', '検索');
  String get filterRecords => _text('筛选', '篩選', '絞り込み');
  String get filterTitle => _text('按海域筛选记录', '依海域篩選記錄', '海域で記録を絞り込む');
  String get allRecords => _text('全部记录', '全部記錄', 'すべての記録');
  String normalArea(int id) => switch (id) {
    1 => _text('镇守府海域', '鎮守府海域', '鎮守府海域'),
    2 => _text('南西群岛海域', '南西群島海域', '南西諸島海域'),
    3 => _text('北方海域', '北方海域', '北方海域'),
    4 => _text('西方海域', '西方海域', '西方海域'),
    5 => _text('南方海域', '南方海域', '南方海域'),
    6 => _text('中部海域', '中部海域', '中部海域'),
    7 => _text('南西海域', '南西海域', '南西海域'),
    _ => area(id),
  };
  String get noRecords => _text('还没有编队记录', '尚無編隊記錄', '編成記録はまだありません');
  String get recordLoadFailed =>
      _text('读取编队记录失败。', '讀取編隊記錄失敗。', '編成記録を読み込めませんでした。');
  String get recordImageUnavailable =>
      _text('记录图片无法读取。', '記錄圖片無法讀取。', '記録画像を読み込めませんでした。');
  String get retry => _text('重试', '重試', '再試行');
  String get noMatches => _text('没有找到匹配的记录。', '找不到符合的記錄。', '該当する記録がありません。');
  String get selectRecord =>
      _text('选择一条记录，即可查看当时保存的编成。', '選擇記錄即可查看儲存時的編成。', '記録を選択すると保存時の編成を表示します。');
  String get deleteRecord => _text('删除记录', '刪除記錄', '記録を削除');
  String get deleteQuestion => _text('删除这条记录？', '刪除此記錄？', 'この記録を削除しますか？');
  String get deleteHint => _text(
    '删除后无法找回，已导出的图片不会受影响。',
    '刪除後無法復原，已匯出的圖片不受影響。',
    '削除すると元に戻せません。書き出した画像には影響しません。',
  );
  String get cancel => _text('取消', '取消', 'キャンセル');
  String get unnamed => _text('未命名编队', '未命名編隊', '無題の編成');
  String get mapRequired =>
      _text('请先选择或填写目标海域。', '請先選擇或填寫目標海域。', '目標海域を選択または入力してください。');
  String get operationFailed => _text('操作失败，请重试。', '操作失敗，請重試。', '操作に失敗しました。');
  String get recordDeleted => _text('记录已删除。', '記錄已刪除。', '記録を削除しました。');
  List<String> get fleetForms => [
    _text('普通舰队', '普通艦隊', '通常艦隊'),
    _text('支援舰队', '支援艦隊', '支援艦隊'),
    _text('水上打击部队', '水上打擊部隊', '水上打撃部隊'),
    _text('空母机动部队', '空母機動部隊', '空母機動部隊'),
    _text('运送护卫部队', '運送護衛部隊', '輸送護衛部隊'),
    _text('游击部队', '遊擊部隊', '遊撃部隊'),
  ];
  String get subtitle =>
      _text('把此刻的舰队，保存成一张图。', '把此刻的艦隊，儲存成一張圖。', '今の艦隊を、一枚の画像に。');
  String get save => _text('保存编成图', '儲存編成圖', '編成画像を保存');
  String get saving => _text('正在保存…', '正在儲存…', '保存中…');
  String get saved => _text('编成图已保存到相册。', '編成圖已儲存至相簿。', '編成画像をアルバムに保存しました。');
  String get saveFailed =>
      _text('编成图保存失败，请重试。', '編成圖儲存失敗，請重試。', '編成画像を保存できませんでした。もう一度お試しください。');
  String get permissionDenied =>
      _text('需要相册存储权限才能保存编成图。', '需要相簿儲存權限才能儲存編成圖。', '編成画像の保存にはストレージの権限が必要です。');
  String get selection => _text('显示内容', '顯示內容', '表示する内容');
  String get fleets => _text('舰队', '艦隊', '艦隊');
  String get airBaseTitle => _text('基地航空队', '基地航空隊', '基地航空隊');
  String get noAirBase => _text('不使用航空队', '不使用航空隊', '基地航空隊を使用しない');
  String get noAirBases => _text(
    '打开游戏中的基地航空队后即可加入编成图。',
    '開啟遊戲中的基地航空隊後即可加入編成圖。',
    'ゲーム内で基地航空隊を開くと、画像に追加できます。',
  );
  String get planeCounts => _text('搭载数', '搭載數', '搭載数');
  String get hidden => _text('隐藏', '隱藏', '非表示');
  String get current => _text('当前', '目前', '現在');
  String get maximum => _text('最大', '最大', '最大');
  String get preview => _text('图片预览', '圖片預覽', '画像プレビュー');
  String get previewHint => _text(
    '保存完整高清图片，包含下方全部编成。',
    '儲存完整高畫質圖片，包含下方全部編成。',
    '下の編成をすべて含む高画質の画像を保存します。',
  );
  String get emptySelection =>
      _text('请选择要保存的舰队或陆航。', '請選擇要儲存的艦隊或陸航。', '保存する艦隊または基地航空隊を選択してください。');
  String get emptyFleet => _text('暂无舰娘', '暫無艦娘', '艦がいません');
  String get waitingForPort => _text('等待母港数据', '等待母港資料', '母港データを待っています');
  String get waitingForEquipment =>
      _text('等待完整装备数据', '等待完整裝備資料', '装備データを待っています');
  String get refreshingShips =>
      _text('正在更新舰娘数据…', '正在更新艦娘資料…', '艦データを更新しています…');
  String get emptySlot => _text('未装备', '未裝備', '未装備');
  String slot(int index) => _text('装备 $index', '裝備 $index', '装備 $index');
  String get expansionSlot => _text('增设', '增設', '補強増設');
  String squadron(int index) => _text('中队 $index', '中隊 $index', '第 $index 中隊');
  String get missingShip => _text('舰娘数据未就绪', '艦娘資料未就緒', '艦データ未取得');
  String get missingEquipment => _text('装备数据未就绪', '裝備資料未就緒', '装備データ未取得');
  String get footer => _text('Yahagi · 编成记录', 'Yahagi · 編成記錄', 'Yahagi · 編成記録');
  String fleet(int id) => _text('第 $id 舰队', '第 $id 艦隊', '第 $id 艦隊');
  String landBase(int id) => _text('第 $id 航空队', '第 $id 航空隊', '第 $id 航空隊');
  String area(int id) => _text('海域 $id', '海域 $id', '海域 $id');
  String level(int value) => 'Lv. $value';
  String range(int value) => _text('航程 $value', '航程 $value', '行動半径 $value');
  String landBaseCount(int value) =>
      _text('$value 队陆航', '$value 隊陸航', '基地航空隊 $value 隊');
  String baseMode(int kind) => switch (kind) {
    1 => _text('出击', '出擊', '出撃'),
    2 => _text('防空', '防空', '防空'),
    3 => _text('退避', '退避', '退避'),
    4 => _text('休息', '休息', '休息'),
    _ => _text('待机', '待機', '待機'),
  };
}
