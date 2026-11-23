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
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _mosqueRiseController;
  late final AnimationController _patternController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

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

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _slideController.forward();
    });

    Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      _navigateBasedOnAuth();
    });
  }

  void _navigateBasedOnAuth() {
    if (!mounted) return;
    final authProvider = context.read<AppAuthProvider>();
    if (authProvider.isLoading) {
      Timer(const Duration(milliseconds: 400), _navigateBasedOnAuth);
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
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
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
                ? const [
                    Color(0xFF02120C),
                    Color(0xFF07241A),
                    Color(0xFF00382B),
                    Color(0xFF041912),
                  ]
                : const [
                    Color(0xFFF2FAF5),
                    Color(0xFFE2F4EA),
                    Color(0xFFFFFFFF),
                  ],
            stops: isDark
                ? const [0.0, 0.35, 0.75, 1.0]
                : const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background — Islamic pattern drift & rising mosque animation
            IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _mosqueRiseController,
                  _patternController,
                ]),
                builder: (_, __) => Stack(
                  fit: StackFit.expand,
                  children: [
                    _IslamicPatternLayer(
                      isDark: isDark,
                      drift: _patternController.value,
                      color: _lineColor(isDark, isDark ? 0.07 : 0.05),
                    ),
                    _RisingMosqueSvg(
                      rise: _mosqueRiseController.value,
                      delay: 0.0,
                      xFactor: 0.5,
                      scale: 1.0,
                      screenWidth: size.width,
                      screenHeight: size.height,
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
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Circular logo with refined gold border and ambient glow
                          Container(
                            width: 124,
                            height: 124,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.85),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.22),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.45 : 0.1,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(62),
                              child: Image.asset(
                                'assets/new-logo.jpg',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // App Name
                          Text(
                            'بصائر',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppColors.darkGreen,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // English Subtitle
                          Text(
                            'Basair',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.gold.withValues(alpha: 0.95)
                                  : AppColors.gold,
                              letterSpacing: 5,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Slogan Pill Container
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.white.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: AppColors.gold.withValues(
                                  alpha: isDark ? 0.35 : 0.45,
                                ),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'فمن أبصر فلنفسه',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16,
                                color: isDark
                                    ? const Color(0xFFF5E8C8)
                                    : AppColors.darkGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 44),

                          // Gold Loading Indicator
                          SizedBox(
                            width: 30,
                            height: 30,
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

  const _RisingMosqueSvg({
    required this.rise,
    required this.delay,
    required this.xFactor,
    required this.scale,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final t = rise <= delay
        ? 0.0
        : ((rise - delay) / (1 - delay)).clamp(0.0, 1.0);
    final curve = Curves.easeOutCubic.transform(t);
    final mosqueH = screenHeight * 0.74 * scale;
    final slideUp = (1 - curve) * mosqueH * 0.35;
    final opacity = (0.04 + curve * 0.2).clamp(0.0, 0.24);

    return Positioned(
      left: screenWidth * xFactor - (screenWidth * 0.56 * scale),
      bottom: -slideUp,
      width: screenWidth * 1.12 * scale,
      height: mosqueH,
      child: Opacity(
        opacity: opacity,
        child: SvgPicture.asset(
          'assets/splash/mosque.svg',
          fit: BoxFit.fitHeight,
          alignment: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
