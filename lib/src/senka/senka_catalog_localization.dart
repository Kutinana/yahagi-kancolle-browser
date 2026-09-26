import 'package:flutter/widgets.dart';

import 'senka_catalog.dart';

/// Display-only labels. Catalog IDs, codes and quest matching remain unchanged.
String senkaCatalogLabel(SenkaCatalogItem item, Locale locale) {
  final index = _localeIndex(locale);
  if (index == null) return item.label;
  final labels = item.category == SenkaRewardCategory.eo
      ? _eoLabels[item.id]
      : _questLabels[item.id];
  return labels == null ? item.label : (index == 0 ? labels.$1 : labels.$2);
}

String senkaCatalogMatrixLabel(SenkaCatalogItem item, Locale locale) {
  final index = _localeIndex(locale);
  if (index == null || item.category == SenkaRewardCategory.eo) {
    return item.matrixLabel;
  }
  final labels = _questShortLabels[item.id];
  final shortName = labels == null
      ? item.shortName
      : (index == 0 ? labels.$1 : labels.$2);
  return item.code == null ? shortName : '${item.code} $shortName';
}

int? _localeIndex(Locale locale) {
  if (locale.languageCode == 'ja') return 1;
  if (locale.languageCode == 'zh' &&
      (locale.scriptCode == 'Hant' ||
          const ['TW', 'HK', 'MO'].contains(locale.countryCode))) {
    return 0;
  }
  return null;
}

// Japanese place names also occur in the bundled quests-scn.json descriptions.
const _eoLabels = <int, (String, String)>{
  15: ('鎮守府近海（1-5）', '鎮守府近海（1-5）'),
  16: ('鎮守府近海航路（1-6）', '鎮守府近海航路（1-6）'),
  25: ('沖之島近海（2-5）', '沖ノ島沖（2-5）'),
  35: ('北方阿留申海域（3-5）', '北方AL海域（3-5）'),
  45: ('咖哩洋里蘭卡島海域（4-5）', 'カレー洋リランカ島沖（4-5）'),
  55: ('沙門海域北方（5-5）', 'サーモン海域北方（5-5）'),
  56: ('拉包爾方面海域（5-6）', 'ラバウル方面海域（5-6）'),
  65: ('KW 環礁沿海海域（6-5）', 'KW環礁沖海域（6-5）'),
  75: ('爪哇島海域（7-5）', 'ジャワ島沖（7-5）'),
};

// Japanese titles are copied from assets/data/quests-scn.json `name` by ID.
const _questLabels = <int, (String, String)>{
  854: ('戰果擴張任務！「Z作戰」前段作戰', '戦果拡張任務！「Z作戦」前段作戦'),
  888: ('新編成「三川艦隊」、突入鐵底海峽！', '新編成「三川艦隊」、鉄底海峡に突入せよ！'),
  893: ('徹底確保泊地周邊海域的安全！', '泊地周辺海域の安全確保を徹底せよ！'),
  872: ('戰果擴張任務！「Z作戰」後段作戰', '戦果拡張任務！「Z作戦」後段作戦'),
  284: ('西南諸島方面「海上警備行動」發布！', '南西諸島方面「海上警備行動」発令！'),
  845: ('發布！「西方海域作戰」', '発令！「西方海域作戦」'),
  903: ('擴張「六水戰」、前往最前線！', '拡張「六水戦」、最前線へ！'),
  947: ('AL作戰', 'AL作戦'),
  948: ('機動部隊決戰', '機動部隊決戦'),
  949: ('改裝特務空母「Gambier Bay Mk.II」拔錨！', '改装特務空母「Gambier Bay Mk.II」抜錨！'),
};

const _questShortLabels = <int, (String, String)>{
  854: ('Z作戰前', 'Z作戦前'),
  888: ('三川艦隊', '三川艦隊'),
  893: ('泊地周邊', '泊地周辺'),
  872: ('Z作戰後', 'Z作戦後'),
  284: ('海上警備', '海上警備'),
  845: ('西方海域', '西方海域'),
  903: ('六水戰', '六水戦'),
  947: ('AL作戰', 'AL作戦'),
  948: ('機動部隊決戰', '機動部隊決戦'),
  949: ('改裝特務空母「Gambier Bay Mk.II」拔錨！', '改装特務空母「Gambier Bay Mk.II」抜錨！'),
};
