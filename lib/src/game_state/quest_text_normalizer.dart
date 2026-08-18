String normalizeQuestDetail(String source) => source
    .replaceAll(
      RegExp(r'[ \t\f]*<br\b[^>]*>[ \t\f]*', caseSensitive: false),
      '',
    )
    .replaceAll(RegExp(r'[ \t\f]*[\r\n\u0085\u2028\u2029]+[ \t\f]*'), '');
