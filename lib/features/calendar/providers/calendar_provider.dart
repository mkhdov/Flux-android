import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_model.dart';
import '../models/event_model.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/event_repository.dart';
import '../../../core/services/notification_service.dart';

enum CalendarViewMode { schedule, day, month }

class _PendingEventDelete {
  final EventModel event;
  final Future<void> Function() action;
  _PendingEventDelete(this.event, this.action);
}

class CalendarProvider extends ChangeNotifier {
  final CalendarRepository _calendarRepo;
  final EventRepository _eventRepo;

  static const String _viewModeKey = 'calendar_view_mode';
  static const String _selectedCalendarKey = 'selected_calendar_id';
  static const String _calendarListExpandedKey = 'calendar_list_expanded';

  List<CalendarModel> _calendars = [];
  CalendarModel? _selectedCalendar;

  /// Events for day/schedule views (short range, ~8 days).
  List<EventModel> _events = [];

  /// Events loaded for the currently-visible month.
  /// Kept separate so that loadEvents() / loadEventsForRange() never
  /// silently wipes out a full-month load.
  List<EventModel> _monthEvents = [];

  List<EventModel> _meetings = [];
  bool _isLoadingCalendars = false;
  bool _isLoadingEvents = false;
  bool _isLoadingMonth = false;
  bool _isLoadingMeetings = false;
  bool _isManualSyncing = false;
  String? _calendarError;
  String? _eventError;
  String? _meetingError;
  String _meetingsFilter = 'today';

  // Mini calendar state
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  CalendarViewMode _viewMode = CalendarViewMode.day;
  bool _isMiniCalendarVisible = false;
  bool _isCalendarListExpanded = true;
  final Map<String, _PendingEventDelete> _pendingDeletes = {};

  CalendarProvider(this._calendarRepo, this._eventRepo) {
    _loadViewMode();
    _loadSelectedCalendarId();
    _loadCalendarListExpanded();
  }

