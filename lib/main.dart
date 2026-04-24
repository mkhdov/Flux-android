import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';

import 'core/constants/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/calendar/providers/calendar_provider.dart';
import 'features/calendar/repositories/calendar_repository.dart';
import 'features/calendar/repositories/event_repository.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/tasks/providers/task_provider.dart';
import 'features/tasks/repositories/task_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  // Initialize AuthProvider for global auth state
  final authProvider = AuthProvider(AuthRepository());
  await authProvider.checkAuthStatus();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(
          create: (_) => CalendarProvider(CalendarRepository(), EventRepository()),
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
    return MaterialApp(
      title: 'Flux',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Main dark aesthetic
      home: const AuthWrapper(),
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
