import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../../calendar/models/event_model.dart';
import '../../calendar/widgets/event_detail_sheet.dart';
import '../../calendar/widgets/create_event_sheet.dart';
import '../../calendar/widgets/event_ui_helpers.dart';
import '../../../core/constants/app_colors.dart';

// ─── Layout info ──────────────────────────────────────────────────────────────
class _LayoutInfo {
  final int col;
  final int totalCols;
  const _LayoutInfo({required this.col, required this.totalCols});
}

// ─── Draft event state ────────────────────────────────────────────────────────
class _Draft {
  int startMins;
  int durationMins;
  String title;
  _Draft({required this.startMins, required this.durationMins, this.title = ''});
}

// ─── Drag state ───────────────────────────────────────────────────────────────
enum _DragKind { move, resizeTop, resizeBottom }

class _DragState {
  final String eventId;
  final _DragKind kind;
  final int origStart;
  final int origDuration;
  final double startGlobalY;

  const _DragState({
    required this.eventId,
    required this.kind,
    required this.origStart,
    required this.origDuration,
    required this.startGlobalY,
  });
}



// ═══════════════════════════════════════════════════════════════════════════════
class DailyScheduleGrid extends StatefulWidget {
  final DateTime date;
  final List<EventModel> events;
  final CalendarProvider provider;

  /// Called when user finishes dragging an event to a new time
  final void Function(EventModel event, int newStartMinutes)? onEventMoved;

  /// Called when user finishes resizing an event
  final void Function(EventModel event, int newStartMinutes, int newDurationMinutes)? onEventResized;

  /// Called when user confirms the draft (quick create)
  final Future<bool> Function(String title, int startMinutes, int durationMinutes)? onDraftConfirmed;

  const DailyScheduleGrid({
    super.key,
    required this.date,
    required this.events,
    required this.provider,
    this.onEventMoved,
    this.onEventResized,
    this.onDraftConfirmed,
  });

  @override
  State<DailyScheduleGrid> createState() => _DailyScheduleGridState();
}

class _DailyScheduleGridState extends State<DailyScheduleGrid> {
  // ─── Constants ──────────────────────────────────────────────────────────────
  static const double _hourH      = 64.0;
  static const double _timeColW   = 56.0;
  static const double _rPad       = 8.0;
  static const double _colGap     = 3.0;
  static const int    _snapMins   = 15;
  static const int    _totalHours = 24;

  // ─── Controllers ────────────────────────────────────────────────────────────
  final ScrollController _scroll = ScrollController();
  final TextEditingController _draftCtrl = TextEditingController();
  final FocusNode _draftFocus = FocusNode();

  // ─── Event drag ─────────────────────────────────────────────────────────────
  _DragState? _drag;
  final Map<String, int> _startOvr = {};
  final Map<String, int> _durOvr   = {};

  // ─── Draft ──────────────────────────────────────────────────────────────────
  _Draft? _draft;
  bool _isSubmittingDraft = false;

  // ─── Current time ticker ────────────────────────────────────────────────────
  late final Stream<DateTime> _clockStream;

