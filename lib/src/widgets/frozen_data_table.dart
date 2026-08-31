import 'package:flutter/material.dart';

class FrozenDataTable extends StatefulWidget {
  const FrozenDataTable({
    super.key,
    required this.frozenColumnWidths,
    required this.frozenHeaders,
    required this.frozenCells,
    required this.scrollableColumnWidths,
    required this.scrollableHeaders,
    required this.scrollableCells,
    required this.rowHeights,
    this.keyPrefix = 'frozen-table',
    this.onEndReached,
    this.onRowTap,
    this.selectedRowIndex,
  }) : assert(frozenColumnWidths.length == frozenHeaders.length),
       assert(scrollableColumnWidths.length == scrollableHeaders.length);

  static const double headerHeight = 34;
  static const double minimumRowHeight = 44;

  final List<double> frozenColumnWidths;
  final List<Widget> frozenHeaders;
  final List<Widget> Function(int index) frozenCells;
  final List<double> scrollableColumnWidths;
  final List<Widget> scrollableHeaders;
  final List<Widget> Function(int index) scrollableCells;
  final List<double> rowHeights;
  final String keyPrefix;
  final VoidCallback? onEndReached;
  final ValueChanged<int>? onRowTap;
  final int? selectedRowIndex;

  @override
  State<FrozenDataTable> createState() => _FrozenDataTableState();
}

