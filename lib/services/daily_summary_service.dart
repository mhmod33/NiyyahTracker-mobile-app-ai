import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/worship_model.dart';
import '../services/firebase_service.dart';

class DailySummaryService {
  static final DailySummaryService _instance = DailySummaryService._internal();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseService _firebaseService = FirebaseService();

  factory DailySummaryService() {
    return _instance;
  }

  DailySummaryService._internal();

  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Daily summary notification tapped');
  }

  Future<void> scheduleMidnightReminder() async {
    await _notifications.cancel(999); // Cancel any existing reminder

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 5); // 12:05 AM

    // If it's already past midnight, schedule for tomorrow
    if (midnight.isBefore(now)) {
      midnight.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_summary_channel',
      'ملخص العبادات اليومية',
      channelDescription: 'تذكير بملخص عبادات اليوم',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.zonedSchedule(
      999,
      'ملخص عباداتك 🌙',
      'اضغط لمشاهدة ملخص عبادات اليوم',
      tz.TZDateTime.from(midnight, tz.local),
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showDailySummary(String userId) async {
    try {
      final today = DateTime.now();
      final worships = await _firebaseService.getDailyWorshipByDate(userId, today);
      
      if (worships.isEmpty) return;

      final todayWorship = worships.first;
      final summary = _generateSummary(todayWorship);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'daily_summary_channel',
        'ملخص العبادات اليومية',
        channelDescription: 'ملخص عبادات اليوم',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        1000,
        'ملخص عباداتك اليوم 🤍',
        summary,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing daily summary: $e');
    }
  }

  String _generateSummary(DailyWorship worship) {
    final buffer = StringBuffer();
    
    buffer.writeln('🕌 الصلوات: ${worship.prayerCount}/5 في وقتها');
    buffer.writeln('📖 صفحات القرآن: ${worship.quranPages}');
    
    final completedWorships = worship.worships.entries
        .where((entry) => entry.value == true)
        .map((entry) => _getWorshipDisplayName(entry.key))
        .toList();
    
    if (completedWorships.isNotEmpty) {
      buffer.writeln('✅ العبادات الأخرى:');
      for (final worshipName in completedWorships) {
        buffer.writeln('  • $worshipName');
      }
    }
    
    buffer.writeln('\nتقبل الله منك ومنا صالح الأعمال 🤍');
    
    return buffer.toString();
  }

  String _getWorshipDisplayName(String key) {
    switch (key) {
      case 'morningRemembrance':
        return 'أذكار الصباح';
      case 'eveningRemembrance':
        return 'أذكار المساء';
      case 'quranRecitation':
        return 'قراءة القرآن';
      case 'charity':
        return 'الصدقة';
      case 'nightPrayer':
        return 'قيام الليل';
      case 'fasting':
        return 'الصيام';
      case 'taraweeh':
        return 'التراويح';
      default:
        return key;
    }
  }

  Future<Map<String, dynamic>> getTodaySummary(String userId) async {
    try {
      final today = DateTime.now();
      final worships = await _firebaseService.getDailyWorshipByDate(userId, today);
      
      if (worships.isEmpty) {
        return {
          'hasData': false,
          'prayerCount': 0,
          'quranPages': 0,
          'completedWorships': <String>[],
          'totalWorships': 0,
        };
      }

      final todayWorship = worships.first;
      final completedWorships = todayWorship.worships.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      return {
        'hasData': true,
        'prayerCount': todayWorship.prayerCount,
        'quranPages': todayWorship.quranPages,
        'completedWorships': completedWorships,
        'totalWorships': completedWorships.length + todayWorship.prayerCount,
        'data': todayWorship,
      };
    } catch (e) {
      debugPrint('Error getting today summary: $e');
      return {
        'hasData': false,
        'prayerCount': 0,
        'quranPages': 0,
        'completedWorships': <String>[],
        'totalWorships': 0,
      };
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
