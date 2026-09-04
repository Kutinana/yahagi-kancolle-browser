import 'package:flutter/material.dart';

class DevelopmentSortHeader extends StatelessWidget {
  const DevelopmentSortHeader({
    super.key,
    required this.label,
    required this.active,
    required this.ascending,
  });

  final String label;
  final bool active;
  final bool ascending;

  @override
  Widget build(BuildContext context) => Text(
    '$label${active ? ' ${ascending ? '▲' : '▼'}' : ''}',
    maxLines: 1,
    style: TextStyle(
      color: active ? const Color(0xffffc85a) : const Color(0xff9fb3bf),
      fontSize: 11,
      fontWeight: FontWeight.w800,
    ),
  );
}
