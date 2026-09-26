import 'package:flutter/material.dart';

/// Shared presentation for the five independently versioned data sources.
class DataUpdateMetadata extends StatelessWidget {
  const DataUpdateMetadata({
    super.key,
    required this.version,
    required this.lastCheckedAt,
  });

  final String version;
  final DateTime? lastCheckedAt;

  static String versionDate(String version) {
    final match = RegExp(
      r'^(\d{4})[./-](\d{2})[./-](\d{2})',
    ).firstMatch(version);
    return match == null ? version : '${match[1]}-${match[2]}-${match[3]}';
  }

  static String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final japanese = Localizations.localeOf(context).languageCode == 'ja';
    const style = TextStyle(color: Color(0xff8197a5));
    final checked = lastCheckedAt;
    return Wrap(
      spacing: 16,
      runSpacing: 2,
      children: [
        Text(
          '${japanese ? 'データバージョン' : '数据版本'}：${versionDate(version)}',
          style: style,
        ),
        Text(
          '${japanese ? '最終確認' : '上次检查'}：'
          '${checked == null ? (japanese ? '未確認' : '尚未检查') : _time(checked)}',
          style: style,
        ),
      ],
    );
  }
}
