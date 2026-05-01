import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app_colors.dart';
import 'features/splash/splash_page.dart';

void main() {
  runApp(const NiyyahTrackerApp());
}

class NiyyahTrackerApp extends StatelessWidget {
  const NiyyahTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NiyyahTracker',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.darkGreen,
          primary: AppColors.darkGreen,
          secondary: AppColors.gold,
          surface: AppColors.background,
        ),
        textTheme: GoogleFonts.cairoTextTheme(),
        scaffoldBackgroundColor: AppColors.background,
      ),
      // Entry point is now the SplashPage
      home: const SplashPage(),
    );
  }
}
