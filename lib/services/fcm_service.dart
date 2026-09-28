import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';

/// Top-level background message handler (required by FCM).
/// When the app is in the background, the system automatically displays
/// the notification from the FCM payload — this handler runs alongside it
/// for data-only messages or custom processing.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log(
    'FCM background message: ${message.notification?.title}',
    name: 'FcmService',
  );
  // System auto-displays the notification from the FCM payload,
  // so no duplicate local notification needed here.
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _currentToken;

  /// Initialize FCM: request permissions, get token, register handlers.
  Future<void> init() async {
    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Request notification permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    developer.log(
      'FCM permission: ${settings.authorizationStatus}',
      name: 'FcmService',
    );

    // Get and store the FCM token
    await _refreshToken();

    // Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) {
      developer.log('FCM token refreshed', name: 'FcmService');
      _currentToken = newToken;
      _storeToken(newToken);
    });

    // Handle foreground messages — show local notification
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification taps when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpenedApp(initialMessage);
    }
  }

  /// Public method to register the current FCM token.
  /// Call this after user logs in.
  Future<void> registerToken() async {
    await _refreshToken();
  }

  /// Refresh the FCM token and store it.
  Future<void> _refreshToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _storeToken(token);
      }
    } catch (e) {
      developer.log('FCM getToken error: $e', name: 'FcmService');
    }
  }

  /// Store the FCM token in Firestore.
  Future<void> _storeToken(String token) async {
    try {
      final existing = await _db
          .collection('fcm_tokens')
          .where('token', isEqualTo: token)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await _db.collection('fcm_tokens').add({
          'token': token,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        developer.log('FCM token stored', name: 'FcmService');
      } else {
        // Update timestamp on existing token
        await existing.docs.first.reference.update({
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      developer.log('FCM storeToken error: $e', name: 'FcmService');
    }
  }

  /// Handle incoming foreground messages.
  void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;

    developer.log(
      'FCM foreground message: $title',
      name: 'FcmService',
    );

    if (title != null && title.isNotEmpty) {
      NotificationService().showAdminSystemNotification(
        title: title,
        body: body ?? '',
      );
    }
  }

  /// Handle notification tap.
  void _onMessageOpenedApp(RemoteMessage message) {
    developer.log(
      'FCM message opened: ${message.notification?.title}',
      name: 'FcmService',
    );
    // Future: navigate to notification details page
  }

  /// Remove a token (call on logout if needed).
  Future<void> removeToken() async {
    if (_currentToken == null) return;
    try {
      final existing = await _db
          .collection('fcm_tokens')
          .where('token', isEqualTo: _currentToken)
          .limit(1)
          .get();
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }
      developer.log('FCM token removed', name: 'FcmService');
    } catch (e) {
      developer.log('FCM removeToken error: $e', name: 'FcmService');
    }
  }
}
