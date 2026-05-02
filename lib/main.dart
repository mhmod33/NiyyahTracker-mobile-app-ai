import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_colors.dart';
import 'features/splash/splash_page.dart';
import 'services/local_storage_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  try {
    // Initialize local storage
    await LocalStorageService().initializeHive();
    print('✅ Local storage initialized');
  } catch (e) {
    print('❌ Local storage initialization error: $e');
  }

  runApp(const NiyyahTrackerApp());
}

class NiyyahTrackerApp extends StatelessWidget {
  const NiyyahTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
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
