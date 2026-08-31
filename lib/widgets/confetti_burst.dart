import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/animation_constants.dart';

/// Fires a short, self-cleaning confetti burst over the whole screen.
/// No-op when the OS asks for reduced motion.
void showConfetti(BuildContext context) {
  if (!Anim.enabled(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final scheme = Theme.of(context).colorScheme;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _ConfettiBurst(
        colors: [
          scheme.primary,
          scheme.tertiary,
          scheme.secondary,
          const Color(0xFF2E9E5B), // completed green
          const Color(0xFFE8890C), // warm orange
          const Color(0xFFC7A500), // gold
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
  const _ConfettiBurst({required this.colors, required this.onDone});

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  final double originX; // 0..1 of width
  final double angle; // launch angle (radians)
  final double velocity; // px/s
  final double size;
  final double spin; // rotations over lifetime
  final double drift; // horizontal sway
  final int colorIndex;
  final bool rect; // rectangle vs circle

  _Particle(math.Random r, int colorCount)
      : originX = 0.2 + r.nextDouble() * 0.6,
        angle = -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 0.9,
        velocity = 420 + r.nextDouble() * 480,
        size = 5 + r.nextDouble() * 6,
        spin = (r.nextDouble() - 0.5) * 10,
        drift = (r.nextDouble() - 0.5) * 140,
        colorIndex = r.nextInt(colorCount),
        rect = r.nextBool();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  static const _lifetime = Duration(milliseconds: 1600);
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rand = math.Random();
    _particles = List.generate(90, (_) => _Particle(rand, widget.colors.length));
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
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final List<Color> colors;
  final double t; // 0..1

  _ConfettiPainter({required this.particles, required this.colors, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 1250.0; // px/s²
    final seconds = t * 1.6;
    final fade = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3);
    final paint = Paint();

    for (final p in particles) {
      final x = p.originX * size.width +
          math.cos(p.angle) * p.velocity * seconds +
          p.drift * seconds;
      final y = size.height * 0.55 +
          math.sin(p.angle) * p.velocity * seconds +
          0.5 * gravity * seconds * seconds;
      if (y > size.height + 20) continue;

      paint.color = colors[p.colorIndex].withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t * math.pi * 2);
      if (p.rect) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2.4, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
