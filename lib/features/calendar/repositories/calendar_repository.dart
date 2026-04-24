import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/calendar_model.dart';

class CalendarRepository {
  final _api = ApiClient.instance;

  Future<List<CalendarModel>> getCalendarsByUserId(String userId) async {
    final response = await _api.get('$kCalendarsByUserEndpoint/$userId');
    final data = response.data;
    if (data is List) {
      return data.map((e) => CalendarModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<String> createCalendar({
    required String userId,
    required String title,
    required String description,
    required String colorHex,
    required String timezone,
    required bool isPrimary,
  }) async {
    final response = await _api.post(kCalendarsEndpoint, data: {
      'userId': userId,
      'title': title,
      'description': description,
      'colorHex': colorHex,
      'timezone': timezone,
      'isPrimary': isPrimary,
    });
    final raw = response.data;
    String? id;
    if (raw is Map<String, dynamic>) {
      id = (raw['id'] ?? raw['_id'] ?? raw['calendarId'])?.toString();
    } else {
      id = raw?.toString();
    }

    if (id != null) {
      id = id.trim();
      if (id.startsWith('"') && id.endsWith('"') && id.length >= 2) {
        id = id.substring(1, id.length - 1).trim();
      }
    }
    return id ?? raw.toString();
  }

  Future<void> updateCalendar({
    required String id,
    required String title,
    required String description,
    required String colorHex,
    required String timezone,
  }) async {
    await _api.put('$kCalendarsEndpoint/update/$id', data: {
      'title': title,
      'description': description,
      'colorHex': colorHex,
      'timezone': timezone,
    });
  }

  Future<void> setPrimaryCalendar({
    required String calendarId,
    required String userId,
  }) async {
    await _api.put('$kCalendarsEndpoint/user/primary/$calendarId', data: {'userId': userId});
  }

  Future<void> deleteCalendar(String id) async {
    await _api.delete('$kCalendarsEndpoint/$id');
  }

  Future<CalendarModel?> getPrimaryCalendar(String userId) async {
    try {
      final response = await _api.get('$kCalendarsEndpoint/user/primary/$userId');
      return CalendarModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
