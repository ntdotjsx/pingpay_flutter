import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

class AppSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double cornerRadius;
  final double cornerSmoothing;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.cornerRadius = 12,
    this.cornerSmoothing = 0.6,
    this.shape = BoxShape.rectangle,
    this.margin,
  });

  const AppSkeleton.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        cornerRadius = size / 2,
        cornerSmoothing = 1.0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2C2D30) : const Color(0xFFE8ECEF);
    final highlightColor = isDark ? const Color(0xFF3D3E42) : const Color(0xFFF6F8FA);

    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          width: width,
          height: height,
          decoration: shape == BoxShape.circle
              ? BoxDecoration(color: baseColor, shape: BoxShape.circle)
              : ShapeDecoration(
                  color: baseColor,
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(
                        cornerRadius: cornerRadius,
                        cornerSmoothing: cornerSmoothing,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Pre-built Skeleton for Debt / Receivable Cards
class DebtCardSkeleton extends StatelessWidget {
  const DebtCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppSkeleton.circle(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppSkeleton(width: 80, height: 12, cornerRadius: 6),
                    SizedBox(height: 6),
                    AppSkeleton(width: 130, height: 16, cornerRadius: 8),
                  ],
                ),
              ),
              const AppSkeleton(width: 65, height: 22, cornerRadius: 8),
            ],
          ),
          const SizedBox(height: 14),
          const AppSkeleton(width: double.infinity, height: 1, cornerRadius: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppSkeleton(width: 140, height: 15, cornerRadius: 7),
                  SizedBox(height: 6),
                  AppSkeleton(width: 90, height: 12, cornerRadius: 6),
                ],
              ),
              const AppSkeleton(width: 85, height: 24, cornerRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pre-built Skeleton for Home Screen Daily Timeline / Bills List
class BillTimelineSkeleton extends StatelessWidget {
  const BillTimelineSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => const DebtCardSkeleton(),
      ),
    );
  }
}

/// Pre-built Skeleton for Bill Detail Screen
class BillDetailSkeleton extends StatelessWidget {
  const BillDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: ShapeDecoration(
              color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
              shape: const SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppSkeleton.circle(size: 44),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeleton(width: 160, height: 18, cornerRadius: 8),
                          SizedBox(height: 6),
                          AppSkeleton(width: 100, height: 12, cornerRadius: 6),
                        ],
                      ),
                    ),
                    AppSkeleton(width: 60, height: 24, cornerRadius: 8),
                  ],
                ),
                const SizedBox(height: 20),
                const AppSkeleton(width: double.infinity, height: 50, cornerRadius: 14),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppSkeleton(width: 140, height: 18, cornerRadius: 8),
          const SizedBox(height: 12),
          const DebtCardSkeleton(),
          const DebtCardSkeleton(),
        ],
      ),
    );
  }
}
