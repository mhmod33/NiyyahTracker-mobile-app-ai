import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:hive/hive.dart';
import 'wird_service.dart';

/// Handles all notifications related to the Daily Wird feature.
/// Uses notification IDs in the range 5000–5099.
class WirdNotificationService {
  static final WirdNotificationService _instance =
      WirdNotificationService._internal();
  factory WirdNotificationService() => _instance;
  WirdNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'wird_reminders';
  static const String _channelName = 'الورد اليومي';
  static const String _channelDesc = 'تذكيرات الورد اليومي من القرآن الكريم';

  // Notification IDs
  static const int _fajrId = 5001;
  static const int _dhuhrId = 5002;
  static const int _asrId = 5003;
  static const int _ishaId = 5004;
  static const int _endOfDayId = 5005;

  static const String _enabledKey = 'wird_notifications_enabled';

  Box? _settingsBox;

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen('wird_settings')) {
        _settingsBox = await Hive.openBox('wird_settings');
      } else {
        _settingsBox = Hive.box('wird_settings');
      }

      await _createChannel();
      developer.log('✅ WirdNotificationService initialized', name: 'WirdNotif');
    } catch (e) {
      developer.log('❌ WirdNotificationService init error: $e', name: 'WirdNotif');
    }
  }

  Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  bool get notificationsEnabled =>
      _settingsBox?.get(_enabledKey, defaultValue: true) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _settingsBox?.put(_enabledKey, enabled);
    if (enabled) {
      await scheduleAll();
    } else {
      await cancelAll();
    }
  }

  /// Schedule all wird reminders (4 prayer-time reminders + end-of-day summary).
  Future<void> scheduleAll() async {
    if (!notificationsEnabled) return;
    await cancelAll();

    await _scheduleSessionReminder(
      id: _fajrId,
      session: WirdSession.fajr,
      hour: 5,
      minute: 30,
      title: 'وقت ورد الصبح',
      body: 'ابدأ يومك بقراءة 5 صفحات من القرآن الكريم',
    );

    await _scheduleSessionReminder(
      id: _dhuhrId,
      session: WirdSession.dhuhr,
      hour: 13,
      minute: 0,
      title: 'وقت ورد الظهر',
      body: 'لا تنسَ قراءة وردك بعد صلاة الظهر',
    );

    await _scheduleSessionReminder(
      id: _asrId,
      session: WirdSession.asr,
      hour: 16,
      minute: 0,
      title: 'وقت ورد العصر',
      body: 'حان وقت قراءة وردك بعد صلاة العصر',
    );

    await _scheduleSessionReminder(
      id: _ishaId,
      session: WirdSession.isha,
      hour: 21,
      minute: 30,
      title: 'وقت ورد العشاء',
      body: 'أتمم وردك اليومي قبل النوم',
    );

    await _scheduleEndOfDaySummary();

    developer.log('✅ All wird notifications scheduled', name: 'WirdNotif');
  }

  Future<void> _scheduleSessionReminder({
    required int id,
    required String session,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      final scheduledTime = _nextTime(hour, minute);

      await _scheduleZoned(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      developer.log('📅 Scheduled wird reminder: $session at $hour:$minute',
          name: 'WirdNotif');
    } catch (e) {
      developer.log('❌ Error scheduling $session reminder: $e',
          name: 'WirdNotif');
    }
  }

  Future<void> _scheduleEndOfDaySummary() async {
    try {
      final scheduledTime = _nextTime(23, 0);
      await _scheduleZoned(
        id: _endOfDayId,
        title: 'ملخص وردك اليومي',
        body: 'اضغط لمشاهدة تقدمك في الورد اليومي',
        scheduledTime: scheduledTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      developer.log('📅 Scheduled end-of-day wird summary', name: 'WirdNotif');
    } catch (e) {
      developer.log('❌ Error scheduling end-of-day summary: $e',
          name: 'WirdNotif');
    }
  }

  /// Show an immediate notification when a session is completed.
  Future<void> showSessionCompletedNotification(String session) async {
    final label = WirdSession.label(session);
    try {
      await _notifications.show(
        5010,
        'أحسنت! أتممت ورد $label',
        'تقبل الله قراءتك، استمر في المواظبة',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
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
    } catch (e) {
      developer.log('❌ Error showing session completed notification: $e',
          name: 'WirdNotif');
    }
  }

  /// Show a streak milestone notification.
  Future<void> showStreakMilestone(int streak) async {
    String title;
    String body;

    if (streak == 7) {
      title = 'أسبوع كامل من المواظبة!';
      body = 'ماشاء الله! حافظت على وردك 7 أيام متتالية';
    } else if (streak == 30) {
      title = 'شهر كامل من المواظبة!';
      body = 'سبحان الله! 30 يوماً متتالياً على الورد اليومي';
    } else if (streak % 10 == 0) {
      title = '$streak يوماً متتالياً!';
      body = 'تقبل الله منك، استمر في هذا الطريق المبارك';
    } else {
      return;
    }

    try {
      await _notifications.show(
        5011,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
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
    } catch (e) {
      developer.log('❌ Error showing streak milestone: $e', name: 'WirdNotif');
    }
  }

  Future<void> cancelAll() async {
    for (int id = 5001; id <= 5015; id++) {
      await _notifications.cancel(id);
    }
    developer.log('🗑️ All wird notifications cancelled', name: 'WirdNotif');
  }

  tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<bool> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
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
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final canExact =
        await androidPlugin?.canScheduleExactNotifications() ?? true;
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
      return true;
    } catch (e) {
      developer.log('❌ _scheduleZoned error id=$id: $e', name: 'WirdNotif');
      return false;
    }
  }
}
