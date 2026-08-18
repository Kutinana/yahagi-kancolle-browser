const Map<String, String> _displayShipTypes = <String, String>{
  'DDorDE': 'DD/DE',
  'SSLike': 'SS/SSV',
  'CVLike': 'CV/CVL/AV/CVB',
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
