import 'package:flutter/widgets.dart';

/// Initializes a tab on first use and retains its state on later switches.
/// Child positions must be stable, as with [IndexedStack].
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  }) : assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = {};

  @override
  Widget build(BuildContext context) {
    _visited.removeWhere((index) => index >= widget.children.length);
    _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          TickerMode(
            enabled: index == widget.index,
            child: _visited.contains(index)
                ? widget.children[index]
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
