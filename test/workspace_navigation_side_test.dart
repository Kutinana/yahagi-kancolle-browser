import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_navigation_side.dart';

void main() {
  test('changes row direction without reordering the stateful children', () {
    expect(
      workspaceNavigationTextDirection(menuOnRight: false),
      TextDirection.ltr,
    );
    expect(
      workspaceNavigationTextDirection(menuOnRight: true),
      TextDirection.rtl,
    );
  });

  test('keeps the divider on the menu edge facing workspace content', () {
    final left = workspaceNavigationBorder(menuOnRight: false);
    final right = workspaceNavigationBorder(menuOnRight: true);

    expect(left.left.style, BorderStyle.none);
    expect(left.right.style, BorderStyle.solid);
    expect(right.left.style, BorderStyle.solid);
    expect(right.right.style, BorderStyle.none);
  });
}
