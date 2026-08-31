import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How long an undo stays available before the action becomes permanent.
const undoWindow = Duration(seconds: 5);

/// Shows an undo bar whose remaining time is drawn as a line that shrinks
/// away — so the window is visible instead of guessed.
void showUndoSnack(
  ScaffoldMessengerState messenger, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = undoWindow,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: duration,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message),
          const SizedBox(height: Gap.sm),
          _CountdownLine(duration: duration),
        ],
      ),
      action: SnackBarAction(label: 'Geri Al', onPressed: onUndo),
    ));
}

class _CountdownLine extends StatefulWidget {
  final Duration duration;
  const _CountdownLine({required this.duration});

  @override
  State<_CountdownLine> createState() => _CountdownLineState();
}

class _CountdownLineState extends State<_CountdownLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // preserve: the line reports real remaining time, so it must not be
    // rescaled by the OS "reduce motion" setting the way decoration is.
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      animationBehavior: AnimationBehavior.preserve,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(
          children: [
            Container(color: scheme.onInverseSurface.withValues(alpha: 0.22)),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 1 - _controller.value,
                child: Container(color: scheme.inversePrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
