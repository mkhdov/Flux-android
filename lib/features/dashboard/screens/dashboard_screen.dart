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
        await calendar.loadEvents(calendar.selectedCalendar!.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendarProvider = context.watch<CalendarProvider>();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF121212),
      drawer: const CalendarDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textSecondary),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: _buildTitle(calendarProvider),
        actions: [
          // Refresh button (not on settings tab)
          if (calendarProvider.selectedCalendar != null && _currentIndex != 3)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
              onPressed: () {
                if (_currentIndex == 0 && calendarProvider.selectedCalendar != null) {
                  calendarProvider.loadEvents(calendarProvider.selectedCalendar!.id);
                } else if (_currentIndex == 1 && calendarProvider.selectedCalendar != null) {
                  context.read<TaskProvider>().fetchTasks(calendarProvider.selectedCalendar!.id);
                } else if (_currentIndex == 2 && calendarProvider.selectedCalendar != null) {
                  calendarProvider.loadMeetings(calendarProvider.selectedCalendar!.id);
                }
              },
            ),
          // Today button (calendar view)
          if (_currentIndex == 0) ...[
            TextButton(
              onPressed: calendarProvider.goToToday,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: Text('Today', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                CalendarView(),
                TaskView(),
                MeetingView(),
                SettingsScreen(),
              ],
            ),
          ),
          if (calendarProvider.isMiniCalendarVisible && _currentIndex == 0)
            // Tap-outside-to-close barrier behind the mini calendar.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => calendarProvider.setMiniCalendarVisible(false),
                child: const SizedBox.expand(),
              ),
            ),
          if (calendarProvider.isMiniCalendarVisible && _currentIndex == 0)
            Positioned(
              top: 0,
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
                child: MiniCalendar(provider: calendarProvider),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          border: Border(top: BorderSide(color: Color(0xFF2D2D2D))),
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
                  if (calendarProvider.selectedCalendar != null) {
                    context.read<TaskProvider>().fetchTasks(calendarProvider.selectedCalendar!.id);
                  }
                },
              ),
              _NavItem(
                icon: Icons.video_camera_back_outlined,
                activeIcon: Icons.video_camera_back,
                label: 'Meetings',
                isActive: _currentIndex == 2,
                onTap: () {
                  setState(() => _currentIndex = 2);
                  if (calendarProvider.selectedCalendar != null) {
                    calendarProvider.loadMeetings(calendarProvider.selectedCalendar!.id);
                  }
                },
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                isActive: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(CalendarProvider calendarProvider) {
    if (_currentIndex == 0) {
      return GestureDetector(
        onTap: calendarProvider.toggleMiniCalendar,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getMonthYear(calendarProvider.currentMonth),
                    style: GoogleFonts.roboto(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    calendarProvider.isMiniCalendarVisible ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              if (calendarProvider.selectedCalendar != null)
                Text(
                  calendarProvider.selectedCalendar!.title,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (_currentIndex == 2) {
      return Text(
        'Meetings',
        style: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );
    }
    if (_currentIndex == 3) {
      return Text(
        'Settings',
        style: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );
    }
    return Text(
      'Tasks',
      style: GoogleFonts.roboto(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  String _getMonthYear(DateTime dt) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[dt.month - 1]} ${dt.year}';
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
                color: isActive ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
