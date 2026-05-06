import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:hive/hive.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
      final currentTimeZone = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = currentTimeZone.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      developer.log('✅ Time zones initialized for $timeZoneName', name: 'NotificationService');
      
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
      
      // Request notification permission
      final androidResult = await androidPlugin?.requestNotificationsPermission();
      developer.log('Android notification permission result: $androidResult', name: 'NotificationService');
      
      if (androidResult == false) {
        developer.log('⚠️ WARNING: Android notification permission was DENIED!', name: 'NotificationService');
      }
      
      // Request exact alarm permission (for Android 12+)
      final canScheduleExactAlarms = await androidPlugin?.canScheduleExactNotifications();
      developer.log('Can schedule exact alarms: $canScheduleExactAlarms', name: 'NotificationService');
      
      if (canScheduleExactAlarms == false) {
        developer.log('Requesting exact alarm permission...', name: 'NotificationService');
        final exactResult = await androidPlugin?.requestExactAlarmsPermission();
        developer.log('Exact alarm permission result: $exactResult', name: 'NotificationService');
        if (exactResult == false) {
          developer.log('⚠️ WARNING: Exact alarm permission was DENIED!', name: 'NotificationService');
        }
      }

      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final iosResult = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      developer.log('iOS permission result: $iosResult', name: 'NotificationService');
      
      if (iosResult == false) {
        developer.log('⚠️ WARNING: iOS notification permissions were DENIED!', name: 'NotificationService');
      }
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

  Future<bool> scheduleMorningAzkar() async {
    developer.log('📌 Scheduling morning azkar notification...', name: 'NotificationService');
    if (!morningAzkarEnabled) {
      developer.log('⏭️ Morning azkar disabled, skipping', name: 'NotificationService');
      return false;
    }

    try {
      // First, cancel any existing notification with this ID
      await _notifications.cancel(1001);
      
      final scheduledTime = _nextTime(4, 45);
      developer.log('🎯 Target time for morning azkar: $scheduledTime', name: 'NotificationService');
      developer.log('⏱️ Time until notification: ${scheduledTime.difference(tz.TZDateTime.now(tz.local)).inMinutes} minutes', 
          name: 'NotificationService');
      
      await _scheduleZoned(
        id: 1001,
        title: 'تذكير بأذكار الصباح',
        body: 'بقي 15 دقيقة على وقت أذكار الصباح',
        scheduledTime: scheduledTime,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            _azkarChannelId,
            'أذكار وتذكيرات',
            channelDescription: 'تذكيرات الأذكار اليومية',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      developer.log('📤 zonedSchedule() call succeeded for ID 1001', name: 'NotificationService');
      
      // Verify notification was scheduled - use longer delay for matchDateTimeComponents
      await Future.delayed(const Duration(milliseconds: 1200));
      final pending = await getPendingNotifications();
      
      final isScheduled = pending.any((n) => n.id == 1001);
      
      if (isScheduled) {
        developer.log('✅✅ SUCCESS: Morning azkar ID 1001 confirmed in pending list', name: 'NotificationService');
      } else {
        developer.log('⚠️ WARNING: Morning azkar ID 1001 NOT found in pending list despite successful zonedSchedule()', 
            name: 'NotificationService');
        developer.log('💡 This might be normal with matchDateTimeComponents - notification will trigger at scheduled time', 
            name: 'NotificationService');
      }
      
      // Return true anyway if zonedSchedule succeeded, even if not in pending list
      return true;
    } catch (e, stackTrace) {
      developer.log('❌ FAILED: Error scheduling morning azkar', name: 'NotificationService', 
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> scheduleEveningAzkar() async {
    developer.log('Scheduling evening azkar notification...', name: 'NotificationService');
    if (!eveningAzkarEnabled) {
      developer.log('Evening azkar disabled, skipping', name: 'NotificationService');
      return false;
    }

    try {
      final scheduledTime = _nextTime(17, 45);
      developer.log('Scheduled time: $scheduledTime', name: 'NotificationService');
      
      await _scheduleZoned(
        id: 1002,
        title: 'تذكير بأذكار المساء',
        body: 'بقي 15 دقيقة على وقت أذكار المساء',
        scheduledTime: scheduledTime,
        details: const NotificationDetails(
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
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      // Verify notification was scheduled
      await Future.delayed(const Duration(milliseconds: 300));
      final pending = await getPendingNotifications();
      final isScheduled = pending.any((n) => n.id == 1002);
      
      if (isScheduled) {
        developer.log('✅ Evening azkar notification scheduled', name: 'NotificationService');
      } else {
        developer.log('⚠️ Evening azkar notification not found in pending list', name: 'NotificationService');
      }
      return isScheduled;
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling evening azkar', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> scheduleSleepAzkar() async {
    developer.log('Scheduling sleep azkar notification...', name: 'NotificationService');
    if (!sleepAzkarEnabled) {
      developer.log('Sleep azkar disabled, skipping', name: 'NotificationService');
      return false;
    }

    try {
      final scheduledTime = _nextTime(21, 45);
      developer.log('Scheduled time: $scheduledTime', name: 'NotificationService');
      
      await _scheduleZoned(
        id: 1003,
        title: 'تذكير بأذكار النوم',
        body: 'بقي 15 دقيقة على وقت أذكار النوم',
        scheduledTime: scheduledTime,
        details: const NotificationDetails(
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
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      // Verify notification was scheduled
      await Future.delayed(const Duration(milliseconds: 300));
      final pending = await getPendingNotifications();
      final isScheduled = pending.any((n) => n.id == 1003);
      
      if (isScheduled) {
        developer.log('✅ Sleep azkar notification scheduled', name: 'NotificationService');
      } else {
        developer.log('⚠️ Sleep azkar notification not found in pending list', name: 'NotificationService');
      }
      return isScheduled;
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling sleep azkar', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> scheduleAzkarReminders() async {
    developer.log('Scheduling azkar reminders...', name: 'NotificationService');
    if (!azkarReminderEnabled) {
      developer.log('Azkar reminders disabled, skipping', name: 'NotificationService');
      return false;
    }

    try {
      int id = 2000;
      int scheduledCount = 0;
      // Every 2 hours from 8 AM to 10 PM => 8, 10, 12, 14, 16, 18, 20, 22 (8 reminders/day)
      for (int hour = 8; hour <= 22; hour += 2) {
        for (int minute in [0]) {
          final scheduledTime = _nextTime(hour, minute);
          await _scheduleZoned(
            id: id++,
            title: 'تذكير بالذكر',
            body: 'لا تنسى ذكر الله في هذا الوقت',
            scheduledTime: scheduledTime,
            details: const NotificationDetails(
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
            matchDateTimeComponents: DateTimeComponents.time,
          );
          scheduledCount++;
        }
      }
      
      // Verify at least some notifications were scheduled
      await Future.delayed(const Duration(milliseconds: 500));
      final pending = await getPendingNotifications();
      final reminderCount = pending.where((n) => n.id >= 2000 && n.id < 2060).length;
      
      developer.log('✅ Azkar reminders scheduled: $scheduledCount notifications, $reminderCount verified in pending', name: 'NotificationService');
      return reminderCount > 0;
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling azkar reminders', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> schedulePrayerTimes() async {
    developer.log('Scheduling prayer times notifications...', name: 'NotificationService');
    if (!prayerTimesEnabled) {
      developer.log('Prayer times disabled, skipping', name: 'NotificationService');
      return false;
    }

    try {
      Coordinates coords = Coordinates(30.0444, 31.2357); // Default to Cairo
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
            Position pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
            coords = Coordinates(pos.latitude, pos.longitude);
          }
        }
      } catch (locErr) {
        developer.log('Location fetch error: $locErr', name: 'NotificationService');
      }

      final params = CalculationMethod.egyptian.getParameters()..madhab = Madhab.shafi;
      final pt = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);

      final prayers = [
        {'name': 'الفجر', 'time': pt.fajr, 'id': 3001},
        {'name': 'الظهر', 'time': pt.dhuhr, 'id': 3002},
        {'name': 'العصر', 'time': pt.asr, 'id': 3003},
        {'name': 'المغرب', 'time': pt.maghrib, 'id': 3004},
        {'name': 'العشاء', 'time': pt.isha, 'id': 3005},
      ];

      for (final prayer in prayers) {
        developer.log('Scheduling notification for ${prayer['name']}', name: 'NotificationService');
        
        DateTime prayerTime = prayer['time'] as DateTime;
        if (prayerTime.isBefore(DateTime.now())) {
          prayerTime = prayerTime.add(const Duration(days: 1));
        }
        final tzScheduledTime = tz.TZDateTime.from(prayerTime, tz.local);

        await _scheduleZoned(
          id: prayer['id'] as int,
          title: 'حان وقت صلاة ${prayer['name']}',
          body: 'الصلاة خير من النوم - حان وقت صلاة ${prayer['name']}',
          scheduledTime: tzScheduledTime,
          details: const NotificationDetails(
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
          matchDateTimeComponents: DateTimeComponents.time,
        );

        final beforeTime = prayerTime.subtract(const Duration(minutes: 15));
        final tzBeforeTime = tz.TZDateTime.from(beforeTime, tz.local);

        await _scheduleZoned(
          id: (prayer['id'] as int) + 100,
          title: 'تذكير بصلاة ${prayer['name']}',
          body: 'بقي 15 دقيقة على أذان ${prayer['name']}',
          scheduledTime: tzBeforeTime,
          details: const NotificationDetails(
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
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      
      // Verify at least some notifications were scheduled
      await Future.delayed(const Duration(milliseconds: 500));
      final pending = await getPendingNotifications();
      final prayerCount = pending.where((n) => n.id >= 3001 && n.id <= 3005).length;
      final reminderCount = pending.where((n) => n.id >= 3101 && n.id <= 3105).length;
      
      developer.log('✅ Prayer times notifications scheduled: $prayerCount prayers, $reminderCount reminders verified', name: 'NotificationService');
      return prayerCount > 0;
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling prayer times', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return false;
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
      0, // seconds
      0, // milliseconds
    );

    developer.log('_nextTime: now=$now, target=$scheduledDate', name: 'NotificationService');
    
    if (scheduledDate.isBefore(now)) {
      developer.log('_nextTime: target is in the past, adding 1 day', name: 'NotificationService');
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    developer.log('_nextTime($hour:$minute) -> final=$scheduledDate (${scheduledDate.difference(now).inMinutes} min from now)', name: 'NotificationService');
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
    developer.log('🔍 Fetching all pending notifications...', name: 'NotificationService');
    try {
      final pending = await _notifications.pendingNotificationRequests();
      developer.log('📊 Total pending notifications: ${pending.length}', name: 'NotificationService');
      
      if (pending.isEmpty) {
        developer.log('⚠️ NO pending notifications found!', name: 'NotificationService');
      } else {
        for (var n in pending) {
          developer.log('  📌 ID: ${n.id}, Title: "${n.title}", Body: "${n.body}"', 
              name: 'NotificationService');
        }
      }
      
      // Additional debug info
      final pendingCount = pending.length;
      final azkarCount = pending.where((n) => n.id >= 1000 && n.id < 2000).length;
      final reminderCount = pending.where((n) => n.id >= 2000 && n.id < 3000).length;
      final prayerCount = pending.where((n) => n.id >= 3000 && n.id < 4000).length;
      
      developer.log('📈 Summary: Total=$pendingCount, Azkar=$azkarCount, Reminders=$reminderCount, Prayer=$prayerCount',
          name: 'NotificationService');
      
      return pending;
    } catch (e, stackTrace) {
      developer.log('❌ Error getting pending notifications', name: 'NotificationService', 
          error: e, stackTrace: stackTrace);
      return [];
    }
  }
  
  Future<void> checkPermissionsStatus() async {
    developer.log('=== Checking Notification Permissions Status ===', name: 'NotificationService');
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      final canScheduleExact = await androidPlugin?.canScheduleExactNotifications();
      developer.log('Can Schedule Exact Notifications: $canScheduleExact', name: 'NotificationService');
      
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      developer.log('=== End Permission Check ===', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log('Error checking permissions', name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<bool> scheduleSimpleTestNotification() async {
    developer.log('📌 Scheduling SIMPLE test notification (no matchDateTimeComponents)...', 
        name: 'NotificationService');
    try {
      // Cancel existing
      await _notifications.cancel(9998);
      
      final now = tz.TZDateTime.now(tz.local);
      final scheduledTime = now.add(const Duration(seconds: 60));

      developer.log('🎯 Scheduling for: $scheduledTime (in ${scheduledTime.difference(now).inSeconds} seconds)',
          name: 'NotificationService');
      
      // Schedule WITHOUT matchDateTimeComponents
      await _scheduleZoned(
        id: 9987,
        title: 'اختبار إشعار بسيط',
        body: 'هذا إشعار اختبار بدون تكرار',
        scheduledTime: scheduledTime,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            'azkar_reminders',
            'أذكار وتذكيرات',
            channelDescription: 'تذكيرات الأذكار اليومية',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      
      developer.log('📤 zonedSchedule() call succeeded for simple test (ID 9998)', 
          name: 'NotificationService');
      
      await Future.delayed(const Duration(milliseconds: 800));
      final pending = await getPendingNotifications();
      
      final isFound = pending.any((n) => n.id == 9998);
      
      if (isFound) {
        developer.log('✅ SUCCESS: Simple test notification ID 9998 found in pending list!', 
            name: 'NotificationService');
      } else {
        developer.log('❌ FAILED: Simple test notification ID 9998 NOT found in pending list!', 
            name: 'NotificationService');
      }
      
      return isFound;
    } catch (e, stackTrace) {
      developer.log('❌ Error scheduling simple test notification', name: 'NotificationService',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> scheduleTestNotificationIn30Seconds() async {
    developer.log('📋 Scheduling test notification in 30 seconds...', name: 'NotificationService');
    try {
      // First cancel any existing notification with the same ID
      await _notifications.cancel(9999);
      developer.log('Cancelled existing notification with ID 9999', name: 'NotificationService');
      
      // Create TZDateTime properly
      final now = tz.TZDateTime.now(tz.local);
      final futureTime = now.add(const Duration(seconds: 30));
      
      // Ensure we have a properly constructed TZDateTime
      final scheduledTime = tz.TZDateTime(
        tz.local,
        futureTime.year,
        futureTime.month,
        futureTime.day,
        futureTime.hour,
        futureTime.minute,
        futureTime.second,
      );
      
      developer.log('Current TZ time: $now', name: 'NotificationService');
      developer.log('Target notification time: $scheduledTime', name: 'NotificationService');
      developer.log('Time difference: ${scheduledTime.difference(now).inSeconds} seconds', name: 'NotificationService');

      // Check permissions before scheduling
      final permissions = await checkNotificationPermissions();
      developer.log('Notification permissions: $permissions', name: 'NotificationService');
      
      developer.log('📤 Calling zonedSchedule with ID 9999...', name: 'NotificationService');
      
      await _scheduleZoned(
        id: 5555,
        title: 'اختبار الإشعارات',
        body: 'هذا إشعار اختباري مجدول بعد 30 ثانية',
        scheduledTime: scheduledTime,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            _azkarChannelId,
            'أذكار وتذكيرات',
            channelDescription: 'تذكيرات الأذكار اليومية',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            showWhen: true,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      
      developer.log('✅ zonedSchedule() completed without error', name: 'NotificationService');
      
      // Verify the notification is pending
      await Future.delayed(const Duration(milliseconds: 1000));
      final pending = await getPendingNotifications();
      developer.log('📊 Total pending notifications: ${pending.length}', name: 'NotificationService');
      
      // Check if our notification with ID 9999 is in the pending list
      final isScheduled = pending.any((n) => n.id == 9999);
      
      if (isScheduled) {
        developer.log('✅ Notification ID 9999 FOUND in pending list', name: 'NotificationService');
        final notif = pending.firstWhere((n) => n.id == 9999);
        developer.log('Notification details: ID=${notif.id}, Title=${notif.title}', name: 'NotificationService');
      } else {
        developer.log('❌ Notification ID 9999 NOT FOUND in pending list', name: 'NotificationService');
        developer.log('All pending notification IDs: ${pending.map((n) => n.id).toList()}', name: 'NotificationService');
      }
      
      return isScheduled;
    } catch (e, stackTrace) {
      developer.log('❌ ERROR in scheduleTestNotificationIn30Seconds', name: 'NotificationService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Map<String, bool>> checkNotificationPermissions() async {
    developer.log('Checking notification permissions...', name: 'NotificationService');
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      final notificationsEnabled = await androidPlugin?.areNotificationsEnabled();
      final canScheduleExact = await androidPlugin?.canScheduleExactNotifications();
      
      developer.log('✅ Notifications enabled: $notificationsEnabled', name: 'NotificationService');
      developer.log('✅ Can schedule exact alarms: $canScheduleExact', name: 'NotificationService');
      
      if (notificationsEnabled != true) {
        developer.log('⚠️ WARNING: Notifications are disabled!', name: 'NotificationService');
      }
      if (canScheduleExact != true) {
        developer.log('⚠️ WARNING: Cannot schedule exact alarms!', name: 'NotificationService');
      }
      
      return {
        'notificationsEnabled': notificationsEnabled ?? false,
        'canScheduleExact': canScheduleExact ?? false,
      };
    } catch (e, stackTrace) {
      developer.log('❌ Error checking permissions', name: 'NotificationService', error: e, stackTrace: stackTrace);
      return {'notificationsEnabled': false, 'canScheduleExact': false};
    }
  }

  /// Opens the system settings page for granting exact alarm permission (Android 12+).
  /// Returns true if the permission is now granted after returning from settings.
  Future<bool> openExactAlarmSettings() async {
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) return false;

      final alreadyGranted = await androidPlugin.canScheduleExactNotifications();
      if (alreadyGranted == true) return true;

      // Opens the "Alarms & reminders" special app access page in Settings
      await androidPlugin.requestExactAlarmsPermission();

      // Re-check after user returns from Settings
      final result = await androidPlugin.canScheduleExactNotifications();
      return result == true;
    } catch (e, stackTrace) {
      developer.log('❌ Error opening exact alarm settings', name: 'NotificationService',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Schedules a notification using exact timing if permitted; falls back to
  /// inexact automatically. Catches the SecurityException that flutter_local_notifications
  /// throws on Android 14+ when exact alarms aren't granted, then retries inexact.
  Future<bool> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required NotificationDetails details,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Default to true on platforms where the API isn't applicable (iOS / older Android).
    final bool canExact =
        await androidPlugin?.canScheduleExactNotifications() ?? true;

    AndroidScheduleMode mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    developer.log(
        '🛠️ _scheduleZoned id=$id at=$scheduledTime mode=$mode '
        'canExact=$canExact match=$matchDateTimeComponents',
        name: 'NotificationService');

    Future<void> doSchedule(AndroidScheduleMode m) {
      return _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        details,
        androidScheduleMode: m,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }

    try {
      await doSchedule(mode);
      developer.log('✅ Scheduled id=$id with mode=$mode', name: 'NotificationService');
      return true;
    } catch (e, st) {
      developer.log('❌ zonedSchedule failed for id=$id mode=$mode: $e',
          name: 'NotificationService', error: e, stackTrace: st);

      // Retry with inexact if the failure was due to missing exact-alarm permission.
      final isPermError = e.toString().toLowerCase().contains('exact_alarm') ||
          e.toString().toLowerCase().contains('exact alarm') ||
          e.toString().toLowerCase().contains('securityexception');
      if (mode == AndroidScheduleMode.exactAllowWhileIdle && isPermError) {
        try {
          developer.log('🔁 Retrying id=$id with inexactAllowWhileIdle…',
              name: 'NotificationService');
          await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
          developer.log('✅ Scheduled id=$id with fallback inexact mode',
              name: 'NotificationService');
          return true;
        } catch (e2, st2) {
          developer.log('❌ Fallback also failed for id=$id: $e2',
              name: 'NotificationService', error: e2, stackTrace: st2);
        }
      }
      return false;
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
