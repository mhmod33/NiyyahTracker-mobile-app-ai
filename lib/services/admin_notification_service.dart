import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/notification_overlay.dart';

class AdminNotificationService {
  static final AdminNotificationService _instance = AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;
  String? _lastSeenId;

  void startListening(BuildContext context) {
    _subscription?.cancel();
    _subscription = _db
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;
      final doc = snapshot.docs.first;
      final id = doc.id;
      if (id == _lastSeenId) return;
      _lastSeenId = id;

      final data = doc.data();
      final title = data['title'] as String? ?? 'إشعار من الإدارة';
      final body = data['body'] as String? ?? '';

      developer.log('📢 New admin notification: $title', name: 'AdminNotificationService');

      if (context.mounted) {
        NotificationOverlayManager.show(
          context,
          title: title,
          body: body,
          icon: Icons.campaign_rounded,
          color: const Color(0xFFD4A843),
          duration: const Duration(seconds: 10),
        );
      }
    }, onError: (e) {
      developer.log('⚠️ Admin notification listener error: $e', name: 'AdminNotificationService');
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
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
      developer.log('✅ Admin notification sent: $title', name: 'AdminNotificationService');
      return true;
    } catch (e) {
      developer.log('❌ Failed to send admin notification: $e', name: 'AdminNotificationService');
      return false;
    }
  }
}
