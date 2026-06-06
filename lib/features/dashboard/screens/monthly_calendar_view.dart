import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../calendar/models/event_model.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../../calendar/widgets/create_event_sheet.dart';
import '../../calendar/widgets/event_detail_sheet.dart';

class MonthlyCalendarView extends StatefulWidget {
  final CalendarProvider provider;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const MonthlyCalendarView(
      {super.key, required this.provider, this.scaffoldKey});

  @override
  State<MonthlyCalendarView> createState() => _MonthlyCalendarViewState();
}

class _MonthlyCalendarViewState extends State<MonthlyCalendarView>
    with WidgetsBindingObserver {
  String? _loadedKey;
  // Track drag for swipe-to-navigate
  double _dragStartX = 0;
  // Direction: 1 = forward (next month), -1 = backward (prev month)
  int _slideDirection = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureMonthLoaded());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadedKey = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureMonthLoaded());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MonthlyCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = _buildKey();
    if (newKey != _loadedKey) {
      _loadedKey = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureMonthLoaded());
  }

  String _buildKey() {
    final cal = widget.provider.selectedCalendar;
    final month = widget.provider.currentMonth;
    if (cal == null) return '';
    return '${cal.id}-${month.year}-${month.month}';
  }

  void _ensureMonthLoaded() {
    if (!mounted) return;
    final provider = widget.provider;
    if (provider.selectedCalendar == null) return;

    final key = _buildKey();
    if (_loadedKey == key) return;

    _loadedKey = key;
    provider.loadEventsForMonth(
      provider.selectedCalendar!.id,
      provider.currentMonth,
    );
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final provider = widget.provider;
    final dx = details.velocity.pixelsPerSecond.dx;
    // Also check position delta for slow swipes
    final positionDelta = details.globalPosition.dx - _dragStartX;
    if (dx < -200 || positionDelta < -60) {
      setState(() => _slideDirection = 1);
      provider.goToNextMonth();
    } else if (dx > 200 || positionDelta > 60) {
      setState(() => _slideDirection = -1);
      provider.goToPrevMonth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    if (provider.selectedCalendar == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month_outlined,
                color: AppColors.textMuted, size: 42),
            const SizedBox(height: 12),
            Text(
              'Select a calendar from the menu',
              style:
                  GoogleFonts.roboto(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final month =
        DateTime(provider.currentMonth.year, provider.currentMonth.month);
    final cells = _buildMonthCells(month);
    final rowCount = (cells.length / 7).ceil();

    return Column(
      children: [
        _MonthHeader(
            provider: provider, month: month, scaffoldKey: widget.scaffoldKey),
        const _WeekdayHeader(),
        Expanded(
          child: GestureDetector(
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    // Incoming widget: slides in from the direction of navigation
                    final isIncoming =
                        child.key == ValueKey('${month.year}-${month.month}');
                    if (isIncoming) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(_slideDirection.toDouble(), 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: const Interval(0.0, 0.5),
                          ),
                          child: child,
                        ),
                      );
                    }
                    // Outgoing widget: slides out in the swipe direction
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset.zero,
                        end: Offset(-_slideDirection.toDouble(), 0),
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInCubic,
                      )),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: const Interval(0.5, 1.0),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Stack(
                    key: ValueKey('${month.year}-${month.month}'),
                    children: [
                      RepaintBoundary(
                        child: _MonthGrid(
                          cells: cells,
                          rowCount: rowCount,
                          provider: provider,
                          onDayTap: (date, events) =>
                              _openDaySheet(context, date, events),
                          onEventTap: _openEventDetail,
                          errorMessage: provider.eventError,
                        ),
                      ),
                      if (provider.isLoadingMonth)
                        const Positioned.fill(
                          child: _LoadingOverlay(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<_MonthCell> _buildMonthCells(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final daysInPrevMonth = DateTime(month.year, month.month, 0).day;
    final leading = first.weekday % 7;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();

    final cells = <_MonthCell>[];
    for (var i = leading - 1; i >= 0; i--) {
      final date = DateTime(month.year, month.month - 1, daysInPrevMonth - i);
      cells.add(_MonthCell(
          date: date, inMonth: false, isToday: _sameDay(date, today)));
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      cells.add(_MonthCell(
          date: date, inMonth: true, isToday: _sameDay(date, today)));
    }
    var nextDay = 1;
    while (cells.length < total) {
      final date = DateTime(month.year, month.month + 1, nextDay++);
      cells.add(_MonthCell(
          date: date, inMonth: false, isToday: _sameDay(date, today)));
    }
    return cells;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _openEventDetail(String eventId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(eventId: eventId),
    );
  }

  void _openDaySheet(
      BuildContext context, DateTime date, List<EventModel> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthDayEventsSheet(
        date: date,
        events: events,
        onEventTap: (eventId) {
          Navigator.pop(context);
          _openEventDetail(eventId);
        },
        onAdd: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CreateEventSheet(selectedDate: date),
          );
        },
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      // Lightly darken the underlying transitioning layout without heavy blur filtering
      color: const Color(0xFF121212).withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background(context).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final List<_MonthCell> cells;
  final int rowCount;
  final CalendarProvider provider;
  final void Function(DateTime date, List<EventModel> events) onDayTap;
  final ValueChanged<String> onEventTap;
  final String? errorMessage;

  const _MonthGrid({
    required this.cells,
    required this.rowCount,
    required this.provider,
    required this.onDayTap,
    required this.onEventTap,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LayoutBuilder(builder: (context, constraints) {
          const minRowHeight = 88.0;
          final naturalRowHeight = (constraints.maxHeight - 8) / rowCount;
          final rowHeight =
              naturalRowHeight < minRowHeight ? minRowHeight : naturalRowHeight;
          final totalHeight = rowHeight * rowCount + 8;

          return SingleChildScrollView(
            physics: totalHeight > constraints.maxHeight
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: totalHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: Column(
                  children: List.generate(rowCount, (rowIndex) {
                    return SizedBox(
                      height: rowHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(7, (colIndex) {
                          final cellIndex = rowIndex * 7 + colIndex;
                          if (cellIndex >= cells.length) {
                            return const Expanded(child: SizedBox.shrink());
                          }
                          final cell = cells[cellIndex];
                          final events = provider.getEventsForDate(cell.date);
                          return Expanded(
                            child: _MonthDayCell(
                              cell: cell,
                              events: events,
                              rowHeight: rowHeight,
                              onTap: cell.inMonth
                                  ? () => onDayTap(cell.date, events)
                                  : null,
                              onEventTap: onEventTap,
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ),
          );
        }),
        if (errorMessage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _ErrorPill(message: errorMessage!),
          ),
      ],
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final CalendarProvider provider;
  final DateTime month;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const _MonthHeader(
      {required this.provider, required this.month, this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final createDate = _createDateForMonth(month);
    final now = DateTime.now();
    final isToday = month.year == now.year && month.month == now.month;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D2D))),
      ),
      child: Row(
        children: [
          // Menu button
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF64748B), size: 22),
            onPressed: () => scaffoldKey?.currentState?.openDrawer(),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          ),
          // Month + year title with mini-calendar toggle
          Expanded(
            child: GestureDetector(
              onTap: provider.toggleMiniCalendar,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: GoogleFonts.dmSans(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    provider.isMiniCalendarVisible
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          // Today button
          if (!isToday)
            TextButton(
              onPressed: provider.goToToday,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Today',
                style: GoogleFonts.roboto(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          // Add event button
          _HeaderIconButton(
            icon: Icons.add_rounded,
            tooltip: 'New event',
            color: AppColors.primary,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CreateEventSheet(selectedDate: createDate),
              );
            },
          ),
        ],
      ),
    );
  }

  DateTime _createDateForMonth(DateTime month) {
    final now = DateTime.now();
    if (now.year == month.year && now.month == month.month) return now;
    return DateTime(month.year, month.month, 1);
  }
}

class _WeekdayHeader extends StatelessWidget {
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: const Color(0xFF121212),
      child: Row(
        children: List.generate(_days.length, (index) {
          final isWeekend = index == 0 || index == 6;
          return Expanded(
            child: Center(
              child: Text(
                _days[index],
                style: GoogleFonts.roboto(
                  color:
                      isWeekend ? AppColors.textDisabled : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Day Cell ──────────────────────────────────────────────────────────────

class _MonthDayCell extends StatelessWidget {
  final _MonthCell cell;
  final List<EventModel> events;
  final double rowHeight;
  final VoidCallback? onTap;
  final ValueChanged<String> onEventTap;

  const _MonthDayCell({
    required this.cell,
    required this.events,
    required this.rowHeight,
    required this.onTap,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    const chipH = 17.0;
    const chipGap = 2.0;
    const headerH = 30.0;
    const vPad = 4.0;
    final availableH = rowHeight - headerH - vPad * 2;
    final maxChips = ((availableH + chipGap) / (chipH + chipGap)).floor();
    final showMax = maxChips > 0 ? maxChips : 1;
    final overflow = events.length > showMax ? events.length - showMax + 1 : 0;
    final chipsToShow = overflow > 0
        ? events.take(showMax - 1).toList()
        : events.take(showMax).toList();

    final isWeekend = cell.date.weekday == DateTime.saturday ||
        cell.date.weekday == DateTime.sunday;

    // Unified dark background — weekend cells get a very subtle warm tint,
    // weekday cells are the same neutral dark. Both stay in the dark-mode
    // palette without the jarring blue-tinted hue.
    final cellBg = cell.isToday
        ? AppColors.primary.withValues(alpha: 0.08)
        : isWeekend
            ? const Color(0xFF181818) // very slightly warm for weekends
            : const Color(0xFF141414); // neutral dark for weekdays

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: cell.isToday
                ? AppColors.primary.withValues(alpha: 0.45)
                : const Color(0xFF252525),
            width: cell.isToday ? 1.5 : 0.8,
          ),
        ),
        child: Opacity(
          opacity: cell.inMonth ? 1.0 : 0.30,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 3, 2, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 22,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cell.isToday
                              ? AppColors.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${cell.date.day}',
                          style: GoogleFonts.dmSans(
                            color: cell.isToday
                                ? Colors.white
                                : isWeekend
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...chipsToShow.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: chipGap),
                    child: _MonthEventChip(
                      event: event,
                      onTap: () => onEventTap(event.id),
                    ),
                  ),
                ),
                if (overflow > 0)
                  Container(
                    height: chipH,
                    margin: const EdgeInsets.only(bottom: chipGap),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+$overflow',
                      style: GoogleFonts.roboto(
                        color: AppColors.textMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Event chip ────────────────────────────────────────────────────────────

class _MonthEventChip extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const _MonthEventChip({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event);
    final time = _timeLabel(event);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 17,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                event.displayTitle,
                style: GoogleFonts.roboto(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (time != null) ...[
              const SizedBox(width: 2),
              Text(
                time,
                style: GoogleFonts.roboto(
                  color: AppColors.textSecondary,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Day events bottom sheet ───────────────────────────────────────────────

class _MonthDayEventsSheet extends StatelessWidget {
  final DateTime date;
  final List<EventModel> events;
  final ValueChanged<String> onEventTap;
  final VoidCallback onAdd;

  const _MonthDayEventsSheet({
    required this.date,
    required this.events,
    required this.onEventTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.46,
      minChildSize: 0.26,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF555555),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(date),
                            style: GoogleFonts.roboto(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMMM d, yyyy').format(date),
                            style: GoogleFonts.dmSans(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded,
                          color: AppColors.primary),
                      onPressed: onAdd,
                      tooltip: 'New event',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2D2D2D)),
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Text(
                          'No events',
                          style: GoogleFonts.roboto(
                              color: AppColors.textDisabled, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return _DaySheetEventTile(
                            event: event,
                            onTap: () => onEventTap(event.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DaySheetEventTile extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const _DaySheetEventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event);
    final range = _eventRangeLabel(event);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2D2D2D)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(10)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.displayTitle,
                    style: GoogleFonts.roboto(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          range,
                          style: GoogleFonts.roboto(
                              color: AppColors.textMuted, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textDisabled, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Small reusable widgets ────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ErrorPill extends StatelessWidget {
  final String message;

  const _ErrorPill({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: GoogleFonts.roboto(
            color: AppColors.errorLight,
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Data / helpers ────────────────────────────────────────────────────────

class _MonthCell {
  final DateTime date;
  final bool inMonth;
  final bool isToday;

  const _MonthCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
  });
}

Color _eventColor(EventModel event) {
  final hex = event.effectiveColor.replaceFirst('#', '');
  try {
    return Color(int.parse('FF$hex', radix: 16));
  } catch (_) {
    return AppColors.primary;
  }
}

String? _timeLabel(EventModel event) {
  if (event.allDay || event.startDateTime == null) return null;
  return DateFormat(event.startDateTime!.minute == 0 ? 'ha' : 'h:mma')
      .format(event.startDateTime!)
      .toUpperCase();
}

String _eventRangeLabel(EventModel event) {
  if (event.allDay) return 'All day';
  final start = event.startDateTime;
  final end = event.endDateTime;
  if (start == null) return 'Time not set';
  if (end == null) return DateFormat('h:mm a').format(start);
  return '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}';
}
