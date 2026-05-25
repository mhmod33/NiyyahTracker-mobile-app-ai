import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../onboarding/onboarding_page.dart';
import '../dashboard/dashboard_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _mosqueRiseController;
  late AnimationController _patternController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _mosqueRiseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
    _patternController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _slideController.forward();
    });

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _navigateBasedOnAuth();
    });
  }

  void _navigateBasedOnAuth() {
    final authProvider = context.read<AppAuthProvider>();
    if (authProvider.isLoading) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _navigateBasedOnAuth();
      });
      return;
    }
    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _mosqueRiseController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  Color _lineColor(bool isDark, double opacity) {
    return (isDark ? AppColors.gold : AppColors.darkGreen)
        .withValues(alpha: opacity);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF040E0A), const Color(0xFF0A1A14), const Color(0xFF122A20)]
                : [const Color(0xFFF0FAF4), const Color(0xFFE0F4E8), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background — does not block touches on foreground
            IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_mosqueRiseController, _patternController]),
                builder: (_, __) => Stack(
                  fit: StackFit.expand,
                  children: [
                    _IslamicPatternLayer(
                      isDark: isDark,
                      drift: _patternController.value,
                      color: _lineColor(isDark, isDark ? 0.06 : 0.05),
                    ),
                    _RisingMosqueSvg(
                      rise: _mosqueRiseController.value,
                      delay: 0.0,
                      xFactor: 0.2,
                      scale: 0.62,
                      screenWidth: size.width,
                      screenHeight: size.height,
                      color: _lineColor(isDark, isDark ? 0.32 : 0.24),
                    ),
                    _RisingMosqueSvg(
                      rise: _mosqueRiseController.value,
                      delay: 0.14,
                      xFactor: 0.5,
                      scale: 0.88,
                      screenWidth: size.width,
                      screenHeight: size.height,
                      color: _lineColor(isDark, isDark ? 0.42 : 0.32),
                    ),
                    _RisingMosqueSvg(
                      rise: _mosqueRiseController.value,
                      delay: 0.28,
                      xFactor: 0.8,
                      scale: 0.7,
                      screenWidth: size.width,
                      screenHeight: size.height,
                      color: _lineColor(isDark, isDark ? 0.32 : 0.24),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.85),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.darkGreen.withValues(alpha: 0.25),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'بصائر',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.darkGreen,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Basair',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.gold.withValues(alpha: 0.9)
                                : AppColors.gold,
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: isDark ? 0.22 : 0.35),
                            ),
                          ),
                          child: Text(
                            'فمن أبصر فلنفسه',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 17,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : AppColors.darkGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.gold.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
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

class _IslamicPatternLayer extends StatelessWidget {
  final bool isDark;
  final double drift;
  final Color color;

  const _IslamicPatternLayer({
    required this.isDark,
    required this.drift,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(drift * 12 - 6, drift * 8 - 4),
      child: Opacity(
        opacity: isDark ? 0.45 : 0.55,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 40,
          itemBuilder: (_, __) => SvgPicture.asset(
            'assets/splash/islamic_pattern.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

class _RisingMosqueSvg extends StatelessWidget {
  final double rise;
  final double delay;
  final double xFactor;
  final double scale;
  final double screenWidth;
  final double screenHeight;
  final Color color;

  const _RisingMosqueSvg({
    required this.rise,
    required this.delay,
    required this.xFactor,
    required this.scale,
    required this.screenWidth,
    required this.screenHeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = rise <= delay
        ? 0.0
        : ((rise - delay) / (1 - delay)).clamp(0.0, 1.0);
    final curve = Curves.easeOutCubic.transform(t);
    final mosqueH = screenHeight * 0.32 * scale;
    final slideUp = (1 - curve) * mosqueH * 1.2;
    final opacity = (0.25 + curve * 0.75).clamp(0.0, 1.0);

    return Positioned(
      left: screenWidth * xFactor - (screenWidth * 0.22 * scale),
      bottom: -slideUp,
      width: screenWidth * 0.44 * scale,
      height: mosqueH,
      child: Opacity(
        opacity: opacity,
        child: SvgPicture.asset(
          'assets/splash/mosque.svg',
          fit: BoxFit.fitHeight,
          alignment: Alignment.bottomCenter,
          colorFilter: ColorFilter.mode(
            color.withValues(alpha: color.a * opacity),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
