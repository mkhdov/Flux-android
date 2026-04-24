import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/calendar_model.dart';
import '../../../core/constants/app_colors.dart';

class CalendarListWidget extends StatelessWidget {
  final List<CalendarModel> calendars;
  final String? selectedCalendarId;
  final ValueChanged<CalendarModel> onSelect;
  final ValueChanged<CalendarModel> onEdit;

  const CalendarListWidget({
    super.key,
    required this.calendars,
    required this.selectedCalendarId,
    required this.onSelect,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: calendars.map((cal) {
        return _CalendarItem(
          calendar: cal,
          isSelected: selectedCalendarId == cal.id,
          onTap: () => onSelect(cal),
          onEdit: () => onEdit(cal),
        );
      }).toList(),
    );
  }
}

class _CalendarItem extends StatelessWidget {
  final CalendarModel calendar;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _CalendarItem({
    required this.calendar,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(calendar.colorHex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                calendar.title,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.more_horiz, color: AppColors.textMuted, size: 18),
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final raw = hex.replaceFirst('#', '');
    try {
      return Color(int.parse('FF$raw', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
