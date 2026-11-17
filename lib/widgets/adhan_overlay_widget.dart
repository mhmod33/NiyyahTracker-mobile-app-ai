import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/azan_service.dart';

/// A sleek top drop-down banner shown when Adhan time arrives.
/// Slides in from the top, takes up only the top portion of the screen
/// (does NOT take up the entire screen), shows prayer info with animated visuals,
/// and lets the user dismiss/mute the Adhan with an "X" button.
class AdhanOverlayWidget extends StatefulWidget {
  final String prayerName;
  final String prayerTime;

  const AdhanOverlayWidget({
    super.key,
    required this.prayerName,
    required this.prayerTime,
  });

  @override
  State<AdhanOverlayWidget> createState() => _AdhanOverlayWidgetState();
}

class _AdhanOverlayWidgetState extends State<AdhanOverlayWidget>
    with TickerProviderStateMixin {
  late AnimationController _soundWaveCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();

    _soundWaveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _soundWaveCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    AzanService().stopAzan();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Tap outside the banner to dismiss
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismiss,
                child: const SizedBox.expand(),
              ),
            ),

            // Top Drop-down Menu / Floating Banner (Does not take up entire screen)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF071E14),
                              Color(0xFF0F3E2B),
                              Color(0xFF0A2B1D),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_soundWaveCtrl, _glowCtrl]),
                          builder: (context, _) {
                            final glow = _glowCtrl.value;
                            return Row(
                              children: [
                                // Glowing Mosque Circle Icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1B6B46),
                                        Color(0xFF0F432B),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(alpha: 0.8),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.35 * glow,
                                        ),
                                        blurRadius: 14 * glow,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.mosque_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Prayer Title & Time & Animated Wave
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'حان الآن موعد أذان ${widget.prayerName}',
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (widget.prayerTime.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              widget.prayerTime,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.gold,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          // Animated Equalizer Sound Waves
                                          SizedBox(
                                            width: 46,
                                            height: 16,
                                            child: CustomPaint(
                                              painter: _SoundWavePainter(
                                                animValue: _soundWaveCtrl.value,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'الله أكبر • اضغط X لإيقاف الأذان',
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 11,
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Close (X) button to mute/stop Adhan
                                GestureDetector(
                                  onTap: _dismiss,
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sound wave painter — draws animated equalizer bars.
class _SoundWavePainter extends CustomPainter {
  final double animValue;

  _SoundWavePainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 5;
    final totalSpacing = size.width * 0.4;
    final barWidth = (size.width - totalSpacing) / barCount;
    final spacing = totalSpacing / (barCount - 1);

    final heights = [
      0.35 + 0.65 * animValue,
      0.80 - 0.50 * animValue,
      0.50 + 0.50 * animValue,
      0.90 - 0.60 * animValue,
      0.40 + 0.60 * animValue,
    ];

    for (int i = 0; i < barCount; i++) {
      final left = i * (barWidth + spacing);
      final barH = (heights[i] * size.height).clamp(4.0, size.height);
      final top = (size.height - barH) / 2;

      final paint = Paint()
        ..color = AppColors.gold.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barH),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWavePainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

/// Custom slide-from-top page route for the Adhan drop-down banner.
class AdhanSlideFromTopRoute extends PageRouteBuilder<void> {
  final String prayerName;
  final String prayerTime;

  AdhanSlideFromTopRoute({
    required this.prayerName,
    required this.prayerTime,
  }) : super(
          opaque: false,
          barrierColor: Colors.black.withValues(alpha: 0.15),
          barrierDismissible: true,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) {
            return AdhanOverlayWidget(
              prayerName: prayerName,
              prayerTime: prayerTime,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -1),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            );
          },
        );
}
