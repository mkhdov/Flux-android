import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../../calendar/models/event_model.dart';
import '../../calendar/widgets/create_event_sheet.dart';
import '../../calendar/widgets/event_detail_sheet.dart';
import '../../calendar/widgets/event_ui_helpers.dart';
import '../../../core/constants/app_colors.dart';
import 'daily_schedule_grid.dart';
import 'monthly_calendar_view.dart';

class CalendarView extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const CalendarView({super.key, this.scaffoldKey});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late PageController _pageController;
  static const int _initialPage = 10000;
  DateTime _baseDate = DateTime.now();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CalendarProvider>();
    _baseDate = provider.selectedDate ?? DateTime.now();
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page, CalendarProvider provider) {
    if (_isSyncing) return;
    final newDate = _baseDate.add(Duration(days: page - _initialPage));
    _isSyncing = true;
    provider.selectDate(newDate);
    _isSyncing = false;
  }

  Future<void> _manualSync(CalendarProvider provider) async {
    final ok = await provider.syncSelectedGoogleCalendar();
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.eventError ?? 'Failed to refresh calendar.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Widget _withPullToSync(Widget child, CalendarProvider provider) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: const Color(0xFF1C1C1E),
      notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
      onRefresh: () => _manualSync(provider),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CalendarProvider>();
    
    // Sync PageController if provider.selectedDate changed externally (e.g. from MiniCalendar)
    if (!_isSyncing && provider.selectedDate != null) {
      final selectedSOD = DateTime(provider.selectedDate!.year, provider.selectedDate!.month, provider.selectedDate!.day);
      final baseSOD = DateTime(_baseDate.year, _baseDate.month, _baseDate.day);
      final diff = selectedSOD.difference(baseSOD).inDays;
      final targetPage = _initialPage + diff;
      if (_pageController.hasClients && _pageController.page?.round() != targetPage) {
        _isSyncing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(targetPage);
          }
          _isSyncing = false;
        });
      }
    }

    if (provider.viewMode == CalendarViewMode.schedule) {
      return _withPullToSync(
        _EventsList(key: const ValueKey('schedule'), provider: provider,
            scaffoldKey: widget.scaffoldKey),
        provider,
      );
    }

    if (provider.viewMode == CalendarViewMode.month) {
      return _withPullToSync(
        MonthlyCalendarView(
          key: const ValueKey('month'),
          provider: provider,
          scaffoldKey: widget.scaffoldKey,
        ),
        provider,
      );
    }

    return _withPullToSync(
      Column(
        children: [
          _buildDailyTopBar(provider, context),
          Expanded(
            child: PageView.builder(
              key: const ValueKey('daily-swipper'),
              controller: _pageController,
              onPageChanged: (page) => _onPageChanged(page, provider),
              itemBuilder: (context, index) {
                final date = _baseDate.add(Duration(days: index - _initialPage));
                return DailyScheduleGrid(
                  key: ValueKey('day-${date.toIso8601String()}'),
                  date: date,
                  events: provider.getEventsForDate(date),
                  provider: provider,
                  scaffoldKey: widget.scaffoldKey,
                  onEventMoved: (event, newStart) {
                    final evDate = event.startDateTime ?? date;
                    final newStartDt = DateTime(evDate.year, evDate.month, evDate.day).add(Duration(minutes: newStart));
                    final duration = (event.endDateTime?.difference(event.startDateTime ?? evDate) ?? const Duration(hours: 1));
                    provider.updateEvent(event.id, {
                      'startTime': newStartDt.toUtc().toIso8601String(),
                      'endTime': newStartDt.add(duration).toUtc().toIso8601String(),
                    });
                  },
                  onEventResized: (event, newStart, newDur) {
                    final evDate = event.startDateTime ?? date;
                    final newStartDt = DateTime(evDate.year, evDate.month, evDate.day).add(Duration(minutes: newStart));
                    final newEndDt = newStartDt.add(Duration(minutes: newDur));
                    provider.updateEvent(event.id, {
                      'startTime': newStartDt.toUtc().toIso8601String(),
                      'endTime': newEndDt.toUtc().toIso8601String(),
                    });
                  },
                  onDraftConfirmed: (title, start, dur) async {
                    if (provider.selectedCalendar == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a calendar first.')),
                        );
                      }
                      return false;
                    }
                    final startDt = DateTime(date.year, date.month, date.day).add(Duration(minutes: start));
                    final endDt = startDt.add(Duration(minutes: dur));
                    final tempId = provider.addOptimisticEvent(
                      title: title,
                      startDateTime: startDt,
                      endDateTime: endDt,
                      colorHex: '#6366F1',
                      allDay: false,
                      status: 'NOTSTARTED',
                      type: 'OTHERS',
                    );
                    final created = await provider.createEvent(data: {
                      'title': title,
                      'colorHex': '#6366F1',
                      'date': DateFormat('yyyy-MM-dd').format(startDt),
                      'startTime': startDt.toUtc().toIso8601String(),
                      'endTime': endDt.toUtc().toIso8601String(),
                      'allDay': false,
                      'status': 'NOTSTARTED',
                      'type': 'OTHERS',
                    });
                    if (!context.mounted) return false;
                    if (created.isEmpty) {
                      provider.removeEventById(tempId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not create event. Please try again.')),
                      );
                      return false;
                    }
                    provider.replaceOptimisticEvent(tempId, created.first);
                    return true;
                  },
                );
              },
            ),
          ),
        ],
      ),
      provider,
    );
  }

  Widget _buildDailyTopBar(CalendarProvider provider, BuildContext context) {
    final date = provider.selectedDate ?? DateTime.now();
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E), 
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D2D)))
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF64748B)),
            onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
          ),
          GestureDetector(
            onTap: () => provider.toggleMiniCalendar(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('EEEE').format(date),
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600,
                        color: isToday ? AppColors.primary : const Color(0xFF64748B))),
                const SizedBox(width: 8),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                      color: isToday ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('${date.day}',
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700,
                          color: isToday ? Colors.white : const Color(0xFFE2E8F0))),
                ),
                const SizedBox(width: 4),
                Icon(
                  provider.isMiniCalendarVisible
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: provider.goToToday,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text('Today',
                style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 26),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CreateEventSheet(selectedDate: date),
              );
            },
          ),
        ],
      ),
    );
  }
}


