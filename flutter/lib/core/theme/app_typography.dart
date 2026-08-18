import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String fontFamily = 'LINESeedSansTH';

  static TextTheme createTextTheme(
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return TextTheme(
      // hero-display: 48px, 700 (Bd), -0.5px
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        letterSpacing: -0.5,
        height: 1.07,
      ),
      // display-lg: 36px, 700 (Bd)
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        letterSpacing: -0.3,
        height: 1.10,
      ),
      // display-md: 30px, 700 (Bd), -0.374px
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        letterSpacing: -0.374,
        height: 1.25,
      ),
      // lead: 26px, 700
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        letterSpacing: -0.2,
        height: 1.15,
      ),
      // tagline: 21px, 700
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        letterSpacing: -0.1,
        height: 1.19,
      ),
      // body-strong: 17px, 700
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        letterSpacing: -0.374,
        height: 1.24,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        letterSpacing: -0.2,
      ),
      // body: 17px, 400 (Rg), -0.374px
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: primaryTextColor,
        letterSpacing: -0.374,
        height: 1.47,
      ),
      // caption: 14px, 400 (Rg), -0.224px
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryTextColor,
        letterSpacing: -0.224,
        height: 1.43,
      ),
      // fine-print: 12px, 400 (Rg), -0.12px
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryTextColor,
        letterSpacing: -0.12,
        height: 1.3,
      ),
      // button-utility: 16px, 700 / 400
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Colors.white,
        letterSpacing: -0.2,
      ),
    );
  }
}
