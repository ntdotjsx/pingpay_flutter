import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ToastType { success, error, info, warning }

class AppToast {
  static void success(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? 'สำเร็จ', type: ToastType.success);
  }

  static void error(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? 'เกิดข้อผิดพลาด', type: ToastType.error);
  }

  static void info(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? 'แจ้งเตือน', type: ToastType.info);
  }

  static void warning(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? 'คำเตือน', type: ToastType.warning);
  }

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _HotToastWidget(
        title: title,
        message: message,
        type: type,
        isDark: isDark,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
        },
        duration: duration,
      ),
    );

    overlay.insert(entry);
  }
}

class _HotToastWidget extends StatefulWidget {
  final String? title;
  final String message;
  final ToastType type;
  final bool isDark;
  final VoidCallback onDismiss;
  final Duration duration;

  const _HotToastWidget({
    this.title,
    required this.message,
    required this.type,
    required this.isDark,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_HotToastWidget> createState() => _HotToastWidgetState();
}

class _HotToastWidgetState extends State<_HotToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _dismissTimer = Timer(widget.duration, () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    Color iconColor;
    Color bgColor;
    IconData icon;

    switch (widget.type) {
      case ToastType.success:
        iconColor = const Color(0xFF34C759);
        bgColor = widget.isDark ? const Color(0xFF1C2D22) : const Color(0xFFF2FBF5);
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        iconColor = const Color(0xFFFF3B30);
        bgColor = widget.isDark ? const Color(0xFF301B1B) : const Color(0xFFFFF5F5);
        icon = Icons.error_rounded;
        break;
      case ToastType.warning:
        iconColor = const Color(0xFFFF9500);
        bgColor = widget.isDark ? const Color(0xFF30261A) : const Color(0xFFFFFBF0);
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        iconColor = const Color(0xFF007AFF);
        bgColor = widget.isDark ? const Color(0xFF1A2634) : const Color(0xFFF0F7FF);
        icon = Icons.info_rounded;
        break;
    }

    return Positioned(
      top: topPadding + 12,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: GestureDetector(
                onTap: () async {
                  await _controller.reverse();
                  widget.onDismiss();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: widget.isDark ? AppColors.surfaceTile1 : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.title != null) ...[
                              Text(
                                widget.title!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDark
                                      ? AppColors.bodyOnDark
                                      : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              widget.message,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark
                                    ? AppColors.bodyMuted
                                    : AppColors.inkMuted80,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

