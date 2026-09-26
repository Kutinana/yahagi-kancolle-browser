import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Displays single-line text and smoothly scrolls back and forth (ping-pong)
/// when the text exceeds the available width constraints.
///
/// If the text fits comfortably within the constraints, it behaves as a static [Text].
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 32.0,
    this.pauseDuration = const Duration(milliseconds: 1200),
    this.edgeFadeWidth = 8.0,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final double velocity;
  final Duration pauseDuration;
  final double edgeFadeWidth;
  final TextAlign textAlign;

  /// Global flag to disable marquee animation during tests when needed.
  static bool disableAnimationForTest = false;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animation;
  double _lastOverflow = 0.0;
  String _lastText = '';
  TextStyle? _lastStyle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _configureAnimation(double overflow) {
    if (_lastOverflow == overflow &&
        _lastText == widget.text &&
        _lastStyle == widget.style &&
        _animation != null) {
      return;
    }

    _lastOverflow = overflow;
    _lastText = widget.text;
    _lastStyle = widget.style;

    if (overflow <= 0.5) {
      _controller.stop();
      _controller.value = 0.0;
      _animation = null;
      return;
    }

    final scrollMs = ((overflow / widget.velocity) * 1000).round().clamp(
      400,
      60000,
    );
    final pauseMs = widget.pauseDuration.inMilliseconds;
    final totalMs = pauseMs * 2 + scrollMs * 2;

    final pWeight = math.max(1.0, pauseMs.toDouble());
    final sWeight = math.max(1.0, scrollMs.toDouble());

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: pWeight),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: overflow,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: sWeight,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(overflow),
        weight: pWeight,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: overflow,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: sWeight,
      ),
    ]).animate(_controller);

    _controller.duration = Duration(milliseconds: totalMs);
    _controller.reset();
    if (!MarqueeText.disableAnimationForTest && mounted) {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0 || !maxWidth.isFinite) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
          );
        }

        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        )..layout();

        final textWidth = textPainter.width;
        textPainter.dispose();
        final overflow = math.max(0.0, textWidth - maxWidth);

        if (overflow != _lastOverflow ||
            _lastText != widget.text ||
            _lastStyle != widget.style) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _configureAnimation(overflow);
          });
        }

        if (overflow <= 0.5 || MarqueeText.disableAnimationForTest) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
          );
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            child: SizedBox(
              width: textWidth + 8,
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                softWrap: false,
                textAlign: widget.textAlign,
              ),
            ),
            builder: (context, child) {
              final offset = _animation?.value ?? 0.0;
              Widget content = Transform.translate(
                key: const Key('marquee-translate'),
                offset: Offset(-offset, 0.0),
                child: child,
              );

              if (widget.edgeFadeWidth > 0 && overflow > 0) {
                final showLeft = offset > 1.5;
                final showRight = offset < overflow - 1.5;
                if (showLeft || showRight) {
                  content = ShaderMask(
                    shaderCallback: (Rect bounds) {
                      final fadeRatio = (widget.edgeFadeWidth / bounds.width)
                          .clamp(0.01, 0.2);
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          if (showLeft) Colors.transparent else Colors.black,
                          Colors.black,
                          Colors.black,
                          if (showRight) Colors.transparent else Colors.black,
                        ],
                        stops: [0.0, fadeRatio, 1.0 - fadeRatio, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: content,
                  );
                }
              }

              return content;
            },
          ),
        );
      },
    );
  }
}