  String? _savedCalendarId;
  Future<void> _loadSelectedCalendarId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedCalendarId = prefs.getString(_selectedCalendarKey);
    } catch (_) {}
  }

  Future<void> _loadViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_viewModeKey);
      if (modeIndex != null && modeIndex < CalendarViewMode.values.length) {
        _viewMode = CalendarViewMode.values[modeIndex];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _loadCalendarListExpanded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isCalendarListExpanded = prefs.getBool(_calendarListExpandedKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  // ─── Getters ─────────────────────────────────────────────────────────────

  List<CalendarModel> get calendars => _calendars;
  CalendarModel? get selectedCalendar => _selectedCalendar;
  List<EventModel> get events => _events;
  List<EventModel> get meetings => _meetings;
  bool get isLoadingCalendars => _isLoadingCalendars;
  bool get isLoadingEvents => _isLoadingEvents;
  bool get isLoadingMonth => _isLoadingMonth;
  bool get isLoadingMeetings => _isLoadingMeetings;
  bool get isManualSyncing => _isManualSyncing;
  String? get calendarError => _calendarError;
  String? get eventError => _eventError;
  String? get meetingError => _meetingError;
  String get meetingsFilter => _meetingsFilter;
  DateTime get currentMonth => _currentMonth;
  DateTime? get selectedDate => _selectedDate;
  CalendarViewMode get viewMode => _viewMode;
  bool get isMiniCalendarVisible => _isMiniCalendarVisible;
  bool get isCalendarListExpanded => _isCalendarListExpanded;

  void toggleMiniCalendar() {
    _isMiniCalendarVisible = !_isMiniCalendarVisible;
    notifyListeners();
  }

  void setMiniCalendarVisible(bool visible) {
    _isMiniCalendarVisible = visible;
    notifyListeners();
  }

  void toggleCalendarListExpanded() {
    _isCalendarListExpanded = !_isCalendarListExpanded;
    notifyListeners();
    _saveCalendarListExpanded(_isCalendarListExpanded);
  }

  Future<void> _saveCalendarListExpanded(bool expanded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_calendarListExpandedKey, expanded);
    } catch (_) {}
  }

  // ─── Event queries ────────────────────────────────────────────────────────

  /// Returns events for [date], using the month cache when in month view,
  /// or the short-range cache otherwise.
  List<EventModel> getEventsForDate(DateTime date) {
    final source = _viewMode == CalendarViewMode.month ? _monthEvents : _events;
    return _filterEventsForDate(source, date);
  }

  List<EventModel> _filterEventsForDate(
      List<EventModel> source, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return source.where((event) {
      if (event.startDateTime == null) return false;

      final eStart = event.startDateTime!;

      if (event.allDay || event.endDateTime == null) {
        return eStart.year == date.year &&
            eStart.month == date.month &&
            eStart.day == date.day;
      }

      final eEnd = event.endDateTime!;
      return eStart.isBefore(endOfDay) && eEnd.isAfter(startOfDay);
    }).toList()
      ..sort((a, b) {
        if (a.allDay && !b.allDay) return -1;
        if (!a.allDay && b.allDay) return 1;
        final aStart = a.startDateTime;
        final bStart = b.startDateTime;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return aStart.compareTo(bStart);
      });
  }

  List<EventModel> getAllDayEventsForDate(DateTime date) {
    return getEventsForDate(date).where((e) => e.allDay).toList();
  }

  List<EventModel> getTimedEventsForDate(DateTime date) {
    return getEventsForDate(date).where((e) => !e.allDay).toList();
  }

  // ─── Calendar CRUD ────────────────────────────────────────────────────────

  Future<void> loadCalendars(String userId) async {
    _isLoadingCalendars = true;
    _calendarError = null;
    notifyListeners();
    try {
      final cals = await _calendarRepo.getCalendarsByUserId(userId);
      _calendars = cals;

      if (_savedCalendarId != null) {
        try {
          _selectedCalendar = cals.firstWhere((c) => c.id == _savedCalendarId);
        } catch (_) {
          _selectedCalendar = null;
        }
      }

      if (_selectedCalendar == null ||
          !cals.any((c) => c.id == _selectedCalendar!.id)) {
        _selectedCalendar = cals.firstWhere(
          (c) => c.isGoogleSyncCalendar,
          orElse: () => cals.firstWhere(
            (c) => c.isPrimary,
            orElse: () => cals.isNotEmpty ? cals.first : _selectedCalendar!,
          ),
        );
      }

      if (_selectedCalendar != null) {
        _saveSelectedCalendarId(_selectedCalendar!.id);
      }
    } catch (e) {
      _calendarError = 'Something went wrong or no calendar found!!';
    } finally {
      _isLoadingCalendars = false;
      notifyListeners();
    }
  }

  Future<void> selectCalendar(CalendarModel calendar) async {
    _events = [];
    _monthEvents = [];
    _selectedCalendar = calendar;
    _saveSelectedCalendarId(calendar.id);
    notifyListeners();
    await loadEvents(calendar.id);
  }

  Future<void> _saveSelectedCalendarId(String id) async {
    try {
      _savedCalendarId = id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedCalendarKey, id);
    } catch (_) {}
  }

  // ─── Event loading ────────────────────────────────────────────────────────

  /// Short-range load for day / schedule views (~8 days).
  /// Only writes to [_events] — never touches [_monthEvents].
  Future<void> loadEvents(String calendarId) async {
    await NotificationService().cancelAll();
    final start = DateTime.now().subtract(const Duration(days: 1));
    final end = start.add(const Duration(days: 7));
    await loadEventsForRange(calendarId, start, end, clearExisting: true);
  }

  /// Full-month load for the monthly calendar view.
  /// Only writes to [_monthEvents] — never touches [_events].
  Future<void> loadEventsForMonth(String calendarId, DateTime month) async {
    _isLoadingMonth = true;
    _eventError = null;
    _monthEvents = [];
    notifyListeners();

    try {
      final evts = await _eventRepo.getEventsByMonth(
        calendarId: calendarId,
        year: month.year,
        month: month.month,
      );

      _monthEvents = evts;

      _monthEvents.sort((a, b) {
        if (a.allDay && !b.allDay) return -1;
        if (!a.allDay && b.allDay) return 1;
        final aStart = a.startDateTime ?? DateTime.now();
        final bStart = b.startDateTime ?? DateTime.now();
        return aStart.compareTo(bStart);
      });
    } catch (_) {
      _eventError = 'Failed to load events.';
    } finally {
      _isLoadingMonth = false;
      notifyListeners();
    }
  }

  /// Range load for day / schedule views.
  /// Only writes to [_events] — never touches [_monthEvents].
  Future<void> loadEventsForRange(
    String calendarId,
    DateTime start,
    DateTime end, {
    bool clearExisting = false,
  }) async {
    await NotificationService().cancelAll();
    _isLoadingEvents = true;
    _eventError = null;
    if (clearExisting) _events = [];
    notifyListeners();

    try {
      DateTime currentStart = start;
      while (currentStart.isBefore(end)) {
        DateTime currentEnd = currentStart.add(const Duration(days: 7));
        if (currentEnd.isAfter(end)) currentEnd = end;

        final evts = await _eventRepo.getEventsByCalendar(
          calendarId,
          startDate: currentStart,
          endDate: currentEnd,
        );

        final existingIds = _events.map((e) => e.id).toSet();
        for (final e in evts) {
          if (!existingIds.contains(e.id)) {
            _events.add(e);
            _scheduleReminderForEvent(e);
          }
        }
        currentStart = currentEnd;
      }

      _events.sort((a, b) {
        if (a.allDay && !b.allDay) return -1;
        if (!a.allDay && b.allDay) return 1;
        final aStart = a.startDateTime ?? DateTime.now();
        final bStart = b.startDateTime ?? DateTime.now();
        return aStart.compareTo(bStart);
      });
    } catch (e) {
      _eventError = 'Failed to load events.';
    } finally {
      _isLoadingEvents = false;
      notifyListeners();
    }
  }

  Future<void> loadMeetings(String calendarId, {String? filter}) async {
    _isLoadingMeetings = true;
    _meetingError = null;
    if (filter != null) _meetingsFilter = filter;
    notifyListeners();

    try {
      final mtgs = await _eventRepo.getMeetingsByCalendar(calendarId,
          filter: _meetingsFilter);
      _meetings = mtgs;
    } catch (e) {
      _meetingError = 'Failed to load meetings.';
    } finally {
      _isLoadingMeetings = false;
      notifyListeners();
    }
  }

  Future<bool> syncSelectedGoogleCalendar() async {
    final calendar = _selectedCalendar;
    if (calendar == null) {
      _eventError = 'Select a calendar first.';
      notifyListeners();
      return false;
    }
    if (_isManualSyncing) return true;

    _isManualSyncing = true;
    _eventError = null;
    notifyListeners();

    try {
      if (calendar.isGoogleSyncCalendar) {
        await _eventRepo.syncGoogleCalendar(calendar.id);
      }

      switch (_viewMode) {
        case CalendarViewMode.month:
          await loadEventsForMonth(calendar.id, _currentMonth);
          break;
        case CalendarViewMode.schedule:
        case CalendarViewMode.day:
          await loadEvents(calendar.id);
          break;
      }
      return true;
    } catch (e) {
      debugPrint('Error syncing Google calendar: $e');
      _eventError = calendar.isGoogleSyncCalendar
          ? 'Failed to sync Google Calendar.'
          : 'Failed to refresh calendar.';
      return false;
    } finally {
      _isManualSyncing = false;
      notifyListeners();
    }
  }

  // ─── Calendar management ──────────────────────────────────────────────────

  Future<CalendarModel?> createCalendar({
    required String userId,
    required String title,
    required String description,
    required String colorHex,
    required String timezone,
    required bool isPrimary,
  }) async {
    try {
      final id = await _calendarRepo.createCalendar(
        userId: userId,
        title: title,
        description: description,
        colorHex: colorHex,
        timezone: timezone,
        isPrimary: isPrimary,
      );
      CalendarModel? created;
      for (int i = 0; i < 3; i++) {
        await loadCalendars(userId);
        try {
          created = _calendars.firstWhere((c) => c.id == id);
          break;
        } catch (_) {
          if (i < 2) await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      return created ?? (_calendars.isNotEmpty ? _calendars.first : null);
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateCalendar({
    required String id,
    required String title,
    required String description,
    required String colorHex,
    required String timezone,
    required String userId,
  }) async {
    try {
      await _calendarRepo.updateCalendar(
          id: id,
          title: title,
          description: description,
          colorHex: colorHex,
          timezone: timezone);
      await loadCalendars(userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setPrimaryCalendar(String calendarId, String userId) async {
    try {
      await _calendarRepo.setPrimaryCalendar(
          calendarId: calendarId, userId: userId);
      await loadCalendars(userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCalendar(
      {required String calendarId, required String userId}) async {
    try {
      await _calendarRepo.deleteCalendar(calendarId);
      await loadCalendars(userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Event CRUD ───────────────────────────────────────────────────────────

  Future<List<EventModel>> createEvent({
    required Map<String, dynamic> data,
    String meetingType = 'none',
    String? userId,
  }) async {
    if (_selectedCalendar == null) return [];
    try {
      final events = await _eventRepo.createEvent(
        calendarId: _selectedCalendar!.id,
        data: data,
        meetingType: meetingType,
        userId: userId,
      );
      // Add to whichever cache is active so the UI reflects it immediately.
      _events.addAll(events);
      _monthEvents.addAll(events);
      for (final e in events) {
        _scheduleReminderForEvent(e);
      }
      notifyListeners();
      return events;
    } catch (e) {
      debugPrint('Error creating event: $e');
      return [];
    }
  }

  String addOptimisticEvent({
    required String title,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String colorHex = '#6366F1',
    bool allDay = false,
    String status = 'NOTSTARTED',
    String type = 'OTHERS',
  }) {
    final calId = _selectedCalendar?.id ?? '';
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();
    final temp = EventModel(
      id: tempId,
      calendarId: calId,
      title: title,
      colorHex: colorHex,
      allDay: allDay,
      startTime: startDateTime.toUtc().toIso8601String(),
      endTime: endDateTime.toUtc().toIso8601String(),
      status: status,
      type: type,
      subtasks: const [],
      notes: const [],
      members: const [],
      attachments: const [],
      createdAt: nowIso,
      updatedAt: nowIso,
    );
    _events.add(temp);
    _monthEvents.add(temp);
    _sortBothLists();
    notifyListeners();
    return tempId;
  }

  void replaceOptimisticEvent(String tempId, EventModel event) {
    _replaceInList(_events, tempId, event);
    _replaceInList(_monthEvents, tempId, event);
    _deduplicateBothLists();
    _sortBothLists();
    notifyListeners();
  }

  void _replaceInList(List<EventModel> list, String tempId, EventModel event) {
    final idx = list.indexWhere((e) => e.id == tempId);
    if (idx != -1) {
      list[idx] = event;
    } else {
      final existingIdx = list.indexWhere((e) => e.id == event.id);
      if (existingIdx != -1) {
        list[existingIdx] = event;
      } else {
        list.add(event);
      }
    }
  }

  void _deduplicateBothLists() {
    _events = _deduplicate(_events);
    _monthEvents = _deduplicate(_monthEvents);
  }

  List<EventModel> _deduplicate(List<EventModel> list) {
    final seen = <String>{};
    return list.where((e) {
      if (seen.contains(e.id)) return false;
      seen.add(e.id);
      return true;
    }).toList();
  }

  void _sortBothLists() {
    _sortList(_events);
    _sortList(_monthEvents);
  }

  void _sortList(List<EventModel> list) {
    list.sort((a, b) {
      if (a.allDay && !b.allDay) return -1;
      if (!a.allDay && b.allDay) return 1;
      final aStart = a.startDateTime ?? DateTime.now();
      final bStart = b.startDateTime ?? DateTime.now();
      return aStart.compareTo(bStart);
    });
  }

  void removeEventById(String eventId) {
    _events.removeWhere((e) => e.id == eventId);
    _monthEvents.removeWhere((e) => e.id == eventId);
    _cancelReminderForEvent(eventId);
    notifyListeners();
  }

  void upsertLocalEvent(EventModel event) {
    _upsertInList(_events, event);
    _upsertInList(_monthEvents, event);
    _scheduleReminderForEvent(event);
    _sortBothLists();
    notifyListeners();
  }

  void _upsertInList(List<EventModel> list, EventModel event) {
    final idx = list.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      list[idx] = event;
    } else {
      list.add(event);
    }
  }

  Future<bool> updateEvent(String eventId, Map<String, dynamic> data) async {
    final idxEvents = _events.indexWhere((e) => e.id == eventId);
    final idxMonth = _monthEvents.indexWhere((e) => e.id == eventId);
    EventModel? previous;

    if (idxEvents != -1) {
      previous = _events[idxEvents];
      _events[idxEvents] = _mergeEventPatch(previous, data);
    }
    if (idxMonth != -1) {
      final prev = previous ?? _monthEvents[idxMonth];
      previous ??= prev;
      _monthEvents[idxMonth] = _mergeEventPatch(prev, data);
    }
    notifyListeners();

    try {
      final updated =
          await _eventRepo.updateEvent(eventId: eventId, data: data);
      if (idxEvents != -1) _events[idxEvents] = updated;
      if (idxMonth != -1) _monthEvents[idxMonth] = updated;
      _scheduleReminderForEvent(updated);
      notifyListeners();
      return true;
    } catch (_) {
      if (idxEvents != -1 && previous != null) {
        _events[idxEvents] = previous;
      }
      if (idxMonth != -1 && previous != null) {
        _monthEvents[idxMonth] = previous;
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final event = _events.firstWhere(
      (e) => e.id == eventId,
      orElse: () => _monthEvents.firstWhere(
        (e) => e.id == eventId,
        orElse: () => throw Exception('Event not found'),
      ),
    );
    _events.removeWhere((e) => e.id == eventId);
    _monthEvents.removeWhere((e) => e.id == eventId);
    _cancelReminderForEvent(eventId);
    notifyListeners();

    Future<void> action() async {
      if (_pendingDeletes.containsKey(eventId)) {
        await _eventRepo.deleteEvent(eventId);
        _pendingDeletes.remove(eventId);
      }
    }

    _pendingDeletes[eventId] = _PendingEventDelete(event, action);

    Future.delayed(const Duration(seconds: 5), () {
      if (_pendingDeletes.containsKey(eventId)) {
        _pendingDeletes[eventId]!.action();
      }
    });
  }

  void undoDeleteEvent(String eventId) {
    if (_pendingDeletes.containsKey(eventId)) {
      final item = _pendingDeletes.remove(eventId);
      _events.add(item!.event);
      _monthEvents.add(item.event);
      _sortBothLists();
      notifyListeners();
    }
  }

  Future<EventModel?> refreshEvent(String eventId) async {
    try {
      final event = await _eventRepo.getEventById(eventId);
      final idxEvents = _events.indexWhere((e) => e.id == eventId);
      final idxMonth = _monthEvents.indexWhere((e) => e.id == eventId);
      if (idxEvents != -1) _events[idxEvents] = event;
      if (idxMonth != -1) _monthEvents[idxMonth] = event;
      _scheduleReminderForEvent(event);
      notifyListeners();
      return event;
    } catch (_) {
      return null;
    }
  }

  // ─── Reminders ────────────────────────────────────────────────────────────

  Future<void> createReminder(Map<String, dynamic> data) async {
    await _eventRepo.createReminder(data);
  }

  Future<void> createRemindersBatch(List<Map<String, dynamic>> data) async {
    await _eventRepo.createRemindersBatch(data);
  }

  Future<List<dynamic>> getRemindersForEvent(String eventId) async {
    return _eventRepo.getRemindersForEvent(eventId);
  }

  Future<void> deleteReminder(String reminderId) async {
    await _eventRepo.deleteReminder(reminderId);
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void goToPrevMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    notifyListeners();
    if (_selectedCalendar != null) {
      loadEventsForMonth(_selectedCalendar!.id, _currentMonth);
    }
  }

  void goToNextMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    notifyListeners();
    if (_selectedCalendar != null) {
      loadEventsForMonth(_selectedCalendar!.id, _currentMonth);
    }
  }

  void goToToday() {
    _currentMonth = DateTime.now();
    _selectedDate = DateTime.now();
    notifyListeners();
    if (_selectedCalendar != null) {
      if (_viewMode == CalendarViewMode.month) {
        loadEventsForMonth(_selectedCalendar!.id, _currentMonth);
      } else {
        loadEvents(_selectedCalendar!.id);
      }
    }
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    _currentMonth = DateTime(date.year, date.month);
    if (_selectedCalendar != null) {
      loadEventsForRange(
        _selectedCalendar!.id,
        date.subtract(const Duration(days: 3)),
        date.add(const Duration(days: 4)),
      );
    } else {
      notifyListeners();
    }
  }

  void setViewMode(CalendarViewMode mode) {
    _viewMode = mode;
    notifyListeners();
    _saveViewMode(mode);
    if (_selectedCalendar != null) {
      if (mode == CalendarViewMode.month) {
        loadEventsForMonth(_selectedCalendar!.id, _currentMonth);
      } else {
        loadEvents(_selectedCalendar!.id);
      }
    }
  }

  Future<void> _saveViewMode(CalendarViewMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_viewModeKey, mode.index);
    } catch (_) {}
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  EventModel _mergeEventPatch(EventModel event, Map<String, dynamic> data) {
    final startIso = data['startTime'] as String?;
    final endIso = data['endTime'] as String?;
    final title = data['title'] as String?;
    final description = data['description'] as String?;
    final status = data['status'] as String?;
    final type = data['type'] as String?;

    return event.copyWithTimes(
      startDateTime:
          startIso != null ? DateTime.tryParse(startIso)?.toLocal() : null,
      endDateTime: endIso != null ? DateTime.tryParse(endIso)?.toLocal() : null,
      title: title,
      description: description,
      status: status,
      type: type,
    );
  }

  static const Duration _localWindow = Duration(hours: 24);

  Future<void> _scheduleReminderForEvent(EventModel event) async {
    if (event.startDateTime == null) return;
    final now = DateTime.now();
    final eventStart = event.startDateTime!;

    // Skip past events entirely — no API call, no scheduling
    if (eventStart.isBefore(now)) return;

    // Cancel stale notifications for this event before re-scheduling
    _cancelReminderForEvent(event.id);

    try {
      final List<dynamic> reminders = await getRemindersForEvent(event.id);
      if (reminders.isNotEmpty) {
        // Backend handles PUSH/EMAIL reminders via FCM.
        // Only schedule local as safety net for triggers within 24h.
        for (int i = 0; i < reminders.length; i++) {
          final triggerTimeStr = reminders[i]['triggerTime'];
          if (triggerTimeStr == null) {
            continue;
          }
          final triggerTime = DateTime.parse(triggerTimeStr).toLocal();
          if (triggerTime.isBefore(now) ||
              triggerTime.isAfter(now.add(_localWindow))) {
            continue;
          }
          final occurrenceStartStr = reminders[i]['eventStartTime'];
          final occurrenceStart = occurrenceStartStr != null
              ? DateTime.tryParse(occurrenceStartStr.toString())?.toLocal()
              : eventStart;
          final minutesBefore =
              (occurrenceStart ?? eventStart).difference(triggerTime).inMinutes;
          await NotificationService().scheduleEventReminder(
            eventId: '${event.id}_rem_$i',
            eventTitle: event.title,
            eventStartTime: occurrenceStart ?? eventStart,
            reminderMinutesBefore: minutesBefore,
          );
        }
        return;
      }
    } catch (_) {
      // API failure — fall through to local default below
    }

    // No backend reminders — local fallback only for near-term events
    if (eventStart.isBefore(now.add(_localWindow))) {
      await NotificationService().scheduleEventReminder(
        eventId: event.id,
        eventTitle: event.title,
        eventStartTime: eventStart,
        reminderMinutesBefore: 15,
      );
    }
  }

  void _cancelReminderForEvent(String eventId) {
    NotificationService().cancelReminder(eventId);
    for (int i = 0; i < 50; i++) {
      NotificationService().cancelReminder('${eventId}_rem_$i');
    }
  }
}