// _MiniCalendar removed and moved to drawer

class _EventsList extends StatefulWidget {
  final CalendarProvider provider;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const _EventsList({super.key, required this.provider, this.scaffoldKey});

  @override
  State<_EventsList> createState() => _EventsListState();
}

class _EventsListState extends State<_EventsList> {
  late ScrollController _scrollController;
  int _pastWeeks = 5;
  int _futureWeeks = 5;
  static const int daysPerWeek = 7;
  final Key _centerKey = const ValueKey('center-sliver');
  bool _isFutureLoading = false;
  bool _isPastLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isFutureLoading || _isPastLoading) return;
    
    // Load more future weeks
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 1000) {
      _loadMore(isFuture: true);
    }
    
    // Load more past weeks
    if (_scrollController.position.pixels <= _scrollController.position.minScrollExtent + 1000) {
      _loadMore(isFuture: false);
    }
  }

  Future<void> _loadMore({required bool isFuture}) async {
    setState(() {
      if (isFuture) {
        _isFutureLoading = true;
      } else {
        _isPastLoading = true;
      }
    });
    
    final selectedDate = widget.provider.selectedDate ?? DateTime.now();
    DateTime start, end;
    
    if (isFuture) {
      start = selectedDate.add(Duration(days: _futureWeeks * daysPerWeek));
      end = start.add(const Duration(days: daysPerWeek));
      setState(() => _futureWeeks += 1);
    } else {
      end = selectedDate.subtract(Duration(days: _pastWeeks * daysPerWeek));
      start = end.subtract(const Duration(days: daysPerWeek));
      setState(() => _pastWeeks += 1);
    }

    if (widget.provider.selectedCalendar != null) {
      await widget.provider.loadEventsForRange(
        widget.provider.selectedCalendar!.id,
        start,
        end,
      );
    }
    
    setState(() {
      _isFutureLoading = false;
      _isPastLoading = false;
    });
  }

  Widget _buildTopBar(BuildContext context) {
    final provider = widget.provider;
    final months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final dt = provider.currentMonth;
    final title = '${months[dt.month - 1]} ${dt.year}';
    return Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(bottom: BorderSide(color: AppColors.border(context))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu, color: AppColors.adaptiveTextSecondary(context)),
            onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: provider.toggleMiniCalendar,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.adaptiveTextPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    provider.isMiniCalendarVisible
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.adaptiveTextMuted(context),
                  ),
                ],
              ),
            ),
          ),
          if (provider.selectedCalendar != null)
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: AppColors.adaptiveTextSecondary(context), size: 22),
              onPressed: () => provider.loadEvents(provider.selectedCalendar!.id),
            ),
          TextButton(
            onPressed: provider.goToToday,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: Text('Today',
                style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.provider.selectedCalendar == null) {
      return Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_outlined, color: AppColors.textMuted, size: 40),
                  const SizedBox(height: 12),
                  Text('Select a calendar from the menu',
                      style: GoogleFonts.roboto(color: AppColors.textMuted, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Show loading only on initial load
    if (widget.provider.isLoadingEvents && widget.provider.events.isEmpty) {
      return Column(
        children: [
          _buildTopBar(context),
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
        ],
      );
    }

    final selectedDate = widget.provider.selectedDate ?? DateTime.now();

    return Column(
      children: [
        _buildTopBar(context),
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            center: _centerKey,
            slivers: [
              // Past loading spinner
              if (_isPastLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
              // Past events
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) {
                    // index 0 is 1 day before selectedDate, index 1 is 2 days before...
                    final date = selectedDate.subtract(Duration(days: index + 1));
                    return _DaySection(
                      date: date,
                      events: widget.provider.getEventsForDate(date),
                      isToday: false,
                      provider: widget.provider,
                    );
                  },
                  childCount: _pastWeeks * daysPerWeek,
                ),
              ),
              // Today and future events
              SliverList(
                key: _centerKey,
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) {
                    final date = selectedDate.add(Duration(days: index));
                    final isToday = date.year == DateTime.now().year && 
                                    date.month == DateTime.now().month && 
                                    date.day == DateTime.now().day;
                    return _DaySection(
                      date: date,
                      events: widget.provider.getEventsForDate(date),
                      isToday: isToday,
                      provider: widget.provider,
                    );
                  },
                  childCount: _futureWeeks * daysPerWeek,
                ),
              ),
              // Future loading spinner
              if (_isFutureLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  final DateTime date;
  final List<EventModel> events;
  final bool isToday;
  final CalendarProvider provider;

  const _DaySection({
    required this.date,
    required this.events,
    required this.isToday,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Day pill
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isToday ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday ? null : Border.all(color: const Color(0xFF2D2D2D)),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEE').format(date).toUpperCase(),
                      style: GoogleFonts.roboto(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isToday ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date.day.toString(),
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isToday ? Colors.white : AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(date),
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (isToday)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Today',
                            style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Rule
              Container(
                height: 1,
                width: 24,
                color: const Color(0xFF2D2D2D),
                margin: const EdgeInsets.only(right: 8),
              ),
              // Add event FAB
              InkWell(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CreateEventSheet(selectedDate: date),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: AppColors.primary, size: 18),
                      Text('Add', style: GoogleFonts.roboto(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Events
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('No events', style: GoogleFonts.roboto(color: AppColors.textDisabled, fontSize: 13)),
          )
        else
          ...events.map((e) => _EventTile(event: e)),
        const Divider(height: 1, color: Color(0xFF2D2D2D), indent: 16, endIndent: 16),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventModel event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final colorHex = event.effectiveColor.replaceFirst('#', '');
    Color color;
    try {
      color = Color(int.parse('FF$colorHex', radix: 16));
    } catch (_) {
      color = AppColors.primary;
    }

    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EventDetailSheet(eventId: event.id),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
        padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2D2D2D)),
        ),
        child: Row(
          children: [
            // Color stripe
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              ),
            ),
            const SizedBox(width: 10),
            // Time column
            if (!event.allDay)
              SizedBox(
                width: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      event.startDateTime != null ? DateFormat('h:mm').format(event.startDateTime!) : '',
                      style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    Text(
                      event.startDateTime != null ? DateFormat('a').format(event.startDateTime!) : '',
                      style: GoogleFonts.roboto(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text('-', style: GoogleFonts.roboto(fontSize: 10, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      event.endDateTime != null ? DateFormat('h:mm').format(event.endDateTime!) : '',
                      style: GoogleFonts.roboto(fontSize: 11, color: AppColors.textMuted),
                    ),
                    Text(
                      event.endDateTime != null ? DateFormat('a').format(event.endDateTime!) : '',
                      style: GoogleFonts.roboto(fontSize: 9, color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: 60,
                child: Text('All day', textAlign: TextAlign.right, style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ),
            const SizedBox(width: 12),
            // Title + info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.displayTitle,
                          style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (event.status != null && event.status != 'NOTSTARTED')
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.status == 'COMPLETED' ? 'Done' : event.status == 'CANCELLED' ? 'Cancelled' : 'Pending',
                            style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                    ],
                  ),
                  if (event.location != null && event.location!.displayText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!.displayText,
                              style: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (event.subtasks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.textDisabled.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Container(
                                      height: 4,
                                      width: constraints.maxWidth * event.subtaskProgress,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${event.subtaskDone}/${event.subtasks.length}',
                            style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  if (event.conference != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              event.conference!.isGoogleMeet ? Icons.video_camera_front : 
                              event.conference!.isZoom ? Icons.videocam : Icons.link,
                              color: color,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              event.conference!.isGoogleMeet ? 'Join Meet' :
                              event.conference!.isZoom ? 'Join Zoom' : 'Join Meeting',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (event.conference == null && event.subtasks.isEmpty && (event.location == null || event.location!.displayText.isEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: EventUi.metaRow(event, showStatus: true, iconSize: 13),
                    ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}
