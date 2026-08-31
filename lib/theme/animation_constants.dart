
import 'package:flutter/widgets.dart';

/// Motion tokens — MD3 asymmetric timing: entrances decelerate and take
/// longer; exits accelerate and get out of the way fast.
abstract final class Anim {
  // Durations
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const pageTransition = Duration(milliseconds: 300);

  /// Something appearing on screen (dialogs, list items, expanding content).
  static const enter = Duration(milliseconds: 400);

  /// Something leaving the screen. Exits are always faster than entrances.
  static const exit = Duration(milliseconds: 200);

  // Curves (MD3 emphasized family)
  static const defaultCurve = Curves.easeOutCubic;
  static const enterCurve = Cubic(0.05, 0.7, 0.1, 1.0); // emphasized decelerate
  static const exitCurve = Cubic(0.3, 0.0, 0.8, 0.15); // emphasized accelerate
  static const standardCurve = Cubic(0.2, 0.0, 0.0, 1.0);

  // Scale
  static const pressedScale = 0.97;

  /// Stagger step for list entrance animations.
  static const staggerStep = Duration(milliseconds: 60);

  /// Whether motion should play at all (honors the OS reduced-motion setting).
  static bool enabled(BuildContext context) => !MediaQuery.of(context).disableAnimations;

  /// [duration] when motion is enabled, [Duration.zero] otherwise.
  static Duration maybe(BuildContext context, Duration duration) =>
      enabled(context) ? duration : Duration.zero;
}
