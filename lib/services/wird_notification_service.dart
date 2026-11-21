import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:hive/hive.dart';
import 'wird_service.dart';

/// Top-level background handler for wird notification actions
@pragma('vm:entry-point')
void wirdNotificationBackgroundHandler(NotificationResponse response) {
  developer.log(
    'Background notification action: ${response.actionId}',
    name: 'WirdNotif',
  );
  // Handle button actions in background
  switch (response.actionId) {
    case 'mark_prayers':
    case 'mark_quran':
    case 'mark_azkar':
      developer.log('Task marked in background: ${response.actionId}', name: 'WirdNotif');
      break;
  }
}

/// Two daily wird notifications:
///   5001 — 9:00 AM  morning encouragement
///   5002 — 10:00 PM evening checklist (persistent, stays in panel)
/// Notification IDs 5001–5099 are reserved for this service.
class WirdNotificationService {
  static final WirdNotificationService _instance =
      WirdNotificationService._internal();
  factory WirdNotificationService() => _instance;
  WirdNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'wird_reminders';
  static const String _channelName = 'الورد اليومي';
  static const String _channelDesc = 'تذكيرات الورد اليومي من القرآن والعبادات';

  static const int _morningId = 5001;
  static const int _eveningId = 5002;

  static const String _enabledKey = 'wird_notifications_enabled';

  Box? _settingsBox;

  Future<void> init() async {
    try {
      _settingsBox = Hive.isBoxOpen('wird_settings')
          ? Hive.box('wird_settings')
          : await Hive.openBox('wird_settings');

      // Initialize notification plugin with action handler
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationAction,
        onDidReceiveBackgroundNotificationResponse: wirdNotificationBackgroundHandler,
      );

      await _createChannel();
      developer.log('✅ WirdNotificationService initialized', name: 'WirdNotif');
    } catch (e) {
      developer.log('❌ WirdNotificationService init error: $e', name: 'WirdNotif');
    }
  }

  void _handleNotificationAction(NotificationResponse response) {
    developer.log(
      'Notification action: ${response.actionId}, payload: ${response.payload}',
      name: 'WirdNotif',
    );

    // Handle button actions
    switch (response.actionId) {
      case 'mark_prayers':
        developer.log('✓ Prayers marked', name: 'WirdNotif');
        // TODO: Update prayers status in database
        break;
      case 'mark_quran':
        developer.log('✓ Quran marked', name: 'WirdNotif');
        // TODO: Update Quran reading status in database
        break;
      case 'mark_azkar':
        developer.log('✓ Azkar marked', name: 'WirdNotif');
        // TODO: Update Azkar status in database
        break;
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

  /// Schedule both daily wird notifications.
  Future<void> scheduleAll() async {
    if (!notificationsEnabled) return;
    await cancelAll();
    await _scheduleMorning();
    await _scheduleEvening();
    developer.log('✅ Wird notifications scheduled: 9:00 AM + 10:00 PM', name: 'WirdNotif');
  }

  /// 9:00 AM — morning encouragement.
  Future<void> _scheduleMorning() async {
    try {
      await _scheduleZoned(
        id: _morningId,
        title: 'صباح الخير 📖',
        body: 'ابدأ يومك بذكر الله — لا تنسَ وردك اليومي من القرآن الكريم',
        hour: 9,
        minute: 0,
      );
    } catch (e) {
      developer.log('❌ Error scheduling morning wird: $e', name: 'WirdNotif');
    }
  }

  /// 10:00 PM — evening checklist (persistent so it stays in the notification panel).
  Future<void> _scheduleEvening() async {
    try {
      final record = WirdService().getTodayRecord();
      final pagesRead = record.pagesRead;
      final target = record.targetPages;

      final body = [
        'الصلوات الخمس • قراءة القرآن ($pagesRead/$target صفحة)',
        'الأذكار • الاستغفار • الدعاء',
      ].join('\n');

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        ongoing: true,
        autoCancel: false,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'mark_prayers',
            '✓ الصلوات',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'mark_quran',
            '✓ القرآن',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'mark_azkar',
            '✓ الأذكار',
            showsUserInterface: false,
          ),
        ],
        styleInformation: BigTextStyleInformation(
          'هل أتممت عبادات اليوم؟\n\n'
          '☐ الصلوات الخمس\n'
          '☐ قراءة القرآن ($pagesRead/$target صفحة)\n'
          '☐ أذكار الصباح والمساء\n'
          '☐ الاستغفار\n'
          '☐ الدعاء',
          contentTitle: 'مراجعة عبادات اليوم 🌙',
          summaryText: 'بصائر • الورد اليومي',
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await androidPlugin?.canScheduleExactNotifications() ?? true;
      final mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _notifications.zonedSchedule(
        _eveningId,
        'مراجعة عبادات اليوم 🌙',
        body,
        _nextTime(22, 0),
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      developer.log('❌ Error scheduling evening wird: $e', name: 'WirdNotif');
    }
  }

  /// Show an immediate notification when a session is completed.
  Future<void> showSessionCompletedNotification(String session) async {
    final label = WirdSession.label(session);
    try {
      await _notifications.show(
        5010,
        'أحسنت! أتممت ورد $label 🎉',
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
      developer.log('❌ Error showing session completed notification: $e', name: 'WirdNotif');
    }
  }

  /// Show a streak milestone notification.
  Future<void> showStreakMilestone(int streak) async {
    if (streak != 7 && streak != 30 && streak % 10 != 0) return;

    final title = streak == 7
        ? 'أسبوع كامل من المواظبة!'
        : streak == 30
            ? 'شهر كامل من المواظبة!'
            : '$streak يوماً متتالياً!';
    final body = streak == 7
        ? 'ماشاء الله! حافظت على وردك 7 أيام متتالية'
        : streak == 30
            ? 'سبحان الله! 30 يوماً متتالياً على الورد اليومي'
            : 'تقبل الله منك، استمر في هذا الطريق المبارك';

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

  /// Test the evening notification immediately with action buttons.
  Future<void> showTestEveningNotification() async {
    try {
      final record = WirdService().getTodayRecord();
      final pagesRead = record.pagesRead;
      final target = record.targetPages;

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        ongoing: true,
        autoCancel: false,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'mark_prayers',
            '✓ الصلوات',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'mark_quran',
            '✓ القرآن',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'mark_azkar',
            '✓ الأذكار',
            showsUserInterface: false,
          ),
        ],
        styleInformation: BigTextStyleInformation(
          'هل أتممت عبادات اليوم؟\n\n'
          '☐ الصلوات الخمس\n'
          '☐ قراءة القرآن ($pagesRead/$target صفحة)\n'
          '☐ أذكار الصباح والمساء\n'
          '☐ الاستغفار\n'
          '☐ الدعاء',
          contentTitle: 'مراجعة عبادات اليوم 🌙 (اختبار)',
          summaryText: 'بصائر • الورد اليومي',
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notifications.show(
        5099,
        'مراجعة عبادات اليوم 🌙 (اختبار)',
        'اختبار الإشعار مع الأزرار',
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );

      developer.log('✅ Test evening notification shown', name: 'WirdNotif');
    } catch (e) {
      developer.log('❌ Error showing test evening notification: $e', name: 'WirdNotif');
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
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }

  Future<void> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidPlugin?.canScheduleExactNotifications() ?? true;
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextTime(hour, minute),
      details,
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
