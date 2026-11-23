import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
// import 'package:qcf_quran_plus/qcf_quran_plus.dart'; // Removed - using custom QcfMushafService
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'core/app_colors.dart';
import 'core/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'features/splash/premium_splash_page.dart';
import 'firebase_options.dart';
import 'services/daily_summary_service.dart';
import 'services/notification_service.dart';
import 'services/azan_service.dart';
import 'services/quran_audio_service.dart';
import 'services/reciter_download_service.dart';
import 'services/wird_service.dart';
import 'services/wird_notification_service.dart';
import 'services/fcm_service.dart';
import 'services/app_update_service.dart';
import 'services/admin_notification_service.dart';
import 'services/admin_background_checker.dart';
import 'services/azkar_reminder_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

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
    await Hive.openBox('quran_progress');
    await Hive.openBox('home_dhikr');
  } catch (e) {
    // Silently fail
  }

  // NOTE: Service init calls (NotificationService, AzanService, QuranAudioService,
  // WirdService) are deferred until after runApp() so the splash paints instantly.
  // Services lazily open their own Hive boxes and read defaults safely before init.

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
/// service initialization, notification scheduling, and similar background setup.
Future<void> _deferredStartupWork() async {
  // ── STEP 1: Initialize timezone FIRST so every service that calls
  // tz.TZDateTime.from(..., tz.local) uses the correct local zone.
  // Without this, tz.local defaults to UTC and all scheduled notifications
  // fire hours early or late.
  try {
    tzData.initializeTimeZones();
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName.identifier));
  } catch (_) {}

  // ── STEP 2: Initialize services (they open Hive boxes, extract audio,
  // configure audio sessions, etc.). These used to block runApp(); now they
  // run after the splash is visible.
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

  // QCF fonts are now downloaded on-demand by QcfMushafService, not pre-loaded
  // if (!kIsWeb) {
  //   try {
  //     await QcfFontLoader.setupFontsAtStartup(
  //       mode: FontStorageMode.permanentDisk,
  //       onProgress: (progress) {
  //         debugPrint('QCF Font loading: ${(progress * 100).toStringAsFixed(1)}%');
  //       },
  //     );
  //     debugPrint('QCF Fonts loaded successfully');
  //   } catch (e) {
  //     debugPrint('QCF Font loading failed: $e');
  //   }
  // }

  try {
    await AzanService().preloadPrayerTimes();
  } catch (_) {}
  try {
    await NotificationService().initializeAllSchedules();
  } catch (_) {}
  try {
    await AzanService().scheduleAzanNotifications();
  } catch (_) {}
  try {
    await DailySummaryService().initializeNotifications();
  } catch (_) {}
  try {
    await WirdNotificationService().init();
    await WirdNotificationService().scheduleAll();
  } catch (_) {}
  try {
    await FcmService().init();
  } catch (_) {}
  try {
    await AppUpdateService().checkForUpdate();
  } catch (_) {}
  try {
    AdminNotificationService().startListening();
  } catch (_) {}
  try {
    await registerAdminBackgroundCheck();
  } catch (_) {}
}

class BasairApp extends StatefulWidget {
  const BasairApp({super.key});

  @override
  State<BasairApp> createState() => _BasairAppState();
}

class _BasairAppState extends State<BasairApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AzkarReminderService.navigatorKey = appNavigatorKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        AzkarReminderService().checkAndShowReminder();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AzkarReminderService().checkAndShowReminder();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: appNavigatorKey,
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

      home: const PremiumSplashPage(),
    );
  }
}
