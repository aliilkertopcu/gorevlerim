import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A drag start listener with customizable delay (default 300ms).
/// Flutter's [ReorderableDelayedDragStartListener] hardcodes 500ms.
class CustomDelayDragStartListener extends ReorderableDragStartListener {
  final Duration delay;

  const CustomDelayDragStartListener({
    super.key,
    required super.index,
    required super.child,
    this.delay = const Duration(milliseconds: 700),
  });

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(delay: delay);
  }
}
