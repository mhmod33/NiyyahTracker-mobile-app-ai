import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../onboarding/onboarding_page.dart';

class PremiumSplashPage extends StatefulWidget {
  const PremiumSplashPage({super.key});

  @override
  State<PremiumSplashPage> createState() => _PremiumSplashPageState();
}

class _PremiumSplashPageState extends State<PremiumSplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _progressController;
  late final AnimationController _glowController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _progressAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeController.forward();
    _progressController.forward();
    _glowController.repeat(reverse: true);

    Timer(const Duration(milliseconds: 3000), _navigateBasedOnAuth);
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
    _progressController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF002B1F), // Deep emerald
              Color(0xFF003D2F), // Forest green
              Color(0xFF00513D), // Dark emerald
              Color(0xFF003D2F),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              // Background architectural patterns
              Positioned.fill(
                child: CustomPaint(
                  painter: LuxuryBackgroundPainter(),
                ),
              ),

              // Animated atmospheric glow
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: size.height * 0.22,
                    left: size.width * 0.5 - 200,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFFD6A84B).withOpacity(0.3 * _glowAnimation.value),
                            Color(0xFFD6A84B).withOpacity(0.15 * _glowAnimation.value),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Logo section
              Positioned(
                top: size.height * 0.25,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Logo with proper handling
                    Container(
                      width: size.width * 0.5,
                      height: size.width * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD6A84B).withOpacity(0.4),
                            blurRadius: 50,
                            spreadRadius: 15,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Gold ornamental divider
                    CustomPaint(
                      size: const Size(160, 30),
                      painter: LuxuryDividerPainter(),
                    ),

                    const SizedBox(height: 24),

                    // Arabic tagline
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        'فمن أبصر لنفسه',
                        style: GoogleFonts.notoNaskhArabic(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF5E8C8),
                          letterSpacing: 2.0,
                          height: 1.8,
                          shadows: [
                            Shadow(
                              color: const Color(0xFFD6A84B).withOpacity(0.6),
                              offset: const Offset(0, 0),
                              blurRadius: 25,
                            ),
                            Shadow(
                              color: Colors.black.withOpacity(0.7),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom scene with professional illustrations
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                height: size.height * 0.25,
                child: Stack(
                  children: [
                    // Lantern on the left
                    Positioned(
                      left: size.width * 0.08,
                      bottom: 20,
                      child: SvgPicture.asset(
                        'assets/splash/lantern.svg',
                        width: size.width * 0.22,
                        height: size.height * 0.18,
                      ),
                    ),

                    // Quran on Rehal in center (focal point)
                    Positioned(
                      left: size.width * 0.5 - (size.width * 0.35 / 2),
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: 5,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          'assets/splash/quran_rehal.svg',
                          width: size.width * 0.45,
                          height: size.height * 0.2,
                        ),
                      ),
                    ),

                    // Mosque arch on the right (background element)
                    Positioned(
                      right: size.width * 0.05,
                      bottom: 10,
                      child: Opacity(
                        opacity: 0.7,
                        child: SvgPicture.asset(
                          'assets/splash/mosque_arch.svg',
                          width: size.width * 0.28,
                          height: size.height * 0.22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Premium loading indicator
              Positioned(
                bottom: 30,
                left: size.width * 0.15,
                right: size.width * 0.15,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Loading text
                        Text(
                          'جاري التحميل',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFF5E8C8).withOpacity(0.7),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Progress bar
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF001810).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFD6A84B).withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                FractionallySizedBox(
                                  widthFactor: _progressAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFD6A84B),
                                          Color(0xFFFFD700),
                                          Color(0xFFD6A84B),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFD6A84B).withOpacity(0.7),
                                          blurRadius: 15,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Luxury Background Painter - Sophisticated architectural patterns
// ═══════════════════════════════════════════════════════════════════════════
class LuxuryBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Large elegant arches with subtle gradients
    final archPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF00513D).withOpacity(0.15);

    // Multiple layered arches for depth
    for (int i = 0; i < 3; i++) {
      final offset = i * 25.0;
      final opacity = 0.2 - (i * 0.05);

      archPaint.color = Color(0xFF00513D).withOpacity(opacity);

      final leftArch = Path();
      leftArch.moveTo(size.width * 0.1 + offset, size.height * 0.4);
      leftArch.quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.2 - offset,
        size.width * 0.4 + offset,
        size.height * 0.4,
      );
      canvas.drawPath(leftArch, archPaint);

      final rightArch = Path();
      rightArch.moveTo(size.width * 0.6 - offset, size.height * 0.4);
      rightArch.quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.2 - offset,
        size.width * 0.9 - offset,
        size.height * 0.4,
      );
      canvas.drawPath(rightArch, archPaint);
    }

    // Subtle Islamic geometric patterns
    final patternPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFD6A84B).withOpacity(0.05);

    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 6; col++) {
        final x = size.width * (0.1 + col * 0.15);
        final y = size.height * (0.5 + row * 0.1);

        // Small decorative circles
        canvas.drawCircle(Offset(x, y), 12, patternPaint);
      }
    }

    // Gold accent curves in corners
    final goldCurvePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFFD6A84B).withOpacity(0.25);

    // Top-left curve
    final topCurve = Path();
    topCurve.moveTo(0, size.height * 0.15);
    topCurve.cubicTo(
      size.width * 0.1,
      size.height * 0.12,
      size.width * 0.15,
      size.height * 0.18,
      size.width * 0.25,
      size.height * 0.14,
    );
    canvas.drawPath(topCurve, goldCurvePaint);

    // Bottom-right curve
    final bottomCurve = Path();
    bottomCurve.moveTo(size.width, size.height * 0.85);
    bottomCurve.cubicTo(
      size.width * 0.9,
      size.height * 0.88,
      size.width * 0.85,
      size.height * 0.82,
      size.width * 0.75,
      size.height * 0.86,
    );
    canvas.drawPath(bottomCurve, goldCurvePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// Luxury Divider Painter - Elegant ornamental divider
// ═══════════════════════════════════════════════════════════════════════════
class LuxuryDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFFD6A84B);

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Center diamond ornament
    final diamond = Path();
    diamond.moveTo(centerX, centerY - 8);
    diamond.lineTo(centerX + 5, centerY);
    diamond.lineTo(centerX, centerY + 8);
    diamond.lineTo(centerX - 5, centerY);
    diamond.close();
    canvas.drawPath(diamond, paint..style = PaintingStyle.fill);

    paint.style = PaintingStyle.stroke;

    // Left flowing curve
    final leftCurve = Path();
    leftCurve.moveTo(centerX - 12, centerY);
    leftCurve.cubicTo(
      centerX - 30,
      centerY - 5,
      centerX - 50,
      centerY + 3,
      centerX - 70,
      centerY,
    );
    canvas.drawPath(leftCurve, paint);

    // Right flowing curve
    final rightCurve = Path();
    rightCurve.moveTo(centerX + 12, centerY);
    rightCurve.cubicTo(
      centerX + 30,
      centerY - 5,
      centerX + 50,
      centerY + 3,
      centerX + 70,
      centerY,
    );
    canvas.drawPath(rightCurve, paint);

    // Accent dots
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX - 60, centerY), 2, paint);
    canvas.drawCircle(Offset(centerX + 60, centerY), 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
