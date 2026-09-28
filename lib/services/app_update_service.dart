import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'notification_service.dart';

/// Checks Firestore for the latest app version and notifies the user
/// if a newer version is available.
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _checked = false;

  /// Check if a newer version is available and notify if so.
  /// Call once on app startup.
  Future<void> checkForUpdate() async {
    if (_checked) return;
    _checked = true;

    try {
      final doc = await _db.collection('app_config').doc('current_version').get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final latestVersion = data['version'] as String?;
      final updateMessage = data['updateMessage'] as String?;
      if (latestVersion == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      developer.log(
        'App version: local=$currentVersion, latest=$latestVersion',
        name: 'AppUpdateService',
      );

      if (_isNewerVersion(latestVersion, currentVersion)) {
        final title = 'تحديث جديد';
        final body = updateMessage ?? 'تحديث جديد للتطبيق v$latestVersion متوفر';

        // Check if we already notified about this version (shared with background checker)
        try {
          final box = Hive.isBoxOpen('settings')
              ? Hive.box('settings')
              : await Hive.openBox('settings');
          final lastNotified = box.get('last_notified_app_version') as String?;
          if (latestVersion == lastNotified) {
            developer.log('Already notified about v$latestVersion', name: 'AppUpdateService');
            return;
          }
          await box.put('last_notified_app_version', latestVersion);
        } catch (_) {}

        await NotificationService().showAdminSystemNotification(
          title: title,
          body: body,
        );
      }
    } catch (e) {
      developer.log('AppUpdateService check error: $e', name: 'AppUpdateService');
    }
  }

  /// Simple semver comparison — returns true if [latest] > [current].
  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      // Pad to equal length
      while (latestParts.length < currentParts.length) latestParts.add(0);
      while (currentParts.length < latestParts.length) currentParts.add(0);

      for (int i = 0; i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false; // equal versions
    } catch (e) {
      return false;
    }
  }
}
