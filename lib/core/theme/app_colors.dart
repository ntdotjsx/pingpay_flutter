import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand & Accent (Vibrant FinTech Orange)
  static const Color primary = Color(
    0xFFFF5000,
  ); // TrueMoney/Shopee Vibrant Orange
  static const Color primaryFocus = Color(0xFFFF6A00); // Focus Orange
  static const Color primaryOnDark = Color(0xFFFF7A00); // Bright Orange on Dark
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onDark = Color(0xFFFFFFFF);

  // Surfaces
  static const Color canvas = Color(0xFFFFFFFF); // Pure White
  static const Color canvasParchment = Color(0xFFF6F7F9); // Light Background
  static const Color surfacePearl = Color(0xFFFFF7ED); // Warm Pearl Capsule
  static const Color surfaceTile1 = Color(0xFF272729); // Near-Black Tile 1
  static const Color surfaceTile2 = Color(0xFF2A2A2C); // Near-Black Tile 2
  static const Color surfaceTile3 = Color(0xFF252527); // Near-Black Tile 3
  static const Color surfaceBlack = Color(0xFF101012); // Pure Black Background
  static const Color surfaceChipTranslucent = Color(0xFFD2D2D7);

  // Text / Inks
  static const Color ink = Color(0xFF1D1D1F); // Near-Black Ink
  static const Color body = Color(0xFF1D1D1F);
  static const Color bodyOnDark = Color(0xFFFFFFFF);
  static const Color bodyMuted = Color(0xFFCCCCCC);
  static const Color inkMuted80 = Color(0xFF333333);
  static const Color inkMuted48 = Color(0xFF7A7A7A);

  // Hairlines & Dividers
  static const Color dividerSoft = Color(0xFFF0F0F0);
  static const Color hairline = Color(0xFFE0E0E0);

  // Semantic Status (Financial & Badges)
  static const Color success = Color(0xFF00B14F); // Green (Settled/Paid)
  static const Color warning = Color(0xFFFF9500); // Apple Orange
  static const Color error = Color(0xFFFF3B30); // Apple Red
  static const Color info = Color(0xFFFF5000); // Orange

  // Backwards compatibility aliases
  static const Color primarySoft = Color(0xFFFFF3E8);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF6F7F9);
  static const Color backgroundDark = Color(0xFF101012);
  static const Color surfaceDark = Color(0xFF272729);
  static const Color successLight = Color(0xFFE8F8EE);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color errorLight = Color(0xFFFFEBEE);
}
