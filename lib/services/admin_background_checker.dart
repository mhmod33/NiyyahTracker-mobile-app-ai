import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase_options.dart';

/// Unique name for the periodic admin notification check task.
const String _kTaskName = 'admin_notification_check';

/// CallbackDispatcher that WorkManager invokes in the background isolate.
@pragma('vm:entry-point')
void adminNotificationBackgroundCallback() {
  Workmanager().executeTask((task, inputData) async {
    developer.log(
      'Background admin check started: $task',
      name: 'AdminBackgroundChecker',
    );

    try {
      await _initializeBackground();
      await _checkForNewNotification();
      await _checkForAppUpdate();
      developer.log(
        'Background admin check complete',
        name: 'AdminBackgroundChecker',
      );
      return true;
    } catch (e) {
      developer.log(
        'Background admin check error: $e',
        name: 'AdminBackgroundChecker',
      );
      return false;
    }
  });
}

/// Initialize Firebase and Hive in the background isolate.
Future<void> _initializeBackground() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    developer.log('Firebase init in background: $e', name: 'AdminBackgroundChecker');
  }

  try {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox('settings');
    }
  } catch (e) {
    developer.log('Hive init in background: $e', name: 'AdminBackgroundChecker');
  }
}

/// Check Firestore for new admin notifications and show a local notification.
Future<void> _checkForNewNotification() async {
  final db = FirebaseFirestore.instance;

  // Get the latest notification
  final snapshot = await db
      .collection('admin_notifications')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) return;

  final doc = snapshot.docs.first;
  final id = doc.id;
  final data = doc.data();

  // Load last seen ID
  String? lastSeenId;
  try {
    final box = Hive.isBoxOpen('settings')
        ? Hive.box('settings')
        : await Hive.openBox('settings');
    lastSeenId = box.get('last_seen_admin_notification_id') as String?;
  } catch (_) {}

  // Skip if already seen
  if (id == lastSeenId) return;

  // Save as seen
  final title = data['title'] as String? ?? 'إشعار من الإدارة';
  final body = data['body'] as String? ?? '';

  try {
    final box = Hive.isBoxOpen('settings')
        ? Hive.box('settings')
        : await Hive.openBox('settings');
    await box.put('last_seen_admin_notification_id', id);
  } catch (_) {}

  // Show local notification
  try {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(initSettings);

    await plugin.show(
      6000 + (DateTime.now().millisecondsSinceEpoch % 100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'azkar_reminders',
          'أذكار وتذكيرات',
          channelDescription: 'إشعارات الإدارة',
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
      payload: 'admin_notification',
    );
  } catch (e) {
    developer.log('Failed to show background notification: $e',
        name: 'AdminBackgroundChecker');
  }
}

/// Check Firestore for a newer app version and notify the user.
Future<void> _checkForAppUpdate() async {
  try {
    final db = FirebaseFirestore.instance;
    final doc = await db.collection('app_config').doc('current_version').get();
    if (!doc.exists) return;

    final latestVersion = doc.data()!['version'] as String?;
    final updateMessage = doc.data()!['updateMessage'] as String?;
    if (latestVersion == null) return;

    // Load last notified version
    final box = Hive.isBoxOpen('settings')
        ? Hive.box('settings')
        : await Hive.openBox('settings');
    final lastNotifiedVersion = box.get('last_notified_app_version') as String?;

    // Skip if already notified for this version
    if (latestVersion == lastNotifiedVersion) return;

    // Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (_isNewerVersion(latestVersion, currentVersion)) {
      final title = 'تحديث جديد لبصائر';
      final body = updateMessage ?? 'تحديث جديد v$latestVersion متوفر في المتجر';

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(initSettings);

      await plugin.show(
        6001,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'azkar_reminders',
            'أذكار وتذكيرات',
            channelDescription: 'إشعارات التحديثات',
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
        payload: 'version_update',
      );

      // Mark as notified
      await box.put('last_notified_app_version', latestVersion);
    }
  } catch (e) {
    developer.log('Background version check error: $e',
        name: 'AdminBackgroundChecker');
  }
}

/// Simple semver comparison — returns true if [latest] > [current].
bool _isNewerVersion(String latest, String current) {
  try {
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (latestParts.length < currentParts.length) latestParts.add(0);
    while (currentParts.length < latestParts.length) currentParts.add(0);
    for (int i = 0; i < latestParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  } catch (e) {
    return false;
  }
}

/// Register the periodic background check (call once at app startup).
Future<void> registerAdminBackgroundCheck() async {
  await Workmanager().initialize(
    adminNotificationBackgroundCallback,
    isInDebugMode: false,
  );

  await Workmanager().registerPeriodicTask(
    _kTaskName,
    _kTaskName,
    frequency: Duration(minutes: 30),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: Duration(minutes: 5),
  );

  developer.log(
    'Admin background check registered (every 30 min)',
    name: 'AdminBackgroundChecker',
  );
}
