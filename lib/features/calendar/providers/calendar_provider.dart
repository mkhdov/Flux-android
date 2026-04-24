import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_model.dart';
import '../models/event_model.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/event_repository.dart';
import '../../../core/services/notification_service.dart';

enum CalendarViewMode { schedule, day }

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

  List<CalendarModel> _calendars = [];
  CalendarModel? _selectedCalendar;
  List<EventModel> _events = [];
  List<EventModel> _meetings = [];
  bool _isLoadingCalendars = false;
  bool _isLoadingEvents = false;
  bool _isLoadingMeetings = false;
  String? _calendarError;
  String? _eventError;
  String? _meetingError;
  String _meetingsFilter = 'today';

  // Mini calendar state
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  CalendarViewMode _viewMode = CalendarViewMode.day;
  bool _isMiniCalendarVisible = false;
  final Map<String, _PendingEventDelete> _pendingDeletes = {};

  CalendarProvider(this._calendarRepo, this._eventRepo) {
    _loadViewMode();
    _loadSelectedCalendarId();
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

  // Getters
  List<CalendarModel> get calendars => _calendars;
  CalendarModel? get selectedCalendar => _selectedCalendar;
  List<EventModel> get events => _events;
  List<EventModel> get meetings => _meetings;
  bool get isLoadingCalendars => _isLoadingCalendars;
  bool get isLoadingEvents => _isLoadingEvents;
  bool get isLoadingMeetings => _isLoadingMeetings;
  String? get calendarError => _calendarError;
  String? get eventError => _eventError;
  String? get meetingError => _meetingError;
  String get meetingsFilter => _meetingsFilter;
  DateTime get currentMonth => _currentMonth;
  DateTime? get selectedDate => _selectedDate;
  CalendarViewMode get viewMode => _viewMode;
  bool get isMiniCalendarVisible => _isMiniCalendarVisible;

  void toggleMiniCalendar() {
    _isMiniCalendarVisible = !_isMiniCalendarVisible;
    notifyListeners();
  }

  void setMiniCalendarVisible(bool visible) {
    _isMiniCalendarVisible = visible;
    notifyListeners();
  }

  // Get events for a specific date
  List<EventModel> getEventsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _events.where((event) {
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

  Future<void> loadCalendars(String userId) async {
    _isLoadingCalendars = true;
    _calendarError = null;
    notifyListeners();
    try {
      final cals = await _calendarRepo.getCalendarsByUserId(userId);
      _calendars = cals;
      
      // Try to restore saved calendar first
      if (_savedCalendarId != null) {
        try {
          _selectedCalendar = cals.firstWhere((c) => c.id == _savedCalendarId);
        } catch (_) {
          _selectedCalendar = null;
        }
      }

      if (_selectedCalendar == null || !cals.any((c) => c.id == _selectedCalendar!.id)) {
        _selectedCalendar = cals.firstWhere((c) => c.isGoogleSyncCalendar, orElse: () =>
            cals.firstWhere((c) => c.isPrimary, orElse: () => cals.isNotEmpty ? cals.first : _selectedCalendar!));
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

  Future<void> loadEvents(String calendarId) async {
    final start = DateTime.now().subtract(const Duration(days: 1));
    final end = start.add(const Duration(days: 7));
    await loadEventsForRange(calendarId, start, end, clearExisting: true);
  }

  Future<void> loadEventsForRange(String calendarId, DateTime start, DateTime end, {bool clearExisting = false}) async {
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
      final mtgs = await _eventRepo.getMeetingsByCalendar(calendarId, filter: _meetingsFilter);
      _meetings = mtgs;
    } catch (e) {
      _meetingError = 'Failed to load meetings.';
    } finally {
      _isLoadingMeetings = false;
      notifyListeners();
    }
  }

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
      // Try to find the new calendar in the refreshed list
      CalendarModel? created;
      for (int i = 0; i < 3; i++) {
        await loadCalendars(userId);
        try {
          created = _calendars.firstWhere((c) => c.id == id);
          break;
        } catch (_) {
          // Wait a bit and try one more time if not found immediately
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
      await _calendarRepo.updateCalendar(id: id, title: title, description: description, colorHex: colorHex, timezone: timezone);
      await loadCalendars(userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setPrimaryCalendar(String calendarId, String userId) async {
    try {
      await _calendarRepo.setPrimaryCalendar(calendarId: calendarId, userId: userId);
      await loadCalendars(userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCalendar({required String calendarId, required String userId}) async {
    try {
      await _calendarRepo.deleteCalendar(calendarId);
      await loadCalendars(userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<EventModel>> createEvent({
    required Map<String, dynamic> data,
    String meetingType = 'none',
    String? userId,
  }) async {
    if (_selectedCalendar == null) return [];
    try {
      final events = await _eventRepo.createEvent(calendarId: _selectedCalendar!.id, data: data, meetingType: meetingType, userId: userId);
      _events.addAll(events);
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
    _events.sort((a, b) {
      if (a.allDay && !b.allDay) return -1;
      if (!a.allDay && b.allDay) return 1;
      final aStart = a.startDateTime ?? DateTime.now();
      final bStart = b.startDateTime ?? DateTime.now();
      return aStart.compareTo(bStart);
    });
    notifyListeners();
    return tempId;
  }

  void replaceOptimisticEvent(String tempId, EventModel event) {
    final idx = _events.indexWhere((e) => e.id == tempId);
    if (idx != -1) {
      _events[idx] = event;
    } else {
      final existingIdx = _events.indexWhere((e) => e.id == event.id);
      if (existingIdx != -1) {
        _events[existingIdx] = event;
      } else {
        _events.add(event);
      }
    }

    final seen = <String>{};
    _events = _events.where((e) {
      if (seen.contains(e.id)) return false;
      seen.add(e.id);
      return true;
    }).toList();

    _events.sort((a, b) {
      if (a.allDay && !b.allDay) return -1;
      if (!a.allDay && b.allDay) return 1;
      final aStart = a.startDateTime ?? DateTime.now();
      final bStart = b.startDateTime ?? DateTime.now();
      return aStart.compareTo(bStart);
    });
    notifyListeners();
  }

  void removeEventById(String eventId) {
    _events.removeWhere((e) => e.id == eventId);
    _cancelReminderForEvent(eventId);
    notifyListeners();
  }

  void upsertLocalEvent(EventModel event) {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      _events[idx] = event;
    } else {
      _events.add(event);
    }
    _scheduleReminderForEvent(event);
    _events.sort((a, b) {
      if (a.allDay && !b.allDay) return -1;
      if (!a.allDay && b.allDay) return 1;
      final aStart = a.startDateTime ?? DateTime.now();
      final bStart = b.startDateTime ?? DateTime.now();
      return aStart.compareTo(bStart);
    });
    notifyListeners();
  }

  Future<bool> updateEvent(String eventId, Map<String, dynamic> data) async {
    final idx = _events.indexWhere((e) => e.id == eventId);
    EventModel? previous;
    if (idx != -1) {
      previous = _events[idx];
      _events[idx] = _mergeEventPatch(previous, data);
      notifyListeners();
    }
    try {
      final updated = await _eventRepo.updateEvent(eventId: eventId, data: data);
      if (idx != -1) {
        _events[idx] = updated;
        _scheduleReminderForEvent(updated);
        notifyListeners();
      }
      return true;
    } catch (_) {
      if (idx != -1 && previous != null) {
        _events[idx] = previous;
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final event = _events.firstWhere((e) => e.id == eventId, orElse: () => throw Exception('Event not found'));
    _events.removeWhere((e) => e.id == eventId);
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
      _events.sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));
      notifyListeners();
    }
  }

  Future<EventModel?> refreshEvent(String eventId) async {
    try {
      final event = await _eventRepo.getEventById(eventId);
      final idx = _events.indexWhere((e) => e.id == eventId);
      if (idx != -1) {
        _events[idx] = event;
        _scheduleReminderForEvent(event);
        notifyListeners();
      }
      return event;
    } catch (_) {
      return null;
    }
  }

  // Reminders
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

  void goToPrevMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    notifyListeners();
  }

  void goToNextMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    notifyListeners();
  }

  void goToToday() {
    _currentMonth = DateTime.now();
    _selectedDate = DateTime.now();
    notifyListeners();
    if (_selectedCalendar != null) loadEvents(_selectedCalendar!.id);
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    _currentMonth = DateTime(date.year, date.month);
    if (_selectedCalendar != null) {
      loadEventsForRange(_selectedCalendar!.id, date.subtract(const Duration(days: 3)), date.add(const Duration(days: 4)));
    } else {
      notifyListeners();
    }
  }

  void setViewMode(CalendarViewMode mode) {
    _viewMode = mode;
    notifyListeners();
    _saveViewMode(mode);
  }

  Future<void> _saveViewMode(CalendarViewMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_viewModeKey, mode.index);
    } catch (_) {}
  }

  EventModel _mergeEventPatch(EventModel event, Map<String, dynamic> data) {
    final startIso = data['startTime'] as String?;
    final endIso = data['endTime'] as String?;
    final title = data['title'] as String?;
    final description = data['description'] as String?;
    final status = data['status'] as String?;
    final type = data['type'] as String?;

    return event.copyWithTimes(
      startDateTime: startIso != null ? DateTime.tryParse(startIso)?.toLocal() : null,
      endDateTime: endIso != null ? DateTime.tryParse(endIso)?.toLocal() : null,
      title: title,
      description: description,
      status: status,
      type: type,
    );
  }

  void _scheduleReminderForEvent(EventModel event) {
    if (event.startDateTime != null) {
      NotificationService().scheduleEventReminder(
        eventId: event.id,
        eventTitle: event.title,
        eventStartTime: event.startDateTime!,
        reminderMinutesBefore: 15, // Default reminder offset
      );
    }
  }

  void _cancelReminderForEvent(String eventId) {
    NotificationService().cancelReminder(eventId);
  }
}
