import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

/// Top-level handler — called by Firebase when the app is fully closed/background.
/// Must be a top-level function (not a method).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the notification using flutter_local_notifications so it appears
  // even when the app is terminated.
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('ic_calendar_notification');
  await plugin.initialize(settings: const InitializationSettings(android: android));

  final title = message.notification?.title ?? message.data['title'] ?? '📅 Reminder';
  final body  = message.notification?.body  ?? message.data['body']  ?? 'You have an upcoming event.';

  await plugin.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'event_reminders_channel',
        'Event Reminders',
        channelDescription: 'Notifications for upcoming calendar events',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_calendar_notification',
      ),
    ),
    payload: message.data['eventId'],
  );
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _deviceIdKey = 'flux_device_id';

  final _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request permission (Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set the background handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Foreground message display
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Register token and refresh listener
    final token = await _messaging.getToken();
    if (token != null) await _registerToken(token);

    _messaging.onTokenRefresh.listen(_registerToken);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? '📅 Reminder';
    final body  = message.notification?.body  ?? 'You have an upcoming event.';
    debugPrint('[FCM] Foreground message — $title: $body');
    // flutter_local_notifications will show this as a banner while app is open
    _showLocalNotification(title, body, message.data['eventId']);
  }

  Future<void> _showLocalNotification(String title, String body, String? eventId) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.show(
      id: title.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'event_reminders_channel',
          'Event Reminders',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_calendar_notification',
        ),
      ),
      payload: eventId,
    );
  }

  /// Register or refresh the FCM token with our backend.
  Future<void> _registerToken(String token) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      final prefs    = await SharedPreferences.getInstance();
      final userId   = prefs.getString('cached_user_id');
      if (userId == null || userId.isEmpty) return;

      await ApiClient.instance.post(
        '/api/devices/token',
        data: {
          'userId':   userId,
          'deviceId': deviceId,
          'fcmToken': token,
        },
      );
      debugPrint('[FCM] Token registered with backend for user $userId');
    } catch (e) {
      debugPrint('[FCM] Failed to register token: $e');
    }
  }

  /// Unregister this device's FCM token on logout.
  Future<void> unregisterToken(String userId) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      await ApiClient.instance.delete(
        '/api/devices/token',
        data: {'userId': userId, 'deviceId': deviceId},
      );
      debugPrint('[FCM] Token unregistered for user $userId');
    } catch (e) {
      debugPrint('[FCM] Failed to unregister token: $e');
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = '${Platform.operatingSystem}-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }
}
