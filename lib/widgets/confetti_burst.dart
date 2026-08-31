import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../utils/chime.dart';

/// Key of the full-screen confetti overlay (used by tests).
const confettiKey = ValueKey('confetti-overlay');

/// Hard stop, in case the asset never finishes loading.
const _safetyTimeout = Duration(seconds: 12);

/// Longest the celebration may run, even if the animation itself is longer.
const _maxDuration = Duration(seconds: 8);

/// Full-screen confetti + chime, played once. Removes itself when done.
///
/// Animation: "Free Confetti Animation" by Tạ Sơn Quỳnh (LottieFiles, Lottie
/// Simple License) — see `assets/animations/CREDITS.md`.
///
/// This is a deliberate, user-requested celebration, so it plays even when the
/// OS asks for reduced motion.
void celebrate(BuildContext context) {
  playChime();
  showConfetti(context);
}

/// Confetti only (no sound).
void showConfetti(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      key: confettiKey,
      child: _ConfettiOverlay(onDone: remove),
    ),
  );
  overlay.insert(entry);
}

class _ConfettiOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiOverlay({required this.onDone});

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _safety;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    // AnimationBehavior.preserve is essential: with the OS "reduce motion"
    // setting on, the default behaviour shrinks every duration by 20x, which
    // turned this celebration into an invisible flash.
    _controller = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    _safety = Timer(_safetyTimeout, _finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _safety?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _safety?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Lottie.asset(
        'assets/animations/confetti.json',
        controller: _controller,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        onLoaded: (composition) {
          _controller.duration =
              composition.duration > _maxDuration ? _maxDuration : composition.duration;
          _controller.forward().whenCompleteOrCancel(_finish);
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Confetti asset failed: $error');
          // Never leave a stuck overlay behind.
          WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
