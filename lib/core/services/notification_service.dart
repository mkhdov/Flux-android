import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

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
        // Handle notification tapped logic here
        debugPrint('Notification clicked: ${notificationResponse.payload}');
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
    }
  }

  Future<void> scheduleEventReminder({
    required String eventId,
    required String eventTitle,
    required DateTime eventStartTime,
    int reminderMinutesBefore = 15,
  }) async {
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      eventStartTime.subtract(Duration(minutes: reminderMinutesBefore)),
      tz.local,
    );

    // If the scheduled date is in the past, don't schedule
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint('Cannot schedule notification in the past for event: $eventTitle');
      return;
    }

    final int notificationId = eventId.hashCode;

    // Motivational natural language body
    final String body =
        "Hey there! Your event '$eventTitle' is starting in $reminderMinutesBefore minutes. You've got this! Get ready to shine 🌟";

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
      title: '📅 Upcoming Event Reminder!',
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: eventId,
    );
    
    debugPrint('Scheduled notification for $eventTitle at $scheduledDate');
  }

  Future<void> cancelReminder(String eventId) async {
    await flutterLocalNotificationsPlugin.cancel(id: eventId.hashCode);
    debugPrint('Cancelled notification for event: $eventId');
  }
}
