import 'package:flutter/material.dart';

/// Global color tokens synchronized with Tailwind CSS theme.
class AppColors {
  AppColors._();

  // Primary Palette
  static const primary = Color(0xFF0F766E);
  static const primaryHover = Color(0xFF115E59);
  static const primaryLight = Color(0xFFCCFBF1);
  static const onPrimary = Color(0xFFFFFFFF);

  // Background & Surface
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const secondarySurface = Color(
    0xFFE2E8F0,
  ); // Disesuaikan dengan border/surface turunan

  // Text & Foreground
  static const foreground = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  // Aliases (untuk kompatibilitas penamaan lama jika diperlukan)
  static const primaryText = Color(0xFF0F172A);
  static const secondaryText = Color(0xFF64748B);

  // Borders
  static const border = Color(0xFFE2E8F0);

  // Status Colors
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const error = Color(0xFFDC2626); // Alias untuk danger
  static const info = Color(0xFF2563EB);

  // Chart Series (categorical identity, fixed order — not status colors,
  // never reused for state). Validated for CVD/contrast on `surface`.
  static const chartCash = Color(0xFF2A78D6);
  static const chartQris = Color(0xFFEB6834);
}
