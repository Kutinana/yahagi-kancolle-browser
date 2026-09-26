import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class QuestCompletionBadge extends StatelessWidget {
  const QuestCompletionBadge({
    super.key,
    required this.count,
    required this.child,
    this.countKey = const Key('quest-completion-count'),
    this.semanticLabel,
    this.inline = false,
  });

  final bool inline;
  final int count;
  final Widget child;
  final Key countKey;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    final badge = IgnorePointer(
      child: Semantics(
        key: countKey,
        label:
            semanticLabel ??
            AppLocalizations.of(context)!.questCompletionCount(count),
        child: ExcludeSemantics(
          child: Text(
            circledCount(count),
            style: const TextStyle(
              color: Color(0xff69c7ff),
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(color: Color(0x9953b9ff), blurRadius: 5),
                Shadow(color: Color(0x5553b9ff), blurRadius: 9),
              ],
            ),
          ),
        ),
      ),
    );
    if (inline) return badge;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(top: -7, right: -9, child: badge),
      ],
    );
  }
}

String circledCount(int count) {
  if (count >= 1 && count <= 20) return String.fromCharCode(0x2460 + count - 1);
  if (count >= 21 && count <= 35) {
    return String.fromCharCode(0x3251 + count - 21);
  }
  if (count >= 36 && count <= 50) {
    return String.fromCharCode(0x32b1 + count - 36);
  }
  return '($count)';
}
