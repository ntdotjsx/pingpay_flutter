import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 17.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double section = 80.0;

  // Insets
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 20.0,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(24.0);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 22.0,
    vertical: 11.0,
  );
}

class AppRadius {
  AppRadius._();

  static const double none = 0.0;
  static const double xs = 5.0;
  static const double sm = 8.0;
  static const double md = 11.0;
  static const double lg = 18.0;
  static const double pill = 9999.0;
  static const double full = 9999.0;

  static const BorderRadius roundedNone = BorderRadius.zero;
  static const BorderRadius roundedXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedPill = BorderRadius.all(
    Radius.circular(pill),
  );
  static const BorderRadius roundedFull = BorderRadius.all(
    Radius.circular(full),
  );

  // Backwards compatibility alias
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(lg));
}
