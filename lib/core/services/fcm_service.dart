import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../network/api_client.dart';
import '../constants/api_constants.dart';

/// This file handles FCM initialization and registration.
/// The background handler is now in main.dart to ensure it is registered 
/// as early as possible as per Firebase documentation.

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static void Function(String? eventId)? onNotificationTap;

  static const _deviceIdKey = 'flux_device_id';

  final _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request permission (Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Create the high-priority channel for Android
    if (Platform.isAndroid) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'event_reminders_channel',
            'Event Reminders',
            description: 'Notifications for upcoming calendar events',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ));
    }

    // Foreground message display
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification click when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification clicked! Data: ${message.data}');
      final eventId = message.data['eventId']?.toString();
      onNotificationTap?.call(eventId);
    });

    // Get any message that caused the app to open from a terminated state
    _messaging.getInitialMessage().then((RemoteMessage? initialMessage) {
      if (initialMessage != null) {
        debugPrint('[FCM] App opened from terminated state via notification: ${initialMessage.data}');
        final eventId = initialMessage.data['eventId']?.toString();
        onNotificationTap?.call(eventId);
      }
    });

    // Register token and refresh listener
    final token = await _messaging.getToken();

    if (token != null) await _registerToken(token);

    _messaging.onTokenRefresh.listen(_registerToken);
  }

  /// Manually register the current token (e.g., after login)
  Future<void> registerCurrentToken({String? userId}) async {
    try {
      debugPrint('[FCM] registerCurrentToken() called...');
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token obtained from Firebase');
        await _registerToken(token, userId: userId);
      } else {
        debugPrint('[FCM] Failed to get token from Firebase (returned null)');
      }
    } catch (e) {
      debugPrint('[FCM] Error getting current token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message received. Data: ${message.data}');
    
    // Render exactly one notification in foreground.
    // Backend sends data-only for reminders to avoid Android auto-displaying duplicates.
    final title = message.data['title'] ?? message.data['eventTitle'] ?? '📅 Reminder';
    final body  = message.data['body']  ?? _buildBodyFromData(message.data);
    
    debugPrint('[FCM] Displaying foreground notification — $title: $body');
    _showLocalNotification(
      title,
      body,
      message.data['eventId'],
      notificationId: _notificationIdForMessage(message),
    );
  }

  int _notificationIdForMessage(RemoteMessage message) {
    final reminderId = message.data['reminderId']?.toString();
    final eventId = message.data['eventId']?.toString();
    if (reminderId != null && reminderId.isNotEmpty) return reminderId.hashCode;
    if (eventId != null && eventId.isNotEmpty) return eventId.hashCode;
    return (message.messageId ?? 'reminder').hashCode;
  }

  String _buildBodyFromData(Map<String, dynamic> data) {
    final eventTitle = (data['eventTitle'] ?? '').toString().trim();
    final startIso = (data['eventStartTime'] ?? '').toString().trim();
    final location = (data['eventLocation'] ?? '').toString().trim();
    final allDay = (data['allDay'] ?? '').toString().toLowerCase() == 'true';

    String when = 'Starting soon';
    if (allDay) {
      when = 'All-day';
    } else if (startIso.isNotEmpty) {
      try {
        final dt = DateTime.parse(startIso).toLocal();
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        final yyyy = dt.year.toString().padLeft(4, '0');
        final mo = dt.month.toString().padLeft(2, '0');
        final dd = dt.day.toString().padLeft(2, '0');
        when = 'Starts $yyyy-$mo-$dd $hh:$mm';
      } catch (_) {
        when = 'Starts $startIso';
      }
    }

    final titlePart = eventTitle.isNotEmpty ? eventTitle : 'Calendar Event';
    final location = data['eventLocation'] ?? '';
    final wherePart = location.isNotEmpty ? ' • $location' : '';
    return '$titlePart — $when$wherePart';
  }

  Future<void> _showLocalNotification(
    String title,
    String body,
    String? eventId, {
    required int notificationId,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.show(
      id: notificationId,
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
  Future<void> _registerToken(String token, {String? userId}) async {
    try {
      final finalUserId = userId ?? await _getCachedUserId();
      
      if (finalUserId == null || finalUserId.isEmpty) {
        debugPrint('[FCM] No user ID provided or cached. Skipping registration.');
        return;
      }

      final deviceId = await _getOrCreateDeviceId();
      debugPrint('[FCM] Sending registration request to: $kDeviceTokenEndpoint');
      debugPrint('[FCM]   User ID:   $finalUserId');
      debugPrint('[FCM]   Device ID: $deviceId');
      debugPrint('[FCM]   Token:     ${token.substring(0, 10)}...');

      final response = await ApiClient.instance.post(
        kDeviceTokenEndpoint,
        data: {
          'userId':   finalUserId,
          'deviceId': deviceId,
          'fcmToken': token,
        },
      );
      
      debugPrint('[FCM] Registration SUCCESS. Status: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('[FCM] Registration FAILED (DioException):');
      debugPrint('[FCM]   Status: ${e.response?.statusCode}');
      debugPrint('[FCM]   Error Data: ${e.response?.data}');
      debugPrint('[FCM]   Message: ${e.message}');
    } catch (e) {
      debugPrint('[FCM] Registration FAILED (Unexpected): $e');
    }
  }

  Future<String?> _getCachedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cached_user_id');
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