class _FrozenDataTableState extends State<FrozenDataTable> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  final _frozenVertical = ScrollController();
  bool _syncingFrozen = false;
  bool _syncingMainVertical = false;

  @override
  void initState() {
    super.initState();
    _vertical.addListener(_syncFrozen);
    _frozenVertical.addListener(_syncMainVertical);
  }

  @override
  void didUpdateWidget(covariant FrozenDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rowHeights, widget.rowHeights) ||
        !identical(
          oldWidget.scrollableColumnWidths,
          widget.scrollableColumnWidths,
        ) ||
        !identical(oldWidget.frozenColumnWidths, widget.frozenColumnWidths)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _clampOffset(_horizontal);
        _clampOffset(_vertical);
        _syncFrozen();
      });
    }
  }

  void _syncFrozen() {
    if (_syncingFrozen || _syncingMainVertical || !_frozenVertical.hasClients) {
      return;
    }
    final target = _vertical.offset;
    if ((_frozenVertical.offset - target).abs() <= 0.1) return;
    _syncingFrozen = true;
    try {
      _frozenVertical.jumpTo(target);
    } finally {
      _syncingFrozen = false;
    }
    if (_vertical.position.maxScrollExtent - target <= 120) {
      widget.onEndReached?.call();
    }
  }

  void _syncMainVertical() {
    if (_syncingFrozen || _syncingMainVertical || !_vertical.hasClients) {
      return;
    }
    final target = _frozenVertical.offset;
    if ((_vertical.offset - target).abs() <= 0.1) return;
    _syncingMainVertical = true;
    try {
      _vertical.jumpTo(target);
    } finally {
      _syncingMainVertical = false;
    }
  }

  void _clampOffset(ScrollController controller) {
    if (!controller.hasClients) return;
    final target = controller.offset
        .clamp(
          controller.position.minScrollExtent,
          controller.position.maxScrollExtent,
        )
        .toDouble();
    if ((controller.offset - target).abs() > 0.1) {
      controller.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    _frozenVertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frozenWidth = widget.frozenColumnWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    final contentWidth = widget.scrollableColumnWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    final fixedRowHeight =
        widget.rowHeights.isNotEmpty &&
            widget.rowHeights.every(
              (height) => height == widget.rowHeights.first,
            )
        ? widget.rowHeights.first
        : null;

    Widget row(
      List<Widget> cells,
      List<double> widths,
      double height, {
      required Color background,
      bool strongTrailingBorder = false,
    }) => SizedBox(
      width: widths.fold<double>(0, (sum, width) => sum + width),
      height: height,
      child: Row(
        children: [
          for (var index = 0; index < cells.length; index++)
            SizedBox(
              width: widths[index],
              height: height,
              child: ClipRect(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    border: Border(
                      right: BorderSide(
                        color: strongTrailingBorder && index == cells.length - 1
                            ? const Color(0xff38586b)
                            : const Color(0xff294052),
                      ),
                      bottom: const BorderSide(color: Color(0xff294052)),
                    ),
                  ),
                  child: cells[index],
                ),
              ),
            ),
        ],
      ),
    );

    Widget interactiveRow(
      int index,
      Widget child, {
      required bool exposeButtonSemantics,
    }) {
      final onTap = widget.onRowTap;
      if (onTap == null) return child;
      final tappable = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: child,
      );
      if (!exposeButtonSemantics) return tappable;
      return Semantics(
        button: true,
        selected: widget.selectedRowIndex == index,
        child: tappable,
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xff0b202c),
            border: Border.all(color: const Color(0xff294052)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: FrozenDataTable.headerHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: frozenWidth,
                      child: row(
                        widget.frozenHeaders,
                        widget.frozenColumnWidths,
                        FrozenDataTable.headerHeight,
                        background: const Color(0xff17303e),
                        strongTrailingBorder: true,
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: AnimatedBuilder(
                          animation: _horizontal,
                          builder: (context, child) {
                            final offset = _horizontal.hasClients
                                ? _horizontal.offset
                                : 0.0;
                            return OverflowBox(
                              alignment: Alignment.centerLeft,
                              maxWidth: double.infinity,
                              child: Transform.translate(
                                offset: Offset(-offset, 0),
                                child: child,
                              ),
                            );
                          },
                          child: row(
                            widget.scrollableHeaders,
                            widget.scrollableColumnWidths,
                            FrozenDataTable.headerHeight,
                            background: const Color(0xff17303e),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: frozenWidth,
                      child: ClipRect(
                        child: ListView.builder(
                          key: Key('${widget.keyPrefix}-frozen-scroll'),
                          controller: _frozenVertical,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          primary: false,
                          addRepaintBoundaries: false,
                          itemCount: widget.rowHeights.length,
                          itemExtent: fixedRowHeight,
                          itemExtentBuilder: fixedRowHeight == null
                              ? (index, dimensions) => widget.rowHeights[index]
                              : null,
                          itemBuilder: (context, index) => RepaintBoundary(
                            child: interactiveRow(
                              index,
                              row(
                                widget.frozenCells(index),
                                widget.frozenColumnWidths,
                                widget.rowHeights[index],
                                background: widget.selectedRowIndex == index
                                    ? const Color(0xff173f4c)
                                    : const Color(0xff0d2330),
                                strongTrailingBorder: true,
                              ),
                              exposeButtonSemantics: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _horizontal,
                        thumbVisibility: true,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          key: Key('${widget.keyPrefix}-horizontal-scroll'),
                          controller: _horizontal,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: SizedBox(
                            width: contentWidth,
                            child: Scrollbar(
                              controller: _vertical,
                              thumbVisibility: true,
                              child: ListView.builder(
                                key: Key('${widget.keyPrefix}-body-scroll'),
                                controller: _vertical,
                                physics: const ClampingScrollPhysics(),
                                padding: EdgeInsets.zero,
                                primary: false,
                                addRepaintBoundaries: false,
                                itemCount: widget.rowHeights.length,
                                itemExtent: fixedRowHeight,
                                itemExtentBuilder: fixedRowHeight == null
                                    ? (index, dimensions) =>
                                          widget.rowHeights[index]
                                    : null,
                                itemBuilder: (context, index) =>
                                    RepaintBoundary(
                                      child: interactiveRow(
                                        index,
                                        row(
                                          widget.scrollableCells(index),
                                          widget.scrollableColumnWidths,
                                          widget.rowHeights[index],
                                          background:
                                              widget.selectedRowIndex == index
                                              ? const Color(0xff173f4c)
                                              : Colors.transparent,
                                        ),
                                        exposeButtonSemantics: false,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
