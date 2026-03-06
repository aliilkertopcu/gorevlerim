import 'package:flutter/animation.dart';

abstract final class Anim {
  // Durations
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const pageTransition = Duration(milliseconds: 300);

  // Curves
  static const defaultCurve = Curves.easeOutCubic;
  static const enterCurve = Curves.easeOut;

  // Scale
  static const pressedScale = 0.97;
}
