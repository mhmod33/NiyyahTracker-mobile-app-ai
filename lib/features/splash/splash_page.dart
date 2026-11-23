import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../onboarding/onboarding_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    Timer(const Duration(milliseconds: 1400), _navigateBasedOnAuth);
  }

  void _navigateBasedOnAuth() {
    if (!mounted) return;
    final authProvider = context.read<AppAuthProvider>();
    if (authProvider.isLoading) {
      Timer(const Duration(milliseconds: 500), _navigateBasedOnAuth);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => authProvider.isAuthenticated
            ? const DashboardPage()
            : const OnboardingPage(),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final splashAsset = isDark
        ? 'assets/splash/basair_splash_dark.png'
        : 'assets/splash/basair_splash_light.png';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF06251B)
          : const Color(0xFFF4F3E9),
      body: SizedBox.expand(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            splashAsset,
            fit: BoxFit.cover,
            semanticLabel: 'شاشة بدء تطبيق بصائر',
          ),
        ),
      ),
    );
  }
}
