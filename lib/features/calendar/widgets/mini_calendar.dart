import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/calendar_provider.dart';
import '../../../core/constants/app_colors.dart';

class MiniCalendar extends StatelessWidget {
  final CalendarProvider provider;

  const MiniCalendar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final currentMonth = provider.currentMonth;
    final today = DateTime.now();
    final selectedDate = provider.selectedDate;

    // Generate 42-cell grid (Mon-Sun)
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    int startOffset = firstDay.weekday - 1; // Monday is 1, so offset 0
    final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);

    final cells = <DateTime?>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= lastDay.day; d++) {
      cells.add(DateTime(currentMonth.year, currentMonth.month, d));
    }
    while (cells.length < 42) {
      cells.add(null);
    }

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Month nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 22),
                onPressed: provider.goToPrevMonth,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text(
                DateFormat('MMMM yyyy').format(currentMonth),
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 22),
                    onPressed: provider.goToNextMonth,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                    onPressed: () => provider.setMiniCalendarVisible(false),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Weekday headers
          Row(
            children: weekdays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 4),
          // Calendar grid
          ...List.generate(6, (row) {
            return Row(
              children: List.generate(7, (col) {
                final idx = row * 7 + col;
                final date = idx < cells.length ? cells[idx] : null;
                if (date == null) return const Expanded(child: SizedBox(height: 34));

                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isSelected = selectedDate != null &&
                    date.year == selectedDate.year &&
                    date.month == selectedDate.month &&
                    date.day == selectedDate.day;

                final eventsOnDate = provider.getEventsForDate(date);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      provider.selectDate(date);
                      provider.setMiniCalendarVisible(false);
                    },
                    child: Container(
                      height: 34,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : isToday
                                ? AppColors.primary.withOpacity(0.15)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            date.day.toString(),
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                            ),
                          ),
                          if (eventsOnDate.isNotEmpty)
                            Positioned(
                              bottom: 4,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: eventsOnDate.take(3).map((e) {
                                  final hex = e.effectiveColor.replaceFirst('#', '');
                                  final color = hex.length == 6
                                      ? Color(int.parse('FF$hex', radix: 16))
                                      : AppColors.primary;
                                  return Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}
