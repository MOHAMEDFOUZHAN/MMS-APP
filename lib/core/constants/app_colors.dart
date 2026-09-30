import 'package:flutter/material.dart';

class AppColors {
  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0F172A);       // Deep Navy
  static const Color backgroundDarker = Color(0xFF020617); // Near-black
  static const Color backgroundPurple = Color(0xFF1E1B4B); // Indigo-950 hint

  // ── Surface / Glass Layer ────────────────────────────────────────────────
  static const Color surface = Color(0xFF1E293B);          // Slate-800 solid
  static const Color surfaceLight = Color(0xFF334155);     // Slate-700
  static const Color glassBg = Color(0x731E293B);          // Slate-800 @ 45%
  static const Color glassSurface = Color(0x731E293B);     // Translucent Surface
  static const Color glassCard = Color(0x661E293B);        // Slate-800 @ 40%
  static const Color glassBorder = Color(0x14FFFFFF);      // White @ 8%
  static const Color glassHighlight = Color(0x08FFFFFF);   // White @ 3%

  // ── Primary — Indigo / Electric Violet ────────────────────────────────────
  static const Color primary = Color(0xFF6366F1);          // Indigo-500
  static const Color primaryLight = Color(0xFF818CF8);     // Indigo-400
  static const Color primaryGlow = Color(0x666366F1);      // Indigo @ 40%

  // ── Accent Colors ────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFFEC4899);        // Hot Pink / Rose-500
  static const Color accent = Color(0xFF06B6D4);           // Cyan-500
  static const Color cyan = Color(0xFF06B6D4);

  // ── Status Colors ────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);          // Emerald-500
  static const Color warning = Color(0xFFF59E0B);          // Amber-500
  static const Color danger = Color(0xFFEF4444);           // Red-500
  static const Color info = Color(0xFF06B6D4);             // Cyan-500

  // ── Text Colors ──────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9);      // Slate-100
  static const Color textSecondary = Color(0xFF94A3B8);    // Slate-400
  static const Color textMuted = Color(0xFF64748B);        // Slate-500

  // ── Glow BoxShadow Generator ─────────────────────────────────────────────
  static List<BoxShadow> neonGlow(Color color, {double blur = 20, double spread = 0}) => [
    BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: blur,
      spreadRadius: spread,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get glassShadow => const [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  ];
}
