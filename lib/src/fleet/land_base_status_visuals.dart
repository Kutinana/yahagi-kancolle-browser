import 'package:flutter/material.dart';

enum LandBaseFatigueLevel { none, yellow, red }

LandBaseFatigueLevel landBaseFatigueLevel(Iterable<int> conditions) {
  var result = LandBaseFatigueLevel.none;
  for (final condition in conditions) {
    if (condition >= 3) return LandBaseFatigueLevel.red;
    if (condition == 2) result = LandBaseFatigueLevel.yellow;
  }
  return result;
}

Color? landBaseFatigueColor(LandBaseFatigueLevel level) => switch (level) {
  LandBaseFatigueLevel.none => null,
  LandBaseFatigueLevel.yellow => const Color(0xffe7ad45),
  LandBaseFatigueLevel.red => const Color(0xffef5a5a),
};
