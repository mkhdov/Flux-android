import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../../core/constants/app_colors.dart';
import 'calendar_view.dart';
import 'task_view.dart';
import 'meeting_view.dart';
import 'flux_ai_view.dart';
import '../../calendar/widgets/calendar_drawer.dart';
import '../../calendar/widgets/mini_calendar.dart';
import '../../settings/screens/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    final auth = context.read<AuthProvider>();
    final calendar = context.read<CalendarProvider>();

    if (auth.user != null) {
      await calendar.loadCalendars(auth.user!.id);
      if (calendar.selectedCalendar != null) {
        if (calendar.viewMode == CalendarViewMode.month) {
          await calendar.loadEventsForMonth(
              calendar.selectedCalendar!.id, calendar.currentMonth);
        } else {
          await calendar.loadEvents(calendar.selectedCalendar!.id);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMiniCalendarVisible = context.select<CalendarProvider, bool>(
      (provider) => provider.isMiniCalendarVisible,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background(context),
      drawer: const CalendarDrawer(),
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SizedBox.expand(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  CalendarView(scaffoldKey: _scaffoldKey),
                  TaskView(scaffoldKey: _scaffoldKey),
                  FluxAiView(scaffoldKey: _scaffoldKey),
                  MeetingView(scaffoldKey: _scaffoldKey),
                  SettingsScreen(scaffoldKey: _scaffoldKey),
                ],
              ),
            ),
            if (isMiniCalendarVisible && _currentIndex == 0)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context
                      .read<CalendarProvider>()
                      .setMiniCalendarVisible(false),
                  child: const SizedBox.expand(),
                ),
              ),
            if (isMiniCalendarVisible && _currentIndex == 0)
              Positioned(
                top: kToolbarHeight,
                left: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Consumer<CalendarProvider>(
                    builder: (context, provider, _) =>
                        MiniCalendar(provider: provider),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          border: Border(top: BorderSide(color: AppColors.border(context))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              _NavItem(
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                label: 'Calendar',
                isActive: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.check_box_outline_blank,
                activeIcon: Icons.check_box,
                label: 'Tasks',
                isActive: _currentIndex == 1,
                onTap: () {
                  setState(() => _currentIndex = 1);
                  final calendarProvider = context.read<CalendarProvider>();
                  if (calendarProvider.selectedCalendar != null) {
                    context
                        .read<TaskProvider>()
                        .fetchTasks(calendarProvider.selectedCalendar!.id);
                  }
                },
              ),
              _FluxAiNavItem(
                isActive: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _NavItem(
                icon: Icons.video_camera_back_outlined,
                activeIcon: Icons.video_camera_back,
                label: 'Meetings',
                isActive: _currentIndex == 3,
                onTap: () {
                  setState(() => _currentIndex = 3);
                  final calendarProvider = context.read<CalendarProvider>();
                  if (calendarProvider.selectedCalendar != null) {
                    calendarProvider
                        .loadMeetings(calendarProvider.selectedCalendar!.id);
                  }
                },
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                isActive: _currentIndex == 4,
                onTap: () => setState(() => _currentIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? AppColors.primary
                    : AppColors.adaptiveTextMuted(context),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.adaptiveTextMuted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FluxAiNavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _FluxAiNavItem({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Flux AI',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.adaptiveTextMuted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
