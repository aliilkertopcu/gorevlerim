import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/animation_constants.dart';

/// Fires a party-popper style confetti burst over the whole screen.
///
/// Reduced motion doesn't cancel the celebration (the user asked for it and it
/// is over in ~2 s) — it becomes calmer instead: fewer pieces, barely any spin.
void showConfetti(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final calm = !Anim.enabled(context);
  final scheme = Theme.of(context).colorScheme;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _ConfettiBurst(
        calm: calm,
        colors: [
          scheme.primary,
          scheme.tertiary,
          scheme.secondary,
          const Color(0xFF2E9E5B), // completed green
          const Color(0xFFE8890C), // warm orange
          const Color(0xFFC7A500), // gold
          const Color(0xFFE0457B), // pink
        ],
        onDone: () => entry.remove(),
      ),
    ),
  );
  overlay.insert(entry);
}

class _ConfettiBurst extends StatefulWidget {
  final List<Color> colors;
  final VoidCallback onDone;
  final bool calm;
  const _ConfettiBurst({required this.colors, required this.onDone, this.calm = false});

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  final double originX; // 0..1 of width
  final double angle; // launch angle (radians)
  final double velocity; // px/s
  final double size; // longest edge, logical px
  final double spin; // turns over the flight
  final double drift; // horizontal sway, px/s
  final int colorIndex;
  final bool rect; // ribbon vs dot

  _Particle(math.Random r, int colorCount, {bool calm = false})
      : originX = 0.30 + r.nextDouble() * 0.40,
        // Upward cone, ±50°
        angle = -math.pi / 2 + (r.nextDouble() - 0.5) * 0.56 * math.pi,
        velocity = 950 + r.nextDouble() * 350,
        size = 9 + r.nextDouble() * 11,
        spin = (r.nextDouble() - 0.5) * (calm ? 2 : 8),
        drift = (r.nextDouble() - 0.5) * 90,
        colorIndex = r.nextInt(colorCount),
        rect = r.nextInt(3) != 0; // mostly ribbons
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  late final Duration _lifetime;

  @override
  void initState() {
    super.initState();
    final rand = math.Random();
    final count = widget.calm ? 90 : 140;
    _particles = List.generate(
      count,
      (_) => _Particle(rand, widget.colors.length, calm: widget.calm),
    );
    _lifetime = Duration(milliseconds: widget.calm ? 2000 : 2600);
    _controller = AnimationController(vsync: this, duration: _lifetime)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ConfettiPainter(
          particles: _particles,
          colors: widget.colors,
          t: _controller.value,
          seconds: _controller.value * (_lifetime.inMilliseconds / 1000),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final List<Color> colors;
  final double t; // 0..1
  final double seconds; // elapsed flight time

  _ConfettiPainter({
    required this.particles,
    required this.colors,
    required this.t,
    required this.seconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 1000.0; // px/s² — gentle, so the burst hangs ~2.3 s
    final fade = t < 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.25);
    final paint = Paint();
    final launchY = size.height * 0.85;

    for (final p in particles) {
      final x = p.originX * size.width +
          math.cos(p.angle) * p.velocity * seconds +
          p.drift * seconds;
      final y = launchY +
          math.sin(p.angle) * p.velocity * seconds +
          0.5 * gravity * seconds * seconds;
      if (y > size.height + 30 || x < -30 || x > size.width + 30) continue;

      paint.color = colors[p.colorIndex].withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t * math.pi * 2);
      if (p.rect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2.6, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
