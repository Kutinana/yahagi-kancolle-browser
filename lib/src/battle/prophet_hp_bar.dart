import 'package:flutter/material.dart';

const _prophetHpThresholds = <double>[0.25, 0.50, 0.75];

class ProphetHpBar extends StatelessWidget {
  const ProphetHpBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final double value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ratio = value.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              LinearProgressIndicator(
                minHeight: 6,
                value: ratio,
                color: color,
                backgroundColor: backgroundColor,
              ),
              ClipRect(
                clipper: _ProphetHpFillClipper(ratio),
                child: Stack(
                  children: <Widget>[
                    for (final threshold in _prophetHpThresholds)
                      if (ratio > threshold)
                        Positioned(
                          key: Key(
                            'prophet-hp-threshold-${(threshold * 100).round()}',
                          ),
                          left: constraints.maxWidth * threshold,
                          top: 1,
                          width: 1,
                          height: 4,
                          child: const ColoredBox(
                            color: Color.fromRGBO(2, 11, 16, 0.78),
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

class _ProphetHpFillClipper extends CustomClipper<Rect> {
  const _ProphetHpFillClipper(this.ratio);

  final double ratio;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * ratio, size.height);

  @override
  bool shouldReclip(covariant _ProphetHpFillClipper oldClipper) =>
      ratio != oldClipper.ratio;
}
