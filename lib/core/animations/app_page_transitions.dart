import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'animation_constants.dart';

class AppPageTransition {
  AppPageTransition._();

  static CustomTransitionPage<T> slide<T>({
    required Widget child,
    LocalKey? key,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: AppAnimation.pageSlide,
      reverseTransitionDuration: AppAnimation.pageSlide,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppAnimation.shouldReduceMotion(context)) return child;

        final slideIn = Tween<Offset>(
          begin: const Offset(0.25, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AppAnimation.standard,
        ));

        final fadeIn = CurvedAnimation(
          parent: animation,
          curve: AppAnimation.standard,
        );

        final slideOut = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.08, 0),
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: AppAnimation.standard,
        ));

        final fadeOut = Tween<double>(
          begin: 1.0,
          end: 0.92,
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: AppAnimation.standard,
        ));

        return SlideTransition(
          position: slideOut,
          child: FadeTransition(
            opacity: fadeOut,
            child: SlideTransition(
              position: slideIn,
              child: FadeTransition(
                opacity: fadeIn,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  static CustomTransitionPage<T> modal<T>({
    required Widget child,
    LocalKey? key,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: AppAnimation.pageModal,
      reverseTransitionDuration: AppAnimation.pageModal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppAnimation.shouldReduceMotion(context)) return child;

        final slide = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AppAnimation.standard,
        ));

        final fade = CurvedAnimation(
          parent: animation,
          curve: AppAnimation.standard,
        );

        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        );
      },
    );
  }

  static CustomTransitionPage<T> fade<T>({
    required Widget child,
    LocalKey? key,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: AppAnimation.pageFade,
      reverseTransitionDuration: AppAnimation.pageFade,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppAnimation.shouldReduceMotion(context)) return child;

        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppAnimation.standard,
          ),
          child: child,
        );
      },
    );
  }
}
