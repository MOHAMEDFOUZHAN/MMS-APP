import 'dart:math';
import 'package:flutter/material.dart';

/// Deep futuristic cosmic background for MIRA AI Assistant
/// Palette: #050019, #090022, #12003D, #1A0757, #240B68
/// Features subtle gradient nebulas and floating micro-star particles.
class MiraCosmicBackground extends StatefulWidget {
  final Widget child;

  const MiraCosmicBackground({
    super.key,
    required this.child,
  });

  @override
  State<MiraCosmicBackground> createState() => _MiraCosmicBackgroundState();
}

class _MiraCosmicBackgroundState extends State<MiraCosmicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Deep Space Base Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF050019), // Darkest void
                Color(0xFF090022), // Deep Space Violet
                Color(0xFF12003D), // Abyssal Indigo
                Color(0xFF1A0757), // Electric Midnight
                Color(0xFF090022), // Grounded bottom deep space
              ],
              stops: [0.0, 0.25, 0.55, 0.85, 1.0],
            ),
          ),
        ),

        // 2. Upper Ambient Nebula Glow (behind MIRA hero visual)
        Positioned(
          top: -60,
          left: 0,
          right: 0,
          height: 380,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.3),
                  radius: 0.9,
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.22), // Electric Purple
                    const Color(0xFF240B68).withValues(alpha: 0.16), // Deep Violet
                    const Color(0xFF06B6D4).withValues(alpha: 0.05), // Subtle Cyan flare
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 3. Subtle floating micro-stars & holographic dust CustomPainter
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _starController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _CosmicDustPainter(progress: _starController.value),
                );
              },
            ),
          ),
        ),

        // 4. Foreground Content
        widget.child,
      ],
    );
  }
}

class _CosmicDustPainter extends CustomPainter {
  final double progress;

  // Pre-calculated deterministic pseudo-random stars for consistent rendering
  static final List<Point<double>> _starPositions = List.generate(36, (i) {
    final random = Random(i * 97 + 13);
    return Point(random.nextDouble(), random.nextDouble());
  });

  _CosmicDustPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _starPositions.length; i++) {
      final pos = _starPositions[i];
      // Subtle vertical harmonic float
      final floatY = (pos.y + sin(progress * 2 * pi + i) * 0.015) % 1.0;
      final x = pos.x * size.width;
      final y = floatY * size.height;

      // Twinkle opacity
      final twinkle = (sin(progress * 2 * pi * 2 + i * 1.5) + 1.0) / 2.0;
      final opacity = (0.15 + twinkle * 0.45).clamp(0.0, 1.0);

      // Micro color variation: violet, cyan, soft white
      if (i % 3 == 0) {
        paint.color = const Color(0xFF8B5CF6).withValues(alpha: opacity * 0.7); // Violet
      } else if (i % 3 == 1) {
        paint.color = const Color(0xFF22D3EE).withValues(alpha: opacity * 0.6); // Cyan
      } else {
        paint.color = Colors.white.withValues(alpha: opacity * 0.5);
      }

      final radius = (i % 5 == 0) ? 1.6 : 1.0;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicDustPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
