import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/mira_state.dart';

/// Futuristic MIRA AI Entity & Orbital Energy Visual
/// Completely custom-painted 60fps holographic digital companion.
/// Features:
/// - Original MIRA AI digital companion silhouette (holographic visor, expressive glowing eyes, blinking, state reactivity)
/// - Multi-layered tilted 3D orbital rings with traveling photon beacons
/// - Floating holographic particle cloud (micro-diamonds & glowing energy dots)
/// - Radial acoustic soundwave ripples responding to audio amplitude
/// - State-specific transitions: IDLE, LISTENING, THINKING, SPEAKING, ERROR
class MiraCoreWave extends StatefulWidget {
  final MiraStateMode mode;
  final double audioAmplitude; // 0.0 to 1.0
  final double size;
  final VoidCallback? onCoreTap;
  final bool showLabel;

  const MiraCoreWave({
    super.key,
    required this.mode,
    this.audioAmplitude = 0.0,
    this.size = 220,
    this.onCoreTap,
    this.showLabel = true,
  });

  @override
  State<MiraCoreWave> createState() => _MiraCoreWaveState();
}

class _MiraCoreWaveState extends State<MiraCoreWave> with TickerProviderStateMixin {
  // 1. Continuous breathing and levitation controller (3.6s cycle)
  late final AnimationController _levitateController;

  // 2. Orbital lines rotation controller (8s cycle)
  late final AnimationController _orbitController;

  // 3. Audio & Voice wave ripple controller (1.6s cycle)
  late final AnimationController _waveController;

  // 4. Natural eye blink controller (triggers every 4.2s)
  late final AnimationController _blinkController;

  // 5. Thinking scanner sweep controller
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();

