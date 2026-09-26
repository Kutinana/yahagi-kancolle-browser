import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Measures panels at their final widths before stretching to the tallest one.
/// Unlike intrinsic sizing, this supports the panels' responsive LayoutBuilders.
class ExpCalcPanelRow extends MultiChildRenderObjectWidget {
  const ExpCalcPanelRow({super.key, required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _PanelRow();
}

class _PanelData extends ContainerBoxParentData<RenderBox> {}

class _PanelRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PanelData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PanelData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PanelData) child.parentData = _PanelData();
  }

  @override
  void performLayout() {
    const weights = [2.7, 3.6, 3.7];
    const gap = 6.0;
    final available = math.max(0.0, constraints.maxWidth - gap * 2);
    var height = 0.0;
    var child = firstChild;
    var index = 0;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: available * weights[index] / 10),
        parentUsesSize: true,
      );
      height = math.max(height, child.size.height);
      child = childAfter(child);
      index++;
    }
    size = constraints.constrain(Size(constraints.maxWidth, height));
    child = firstChild;
    index = 0;
    var x = 0.0;
    while (child != null) {
      final width = available * weights[index] / 10;
      child.layout(
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: size.height,
        ),
        parentUsesSize: true,
      );
      (child.parentData! as _PanelData).offset = Offset(x, 0);
      x += width + gap;
      index++;
      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
