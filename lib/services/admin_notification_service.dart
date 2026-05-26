import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import 'notification_service.dart';

class AdminNotificationService {
  static final AdminNotificationService _instance =
      AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;
  String? _lastSeenId;
  DateTime? _listeningSince;

  void startListening() {
    _subscription?.cancel();
    _listeningSince = DateTime.now();

    _subscription = _db
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          (snapshot) async {
            if (snapshot.docs.isEmpty) return;

            final doc = snapshot.docs.first;
            final id = doc.id;
            final data = doc.data();

            await _loadLastSeenId();
            if (id == _lastSeenId) return;

            final createdAt = data['createdAt'];
            final createdAtDate = createdAt is Timestamp
                ? createdAt.toDate()
                : null;
            final isOldNotification =
                createdAtDate != null &&
                _listeningSince != null &&
                createdAtDate.isBefore(_listeningSince!);

            await _markNotificationSeen(id);

            if (isOldNotification) {
              developer.log(
                'Skipping old admin notification: $id',
                name: 'AdminNotificationService',
              );
              return;
            }

            final title =
                data['title'] as String? ?? 'إشعار من الإدارة';
            final body = data['body'] as String? ?? '';

            developer.log(
              'New admin notification: $title',
              name: 'AdminNotificationService',
            );

            await NotificationService().showAdminSystemNotification(
              title: title,
              body: body,
            );
          },
          onError: (e) {
            developer.log(
              'Admin notification listener error: $e',
              name: 'AdminNotificationService',
            );
          },
        );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _listeningSince = null;
  }

  Future<bool> sendNotification({
    required String title,
    required String body,
    String? adminId,
    String? adminName,
  }) async {
    try {
      await _db.collection('admin_notifications').add({
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'adminId': adminId ?? '',
        'adminName': adminName ?? 'الإدارة',
      });
      developer.log(
        'Admin notification sent: $title',
        name: 'AdminNotificationService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Failed to send admin notification: $e',
        name: 'AdminNotificationService',
      );
      return false;
    }
  }

  Future<void> _loadLastSeenId() async {
    if (_lastSeenId != null) return;

    try {
      final box = Hive.isBoxOpen('settings')
          ? Hive.box('settings')
          : await Hive.openBox('settings');
      _lastSeenId = box.get('last_seen_admin_notification_id') as String?;
    } catch (e) {
      developer.log(
        'Failed to load last seen notification ID: $e',
        name: 'AdminNotificationService',
      );
    }
  }

  Future<void> _markNotificationSeen(String id) async {
    _lastSeenId = id;

    try {
      final box = Hive.isBoxOpen('settings')
          ? Hive.box('settings')
          : await Hive.openBox('settings');
      await box.put('last_seen_admin_notification_id', id);
    } catch (e) {
      developer.log(
        'Failed to save last seen notification ID: $e',
        name: 'AdminNotificationService',
      );
    }
  }
}
