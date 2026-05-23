import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/event_model.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class EventRepository {
  final _api = ApiClient.instance;

  String _baseId(String eventId) {
    return eventId.contains(':') ? eventId.split(':')[0] : eventId;
  }

  bool _looksLikeEventMap(Map<String, dynamic> map) {
    return map.containsKey('id') ||
        map.containsKey('calendarId') ||
        map.containsKey('startTime') ||
        map.containsKey('endTime') ||
        map.containsKey('title') ||
        map.containsKey('summary');
  }

  String? _extractEventId(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      final candidate = raw['id'] ?? raw['_id'] ?? raw['eventId'];
      return candidate?.toString();
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s.startsWith('"') && s.endsWith('"') && s.length > 1) {
      return s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  Future<List<EventModel>> getEventsByCalendar(
    String calendarId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Backend supports:
    // - GET /events/range?calendarId=...&start=...&end=...
    // - GET /events/calendar/{calendarId}  (all events, no range)
    final DateTime? rangeStart = startDate;
    final DateTime? rangeEnd = endDate;
    final bool hasRange = rangeStart != null && rangeEnd != null;
    final String path = hasRange ? '$kEventsEndpoint/range' : '$kEventsByCalendarEndpoint/$calendarId';
    final Map<String, dynamic> queryParams = hasRange
        ? {
            'calendarId': calendarId,
            'start': rangeStart.toUtc().toIso8601String(),
            'end': rangeEnd.toUtc().toIso8601String(),
          }
        : {};

    final response = await _api.get(path, queryParameters: queryParams);
    final data = response.data;
    if (data is List) {
      return data.map((e) => EventModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<EventModel>> getEventsByMonth({
    required String calendarId,
    required int year,
    required int month,
  }) async {
    final response = await _api.get(
      '$kEventsEndpoint/month',
      queryParameters: {
        'calendarId': calendarId,
        'year': year,
        'month': month,
      },
    );
    final data = response.data;
    final list = data is List
        ? data
        : data is Map<String, dynamic> && data['data'] is List
            ? data['data'] as List
            : const [];

    return list.whereType<Map<String, dynamic>>().map(EventModel.fromJson).toList();
  }

  Future<List<EventModel>> getMeetingsByCalendar(String calendarId, {String filter = 'today'}) async {
    final response = await _api.get(
      '$kEventsByCalendarEndpoint/$calendarId/meetings',
      queryParameters: {'filter': filter},
    );
    final data = response.data;
    if (data is List) {
      return data.map((e) => EventModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> syncGoogleCalendar(String calendarId) async {
    await _api.post('$kGoogleCalendarSyncEndpoint/$calendarId');
  }

  Future<EventModel> getEventById(String id) async {
    final isRecurringInstance = id.contains(':');
    final String baseId = isRecurringInstance ? id.split(':')[0] : id;

    final response = await _api.get('$kEventsEndpoint/$baseId');
    final model = EventModel.fromJson(response.data as Map<String, dynamic>);

    if (isRecurringInstance) {
      final parts = id.split(':');
      try {
        final startMs = int.parse(parts[1]);
        final startDt = DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true).toLocal();
        final duration = model.endDateTime != null && model.startDateTime != null
            ? model.endDateTime!.difference(model.startDateTime!)
            : const Duration(hours: 1);
        final endDt = startDt.add(duration);
        return EventModel(
          id: id,
          calendarId: model.calendarId,
          title: model.title,
          description: model.description,
          type: model.type,
          status: model.status,
          colorHex: model.colorHex,
          allDay: model.allDay,
          startTime: startDt.toUtc().toIso8601String(),
          endTime: endDt.toUtc().toIso8601String(),
          syncStatus: model.syncStatus,
          location: model.location,
          conference: model.conference,
          subtasks: model.subtasks,
          notes: model.notes,
          members: model.members,
          attachments: model.attachments,
          createdAt: model.createdAt,
          updatedAt: model.updatedAt,
          virtual: true,
        );
      } catch (_) {
        // ignore and return normal model if parsing fails
      }
    }
    return model;
  }

  Future<List<EventModel>> createEvent({
    required String calendarId,
    required Map<String, dynamic> data,
    String meetingType = 'none',
    String? userId,
  }) async {
    String endpoint = '$kEventsByCalendarEndpoint/$calendarId';
    if (meetingType == 'meet') {
      endpoint = '$endpoint/add-meet';
    } else if (meetingType == 'zoom') {
      endpoint = '$endpoint/add-zoom';
    }

    final options = meetingType == 'zoom' && userId != null
        ? dioOptionsWithHeader(userId)
        : null;

    final response = await _api.post(endpoint, data: data, options: options);
    final raw = response.data;

    // Some endpoints return full event payload(s) instead of IDs.
    if (raw is List) {
      final eventMaps = raw.whereType<Map<String, dynamic>>().where(_looksLikeEventMap).toList();
      if (eventMaps.isNotEmpty) {
        return eventMaps.map(EventModel.fromJson).toList();
      }
    } else if (raw is Map<String, dynamic> && _looksLikeEventMap(raw)) {
      return [EventModel.fromJson(raw)];
    }

    List<String> ids = [];
    if (raw is List) {
      ids = raw.map((e) => e.toString()).toList();
    } else if (raw is Map<String, dynamic>) {
      final id = (raw['id'] ?? raw['_id'] ?? raw['eventId'])?.toString();
      if (id != null) ids.add(id);
    } else if (raw != null) {
      ids.add(raw.toString());
    }

    if (ids.isEmpty) {
      throw Exception('Failed to parse created event IDs from response: $raw');
    }

    List<EventModel> createdEvents = [];
    for (String id in ids) {
      id = id.trim();
      if (id.startsWith('"') && id.endsWith('"') && id.length >= 2) {
        id = id.substring(1, id.length - 1).trim();
      }
      if (id.isEmpty || id == 'null') continue;

      try {
        createdEvents.add(await getEventById(id));
      } catch (e) {
        // Retry once
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          createdEvents.add(await getEventById(id));
        } catch (_) {}
      }
    }

    if (createdEvents.isEmpty && ids.isNotEmpty) {
      // Fallback: return dummy models so UI proceeds
      return ids.map((id) => EventModel(
        id: id,
        calendarId: calendarId,
        title: data['title'] ?? 'New Event',
        allDay: data['allDay'] ?? false,
        startTime: data['startTime']?.toString(),
        endTime: data['endTime']?.toString(),
        description: data['description']?.toString(),
        status: data['status']?.toString(),
        type: data['type']?.toString(),
        colorHex: data['colorHex']?.toString(),
        subtasks: [],
        notes: [],
        members: [],
        attachments: [],
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      )).toList();
    }

    if (createdEvents.isEmpty) {
      throw Exception('Failed to fetch created events for IDs: $ids');
    }

    return createdEvents;
  }

  dynamic dioOptionsWithHeader(String userId) {
    return null; // Handled by adding userId to headers if needed
  }

  Future<EventModel> updateEvent({
    required String eventId,
    required Map<String, dynamic> data,
    String? scope,
  }) async {
    final cleanId = _baseId(eventId);
    final scoped = scope != null && scope.isNotEmpty;
    final response = await _api.put(
      scoped ? '$kEventsEndpoint/$cleanId/recurring' : '$kEventsEndpoint/$cleanId',
      data: data,
      queryParameters: scoped ? {'scope': scope} : null,
    );
    final raw = response.data;

    if (raw is Map<String, dynamic>) {
      return EventModel.fromJson(raw);
    }

    return getEventById(eventId);
  }

  Future<void> deleteEvent(String eventId) async {
    final cleanId = _baseId(eventId);
    await _api.delete('$kEventsEndpoint/$cleanId');
  }

  Future<void> deleteRecurringEvent(String eventId, String scope) async {
    final cleanId = _baseId(eventId);
    await _api.delete(
      '$kEventsEndpoint/$cleanId/recurring',
      queryParameters: {'scope': scope},
    );
  }


  // Conference
  Future<EventModel> addGoogleMeet(String eventId) async {
    final cleanId = _baseId(eventId);
    final response = await _api.post('$kConferenceEndpoint/$cleanId/add-meet');
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      return EventModel.fromJson(raw);
    }
    final parsedId = _extractEventId(raw);
    if (parsedId != null && parsedId.isNotEmpty && parsedId != eventId) {
      return getEventById(parsedId);
    }
    return getEventById(eventId);
  }

  Future<EventModel> addZoom(String eventId) async {
    final cleanId = _baseId(eventId);
    final response = await _api.post('$kEventsEndpoint/add-zoom/$cleanId');
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      return EventModel.fromJson(raw);
    }
    final parsedId = _extractEventId(raw);
    if (parsedId != null && parsedId.isNotEmpty && parsedId != eventId) {
      return getEventById(parsedId);
    }
    return getEventById(eventId);
  }

  Future<EventModel> removeConference(String eventId, String type) async {
    final cleanId = _baseId(eventId);
    final endpoint = type == 'zoom'
        ? '$kEventsEndpoint/remove-zoom/$cleanId'
        : '$kConferenceEndpoint/$cleanId/remove-meet';
    final response = await _api.delete(endpoint);
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      return EventModel.fromJson(raw);
    }
    final parsedId = _extractEventId(raw);
    if (parsedId != null && parsedId.isNotEmpty && parsedId != eventId) {
      return getEventById(parsedId);
    }
    return getEventById(eventId);
  }

  // Location
  Future<EventModel> addLocation({
    required String eventId,
    required Map<String, dynamic> locationData,
  }) async {
    final cleanId = _baseId(eventId);
    final response = await _api.post('$kLocationEndpoint/$cleanId', data: locationData);
    return EventModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeLocation(String locationId) async {
    await _api.delete('$kLocationEndpoint/$locationId');
  }

  Future<Map<String, dynamic>?> getMapLinks(String locationId) async {
    try {
      final response = await _api.get('$kLocationEndpoint/maps/$locationId');
      return response.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // Subtasks — update via event update
  Future<EventModel> updateSubtask({
    required String eventId,
    required String subtaskId,
    required bool isDone,
    String? subtaskText,
  }) async {
    await _api.patch(
      '/subtasks/$subtaskId/toggle',
      options: Options(
        validateStatus: (status) => status != null && status < 300,
      ),
    );
    return getEventById(eventId);
  }

  Future<EventModel> addSubtask({
    required String eventId,
    required String subtaskText,
  }) async {
    final cleanId = _baseId(eventId);
    await _api.post(
      '/subtasks/event/$cleanId',
      data: subtaskText,
      options: Options(contentType: 'text/plain'),
    );
    return getEventById(eventId);
  }

  Future<void> deleteSubtask(String eventId, String subtaskId) async {
    await _api.delete('/subtasks/$subtaskId');
  }

  Future<AttachmentModel> uploadAttachment({
    required String eventId,
    required String filePath,
    required String fileName,
  }) async {
    final cleanId = _baseId(eventId);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _api.post(
      '/attachments/event/$cleanId',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return AttachmentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteAttachment(String attachmentId) async {
    await _api.delete('/attachments/$attachmentId');
  }

  Future<String> downloadAttachmentToTemp({
    required String attachmentId,
    required String fileName,
  }) async {
    final response = await _api.dio.get<List<int>>(
      '/attachments/$attachmentId/file',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Empty attachment');
    }
    final sanitized = fileName.trim().isEmpty ? 'attachment.bin' : fileName;
    final path = '${Directory.systemTemp.path}/$sanitized';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // Members
  Future<void> inviteMember(String eventId, String email) async {
    final cleanId = _baseId(eventId);
    await _api.get('$kShareEventEndpoint/$cleanId/${Uri.encodeComponent(email)}');
  }

  Future<List<MemberModel>> getEventMembers(String eventId) async {
    final cleanId = _baseId(eventId);
    final response = await _api.get('$kMembersEndpoint/event/$cleanId');
    final data = response.data;
    if (data is List) {
      return data.map((e) => MemberModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> deleteMember({required String memberId, required String userId}) async {
    await _api.get('$kMembersEndpoint/delete/$memberId', queryParameters: {'userId': userId});
  }

  // Reminders
  Future<void> createReminder(Map<String, dynamic> data) async {
    await _api.post(kRemindersEndpoint, data: data);
  }

  Future<void> createRemindersBatch(List<Map<String, dynamic>> data) async {
    await _api.post('$kRemindersEndpoint/batch', data: data);
  }

  Future<List<dynamic>> getRemindersForEvent(String eventId) async {
    final cleanId = _baseId(eventId);
    final response = await _api.get('$kRemindersEndpoint/event/$cleanId');
    final data = response.data;
    if (data is List) return data;
    return [];
  }

  Future<void> deleteReminder(String reminderId) async {
    await _api.delete('$kRemindersEndpoint/$reminderId');
  }
}
