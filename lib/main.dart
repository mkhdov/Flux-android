import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/fcm_service.dart';

import 'core/constants/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/calendar/providers/calendar_provider.dart';
import 'features/calendar/repositories/calendar_repository.dart';
import 'features/calendar/repositories/event_repository.dart';
import 'features/calendar/widgets/event_detail_sheet.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/tasks/providers/task_provider.dart';
import 'features/tasks/repositories/task_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  debugPrint('[FCM] Background message received. ID: ${message.messageId}');
  debugPrint('[FCM] Data: ${message.data}');
  debugPrint('[FCM] Notification: ${message.notification?.title}');

  final plugin = FlutterLocalNotificationsPlugin();

  // Re-create/ensure channel exists in this isolate
  const channel = AndroidNotificationChannel(
    'event_reminders_channel',
    'Event Reminders',
    description: 'Notifications for upcoming calendar events',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const androidInit = AndroidInitializationSettings('ic_calendar_notification');
  await plugin.initialize(
    settings: const InitializationSettings(android: androidInit),
  );

  // Show exactly one notification in background.
  // Backend sends data-only for reminders, so message.notification is usually null.
  final title =
      message.data['title'] ?? message.data['eventTitle'] ?? '📅 Reminder';

  String body = (message.data['body'] ?? '').toString();
  if (body.trim().isEmpty) {
    final eventTitle = (message.data['eventTitle'] ?? '').toString().trim();
    final startIso = (message.data['eventStartTime'] ?? '').toString().trim();
    final location = (message.data['eventLocation'] ?? '').toString().trim();
    final allDay =
        (message.data['allDay'] ?? '').toString().toLowerCase() == 'true';

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
    final wherePart = location.isNotEmpty ? ' • $location' : '';
    body = '$titlePart — $when$wherePart';
  }

  final reminderId = (message.data['reminderId'] ?? '').toString();
  final eventId = (message.data['eventId'] ?? '').toString();
  final int notificationId = reminderId.isNotEmpty
      ? reminderId.hashCode
      : (eventId.isNotEmpty
          ? eventId.hashCode
          : (message.messageId ?? title).hashCode);

  await plugin.show(
    id: notificationId,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_calendar_notification',
        ticker: 'ticker',
      ),
    ),
    payload: message.data['eventId'],
  );

  debugPrint('[FCM] Background notification displayed.');
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void openEventDetail(String? eventId) {
  if (eventId == null || eventId.isEmpty) return;
  final context = navigatorKey.currentContext;
  if (context == null) return;
  showModalBottomSheet(
    context: context,
    builder: (_) => EventDetailSheet(eventId: eventId),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set the background handler as early as possible
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

  // Initialize local scheduled notifications
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  // Wire up notification tap navigation
  NotificationService.onNotificationTap = openEventDetail;
  FcmService.onNotificationTap = openEventDetail;

  // Initialize Firebase Cloud Messaging (remote push from backend)
  await FcmService.instance.init();

  // Initialize AuthProvider for global auth state
  final authProvider = AuthProvider(AuthRepository());
  await authProvider.checkAuthStatus();
  final themeProvider = await ThemeProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(
          create: (_) =>
              CalendarProvider(CalendarRepository(), EventRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => TaskProvider(TaskRepository()),
        ),
      ],
      child: const FluxApp(),
    ),
  );
}

class FluxApp extends StatelessWidget {
  const FluxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Flux',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.unknown) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (auth.status == AuthStatus.authenticated && auth.user != null) {
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
