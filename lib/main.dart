import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'core/app_colors.dart';
import 'core/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'features/splash/splash_page.dart';
import 'firebase_options.dart';
import 'services/daily_summary_service.dart';
import 'services/notification_service.dart';

/// App-wide font helper — IBM Plex Sans Arabic everywhere.
TextStyle _font({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
}) {
  return GoogleFonts.ibmPlexSansArabic(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Silently fail
  }

  try {
    await Hive.initFlutter();
    await Hive.openBox('settings');
    await Hive.openBox('notification_settings');
  } catch (e) {
    // Silently fail
  }

  try {
    await DailySummaryService().initializeNotifications();
    await DailySummaryService().scheduleMidnightReminder();
  } catch (e) {
    // Silently fail
  }

  try {
    await NotificationService().init();
    await NotificationService().initializeAllSchedules();
  } catch (e) {
    // Silently fail
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ],
      child: const NiyyahTrackerApp(),
    ),
  );
}

class NiyyahTrackerApp extends StatelessWidget {
  const NiyyahTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'النية',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeProvider.themeMode,

      // ── Light Theme ──
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.darkGreen,
          primary: AppColors.darkGreen,
          secondary: AppColors.gold,
          surface: AppColors.cardBg,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.cardBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
          titleTextStyle: _font(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      // ── Dark Theme ──
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.darkGreen,
          primary: AppColors.lightGreen,
          secondary: AppColors.gold,
          surface: const Color(0xFF1E1E1E),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          titleTextStyle: _font(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      home: const SplashPage(),
    );
  }
}
