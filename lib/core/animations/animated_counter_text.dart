import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'animation_constants.dart';

class AnimatedCounterText extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int decimalPlaces;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  const AnimatedCounterText({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 2,
    this.duration = AppAnimation.medium,
    this.curve = AppAnimation.standard,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    if (AppAnimation.shouldReduceMotion(context)) {
      final formatter = NumberFormat.currency(
        symbol: prefix,
        decimalDigits: decimalPlaces,
        customPattern: '$prefix#,##0${decimalPlaces > 0 ? '.${'0' * decimalPlaces}' : ''}$suffix',
      );
      return Text(
        formatter.format(value),
        style: style,
        textAlign: textAlign,
      );
    }

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: value, end: value),
        duration: duration,
        curve: curve,
        builder: (context, animatedValue, child) {
          final formatter = NumberFormat.currency(
            symbol: prefix,
            decimalDigits: decimalPlaces,
            customPattern: '$prefix#,##0${decimalPlaces > 0 ? '.${'0' * decimalPlaces}' : ''}$suffix',
          );
          return Text(
            formatter.format(animatedValue),
            style: style,
            textAlign: textAlign,
          );
        },
      ),
    );
  }
}
