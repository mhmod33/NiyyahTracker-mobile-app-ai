import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class NotificationOverlay extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationOverlay({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.notifications_active_rounded,
    this.color = AppColors.darkGreen,
    this.duration = const Duration(seconds: 5),
    this.onTap,
    this.onDismiss,
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
    _startDismissTimer();
  }

  void _startDismissTimer() {
    _dismissTimer = Timer(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss?.call();
        Navigator.of(context).pop();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTap: () {
                    widget.onTap?.call();
                    _dismiss();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: isDark
                            ? [
                                widget.color.withOpacity(0.95),
                                widget.color.withOpacity(0.85),
                              ]
                            : [
                                widget.color,
                                widget.color.withOpacity(0.9),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          // Icon Section - Smaller
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Content Section - More compact
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  style: _f(
                                    sz: 14,
                                    fw: FontWeight.w700,
                                    c: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.body,
                                  style: _f(
                                    sz: 12,
                                    fw: FontWeight.w500,
                                    c: Colors.white.withOpacity(0.9),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          
                          // Close Button - Smaller
                          GestureDetector(
                            onTap: _dismiss,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
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
        ),
      ),
    );
  }
}

// Notification Manager for showing overlays
class NotificationOverlayManager {
  static void show(
    BuildContext context, {
    required String title,
    required String body,
    IconData icon = Icons.notifications_active_rounded,
    Color color = AppColors.darkGreen,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            NotificationOverlay(
              title: title,
              body: body,
              icon: icon,
              color: color,
              duration: duration,
              onTap: onTap,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 300),
        opaque: false,
        barrierDismissible: false,
      ),
    );
  }

  static void showAzkarNotification(
    BuildContext context, {
    required String type,
    String? customMessage,
  }) {
    final messages = {
      'morning': 'حان وقت أذكار الصباح',
      'evening': 'حان وقت أذكار المساء',
      'reminder': 'لا تنسى ذكر الله',
    };

    final icons = {
      'morning': Icons.wb_twilight_rounded,
      'evening': Icons.nights_stay_rounded,
      'reminder': Icons.timer_rounded,
    };

    final colors = {
      'morning': Colors.orange,
      'evening': Colors.indigo,
      'reminder': Colors.teal,
    };

    show(
      context,
      title: 'تذكير الأذكار',
      body: customMessage ?? messages[type] ?? 'تذكير بذكر الله',
      icon: icons[type] ?? Icons.notifications_active_rounded,
      color: colors[type] ?? AppColors.darkGreen,
    );
  }

  static void showPrayerNotification(
    BuildContext context, {
    required String prayerName,
  }) {
    show(
      context,
      title: 'أذان الصلاة',
      body: 'حان وقت صلاة $prayerName',
      icon: Icons.mosque_rounded,
      color: AppColors.darkGreen,
      duration: const Duration(seconds: 8),
    );
  }
}
