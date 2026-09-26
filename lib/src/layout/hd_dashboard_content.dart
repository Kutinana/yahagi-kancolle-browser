import 'package:flutter/material.dart';

/// Bottom-row cards opt into a column count matching their span.
class HdModuleColumns extends InheritedWidget {
  const HdModuleColumns({
    super.key,
    required this.columns,
    required super.child,
  });
  final int columns;
  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HdModuleColumns>()?.columns ??
      1;
  @override
  bool updateShouldNotify(HdModuleColumns oldWidget) =>
      columns != oldWidget.columns;
}

/// Full-width modules can use several columns without adding module rows.
/// Outside HD, the same items retain their original vertical arrangement.
class HdDashboardItems extends StatelessWidget {
  const HdDashboardItems({
    super.key,
    required this.children,
    this.spacing = 3,
    this.runSpacing = 6,
  });
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final columns = HdModuleColumns.of(context).clamp(1, 3);
    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: runSpacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
