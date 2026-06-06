import 'dart:async';
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
import 'services/azan_service.dart';
import 'services/quran_audio_service.dart';
import 'services/reciter_download_service.dart';
import 'services/wird_service.dart';
import 'services/wird_notification_service.dart';

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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

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

  // Fast, local init only — opens Hive boxes / sets up the audio player so the
  // UI can read service state safely. No network calls and no notification
  // scheduling happen here (those are deferred below to keep startup snappy).
  try {
    await NotificationService().init();
  } catch (e) {
    // Silently fail
  }
  try {
    await AzanService().init();
  } catch (e) {
    // Silently fail
  }
  try {
    await QuranAudioService().init();
  } catch (e) {
    // Silently fail
  }
  try {
    await WirdService().init();
  } catch (e) {
    // Silently fail
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider.value(value: QuranAudioService()),
        ChangeNotifierProvider.value(value: ReciterDownloadService()),
      ],
      child: const BasairApp(),
    ),
  );

  // Defer slow, non-critical work until after the first frame so the splash
  // appears instantly instead of waiting on notification scheduling and
  // network calls.
  unawaited(_deferredStartupWork());
}

/// Heavy startup work that does not need to block the first frame:
/// notification scheduling (iterates many alarms) and similar background setup.
Future<void> _deferredStartupWork() async {
  try {
    await NotificationService().initializeAllSchedules();
  } catch (_) {}
  try {
    await AzanService().scheduleAzanNotifications();
  } catch (_) {}
  try {
    await DailySummaryService().initializeNotifications();
    await DailySummaryService().scheduleMidnightReminder();
  } catch (_) {}
  try {
    await WirdNotificationService().init();
    await WirdNotificationService().scheduleAll();
  } catch (_) {}
}

class BasairApp extends StatelessWidget {
  const BasairApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'بصائر',
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
          titleTextStyle: _font(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
        textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(
          ThemeData.dark().textTheme,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          titleTextStyle: _font(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      home: const SplashPage(),
    );
  }
}
