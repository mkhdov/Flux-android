import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/calendar_model.dart';
import '../providers/calendar_provider.dart';
import '../../../core/constants/app_colors.dart';

/// A collapsible calendar list with an animated expand/collapse arrow.
class CalendarListWidget extends StatefulWidget {
  final List<CalendarModel> calendars;
  final String? selectedCalendarId;
  final ValueChanged<CalendarModel> onSelect;
  final ValueChanged<CalendarModel> onEdit;
  final VoidCallback onAdd;

  const CalendarListWidget({
    super.key,
    required this.calendars,
    required this.selectedCalendarId,
    required this.onSelect,
    required this.onEdit,
    required this.onAdd,
  });

  @override
  State<CalendarListWidget> createState() => _CalendarListWidgetState();
}

class _CalendarListWidgetState extends State<CalendarListWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrowController;
  late final Animation<double> _arrowTurns;
  bool? _lastExpanded;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _arrowTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    context.read<CalendarProvider>().toggleCalendarListExpanded();
  }

   @override
  Widget build(BuildContext context) {
    final calendarProvider = context.watch<CalendarProvider>();
    final expanded = calendarProvider.isCalendarListExpanded;

    // Sync animation controller with provider state
    if (_lastExpanded == null) {
      _arrowController.value = expanded ? 1.0 : 0.0;
      _lastExpanded = expanded;
    } else if (_lastExpanded != expanded) {
      if (expanded) {
        _arrowController.forward();
      } else {
        _arrowController.reverse();
      }
      _lastExpanded = expanded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsible header row
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _toggleExpanded,
                  borderRadius: BorderRadius.circular(6),
                  hoverColor: Colors.white.withValues(alpha: 0.05),
                  splashColor: AppColors.primary.withValues(alpha: 0.1),
                  highlightColor: AppColors.primary.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          'MY CALENDARS',
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Spacer(),
                        RotationTransition(
                          turns: _arrowTurns,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onAdd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add, color: AppColors.primary, size: 16),
                ),
              ),
            ],
          ),
        ),
        // Animated collapsible list
        SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: _arrowController,
            curve: Curves.easeInOut,
          ),
          axisAlignment: -1.0, // align to top so it grows downwards
          child: Column(
            children: widget.calendars.map((cal) {
              return _CalendarItem(
                calendar: cal,
                isSelected: widget.selectedCalendarId == cal.id,
                onTap: () => widget.onSelect(cal),
                onEdit: () => widget.onEdit(cal),
              );
            }).toList(),
          ),
        ),
      ],
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

  Color _hexToColor(String hex) {
    final raw = hex.replaceFirst('#', '');
    try {
      return Color(int.parse('FF$raw', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(calendar.colorHex);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
        decoration: BoxDecoration(
          // Selected: use calendar's own color as the highlight tint
          color: isSelected ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.30), width: 0.8)
              : null,
        ),
        child: Row(
          children: [
            // Colour dot
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            // Title
            Expanded(
              child: Text(
                calendar.title,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : const Color(0xFFCCCCCC),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Primary badge – small star icon
            if (calendar.isPrimary)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            // Edit button — compact
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.more_horiz,
                    color: AppColors.textMuted, size: 16),
                padding: EdgeInsets.zero,
                splashRadius: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

