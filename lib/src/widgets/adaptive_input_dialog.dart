import 'package:flutter/material.dart';

class AdaptiveInputDialog extends StatelessWidget {
  const AdaptiveInputDialog({
    super.key,
    this.dialogKey,
    required this.title,
    required this.content,
    required this.actions,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final Key? dialogKey;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: dialogKey,
    scrollable: true,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
    actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
    title: title,
    content: content,
    actions: actions,
  );
}
