import 'package:flutter/material.dart';

class AppAnimation {
  AppAnimation._();

  // Durations
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const medium = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 450);

  // Page transition durations
  static const pageSlide = Duration(milliseconds: 280);
  static const pageModal = Duration(milliseconds: 300);
  static const pageFade = Duration(milliseconds: 200);

  // Curves
  static const standard = Curves.easeOutCubic;
  static const decelerate = Curves.easeOutQuart;
  static const emphasize = Curves.easeInOutCubic;
  static const spring = Curves.easeOutBack;

  // Press feedback
  static const pressScale = 0.97;
  static const pressDownDuration = Duration(milliseconds: 100);
  static const pressUpDuration = Duration(milliseconds: 150);

  // List stagger
  static const staggerDelay = Duration(milliseconds: 40);
  static const staggerMaxIndex = 8;
  static const listItemDuration = Duration(milliseconds: 300);
  static const listItemSlideOffset = 12.0;

  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  static Duration durationOf(BuildContext context, Duration duration) {
    return shouldReduceMotion(context) ? Duration.zero : duration;
  }
}
