const Map<String, String> _displayShipTypes = <String, String>{
  'DDorDE': 'DD/DE',
  'SSLike': 'SS/SSV',
  'CVLike': 'CV/CVL/AV/CVB',
};

const Map<int, String> _flagshipShipTypes = <int, String>{
  3: '轻巡洋舰（CL）',
  5: '重巡洋舰（CA）',
  7: '轻空母（CVL）',
  16: '水上机母舰（AV）',
  20: '潜水母舰（AS）',
  21: '练习巡洋舰（CT）',
};

String formatExpeditionComposition(List<Map<String, int>> variants) => variants
    .map(
      (variant) => variant.entries
          .map(
            (entry) =>
                '${entry.value}${_displayShipTypes[entry.key] ?? entry.key}',
          )
          .join('+'),
    )
    .join(' or ');

String formatExpeditionFlagshipType(int shipTypeId) =>
    _flagshipShipTypes[shipTypeId] ?? '舰种 $shipTypeId';
