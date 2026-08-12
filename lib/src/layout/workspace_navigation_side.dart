import 'package:flutter/widgets.dart';

TextDirection workspaceNavigationTextDirection({required bool menuOnRight}) =>
    menuOnRight ? TextDirection.rtl : TextDirection.ltr;

Border workspaceNavigationBorder({required bool menuOnRight}) {
  const divider = BorderSide(color: Color(0xff294052));
  return menuOnRight
      ? const Border(left: divider)
      : const Border(right: divider);
}
