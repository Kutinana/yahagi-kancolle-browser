import 'package:flutter/widgets.dart';

import 'battle_detail_strings.dart';

/// Localizes displayed battle labels without changing persisted battle values.
class BattleUiText extends StatelessWidget {
  const BattleUiText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) => Text(
    BattleDetailStrings.of(context).localize(data),
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
    softWrap: softWrap,
  );
}
