import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../onboarding/onboarding_page.dart';

class PremiumSplashPage extends StatefulWidget {
  const PremiumSplashPage({super.key, this.skipNavigation = false});

  /// When true, the splash stays on screen (used for visual tests).
  final bool skipNavigation;

  @override
  State<PremiumSplashPage> createState() => _PremiumSplashPageState();
}

class _PremiumSplashPageState extends State<PremiumSplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final AnimationController _glowController;
  late final AnimationController _progressController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 1.03, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();
    _scaleController.forward();
    _glowController.repeat(reverse: true);
    _progressController.forward();

    if (!widget.skipNavigation) {
      Timer(const Duration(milliseconds: 3000), _navigateBasedOnAuth);
    }
  }

  void _navigateBasedOnAuth() {
    if (!mounted) return;
    final authProvider = context.read<AppAuthProvider>();
    if (authProvider.isLoading) {
      Timer(const Duration(milliseconds: 500), _navigateBasedOnAuth);
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            authProvider.isAuthenticated
                ? const DashboardPage()
                : const OnboardingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;
    final w = size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF00180F),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF003F32),
        body: Container(
          width: w,
          height: h,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF001A14),
                Color(0xFF003F32),
                Color(0xFF003A2E),
                Color(0xFF002820),
                Color(0xFF00180F),
              ],
              stops: [0.0, 0.25, 0.50, 0.75, 1.0],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Subtle gold decorative curves (background) ──
              Positioned.fill(
                child: CustomPaint(painter: _SubtleBackgroundPainter()),
              ),

              // ── Subtle warm ambient glow behind the scene ──
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  final g = _glowAnimation.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Warm glow at bottom-center where the scene sits
                      Positioned(
                        left: w * 0.10,
                        bottom: h * 0.06,
                        child: IgnorePointer(
                          child: Container(
                            width: w * 0.80,
                            height: h * 0.30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(w * 0.4),
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFFD6A84B)
                                      .withValues(alpha: 0.12 * g),
                                  Color(0xFFD6A84B)
                                      .withValues(alpha: 0.04 * g),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Soft glow behind logo area
                      Positioned(
                        top: h * 0.04,
                        left: w * 0.20,
                        right: w * 0.20,
                        child: IgnorePointer(
                          child: Container(
                            height: w * 0.40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFFD6A84B)
                                      .withValues(alpha: 0.06 * g),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // ── Main content ──
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      children: [
                        // ── Top spacing ──
                        SizedBox(height: h * 0.035),

                        // ── Logo (sharp, centered, no container) ──
                        Image.asset(
                          'assets/splash/basair_logo.png',
                          width: w * 0.36,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),

                        SizedBox(height: h * 0.012),

                        // ── Gold ornamental divider ──
                        CustomPaint(
                          size: const Size(200, 28),
                          painter: _GoldDividerPainter(),
                        ),

                        SizedBox(height: h * 0.004),

                        // ── Arabic tagline ──
                        Text(
                          'فمن أبصر فلنفسه',
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF5E8C8),
                            letterSpacing: 1.4,
                            height: 1.5,
                            shadows: const [
                              Shadow(
                                color: Color(0x80D6A84B),
                                offset: Offset(0, 0),
                                blurRadius: 10,
                              ),
                              Shadow(
                                color: Colors.black45,
                                offset: Offset(0, 2),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),

                        // ── Reduced spacing — push scene closer to tagline ──
                        SizedBox(height: h * 0.015),

                        // ── Bottom 3D Islamic scene (combined asset) ──
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: w * 0.03,
                            ),
                            child: Image.asset(
                              'assets/splash/Illuminated Ramadan Lantern and Quran Scene.png',
                              width: w * 0.94,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),

                        // ── Animated gold progress bar ──
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: math.max(h * 0.028, 16),
                                top: h * 0.008,
                                left: w * 0.32,
                                right: w * 0.32,
                              ),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  color: const Color(0xFF002820),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progressAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(99),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFE6C57A),
                                          Color(0xFFD6A84B),
                                          Color(0xFFE6C57A),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFD6A84B)
                                              .withValues(alpha: 0.45),
                                          blurRadius: 6,
                                          spreadRadius: 0.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Subtle gold decorative curves painted on the background
// ─────────────────────────────────────────────────────────────
class _SubtleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD6A84B).withValues(alpha: 0.18);

    // Top-left decorative curve (outer)
    final topLeft = Path()
      ..moveTo(0, size.height * 0.14)
      ..cubicTo(
        size.width * 0.08,
        size.height * 0.04,
        size.width * 0.18,
        size.height * 0.02,
        size.width * 0.34,
        0,
      );
    canvas.drawPath(topLeft, gold);

    // Top-left decorative curve (inner, lighter)
    final topLeftInner = Path()
      ..moveTo(0, size.height * 0.09)
      ..cubicTo(
        size.width * 0.10,
        size.height * 0.03,
        size.width * 0.16,
        size.height * 0.015,
        size.width * 0.24,
        0,
      );
    canvas.drawPath(
      topLeftInner,
      gold..color = const Color(0xFFD6A84B).withValues(alpha: 0.11),
    );

    // Bottom-right decorative curve
    final bottomRight = Path()
      ..moveTo(size.width, size.height * 0.86)
      ..cubicTo(
        size.width * 0.90,
        size.height * 0.96,
        size.width * 0.78,
        size.height * 0.98,
        size.width * 0.62,
        size.height,
      );
    canvas.drawPath(
      bottomRight,
      gold..color = const Color(0xFFD6A84B).withValues(alpha: 0.18),
    );

    // Subtle radial veil for depth
    final veil = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00513D).withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.40),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawRect(Offset.zero & size, veil);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// Gold ornamental divider with 8-point star
// ─────────────────────────────────────────────────────────────
class _GoldDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD6A84B);

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Left curve
    final left = Path()
      ..moveTo(cx - 14, cy)
      ..cubicTo(cx - 36, cy - 5, cx - 64, cy + 4, cx - 90, cy);
    canvas.drawPath(left, paint);

    // Right curve
    final right = Path()
      ..moveTo(cx + 14, cy)
      ..cubicTo(cx + 36, cy - 5, cx + 64, cy + 4, cx + 90, cy);
    canvas.drawPath(right, paint);

    // End dots
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 90, cy), 1.6, paint);
    canvas.drawCircle(Offset(cx + 90, cy), 1.6, paint);

    // Center 8-point star ornament
    final star = Path();
    const rOuter = 6.0;
    const rInner = 2.8;
    for (int i = 0; i < 8; i++) {
      final outerA = -math.pi / 2 + i * math.pi / 4;
      final innerA = outerA + math.pi / 8;
      final op = Offset(
        cx + math.cos(outerA) * rOuter,
        cy + math.sin(outerA) * rOuter,
      );
      final ip = Offset(
        cx + math.cos(innerA) * rInner,
        cy + math.sin(innerA) * rInner,
      );
      if (i == 0) {
        star.moveTo(op.dx, op.dy);
      } else {
        star.lineTo(op.dx, op.dy);
      }
      star.lineTo(ip.dx, ip.dy);
    }
    star.close();
    canvas.drawPath(star, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
