import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static void Function(String? eventId)? onNotificationTap;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int maxPending = 50;
  static const Duration futureWindow = Duration(hours: 24);

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } catch (e) {
      debugPrint('Could not get local timezone: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_calendar_notification');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
        debugPrint('Notification clicked: ${notificationResponse.payload}');
        onNotificationTap?.call(notificationResponse.payload);
      },
    );
  }

  Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  /// One-shot local notification.
  /// Returns true if scheduled, false if skipped (past, beyond 24h window, or cap reached).
  Future<bool> scheduleEventReminder({
    required String eventId,
    required String eventTitle,
    required DateTime eventStartTime,
    int reminderMinutesBefore = 15,
  }) async {
    final scheduledDate =
        eventStartTime.subtract(Duration(minutes: reminderMinutesBefore));
    final now = DateTime.now();

    if (scheduledDate.isBefore(now)) {
      debugPrint('Skipping past notification for event: $eventTitle');
      return false;
    }

    if (scheduledDate.isAfter(now.add(futureWindow))) {
      debugPrint(
          'Skipping notification for $eventTitle (beyond 24h window)');
      return false;
    }

    final pendingCount = await pendingNotificationCount();
    if (pendingCount >= maxPending) {
      debugPrint(
          'Max pending notifications ($maxPending) reached. Skipping $eventTitle');
      return false;
    }

    final tz.TZDateTime tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
    final int notificationId = eventId.hashCode;

    const String bodyTemplate =
        "Hey there! Your event '{title}' is starting in {mins} minutes. You've got this! Get ready to shine";
    final String body = bodyTemplate
        .replaceAll('{title}', eventTitle)
        .replaceAll('{mins}', reminderMinutesBefore.toString());

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'event_reminders_channel',
      'Event Reminders',
      channelDescription: 'Notifications for upcoming calendar events',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Upcoming Event Reminder',
      body: body,
      scheduledDate: tzScheduled,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: eventId,
    );

    debugPrint(
        'Scheduled one-shot notification for $eventTitle at $scheduledDate');
    return true;
  }

  Future<void> cancelReminder(String eventId) async {
    await flutterLocalNotificationsPlugin.cancel(id: eventId.hashCode);
  }

  Future<int> pendingNotificationCount() async {
    try {
      final pending =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      debugPrint('Failed to get pending count: $e');
      return 0;
    }
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('Cancelled all local notifications');
  }
}