  @override
  void initState() {
    super.initState();
    _clockStream = Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _draftCtrl.dispose();
    _draftFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DailyScheduleGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.date != oldWidget.date) {
      _scrollToNow();
    }
  }

  // ─── Scroll ─────────────────────────────────────────────────────────────────
  void _scrollToNow() {
    if (!_scroll.hasClients) return;
    final now  = DateTime.now();
    final topY = (_minsToY(now.hour * 60 + now.minute) - 80).clamp(0.0, double.infinity);
    _scroll.animateTo(
      topY.clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  // ─── Coordinate helpers ─────────────────────────────────────────────────────
  double _minsToY(int mins)   => (mins / 60.0) * _hourH;
  int    _snapToGrid(double m) => ((m / _snapMins).round() * _snapMins).clamp(0, 24 * 60).toInt();
  int    _yToMins(double y)    => _snapToGrid((y / _hourH) * 60);

  int _clampStart(int start, int dur) => start.clamp(0, 24 * 60 - dur);
  int _clampEnd(int end, int fs)      => end.clamp(fs + _snapMins, 24 * 60);

  int _snapHalf(double mins) => ((mins / 30).floor() * 30).clamp(0, 23 * 60).toInt();

  int _deltaToMins(double globalY, double startGlobalY, int origMins) {
    final deltaY    = globalY - startGlobalY;
    final rawMins   = origMins + (deltaY / _hourH) * 60;
    return _snapToGrid(rawMins);
  }

  // ─── Event helpers ──────────────────────────────────────────────────────────
  int _evStart(EventModel ev) {
    if (_startOvr.containsKey(ev.id)) return _startOvr[ev.id]!;
    if (ev.startDateTime == null) return 0;
    final dayStart = DateTime(widget.date.year, widget.date.month, widget.date.day);
    if (ev.startDateTime!.isBefore(dayStart)) return 0;
    return ev.startDateTime!.hour * 60 + ev.startDateTime!.minute;
  }

  int _evDur(EventModel ev) {
    if (_durOvr.containsKey(ev.id)) return _durOvr[ev.id]!;
    if (ev.startDateTime == null) return 60;
    final dayStart = DateTime(widget.date.year, widget.date.month, widget.date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final actualStart = ev.startDateTime!.isBefore(dayStart) ? dayStart : ev.startDateTime!;
    final actualEnd   = (ev.endDateTime == null || ev.endDateTime!.isAfter(dayEnd)) ? dayEnd : ev.endDateTime!;
    final sMins = actualStart.hour * 60 + actualStart.minute;
    final eMins = (actualEnd.isAtSameMomentAs(dayEnd)) ? 24 * 60 : actualEnd.hour * 60 + actualEnd.minute;
    return (eMins - sMins).clamp(5, 24 * 60);
  }

  Color _evColor(EventModel ev) {
    final hex = ev.effectiveColor.replaceFirst('#', '');
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  bool _overlap(EventModel a, EventModel b) {
    final as_ = _evStart(a), ad = _evDur(a);
    final bs  = _evStart(b), bd = _evDur(b);
    return as_ < bs + bd && bs < as_ + ad;
  }

  Map<String, _LayoutInfo> _computeLayout(List<EventModel> timed) {
    final result = <String, _LayoutInfo>{};
    final sorted = [...timed]..sort((a, b) => _evStart(a).compareTo(_evStart(b)));
    final colEnds = <int>[];
    for (final ev in sorted) {
      final s = _evStart(ev), d = _evDur(ev);
      bool placed = false;
      for (int c = 0; c < colEnds.length; c++) {
        if (colEnds[c] <= s) {
          result[ev.id] = _LayoutInfo(col: c, totalCols: 1);
          colEnds[c] = s + d;
          placed = true;
          break;
        }
      }
      if (!placed) {
        result[ev.id] = _LayoutInfo(col: colEnds.length, totalCols: 1);
        colEnds.add(s + d);
      }
    }
    for (final ev in timed) {
      final peers  = timed.where((o) => o.id != ev.id && _overlap(ev, o)).toList();
      final myCol  = result[ev.id]?.col ?? 0;
      final maxCol = peers.isEmpty ? myCol : peers.fold(myCol, (m, o) {
        final oc = result[o.id]?.col ?? 0;
        return oc > m ? oc : m;
      });
      result[ev.id] = _LayoutInfo(col: myCol, totalCols: maxCol + 1);
    }
    return result;
  }

  void _openDraft(double gridY) {
    if (_draft != null) {
      _confirmDraft();
      return;
    }
    final start = _snapHalf(_yToMins(gridY).toDouble());
    _draftCtrl.clear();
    setState(() {
      _draft = _Draft(startMins: start, durationMins: 60);
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _draftFocus.requestFocus();
    });
  }

  void _cancelDraft() {
    setState(() { _draft = null; });
    _draftCtrl.clear();
  }

  Future<void> _confirmDraft() async {
    if (_draft == null) return;
    final title = _draftCtrl.text.trim().isEmpty ? 'New Event' : _draftCtrl.text.trim();
    final dStart = _draft!.startMins;
    final dDur = _draft!.durationMins;
    
    setState(() => _draft = null); // Erase inline draft instantly; delegate entirely to optimistic sync
    
    final cb = widget.onDraftConfirmed;
    if (cb != null) {
      final ok = await cb(title, dStart, dDur);
      if (ok) {
        _draftCtrl.clear();
      }
    }
  }

  void _onGridTapUp(TapUpDetails d) {
    _openDraft(d.localPosition.dy);
  }

  void _openDetail(String eventId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(eventId: eventId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now      = DateTime.now();
    final isToday  = widget.date.year  == now.year  && widget.date.month == now.month  && widget.date.day   == now.day;
    final allDay   = widget.events.where((e) => e.allDay).toList();
    final timed    = widget.events.where((e) => !e.allDay).toList();
    final layout   = _computeLayout(timed);
    return Column(
      children: [
        _buildHeader(isToday),
        if (allDay.isNotEmpty) _buildAllDayStrip(allDay),
        Expanded(
          child: Stack(
            children: [
              _buildGrid(timed, layout, isToday, now),
              if (widget.provider.isLoadingEvents)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isToday) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(color: Color(0xFF1C1C1E), border: Border(bottom: BorderSide(color: Color(0xFF2D2D2D)))),
      child: Row(
        children: [
          Text(DateFormat('EEEE').format(widget.date), style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isToday ? AppColors.primary : const Color(0xFF64748B))),
          const SizedBox(width: 8),
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: isToday ? AppColors.primary : Colors.transparent, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${widget.date.day}', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: isToday ? Colors.white : const Color(0xFFE2E8F0))),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 26),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CreateEventSheet(selectedDate: widget.date),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.calendar_month, color: AppColors.textMuted, size: 20), onPressed: () => widget.provider.toggleMiniCalendar()),
        ],
      ),
    );
  }

  Widget _buildAllDayStrip(List<EventModel> events) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(bottom: BorderSide(color: Color(0xFF1C2030)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _timeColW,
            child: Padding(
              padding: const EdgeInsets.only(right: 10, top: 9),
              child: Text('ALL\nDAY', textAlign: TextAlign.right, style: GoogleFonts.dmMono(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.06, color: const Color(0xFF3E4A5E), height: 1.4)),
            ),
          ),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(0, 6, 8, 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: events.map(_buildAllDayChip).toList()))),
        ],
      ),
    );
  }

  Widget _buildAllDayChip(EventModel ev) {
    final c = _evColor(ev);
    return GestureDetector(
      onTap: () => _openDetail(ev.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final padH = w < 220 ? 6.0 : 8.0;
          final padV = 4.0;
          final accentW = w < 180 ? 2.0 : 3.0;
          final borderC = c.withOpacity(0.45);

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.withOpacity(0.13),
                  border: Border.all(color: borderC, width: 1),
                ),
                child: Row(
                  children: [
                    SizedBox(width: accentW, height: 28, child: ColoredBox(color: c)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                        child: Row(
                          children: [
                            EventUi.statusDot(ev.status, size: 6.5),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                ev.displayTitle,
                                style: GoogleFonts.roboto(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<EventModel> timed, Map<String, _LayoutInfo> layout, bool isToday, DateTime now) {
    return StreamBuilder<DateTime>(
      stream: _clockStream,
      initialData: now,
      builder: (context, snap) {
        final currentNow = snap.data ?? now;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Must match the scroll viewport width — not MediaQuery.screenWidth (prevents horizontal misalignment / clipping).
            final gridW = constraints.maxWidth;
            return SingleChildScrollView(
              controller: _scroll,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: gridW,
                height: _totalHours * _hourH,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: _onGridTapUp,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ..._buildHourRows(),
                      ..._buildHalfLines(),
                      ...timed.map((ev) => _buildEventPositioned(ev, layout[ev.id]!, isToday, currentNow, gridW)),
                      if (_draft != null) _buildDraftPositioned(gridW),
                      if (isToday) _buildNowLine(currentNow),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildHourRows() {
    return List.generate(_totalHours, (i) {
      final String label;
      final String ampm;
      if (i == 0) { label = '12:00'; ampm = 'am'; }
      else if (i < 12) { label = '$i:00'; ampm = 'am'; }
      else if (i == 12) { label = '12:00'; ampm = 'pm'; }
      else { label = '${i - 12}:00'; ampm = 'pm'; }
      return Positioned(
        top: i * _hourH, left: 0, right: 0, height: _hourH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _timeColW,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Transform.translate(
                  offset: const Offset(0, -7),
                  child: RichText(
                    textAlign: TextAlign.right,
                    text: TextSpan(children: [
                      TextSpan(text: label, style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF3E4A5E))),
                      TextSpan(text: ampm, style: GoogleFonts.dmMono(fontSize: 9, color: const Color(0xFF3E4A5E))),
                    ]),
                  ),
                ),
              ),
            ),
            Expanded(child: i == 0 ? const SizedBox.expand() : Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1C2030), width: 1))))),
          ],
        ),
      );
    });
  }

  List<Widget> _buildHalfLines() {
    return List.generate(_totalHours, (i) => Positioned(top: i * _hourH + _hourH / 2, left: _timeColW, right: 0, child: Container(height: 1, color: const Color(0xFF15181F))));
  }

  Widget _buildNowLine(DateTime now) {
    final mins = now.hour * 60 + now.minute;
    return Positioned(
      top: _minsToY(mins) - 4, left: _timeColW - 4, right: 0,
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
          Expanded(child: Container(height: 1.5, color: const Color(0xFFEF4444).withOpacity(0.55))),
        ],
      ),
    );
  }

  Widget _buildEventPositioned(EventModel ev, _LayoutInfo info, bool isToday, DateTime now, double gridWidth) {
    final startMins = _evStart(ev), durMins = _evDur(ev);
    final top = _minsToY(startMins), rawH = (durMins / 60.0) * _hourH, height = rawH.clamp(28.0, double.infinity);
    final c = _evColor(ev), isDragging = _drag?.eventId == ev.id;
    final innerRight = gridWidth - _rPad;
    final availW = math.max(0.0, innerRight - _timeColW);
    final gapTotal = (info.totalCols - 1) * _colGap;
    final colW = info.totalCols > 0 ? (availW - gapTotal) / info.totalCols : availW;
    final left = _timeColW + (colW + _colGap) * info.col;
    var effColW = colW;
    if (left + effColW > innerRight + 0.5) {
      effColW = math.max(18.0, innerRight - left);
    }
    final nowMins = now.hour * 60 + now.minute, isPast  = isToday && !isDragging && (startMins + durMins) < nowMins;
    return Positioned(
      top: top, left: left, width: effColW, height: height,
      child: Opacity(
        opacity: isPast ? 0.52 : 1.0,
        child: _EventTile(
          event: ev, color: c, height: height, durMins: durMins, isDragging: isDragging, tileWidth: effColW,
          onTap: () { if (_drag == null) _openDetail(ev.id); },
          onMoveStart: (globalY) { setState(() { _drag = _DragState(eventId: ev.id, kind: _DragKind.move, origStart: startMins, origDuration: durMins, startGlobalY: globalY); _startOvr[ev.id] = startMins; _durOvr[ev.id] = durMins; }); },
          onMoveUpdate: (globalY) { if (_drag?.eventId != ev.id || _drag?.kind != _DragKind.move) return; final newStart = _clampStart(_deltaToMins(globalY, _drag!.startGlobalY, _drag!.origStart), _drag!.origDuration); setState(() => _startOvr[ev.id] = newStart); },
          onMoveEnd: () { if (_drag?.eventId != ev.id) return; final newStart = _startOvr[ev.id] ?? startMins; widget.onEventMoved?.call(ev, newStart); setState(() { _drag = null; _startOvr.remove(ev.id); _durOvr.remove(ev.id); }); },
          onResizeTopStart: (globalY) { setState(() { _drag = _DragState(eventId: ev.id, kind: _DragKind.resizeTop, origStart: startMins, origDuration: durMins, startGlobalY: globalY); _startOvr[ev.id] = startMins; _durOvr[ev.id] = durMins; }); },
          onResizeTopUpdate: (globalY) { if (_drag?.eventId != ev.id || _drag?.kind != _DragKind.resizeTop) return; final fixedEnd = _drag!.origStart + _drag!.origDuration; final newStart = _deltaToMins(globalY, _drag!.startGlobalY, _drag!.origStart).clamp(0, fixedEnd - _snapMins); setState(() { _startOvr[ev.id] = newStart; _durOvr[ev.id] = fixedEnd - newStart; }); },
          onResizeTopEnd: () { if (_drag?.eventId != ev.id) return; final newStart = _startOvr[ev.id] ?? startMins; final newDur = _durOvr[ev.id] ?? durMins; widget.onEventResized?.call(ev, newStart, newDur); setState(() { _drag = null; _startOvr.remove(ev.id); _durOvr.remove(ev.id); }); },
          onResizeBottomStart: (globalY) { setState(() { _drag = _DragState(eventId: ev.id, kind: _DragKind.resizeBottom, origStart: startMins, origDuration: durMins, startGlobalY: globalY); _startOvr[ev.id] = startMins; _durOvr[ev.id] = durMins; }); },
          onResizeBottomUpdate: (globalY) { if (_drag?.eventId != ev.id || _drag?.kind != _DragKind.resizeBottom) return; final fixedStart = _drag!.origStart, origEnd = fixedStart + _drag!.origDuration, newEnd = _clampEnd(_deltaToMins(globalY, _drag!.startGlobalY, origEnd), fixedStart); setState(() { _startOvr[ev.id] = fixedStart; _durOvr[ev.id] = newEnd - fixedStart; }); },
          onResizeBottomEnd: () { if (_drag?.eventId != ev.id) return; final newStart = _startOvr[ev.id] ?? startMins; final newDur = _durOvr[ev.id] ?? durMins; widget.onEventResized?.call(ev, newStart, newDur); setState(() { _drag = null; _startOvr.remove(ev.id); _durOvr.remove(ev.id); }); },
        ),
      ),
    );
  }

  Widget _buildDraftPositioned(double gridWidth) {
    final d = _draft!; 
    final top = _minsToY(d.startMins);
    
    return Positioned(
      top: top, 
      left: _timeColW + 4, 
      width: math.max(0.0, gridWidth - _timeColW - 4 - _rPad),
      // We don't set height here because the DraftTile will handle its own height sizing and constraints.
      child: _DraftTile(
        draft: d, 
        controller: _draftCtrl, 
        focusNode: _draftFocus, 
        onConfirm: _confirmDraft, 
        onCancel: _cancelDraft,
        isSubmitting: _isSubmittingDraft,
        date: widget.date,
        onDurationChanged: (newDur) {
          setState(() { _draft!.durationMins = newDur; });
        },
        hourHeight: _hourH,
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventModel event;
  final Color color;
  final double height;
  final double tileWidth;
  final int durMins;
  final bool isDragging;
  final VoidCallback onTap;
  final void Function(double globalY) onMoveStart, onMoveUpdate;
  final VoidCallback onMoveEnd;
  final void Function(double globalY) onResizeTopStart, onResizeTopUpdate;
  final VoidCallback onResizeTopEnd;
  final void Function(double globalY) onResizeBottomStart, onResizeBottomUpdate;
  final VoidCallback onResizeBottomEnd;

  static const double _handleH = 8.0;

  const _EventTile({
    required this.event,
    required this.color,
    required this.height,
    required this.tileWidth,
    required this.durMins,
    required this.isDragging,
    required this.onTap,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onResizeTopStart,
    required this.onResizeTopUpdate,
    required this.onResizeTopEnd,
    required this.onResizeBottomStart,
    required this.onResizeBottomUpdate,
    required this.onResizeBottomEnd,
  });

  static const double _hourH = 64.0;

  bool get _showTime => (durMins / 60.0) * _hourH > 34;

  String _fmtTime() {
    if (event.startDateTime == null || event.endDateTime == null) return '';
    final s = event.startDateTime!, e = event.endDateTime!;
    final sh = s.hour % 12 == 0 ? 12 : s.hour % 12;
    final sm = s.minute.toString().padLeft(2, '0');
    final eh = e.hour % 12 == 0 ? 12 : e.hour % 12;
    final em = e.minute.toString().padLeft(2, '0');
    final ap = e.hour >= 12 ? 'PM' : 'AM';
    return '$sh:$sm – $eh:$em $ap';
  }

  @override
  Widget build(BuildContext context) {
    final padV = durMins < 30 ? 2.0 : _handleH;
    final padH = tileWidth < 44 ? 3.0 : (tileWidth < 72 ? 5.0 : 6.0);
    final accentW = tileWidth < 36 ? 2.0 : 3.0;
    final borderC = color.withOpacity(isDragging ? 0.9 : 0.45);

    // Available inner height after padding & resize handles
    final innerH = height - padV * 2;
    final showTime = _showTime && innerH >= 30;
    final showFooter = innerH >= 38;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        boxShadow: isDragging
            ? [BoxShadow(color: color.withOpacity(0.28), blurRadius: 28, offset: const Offset(0, 6))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withOpacity(isDragging ? 0.18 : 0.13),
            border: Border.all(color: borderC, width: 1),
          ),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: accentW, child: ColoredBox(color: color)),
            Expanded(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: onTap,
                      onLongPressStart: (d) => onMoveStart(d.globalPosition.dy),
                      onLongPressMoveUpdate: (d) => onMoveUpdate(d.globalPosition.dy),
                      onLongPressEnd: (_) => onMoveEnd(),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Flexible(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (innerH >= 24)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 5, top: 3.5),
                                      child: EventUi.statusDot(event.status, size: 6.5),
                                    ),
                                  Expanded(
                                    child: Text(
                                      event.displayTitle,
                                      style: GoogleFonts.roboto(
                                        fontSize: tileWidth < 56 ? 11 : 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        height: 1.2,
                                      ),
                                      maxLines: innerH >= 48 ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (showFooter)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, top: 1),
                                      child: EventUi.dailyFooter(event, iconSize: 10),
                                    ),
                                ],
                              ),
                            ),
                            if (showTime)
                              Flexible(
                                flex: 0,
                                child: Text(
                                  _fmtTime(),
                                  style: GoogleFonts.roboto(fontSize: 9, color: AppColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _handleH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragStart: (d) => onResizeTopStart(d.globalPosition.dy),
                      onVerticalDragUpdate: (d) => onResizeTopUpdate(d.globalPosition.dy),
                      onVerticalDragEnd: (_) => onResizeTopEnd(),
                      child: _ResizeBar(color: color),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: _handleH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragStart: (d) => onResizeBottomStart(d.globalPosition.dy),
                      onVerticalDragUpdate: (d) => onResizeBottomUpdate(d.globalPosition.dy),
                      onVerticalDragEnd: (_) => onResizeBottomEnd(),
                      child: _ResizeBar(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _DraftTile extends StatefulWidget {
  final _Draft draft;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;
  final DateTime date;
  final bool isSubmitting;
  final Function(int) onDurationChanged;
  final double hourHeight;

  const _DraftTile({
    required this.draft,
    required this.controller,
    required this.focusNode,
    required this.onConfirm,
    required this.onCancel,
    required this.date,
    required this.isSubmitting,
    required this.onDurationChanged,
    required this.hourHeight,
  });

  @override
  State<_DraftTile> createState() => _DraftTileState();
}

class _DraftTileState extends State<_DraftTile> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  
  double? _dragInitialHeight;
  double? _dragStartY;
  
  static const double _snapMins = 15.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String _timeLabel() {
    final s = widget.draft.startMins;
    final e = s + widget.draft.durationMins;
    final sh = (s ~/ 60) % 24, sm = (s % 60).toString().padLeft(2, '0');
    final eh = e ~/ 60 % 24, em = (e % 60).toString().padLeft(2, '0');
    final ap = eh >= 12 ? 'PM' : 'AM';
    final sh12 = sh % 12 == 0 ? 12 : sh % 12;
    final eh12 = eh % 12 == 0 ? 12 : eh % 12;
    return '$sh12:$sm – $eh12:$em $ap';
  }

  void _onResizeStart(DragStartDetails d) {
    _dragStartY = d.globalPosition.dy;
    _dragInitialHeight = (widget.draft.durationMins / 60.0) * widget.hourHeight;
  }

  void _onResizeUpdate(DragUpdateDetails d) {
    if (_dragStartY == null || _dragInitialHeight == null) return;
    final dy = d.globalPosition.dy - _dragStartY!;
    final newHeight = math.max(30.0, _dragInitialHeight! + dy); // config min height
    
    // Convert height back to mins and snap
    final rawMins = (newHeight / widget.hourHeight) * 60;
    final snappedMins = ((rawMins / _snapMins).round() * _snapMins).clamp(15.0, 24 * 60.0).toInt();
    
    if (snappedMins != widget.draft.durationMins) {
      widget.onDurationChanged(snappedMins);
    }
  }

  void _onResizeEnd(DragEndDetails d) {
    _dragStartY = null;
    _dragInitialHeight = null;
  }

  void _openDetailEditor() {
    final currentTitle = widget.controller.text;
    final currentStart = widget.draft.startMins;
    final currentDur = widget.draft.durationMins;
    widget.onCancel();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateEventSheet(
        selectedDate: widget.date,
        initialTitle: currentTitle,
        initialStartMinutes: currentStart,
        initialDurationMinutes: currentDur,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHeight = (widget.draft.durationMins / 60.0) * widget.hourHeight;
    final h = math.max(48.0, currentHeight); // minimum visual height

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {}, // consume tap so it doesn't close the draft
        onDoubleTap: _openDetailEditor, // Notion-style: double tap or separate button to open full editor? Let's use a button.
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08), 
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 1),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0, top: 0, bottom: 0, width: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(5)),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              style: GoogleFonts.inter(
                                fontSize: 13, 
                                fontWeight: FontWeight.w600, 
                                color: const Color(0xFF6366F1),
                                height: 1.2,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Event title',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w500, 
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                                  height: 1.2,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => widget.onConfirm(),
                              cursorColor: const Color(0xFF6366F1),
                              maxLines: 1,
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                          _DraftBtn(icon: Icons.more_horiz_rounded, onTap: _openDetailEditor),
                          const SizedBox(width: 6),
                          _DraftBtn(icon: Icons.check_rounded, onTap: widget.onConfirm),
                          const SizedBox(width: 6),
                          _DraftBtn(icon: Icons.close_rounded, onTap: widget.onCancel),
                        ],
                      ),
                      if (h > 60) ...[
                        const SizedBox(height: 4),
                        Text(
                          _timeLabel(),
                          style: GoogleFonts.inter(
                            fontSize: 11, 
                            color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Bottom resize handle
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 16, // larger hit area
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: _onResizeStart,
                  onVerticalDragUpdate: _onResizeUpdate,
                  onVerticalDragEnd: _onResizeEnd,
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResizeBar extends StatelessWidget {
  final Color color; 
  const _ResizeBar({required this.color});
  
  @override
  Widget build(BuildContext context) { 
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown, 
      child: Container(
        alignment: Alignment.center, 
        child: Container(
          width: 28, 
          height: 2, 
          decoration: BoxDecoration(
            color: color.withOpacity(0.35), 
            borderRadius: BorderRadius.circular(2)
          )
        )
      )
    ); 
  }
}

class _DraftBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DraftBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22, height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4), 
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25))
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 12, color: const Color(0xFF6366F1)),
      ),
    );
  }
}