    _levitateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7500),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant MiraCoreWave oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Speed up orbital rotation & scanning when thinking/processing
    if (widget.mode == MiraStateMode.processing && oldWidget.mode != MiraStateMode.processing) {
      _orbitController.duration = const Duration(milliseconds: 2200);
      _orbitController.repeat();
      _scanController.duration = const Duration(milliseconds: 800);
      _scanController.repeat(reverse: true);
    } else if (widget.mode != MiraStateMode.processing && oldWidget.mode == MiraStateMode.processing) {
      _orbitController.duration = const Duration(milliseconds: 7500);
      _orbitController.repeat();
      _scanController.duration = const Duration(milliseconds: 1400);
      _scanController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _levitateController.dispose();
    _orbitController.dispose();
    _waveController.dispose();
    _blinkController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onCoreTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _levitateController,
          _orbitController,
          _waveController,
          _blinkController,
          _scanController,
        ]),
        builder: (context, _) {
          return SizedBox(
            width: widget.size,
            height: widget.size + (widget.showLabel ? 28 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Holographic Canvas
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _MiraEntityPainter(
                      mode: widget.mode,
                      levitateValue: _levitateController.value,
                      orbitValue: _orbitController.value,
                      waveValue: _waveController.value,
                      blinkValue: _blinkController.value,
                      scanValue: _scanController.value,
                      amplitude: widget.audioAmplitude,
                    ),
                  ),
                ),

                if (widget.showLabel) ...[
                  const SizedBox(height: 6),
                  _buildStatusIndicator(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final (label, color) = switch (widget.mode) {
      MiraStateMode.idle => ('MIRA AI • READY', const Color(0xFF8B5CF6)),
      MiraStateMode.listening => ('LISTENING...', const Color(0xFF22D3EE)),
      MiraStateMode.processing => ('THINKING...', const Color(0xFFA78BFA)),
      MiraStateMode.speaking => ('SPEAKING...', const Color(0xFF38BDF8)),
      MiraStateMode.responding => ('RESPONDING...', const Color(0xFFEC4899)),
      MiraStateMode.error => ('NEEDS ATTENTION', AppColors.danger),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 5.5,
          height: 5.5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: (widget.size * 0.05).clamp(9.5, 12.0),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: color.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

/// CustomPainter rendering the living MIRA AI Entity & Orbital Cosmos
class _MiraEntityPainter extends CustomPainter {
  final MiraStateMode mode;
  final double levitateValue;
  final double orbitValue;
  final double waveValue;
  final double blinkValue;
  final double scanValue;
  final double amplitude;

  _MiraEntityPainter({
    required this.mode,
    required this.levitateValue,
    required this.orbitValue,
    required this.waveValue,
    required this.blinkValue,
    required this.scanValue,
    required this.amplitude,
  });

  // Deterministic seed particle positions
  static final List<_ParticleData> _particles = List.generate(24, (i) {
    final r = Random(i * 123 + 47);
    return _ParticleData(
      orbitRadius: 0.42 + r.nextDouble() * 0.50,
      orbitSpeed: 0.4 + r.nextDouble() * 0.8,
      phaseOffset: r.nextDouble() * 2 * pi,
      tiltAngle: (r.nextDouble() - 0.5) * 0.8,
      size: 1.2 + r.nextDouble() * 2.2,
      isDiamond: i % 4 == 0,
      colorType: i % 4,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = min(size.width, size.height);
    final scale = minDim / 220.0;

    // 1. Ambient Volumetric Glow (Behind everything)
    _paintVolumetricBloom(canvas, center, scale);

    // 2. Audio-reactive concentric acoustic wave ripples
    if (mode == MiraStateMode.listening || mode == MiraStateMode.speaking || amplitude > 0.05) {
      _paintAcousticWaves(canvas, center, scale);
    }

    // 3. Curved Futuristic Orbital Lines (Background half)
    _paintOrbitalRings(canvas, center, scale, isBackground: true);

    // 4. Floating Holographic Particles (Background depth)
    _paintParticleCloud(canvas, center, scale, isBackground: true);

    // 5. The Living MIRA AI Entity (Companion Head + Visor + Optics)
    _paintMiraCompanion(canvas, center, scale);

    // 6. Floating Holographic Particles (Foreground depth)
    _paintParticleCloud(canvas, center, scale, isBackground: false);

    // 7. Curved Futuristic Orbital Lines (Foreground passing)
    _paintOrbitalRings(canvas, center, scale, isBackground: false);
  }

  // ────────────────────────────────────────────────────────────
  // 1. Ambient Volumetric Bloom
  // ────────────────────────────────────────────────────────────
  void _paintVolumetricBloom(Canvas canvas, Offset center, double scale) {
    final bloomRadius = 88.0 * scale * (1.0 + (mode == MiraStateMode.listening ? amplitude * 0.35 : 0.08 * sin(levitateValue * pi)));
    final glowColor = _getPrimaryGlowColor();

    final bloomPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: mode == MiraStateMode.listening ? 0.38 : 0.22),
          const Color(0xFF1E0B4B).withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: bloomRadius));

    canvas.drawCircle(center, bloomRadius, bloomPaint);
  }

  // ────────────────────────────────────────────────────────────
  // 2. Acoustic Radial Shockwave Ripples (Voice Reactive)
  // ────────────────────────────────────────────────────────────
  void _paintAcousticWaves(Canvas canvas, Offset center, double scale) {
    final effectiveAmp = max(amplitude, 0.25);
    final ringCount = 3;

    for (int i = 0; i < ringCount; i++) {
      final waveProgress = (waveValue + (i / ringCount)) % 1.0;
      final waveRadius = (44.0 + waveProgress * 56.0 * (1.0 + effectiveAmp * 0.4)) * scale;
      final opacity = (1.0 - waveProgress) * (0.35 + effectiveAmp * 0.45);

      final wavePaint = Paint()
        ..color = (mode == MiraStateMode.listening ? const Color(0xFF22D3EE) : const Color(0xFF8B5CF6))
            .withValues(alpha: opacity.clamp(0.0, 0.8))
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.5 - waveProgress * 0.8) * scale;

      canvas.drawCircle(center, waveRadius, wavePaint);
    }
  }

  // ────────────────────────────────────────────────────────────
  // 3. Orbital Lines System (Multiple elliptical 3D orbits)
  // ────────────────────────────────────────────────────────────
  void _paintOrbitalRings(Canvas canvas, Offset center, double scale, {required bool isBackground}) {
    // Primary Orbit 1: Tilted -24 degrees
    _drawEllipticalOrbit(
      canvas: canvas,
      center: center,
      radiusX: 96.0 * scale,
      radiusY: 38.0 * scale,
      tiltAngle: -24.0 * pi / 180,
      orbitProgress: orbitValue,
      primaryColor: const Color(0xFF8B5CF6), // Neon Violet
      accentColor: const Color(0xFF22D3EE),  // Cyan
      strokeWidth: 1.2 * scale,
      hasBeacon: true,
      isBackground: isBackground,
    );

    // Secondary Orbit 2: Tilted +36 degrees
    _drawEllipticalOrbit(
      canvas: canvas,
      center: center,
      radiusX: 84.0 * scale,
      radiusY: 30.0 * scale,
      tiltAngle: 36.0 * pi / 180,
      orbitProgress: (orbitValue * 1.35 + 0.5) % 1.0,
      primaryColor: const Color(0xFF22D3EE), // Cyan
      accentColor: const Color(0xFFEC4899),  // Pink
      strokeWidth: 1.0 * scale,
      hasBeacon: true,
      isBackground: isBackground,
    );

    // Tertiary Horizon Equator Arc: Faint dashed boundary
    if (!isBackground) {
      final equatorPaint = Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * scale;
      final equatorRect = Rect.fromCenter(
        center: center,
        width: 170.0 * scale,
        height: 48.0 * scale,
      );
      canvas.drawOval(equatorRect, equatorPaint);
    }
  }

  void _drawEllipticalOrbit({
    required Canvas canvas,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double tiltAngle,
    required double orbitProgress,
    required Color primaryColor,
    required Color accentColor,
    required double strokeWidth,
    required bool hasBeacon,
    required bool isBackground,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tiltAngle);

    final orbitRect = Rect.fromCenter(center: Offset.zero, width: radiusX * 2, height: radiusY * 2);

    // Back half = -pi to 0 (top/back), Front half = 0 to pi (bottom/front)
    final sweepStart = isBackground ? pi : 0.0;
    final sweepAngle = pi;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: isBackground ? 0.20 : 0.45),
          accentColor.withValues(alpha: isBackground ? 0.35 : 0.75),
          primaryColor.withValues(alpha: isBackground ? 0.20 : 0.45),
        ],
      ).createShader(orbitRect);

    canvas.drawArc(orbitRect, sweepStart, sweepAngle, false, ringPaint);

    // Traveling Energy Photon Beacon along this ellipse
    if (hasBeacon) {
      final beaconAngle = orbitProgress * 2 * pi;
      // In 3D perspective, sin(beaconAngle) > 0 is front, < 0 is back
      final isFront = sin(beaconAngle) >= 0;

      if (isFront == !isBackground) {
        final bx = radiusX * cos(beaconAngle);
        final by = radiusY * sin(beaconAngle);

        // Core light photon
        final beaconPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(bx, by), 2.4 * (isFront ? 1.2 : 0.8), beaconPaint);

        // Surrounding energy halo
        final haloPaint = Paint()
          ..color = accentColor.withValues(alpha: isFront ? 0.8 : 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(bx, by), 5.2 * (isFront ? 1.2 : 0.8), haloPaint);
      }
    }

    canvas.restore();
  }

  // ────────────────────────────────────────────────────────────
  // 4. Floating Holographic Particles (With 3D Parallax)
  // ────────────────────────────────────────────────────────────
  void _paintParticleCloud(Canvas canvas, Offset center, double scale, {required bool isBackground}) {
    for (final p in _particles) {
      final currentAngle = (orbitValue * p.orbitSpeed * 2 * pi + p.phaseOffset) % (2 * pi);
      final isFront = sin(currentAngle) >= 0;

      if (isFront == !isBackground) {
        final rX = p.orbitRadius * 105.0 * scale;
        final rY = p.orbitRadius * 48.0 * scale;

        // Apply tilt
        final rawX = rX * cos(currentAngle);
        final rawY = rY * sin(currentAngle);
        final cosTilt = cos(p.tiltAngle);
        final sinTilt = sin(p.tiltAngle);
        final px = center.dx + (rawX * cosTilt - rawY * sinTilt);
        final py = center.dy + (rawX * sinTilt + rawY * cosTilt);

        final pColor = switch (p.colorType) {
          0 => const Color(0xFF8B5CF6), // Neon Violet
          1 => const Color(0xFF22D3EE), // Cyan
          2 => const Color(0xFFEC4899), // Pink
          _ => Colors.white,
        };

        final alpha = (isFront ? 0.85 : 0.40) * (mode == MiraStateMode.listening ? 1.0 : 0.8);
        final paint = Paint()
          ..color = pColor.withValues(alpha: alpha)
          ..style = PaintingStyle.fill;

        if (p.isDiamond) {
          // Draw diamond fragment
          final dSize = p.size * scale * (isFront ? 1.2 : 0.85);
          final path = Path()
            ..moveTo(px, py - dSize)
            ..lineTo(px + dSize * 0.8, py)
            ..lineTo(px, py + dSize)
            ..lineTo(px - dSize * 0.8, py)
            ..close();
          canvas.drawPath(path, paint);
        } else {
          canvas.drawCircle(Offset(px, py), p.size * scale * (isFront ? 1.1 : 0.75), paint);
        }
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  // 5. The Living MIRA AI Entity (Contoured Head, Glass Visor, Digital Eyes)
  // ────────────────────────────────────────────────────────────
  void _paintMiraCompanion(Canvas canvas, Offset center, double scale) {
    // Levitation physics: gentle float up and down
    final levitateOffset = sin(levitateValue * 2 * pi) * 5.0 * scale;
    final entityCenter = Offset(center.dx, center.dy + levitateOffset);

    // Floating segmented Halo hovering above head
    _paintFloatingHalo(canvas, entityCenter, scale);

    // Obsidian Glass Cranial Visor Silhouette
    final headWidth = 72.0 * scale;
    final headHeight = 84.0 * scale;
    final headRect = Rect.fromCenter(
      center: entityCenter,
      width: headWidth,
      height: headHeight,
    );

    // A. Outer Specular Neon Rim Aura
    final rimColor = _getPrimaryGlowColor();
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF22D3EE).withValues(alpha: 0.9), // Cyan rim top-left
          rimColor.withValues(alpha: 0.95),              // Neon Purple
          const Color(0xFFEC4899).withValues(alpha: 0.7), // Pink reflection
        ],
      ).createShader(headRect);

    // Outer Head Shape: Sophisticated rounded ergonomic capsule
    final headRRect = RRect.fromRectAndRadius(headRect, Radius.circular(36.0 * scale));
    canvas.drawRRect(headRRect, rimPaint);

    // B. Inner Obsidian Glass Faceplate Cavity
    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.2),
        radius: 0.85,
        colors: [
          const Color(0xFF1F0C42), // Deep internal luminescence
          const Color(0xFF0F0422), // Abyssal obsidian glass
          const Color(0xFF070014), // Void edge
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(headRect);
    canvas.drawRRect(headRRect, innerPaint);

    // C. Visor Horizontal Cybernetic Micro-Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * scale;
    for (double y = headRect.top + 16 * scale; y < headRect.bottom - 16 * scale; y += 8 * scale) {
      canvas.drawLine(
        Offset(headRect.left + 10 * scale, y),
        Offset(headRect.right - 10 * scale, y),
        gridPaint,
      );
    }

    // D. Visor Specular Glass Sheen (Gloss curve on upper visor)
    final sheenPath = Path()
      ..moveTo(headRect.left + 8 * scale, headRect.top + 20 * scale)
      ..quadraticBezierTo(
        entityCenter.dx,
        headRect.top + 10 * scale,
        headRect.right - 8 * scale,
        headRect.top + 20 * scale,
      )
      ..lineTo(headRect.right - 12 * scale, headRect.top + 34 * scale)
      ..quadraticBezierTo(
        entityCenter.dx,
        headRect.top + 22 * scale,
        headRect.left + 12 * scale,
        headRect.top + 34 * scale,
      )
      ..close();

    final sheenPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(headRect);
    canvas.drawPath(sheenPath, sheenPaint);

    // E. Thinking Laser Scanner Sweep
    if (mode == MiraStateMode.processing) {
      _paintThinkingScanner(canvas, headRect, scale);
    }

    // F. Expressive Digital Optics / Eyes
    _paintDigitalEyes(canvas, entityCenter, scale);

    // G. Speaking Voice Frequency Resonator (Under eyes)
    if (mode == MiraStateMode.speaking || amplitude > 0.08) {
      _paintVoiceResonator(canvas, entityCenter, scale);
    }
  }

  // ────────────────────────────────────────────────────────────
  // Floating Halo Crown above companion head
  // ────────────────────────────────────────────────────────────
  void _paintFloatingHalo(Canvas canvas, Offset entityCenter, double scale) {
    final haloCenter = Offset(entityCenter.dx, entityCenter.dy - 48.0 * scale);
    final haloRect = Rect.fromCenter(
      center: haloCenter,
      width: 44.0 * scale,
      height: 12.0 * scale,
    );

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF22D3EE).withValues(alpha: 0.1),
          const Color(0xFF22D3EE).withValues(alpha: 0.9),
          const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ],
        transform: GradientRotation(orbitValue * 2 * pi),
      ).createShader(haloRect);

    canvas.drawOval(haloRect, haloPaint);
  }

  // ────────────────────────────────────────────────────────────
  // Thinking Holographic Scanner Beam
  // ────────────────────────────────────────────────────────────
  void _paintThinkingScanner(Canvas canvas, Rect headRect, double scale) {
    final scanY = headRect.top + 22 * scale + scanValue * (headRect.height - 44 * scale);

    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF22D3EE).withValues(alpha: 0.7),
          const Color(0xFFA78BFA),
          const Color(0xFF22D3EE).withValues(alpha: 0.7),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(headRect.left, scanY - 2, headRect.right, scanY + 2))
      ..strokeWidth = 1.8 * scale;

    canvas.drawLine(
      Offset(headRect.left + 8 * scale, scanY),
      Offset(headRect.right - 8 * scale, scanY),
      beamPaint,
    );
  }

  // ────────────────────────────────────────────────────────────
  // Expressive Digital Optics / Eyes (The Sentient Spark of MIRA)
  // ────────────────────────────────────────────────────────────
  void _paintDigitalEyes(Canvas canvas, Offset entityCenter, double scale) {
    // Eye spacing and size
    final eyeSpacing = 16.0 * scale;
    final eyeWidth = 13.0 * scale;
    var eyeHeight = 10.0 * scale;

    // Natural Soft Blink interpolation: every 4.2s, smoothly close for 180ms
    // blinkValue cycles 0.0 to 1.0. Near 0.95 - 1.0 is blink window.
    double blinkScaleY = 1.0;
    if (blinkValue > 0.92 && mode != MiraStateMode.listening) {
      final blinkProgress = (blinkValue - 0.92) / 0.08;
      blinkScaleY = (sin(blinkProgress * pi) > 0.0) ? max(0.08, 1.0 - sin(blinkProgress * pi) * 0.92) : 1.0;
    }

    // State adjustments
    if (mode == MiraStateMode.listening) {
      eyeHeight *= (1.15 + amplitude * 0.2); // Eyes widen attentively
    } else if (mode == MiraStateMode.processing) {
      eyeHeight *= 0.85; // Focused squint
    }

    eyeHeight *= blinkScaleY;

    final eyeCenterY = entityCenter.dy - 4.0 * scale;
    final leftEyeCenter = Offset(entityCenter.dx - eyeSpacing, eyeCenterY);
    final rightEyeCenter = Offset(entityCenter.dx + eyeSpacing, eyeCenterY);

    final eyeColor = _getEyeColor();

    for (final eyeCenter in [leftEyeCenter, rightEyeCenter]) {
      final eyeRect = Rect.fromCenter(
        center: eyeCenter,
        width: eyeWidth,
        height: max(eyeHeight, 1.5 * scale),
      );

      // Eye Outer Halo
      final haloPaint = Paint()
        ..color = eyeColor.withValues(alpha: mode == MiraStateMode.listening ? 0.45 : 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: eyeCenter, width: eyeWidth * 1.5, height: max(eyeHeight * 1.6, 3 * scale)),
        haloPaint,
      );

      // Eye Aperture Body (Vibrant Cyan-Violet gradient)
      final eyePaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            eyeColor,
            eyeColor.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(eyeRect);

      canvas.drawOval(eyeRect, eyePaint);

      // In listening mode: draw micro audio-reticle around each eye
      if (mode == MiraStateMode.listening && blinkScaleY > 0.5) {
        final reticlePaint = Paint()
          ..color = const Color(0xFF22D3EE).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 * scale;
        canvas.drawCircle(eyeCenter, eyeWidth * 0.85 * (1.0 + amplitude * 0.25), reticlePaint);
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  // Speaking Voice Resonator Waveform below eyes
  // ────────────────────────────────────────────────────────────
  void _paintVoiceResonator(Canvas canvas, Offset entityCenter, double scale) {
    final waveY = entityCenter.dy + 18.0 * scale;
    final waveWidth = 26.0 * scale;
    final vocalAmp = max(amplitude, 0.2) * 5.0 * scale;

    final path = Path();
    path.moveTo(entityCenter.dx - waveWidth / 2, waveY);

    for (double x = -waveWidth / 2; x <= waveWidth / 2; x += 2.0 * scale) {
      final normalX = x / (waveWidth / 2);
      final envelope = 1.0 - (normalX * normalX); // Parabolic fade at ends
      final yOffset = sin((normalX * 3.5 + waveValue * 2) * pi) * vocalAmp * envelope;
      path.lineTo(entityCenter.dx + x, waveY + yOffset);
    }

    final wavePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale;

    canvas.drawPath(path, wavePaint);
  }

  // ────────────────────────────────────────────────────────────
  // Color Selectors
  // ────────────────────────────────────────────────────────────
  Color _getPrimaryGlowColor() {
    return switch (mode) {
      MiraStateMode.idle => const Color(0xFF7C3AED),       // Electric Purple
      MiraStateMode.listening => const Color(0xFF22D3EE),  // Cyan
      MiraStateMode.processing => const Color(0xFFA78BFA), // Violet
      MiraStateMode.speaking => const Color(0xFF38BDF8),    // Soft Blue
      MiraStateMode.responding => const Color(0xFFEC4899),  // Pink
      MiraStateMode.error => AppColors.danger,
    };
  }

  Color _getEyeColor() {
    return switch (mode) {
      MiraStateMode.idle => const Color(0xFF22D3EE),       // Friendly Cyan
      MiraStateMode.listening => const Color(0xFF38BDF8),  // Electric Sky
      MiraStateMode.processing => const Color(0xFFA78BFA), // Lavender
      MiraStateMode.speaking => const Color(0xFF22D3EE),   // Radiant Cyan
      MiraStateMode.responding => const Color(0xFFEC4899), // Neon Pink
      MiraStateMode.error => const Color(0xFFF59E0B),      // Amber alert
    };
  }

  @override
  bool shouldRepaint(covariant _MiraEntityPainter oldDelegate) {
    return true; // 60fps dynamic animation driven by merged controllers
  }
}

class _ParticleData {
  final double orbitRadius;
  final double orbitSpeed;
  final double phaseOffset;
  final double tiltAngle;
  final double size;
  final bool isDiamond;
  final int colorType;

  _ParticleData({
    required this.orbitRadius,
    required this.orbitSpeed,
    required this.phaseOffset,
    required this.tiltAngle,
    required this.size,
    required this.isDiamond,
    required this.colorType,
  });
}
