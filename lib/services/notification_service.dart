import 'dart:async';
import 'dart:developer' as developer;
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

  static const String _azkarChannelId = 'azkar_reminders';
  static const String _prayerChannelId = 'prayer_times';
  
  static const String _morningAzkarKey = 'morning_azkar_enabled';
  static const String _eveningAzkarKey = 'evening_azkar_enabled';
  static const String _sleepAzkarKey = 'sleep_azkar_enabled';
  static const String _prayerTimesKey = 'prayer_times_enabled';
  static const String _azkarReminderKey = 'azkar_reminder_enabled';

  Future<void> init() async {
    developer.log('🔔 NotificationService.init() called', name: 'NotificationService');
    try {
      tz.initializeTimeZones();
      developer.log('✅ Time zones initialized', name: 'NotificationService');
      
      if (!Hive.isBoxOpen('notification_settings')) {
        developer.log('Opening notification_settings box...', name: 'NotificationService');
        _settingsBox = await Hive.openBox('notification_settings');
      } else {
        developer.log('notification_settings box already open', name: 'NotificationService');
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

      developer.log('Initializing notifications plugin...', name: 'NotificationService');
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      developer.log('✅ Notifications plugin initialized', name: 'NotificationService');

      await _createNotificationChannels();
      await _requestPermissions();
      developer.log('✅ NotificationService.init() completed successfully', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error in NotificationService.init()', name: 'NotificationService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _createNotificationChannels() async {
    developer.log('Creating notification channels...', name: 'NotificationService');
    try {
      const androidChannels = [
        AndroidNotificationChannel(
          _azkarChannelId,
          'أذكار وتذكيرات',
          description: 'تذكيرات الأذكار اليومية',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          _prayerChannelId,
          'أوقات الصلاة',
          description: 'تنبيهات أوقات الصلاة',
          importance: Importance.high,
        ),
      ];

      for (final channel in androidChannels) {
        developer.log('Creating channel: ${channel.id}', name: 'NotificationService');
        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
      developer.log('✅ Notification channels created', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error creating notification channels', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _requestPermissions() async {
    developer.log('Requesting notification permissions...', name: 'NotificationService');
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final androidResult = await androidPlugin?.requestNotificationsPermission();
      developer.log('Android permission result: $androidResult', name: 'NotificationService');

      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final iosResult = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      developer.log('iOS permission result: $iosResult', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error requesting permissions', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    developer.log('Notification tapped: ${response.payload}', name: 'NotificationService');
  }

  bool get morningAzkarEnabled {
    try {
      final value = _settingsBox.get(_morningAzkarKey, defaultValue: true);
      developer.log('morningAzkarEnabled: $value', name: 'NotificationService');
      return value;
    } catch (e, stackTrace) {
      developer.log('❌ Error getting morningAzkarEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return true;
    }
  }
  
  bool get eveningAzkarEnabled {
    try {
      final value = _settingsBox.get(_eveningAzkarKey, defaultValue: true);
      developer.log('eveningAzkarEnabled: $value', name: 'NotificationService');
      return value;
    } catch (e, stackTrace) {
      developer.log('❌ Error getting eveningAzkarEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return true;
    }
  }

  bool get sleepAzkarEnabled {
    try {
      final value = _settingsBox.get(_sleepAzkarKey, defaultValue: true);
      developer.log('sleepAzkarEnabled: $value', name: 'NotificationService');
      return value;
    } catch (e, stackTrace) {
      developer.log('❌ Error getting sleepAzkarEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return true;
    }
  }
  
  bool get prayerTimesEnabled {
    try {
      final value = _settingsBox.get(_prayerTimesKey, defaultValue: true);
      developer.log('prayerTimesEnabled: $value', name: 'NotificationService');
      return value;
    } catch (e, stackTrace) {
      developer.log('❌ Error getting prayerTimesEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return true;
    }
  }
  
  bool get azkarReminderEnabled {
    try {
      final value = _settingsBox.get(_azkarReminderKey, defaultValue: true);
      developer.log('azkarReminderEnabled: $value', name: 'NotificationService');
      return value;
    } catch (e, stackTrace) {
      developer.log('❌ Error getting azkarReminderEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return true;
    }
  }

  Future<void> setMorningAzkarEnabled(bool enabled) async {
    developer.log('Setting morningAzkarEnabled to: $enabled', name: 'NotificationService');
    try {
      await _settingsBox.put(_morningAzkarKey, enabled);
      if (enabled) {
        await scheduleMorningAzkar();
      } else {
        await cancelMorningAzkar();
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error setting morningAzkarEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> setEveningAzkarEnabled(bool enabled) async {
    developer.log('Setting eveningAzkarEnabled to: $enabled', name: 'NotificationService');
    try {
      await _settingsBox.put(_eveningAzkarKey, enabled);
      if (enabled) {
        await scheduleEveningAzkar();
      } else {
        await cancelEveningAzkar();
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error setting eveningAzkarEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> setSleepAzkarEnabled(bool enabled) async {
    developer.log('Setting sleepAzkarEnabled to: $enabled', name: 'NotificationService');
    try {
      await _settingsBox.put(_sleepAzkarKey, enabled);
      if (enabled) {
        await scheduleSleepAzkar();
      } else {
          await cancelSleepAzkar();
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error setting sleepAzkarEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> setPrayerTimesEnabled(bool enabled) async {
    developer.log('Setting prayerTimesEnabled to: $enabled', name: 'NotificationService');
    try {
      await _settingsBox.put(_prayerTimesKey, enabled);
      if (enabled) {
        await schedulePrayerTimes();
      } else {
        await cancelPrayerTimes();
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error setting prayerTimesEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> setAzkarReminderEnabled(bool enabled) async {
    developer.log('Setting azkarReminderEnabled to: $enabled', name: 'NotificationService');
    try {
      await _settingsBox.put(_azkarReminderKey, enabled);
      if (enabled) {
        await scheduleAzkarReminders();
      } else {
        await cancelAzkarReminders();
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error setting azkarReminderEnabled', name: 'NotificationService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> scheduleMorningAzkar() async {
    developer.log('Scheduling morning azkar notification...', name: 'NotificationService');
    if (!morningAzkarEnabled) {
      developer.log('Morning azkar disabled, skipping', name: 'NotificationService');
      return;
    }

    try {
      final scheduledTime = _nextTime(4, 45);
      developer.log('Scheduled time: $scheduledTime', name: 'NotificationService');
      
      await _notifications.zonedSchedule(
        1001,
        'تذكير بأذكار الصباح',
        'بقي 15 دقيقة على وقت أذكار الصباح',
        scheduledTime,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      developer.log('✅ Morning azkar notification scheduled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling morning azkar', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> scheduleEveningAzkar() async {
    developer.log('Scheduling evening azkar notification...', name: 'NotificationService');
    if (!eveningAzkarEnabled) {
      developer.log('Evening azkar disabled, skipping', name: 'NotificationService');
      return;
    }

    try {
      final scheduledTime = _nextTime(17, 45);
      developer.log('Scheduled time: $scheduledTime', name: 'NotificationService');
      
      await _notifications.zonedSchedule(
        1002,
        'تذكير بأذكار المساء',
        'بقي 15 دقيقة على وقت أذكار المساء',
        scheduledTime,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      developer.log('✅ Evening azkar notification scheduled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling evening azkar', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> scheduleSleepAzkar() async {
    developer.log('Scheduling sleep azkar notification...', name: 'NotificationService');
    if (!sleepAzkarEnabled) {
      developer.log('Sleep azkar disabled, skipping', name: 'NotificationService');
      return;
    }

    try {
      final scheduledTime = _nextTime(21, 45);
      developer.log('Scheduled time: $scheduledTime', name: 'NotificationService');
      
      await _notifications.zonedSchedule(
        1003,
        'تذكير بأذكار النوم',
        'بقي 15 دقيقة على وقت أذكار النوم',
        scheduledTime,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      developer.log('✅ Sleep azkar notification scheduled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling sleep azkar', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> scheduleAzkarReminders() async {
    developer.log('Scheduling azkar reminders...', name: 'NotificationService');
    if (!azkarReminderEnabled) {
      developer.log('Azkar reminders disabled, skipping', name: 'NotificationService');
      return;
    }

    try {
      int id = 2000;
      for (int hour = 8; hour <= 22; hour++) {
        for (int minute in [0, 15, 30, 45]) {
          final scheduledTime = _nextTime(hour, minute);
          await _notifications.zonedSchedule(
            id++,
            'تذكير بالذكر',
            'لا تنسى ذكر الله في هذا الوقت',
            scheduledTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                _azkarChannelId,
                'أذكار وتذكيرات',
                channelDescription: 'تذكيرات الأذكار اليومية',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexact,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        }
      }
      developer.log('✅ Azkar reminders scheduled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling azkar reminders', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> schedulePrayerTimes() async {
    developer.log('Scheduling prayer times notifications...', name: 'NotificationService');
    if (!prayerTimesEnabled) {
      developer.log('Prayer times disabled, skipping', name: 'NotificationService');
      return;
    }

    try {
      final prayers = [
        {'name': 'الفجر', 'hour': 5, 'id': 3001},
        {'name': 'الظهر', 'hour': 12, 'id': 3002},
        {'name': 'العصر', 'hour': 15, 'id': 3003},
        {'name': 'المغرب', 'hour': 18, 'id': 3004},
        {'name': 'العشاء', 'hour': 20, 'id': 3005},
      ];

      for (final prayer in prayers) {
        developer.log('Scheduling notification for ${prayer['name']}', name: 'NotificationService');
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
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );

        int beforeHour = (prayer['hour'] as int) - 1;
        int beforeMinute = 45;
        if (beforeHour < 0) beforeHour = 23;
        
        await _notifications.zonedSchedule(
          (prayer['id'] as int) + 100,
          'تذكير بصلاة ${prayer['name']}',
          'بقي 15 دقيقة على أذان ${prayer['name']}',
          _nextTime(beforeHour, beforeMinute),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _prayerChannelId,
              'تنبيهات قبل الصلاة',
              channelDescription: 'تنبيهات قبل أوقات الصلاة بـ 15 دقيقة',
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
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      developer.log('✅ Prayer times notifications scheduled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling prayer times', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> cancelMorningAzkar() async {
    developer.log('Canceling morning azkar notification (ID: 1001)', name: 'NotificationService');
    try {
      await _notifications.cancel(1001);
      developer.log('✅ Morning azkar notification canceled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error canceling morning azkar', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> cancelEveningAzkar() async {
    developer.log('Canceling evening azkar notification (ID: 1002)', name: 'NotificationService');
    try {
      await _notifications.cancel(1002);
      developer.log('✅ Evening azkar notification canceled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error canceling evening azkar', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> cancelSleepAzkar() async {
    developer.log('Canceling sleep azkar notification (ID: 1003)', name: 'NotificationService');
    try {
      await _notifications.cancel(1003);
      developer.log('✅ Sleep azkar notification canceled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error canceling sleep azkar', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> cancelAzkarReminders() async {
    developer.log('Canceling all azkar reminders (IDs: 2000-2059)', name: 'NotificationService');
    try {
      for (int id = 2000; id < 2060; id++) {
        await _notifications.cancel(id);
      }
      developer.log('✅ Azkar reminders canceled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error canceling azkar reminders', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> cancelPrayerTimes() async {
    developer.log('Canceling all prayer times notifications', name: 'NotificationService');
    try {
      for (int id = 3001; id <= 3005; id++) {
        await _notifications.cancel(id);
        await _notifications.cancel(id + 100);
      }
      developer.log('✅ Prayer times notifications canceled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error canceling prayer times', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> cancelAllNotifications() async {
    developer.log('Canceling ALL notifications', name: 'NotificationService');
    try {
      await _notifications.cancelAll();
      developer.log('✅ All notifications canceled', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error canceling all notifications', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

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

    developer.log('nextTime($hour:$minute) -> $scheduledDate', name: 'NotificationService');
    return scheduledDate;
  }

  Future<void> showTestNotification({BuildContext? context}) async {
    developer.log('Showing test notification...', name: 'NotificationService');
    try {
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
      developer.log('✅ Test notification shown', name: 'NotificationService');

      if (context != null) {
        NotificationOverlayManager.show(
          context,
          title: 'اختبار الإشعارات',
          body: 'هذا إشعار اختباري من تطبيق نيّة',
          icon: Icons.notifications_active_rounded,
          color: Colors.blue,
        );
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error showing test notification', name: 'NotificationService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  void showAzkarOverlay(BuildContext context, String type) {
    NotificationOverlayManager.showAzkarNotification(context, type: type);
  }

  void showPrayerOverlay(BuildContext context, String prayerName) {
    NotificationOverlayManager.showPrayerNotification(context, prayerName: prayerName);
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    developer.log('Getting pending notifications...', name: 'NotificationService');
    try {
      final pending = await _notifications.pendingNotificationRequests();
      developer.log('Found ${pending.length} pending notifications', name: 'NotificationService');
      for (var n in pending) {
        developer.log(' - ID: ${n.id}, Title: ${n.title}', name: 'NotificationService');
      }
      return pending;
    } catch (e, stackTrace) {
      developer.log('❌ Error getting pending notifications', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<void> scheduleTestNotificationIn5Minutes() async {
    developer.log('Scheduling test notification in 5 minutes...', name: 'NotificationService');
    try {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5));
      developer.log('Test notification will be sent at: $scheduledTime', name: 'NotificationService');

      await _notifications.zonedSchedule(
        9999,
        'اختبار الإشعارات',
        'هذا إشعار اختباري مجدول بعد 5 دقائق',
        scheduledTime,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      developer.log('✅ Test notification scheduled successfully', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling test notification', name: 'NotificationService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> initializeAllSchedules() async {
    developer.log('Initializing all notification schedules...', name: 'NotificationService');
    try {
      if (morningAzkarEnabled) await scheduleMorningAzkar();
      if (eveningAzkarEnabled) await scheduleEveningAzkar();
      if (sleepAzkarEnabled) await scheduleSleepAzkar();
      if (azkarReminderEnabled) await scheduleAzkarReminders();
      if (prayerTimesEnabled) await schedulePrayerTimes();
      developer.log('✅ All schedules initialized', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('❌ Error initializing schedules', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }
}
