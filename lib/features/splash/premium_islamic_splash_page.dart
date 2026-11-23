import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../onboarding/onboarding_page.dart';

class PremiumIslamicSplashPage extends StatefulWidget {
  const PremiumIslamicSplashPage({super.key});

  @override
  State<PremiumIslamicSplashPage> createState() =>
      _PremiumIslamicSplashPageState();
}

class _PremiumIslamicSplashPageState extends State<PremiumIslamicSplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final AnimationController _glowController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

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
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.1,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _scaleController.forward();
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
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF001810),
                    const Color(0xFF002B1F),
                    const Color(0xFF003D2F),
                    const Color(0xFF002B1F),
                  ]
                : [
                    const Color(0xFFF4F3E9),
                    const Color(0xFFEBE8D8),
                    const Color(0xFFE2DFC8),
                    const Color(0xFFEBE8D8),
                  ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SubtleBackgroundPainter(isDark: isDark),
              ),
            ),

            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Positioned(
                  top: size.height * 0.3,
                  left: size.width * 0.5 - 300,
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFFD6A84B)
                              .withOpacity(0.25 * _glowAnimation.value),
                          Color(0xFFD6A84B)
                              .withOpacity(0.12 * _glowAnimation.value),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),

            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.12),

                    Container(
                      width: size.width * 0.45,
                      height: size.width * 0.45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD6A84B).withOpacity(0.3),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            isDark
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.1),
                            BlendMode.lighten,
                          ),
                          child: Image.asset(
                            'assets/new-logo.jpg',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: size.height * 0.04),

                    Text(
                      'فمن أبصر فلنفسه',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Noto Naskh Arabic',
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFF5E8C8)
                            : const Color(0xFF003D2F),
                        letterSpacing: 2.5,
                        height: 1.6,
                        shadows: isDark
                            ? [
                                Shadow(
                                  color: const Color(0xFFD6A84B)
                                      .withOpacity(0.5),
                                  offset: const Offset(0, 0),
                                  blurRadius: 20,
                                ),
                                Shadow(
                                  color: Colors.black.withOpacity(0.6),
                                  offset: const Offset(0, 3),
                                  blurRadius: 10,
                                ),
                              ]
                            : [
                                Shadow(
                                  color: const Color(0xFFD6A84B)
                                      .withOpacity(0.3),
                                  offset: const Offset(0, 2),
                                  blurRadius: 8,
                                ),
                              ],
                      ),
                    ),

                    const Spacer(),

                    SizedBox(
                      width: size.width,
                      height: size.height * 0.42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Image.asset(
                              'assets/splash/Golden Ramadan Lantern and Quran Scene.png',
                              width: size.width * 0.95,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: size.height * 0.04),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubtleBackgroundPainter extends CustomPainter {
  final bool isDark;

  SubtleBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final decorativePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isDark ? const Color(0xFF00513D) : const Color(0xFFD6C9A8))
          .withOpacity(0.08);

    for (int i = 0; i < 4; i++) {
      final offset = i * 30.0;
      final leftCurve = Path();
      leftCurve.moveTo(0, size.height * 0.25 + offset);
      leftCurve.quadraticBezierTo(
        size.width * 0.15,
        size.height * 0.15 + offset,
        size.width * 0.3,
        size.height * 0.25 + offset,
      );
      canvas.drawPath(leftCurve, decorativePaint);
    }

    final goldAccent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFD6A84B).withOpacity(isDark ? 0.15 : 0.12);

    final topCurve = Path();
    topCurve.moveTo(0, size.height * 0.12);
    topCurve.cubicTo(
      size.width * 0.08,
      size.height * 0.1,
      size.width * 0.12,
      size.height * 0.14,
      size.width * 0.2,
      size.height * 0.11,
    );
    canvas.drawPath(topCurve, goldAccent);

    final bottomCurve = Path();
    bottomCurve.moveTo(size.width, size.height * 0.88);
    bottomCurve.cubicTo(
      size.width * 0.92,
      size.height * 0.9,
      size.width * 0.88,
      size.height * 0.86,
      size.width * 0.8,
      size.height * 0.89,
    );
    canvas.drawPath(bottomCurve, goldAccent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
