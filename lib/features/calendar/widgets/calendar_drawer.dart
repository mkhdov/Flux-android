import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../../calendar/widgets/calendar_edit_sheet.dart';
import '../../calendar/widgets/create_calendar_sheet.dart';
import '../../calendar/widgets/calendar_list_widget.dart';
import '../../../core/constants/app_colors.dart';

class CalendarDrawer extends StatelessWidget {
  const CalendarDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final calendarProvider = context.watch<CalendarProvider>();
    final user = auth.user;

    return Drawer(
      backgroundColor: const Color(0xFF1C1C1E),
      child: SafeArea(
        child: Column(
          children: [

            // Calendars section
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  const SizedBox(height: 8),
                  // View Mode Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ViewModeItem(
                          icon: Icons.view_agenda_outlined,
                          label: 'Scheduled',
                          isSelected: calendarProvider.viewMode == CalendarViewMode.schedule,
                          onTap: () {
                            calendarProvider.setViewMode(CalendarViewMode.schedule);
                            Navigator.pop(context);
                          },
                        ),
                        _ViewModeItem(
                          icon: Icons.calendar_view_day_outlined,
                          label: 'Daily',
                          isSelected: calendarProvider.viewMode == CalendarViewMode.day,
                          onTap: () {
                            calendarProvider.setViewMode(CalendarViewMode.day);
                            Navigator.pop(context);
                          },
                        ),
                        _ViewModeItem(
                          icon: Icons.calendar_month_outlined,
                          label: 'Monthly',
                          isSelected: calendarProvider.viewMode == CalendarViewMode.month,
                          onTap: () {
                            calendarProvider.setViewMode(CalendarViewMode.month);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF2D2D2D), height: 1),
                  const SizedBox(height: 8),


                  if (calendarProvider.isLoadingCalendars)
                    const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  else if (calendarProvider.calendarError != null)
                    Text(
                      calendarProvider.calendarError!,
                      style: GoogleFonts.roboto(color: AppColors.error, fontSize: 13),
                    )
                  else
                    CalendarListWidget(
                      calendars: calendarProvider.calendars,
                      selectedCalendarId: calendarProvider.selectedCalendar?.id,
                      onSelect: (cal) {
                        calendarProvider.selectCalendar(cal);
                        Navigator.pop(context);
                      },
                      onEdit: (cal) => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => CalendarEditSheet(
                          calendar: cal,
                          userId: user?.id ?? '',
                        ),
                      ),
                      onAdd: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => CreateCalendarSheet(userId: user?.id ?? ''),
                      ),
                    ),
                ],
              ),
            ),

            // User profile section at bottom
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF2D2D2D))),
              ),
              child: Row(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: () => _showUserMenu(context, auth),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user?.initials ?? '?',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome',
                          style: GoogleFonts.roboto(fontSize: 11, color: AppColors.textMuted),
                        ),
                        Text(
                          user?.fullName ?? '',
                          style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.accent, size: 18),
                    onPressed: () => _confirmLogout(context, auth),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF555555),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(auth.user?.fullName ?? '', style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(auth.user?.email ?? '', style: GoogleFonts.roboto(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF3A3A3C)),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.accent),
              title: Text('Log out', style: GoogleFonts.roboto(color: AppColors.accent)),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout(context, auth);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2C),
        title: Text('Log out?', style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.roboto(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.roboto(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop(); // Close drawer
              auth.logout();
            },
            child: Text('Log out', style: GoogleFonts.roboto(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ViewModeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
