import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:hive/hive.dart';
import '../widgets/notification_overlay.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  late Box _settingsBox;

  // Notification channels
  static const String _azkarChannelId = 'azkar_reminders';
  static const String _prayerChannelId = 'prayer_times';
  
  // Notification settings keys
  static const String _morningAzkarKey = 'morning_azkar_enabled';
  static const String _eveningAzkarKey = 'evening_azkar_enabled';
  static const String _prayerTimesKey = 'prayer_times_enabled';
  static const String _azkarReminderKey = 'azkar_reminder_enabled';

  Future<void> init() async {
    tz.initializeTimeZones();
    
    // Ensure Hive is initialized before opening the box
    if (!Hive.isBoxOpen('notification_settings')) {
      _settingsBox = await Hive.openBox('notification_settings');
    } else {
      _settingsBox = Hive.box('notification_settings');
    }
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannels();
    await _requestPermissions();
  }

  Future<void> _createNotificationChannels() async {
    const androidChannels = [
      AndroidNotificationChannel(
        _azkarChannelId,
        'أذكار وتذكيرات',
        description: 'تذكيرات الأذكار اليومية',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
      AndroidNotificationChannel(
        _prayerChannelId,
        'أوقات الصلاة',
        description: 'تنبيهات أوقات الصلاة',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('adhan_sound'),
      ),
    ];

    for (final channel in androidChannels) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  // Settings methods
  bool get morningAzkarEnabled {
    try {
      return _settingsBox.get(_morningAzkarKey, defaultValue: true);
    } catch (e) {
      debugPrint('Error getting morning azkar setting: $e');
      return true;
    }
  }
  
  bool get eveningAzkarEnabled {
    try {
      return _settingsBox.get(_eveningAzkarKey, defaultValue: true);
    } catch (e) {
      debugPrint('Error getting evening azkar setting: $e');
      return true;
    }
  }
  
  bool get prayerTimesEnabled {
    try {
      return _settingsBox.get(_prayerTimesKey, defaultValue: true);
    } catch (e) {
      debugPrint('Error getting prayer times setting: $e');
      return true;
    }
  }
  
  bool get azkarReminderEnabled {
    try {
      return _settingsBox.get(_azkarReminderKey, defaultValue: true);
    } catch (e) {
      debugPrint('Error getting azkar reminder setting: $e');
      return true;
    }
  }

  Future<void> setMorningAzkarEnabled(bool enabled) async {
    try {
      await _settingsBox.put(_morningAzkarKey, enabled);
      if (enabled) {
        await scheduleMorningAzkar();
      } else {
        await cancelMorningAzkar();
      }
    } catch (e) {
      debugPrint('Error setting morning azkar enabled: $e');
    }
  }

  Future<void> setEveningAzkarEnabled(bool enabled) async {
    try {
      await _settingsBox.put(_eveningAzkarKey, enabled);
      if (enabled) {
        await scheduleEveningAzkar();
      } else {
        await cancelEveningAzkar();
      }
    } catch (e) {
      debugPrint('Error setting evening azkar enabled: $e');
    }
  }

  Future<void> setPrayerTimesEnabled(bool enabled) async {
    try {
      await _settingsBox.put(_prayerTimesKey, enabled);
      if (enabled) {
        await schedulePrayerTimes();
      } else {
        await cancelPrayerTimes();
      }
    } catch (e) {
      debugPrint('Error setting prayer times enabled: $e');
    }
  }

  Future<void> setAzkarReminderEnabled(bool enabled) async {
    try {
      await _settingsBox.put(_azkarReminderKey, enabled);
      if (enabled) {
        await scheduleAzkarReminders();
      } else {
        await cancelAzkarReminders();
      }
    } catch (e) {
      debugPrint('Error setting azkar reminder enabled: $e');
    }
  }

  // Azkar notifications
  Future<void> scheduleMorningAzkar() async {
    if (!morningAzkarEnabled) return;

    await _notifications.zonedSchedule(
      1001,
      'أذكار الصباح',
      'حان وقت أذكار الصباح - ابدأ يومك بذكر الله',
      _nextTime(5, 0), // 5:00 AM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _azkarChannelId,
          'أذكار وتذكيرات',
          channelDescription: 'تذكيرات الأذكار اليومية',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
          icon: '@mipmap/ic_launcher',
          largeIcon: DrawableResourceAndroidBitmap('notification_icon'),
          styleInformation: BigTextStyleInformation(
            'حان وقت أذكار الصباح\n\n"أَصْـبَحْنا وَأَصْـبَحَ المُـلْكُ لله وَالحَمدُ لله"',
            htmlFormatBigText: false,
            contentTitle: 'أذكار الصباح',
            htmlFormatContentTitle: false,
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification_sound.aiff',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleEveningAzkar() async {
    if (!eveningAzkarEnabled) return;

    await _notifications.zonedSchedule(
      1002,
      'أذكار المساء',
      'حان وقت أذكار المساء - اختم يومك بذكر الله',
      _nextTime(18, 0), // 6:00 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _azkarChannelId,
          'أذكار وتذكيرات',
          channelDescription: 'تذكيرات الأذكار اليومية',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
          icon: '@mipmap/ic_launcher',
          largeIcon: DrawableResourceAndroidBitmap('notification_icon'),
          styleInformation: BigTextStyleInformation(
            'حان وقت أذكار المساء\n\n"أَمْسَيْـنا وَأَمْسـى المـلكُ لله وَالحَمدُ لله"',
            htmlFormatBigText: false,
            contentTitle: 'أذكار المساء',
            htmlFormatContentTitle: false,
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification_sound.aiff',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleAzkarReminders() async {
    if (!azkarReminderEnabled) return;

    // Schedule reminders every 2 hours during the day
    for (int hour = 8; hour <= 22; hour += 2) {
      await _notifications.zonedSchedule(
        2000 + hour,
        'تذكير بالذكر',
        'لا تنسى ذكر الله في هذا الوقت',
        _nextTime(hour, 0),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _azkarChannelId,
            'أذكار وتذكيرات',
            channelDescription: 'تذكيرات الأذكار اليومية',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            sound: RawResourceAndroidNotificationSound('notification_sound'),
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'notification_sound.aiff',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // Prayer times notifications
  Future<void> schedulePrayerTimes() async {
    if (!prayerTimesEnabled) return;

    final prayers = [
      {'name': 'الفجر', 'hour': 5, 'id': 3001},
      {'name': 'الظهر', 'hour': 12, 'id': 3002},
      {'name': 'العصر', 'hour': 15, 'id': 3003},
      {'name': 'المغرب', 'hour': 18, 'id': 3004},
      {'name': 'العشاء', 'hour': 20, 'id': 3005},
    ];

    for (final prayer in prayers) {
      await _notifications.zonedSchedule(
        prayer['id'] as int,
        'حان وقت صلاة ${prayer['name']}',
        'الصلاة خير من النوم - حان وقت صلاة ${prayer['name']}',
        _nextTime(prayer['hour'] as int, 0),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _prayerChannelId,
            'أوقات الصلاة',
            channelDescription: 'تنبيهات أوقات الصلاة',
            importance: Importance.high,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('adhan_sound'),
            icon: '@mipmap/ic_launcher',
            largeIcon: DrawableResourceAndroidBitmap('prayer_icon'),
            styleInformation: BigTextStyleInformation(
              'حان وقت صلاة ${prayer['name']}\n\n"قُلْ لِعِبَادِيَ الَّذِينَ آمَنُوا يُقِيمُوا الصَّلَاةَ"',
              htmlFormatBigText: false,
              contentTitle: 'صلاة ${prayer['name']}',
              htmlFormatContentTitle: false,
            ),
            color: const Color(0xFF145A3A),
            ledColor: const Color(0xFF145A3A),
            enableLights: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'adhan_sound.aiff',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // Cancel methods
  Future<void> cancelMorningAzkar() async {
    await _notifications.cancel(1001);
  }

  Future<void> cancelEveningAzkar() async {
    await _notifications.cancel(1002);
  }

  Future<void> cancelAzkarReminders() async {
    for (int hour = 8; hour <= 22; hour += 2) {
      await _notifications.cancel(2000 + hour);
    }
  }

  Future<void> cancelPrayerTimes() async {
    for (int id = 3001; id <= 3005; id++) {
      await _notifications.cancel(id);
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Helper method to get next occurrence of specific time
  tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // Show immediate notification (for testing)
  Future<void> showTestNotification({BuildContext? context}) async {
    // Show system notification
    await _notifications.show(
      0,
      'اختبار الإشعارات',
      'هذا إشعار اختباري من تطبيق نيّة',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _azkarChannelId,
          'أذكار وتذكيرات',
          channelDescription: 'تذكيرات الأذكار اليومية',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    // Show overlay notification if context is provided
    if (context != null) {
      NotificationOverlayManager.show(
        context,
        title: 'اختبار الإشعارات',
        body: 'هذا إشعار اختباري من تطبيق نيّة',
        icon: Icons.notifications_active_rounded,
        color: Colors.blue,
      );
    }
  }

  // Show overlay notification for azkar
  void showAzkarOverlay(BuildContext context, String type) {
    NotificationOverlayManager.showAzkarNotification(context, type: type);
  }

  // Show overlay notification for prayer
  void showPrayerOverlay(BuildContext context, String prayerName) {
    NotificationOverlayManager.showPrayerNotification(context, prayerName: prayerName);
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Initialize all schedules
  Future<void> initializeAllSchedules() async {
    if (morningAzkarEnabled) await scheduleMorningAzkar();
    if (eveningAzkarEnabled) await scheduleEveningAzkar();
    if (azkarReminderEnabled) await scheduleAzkarReminders();
    if (prayerTimesEnabled) await schedulePrayerTimes();
  }
}
