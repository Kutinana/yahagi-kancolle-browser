import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

final class GameMouseWheelInput {
  const GameMouseWheelInput({
    required this.xRatio,
    required this.yRatio,
    required this.deltaX,
    required this.deltaY,
  });
  final double xRatio;
  final double yRatio;
  final double deltaX;
  final double deltaY;
}

/// Uses Flutter hit testing so covered games and neighboring panels cannot
/// receive wheel input. The platform view's touch gesture arena is unchanged.
final class GameMouseWheelRegion extends StatelessWidget {
  const GameMouseWheelRegion({
    super.key,
    required this.enabled,
    required this.onScroll,
    required this.child,
  });
  final bool enabled;
  final ValueChanged<GameMouseWheelInput> onScroll;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: enabled
        ? (event) {
            if (event is! PointerScrollEvent ||
                event.kind != PointerDeviceKind.mouse ||
                HardwareKeyboard.instance.isControlPressed) {
              return;
            }
            final box = context.findRenderObject();
            if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
            final point = box.globalToLocal(event.position);
            if (!(Offset.zero & box.size).contains(point) ||
                !event.scrollDelta.dx.isFinite ||
                !event.scrollDelta.dy.isFinite ||
                event.scrollDelta.dy == 0) {
              return;
            }
            final input = GameMouseWheelInput(
              xRatio: point.dx / box.size.width,
              yRatio: point.dy / box.size.height,
              deltaX: event.scrollDelta.dx,
              deltaY: event.scrollDelta.dy,
            );
            GestureBinding.instance.pointerSignalResolver.register(
              event,
              (_) => onScroll(input),
            );
          }
        : null,
    child: child,
  );
}
