class LocationModel {
  final String? id;
  final String? placeName;
  final String? streetAddress;
  final String? city;
  final String? country;
  final String? buildingName;
  final String? floor;
  final String? room;

  const LocationModel({
    this.id,
    this.placeName,
    this.streetAddress,
    this.city,
    this.country,
    this.buildingName,
    this.floor,
    this.room,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] as String?,
      placeName: json['placeName'] as String?,
      streetAddress: json['streetAddress'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      buildingName: json['buildingName'] as String?,
      floor: json['floor']?.toString(),
      room: json['room'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (placeName != null) 'placeName': placeName,
        if (streetAddress != null) 'streetAddress': streetAddress,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (buildingName != null) 'buildingName': buildingName,
        if (floor != null) 'floor': floor,
        if (room != null) 'room': room,
      };

  String get displayText {
    final parts = <String>[];
    if (placeName != null) parts.add(placeName!);
    if (streetAddress != null) parts.add(streetAddress!);
    if (city != null) parts.add(city!);
    if (country != null) parts.add(country!);
    return parts.join(', ');
  }
}

class ConferenceModel {
  final String? id;
  final String? type;
  final String? platformName;
  final String? meetingLink;
  final String? meetingCode;
  final String? phoneNumber;
  final String? pin;
  final String? conferencePassword;

  const ConferenceModel({
    this.id,
    this.type,
    this.platformName,
    this.meetingLink,
    this.meetingCode,
    this.phoneNumber,
    this.pin,
    this.conferencePassword,
  });

  factory ConferenceModel.fromJson(Map<String, dynamic> json) {
    return ConferenceModel(
      id: json['id'] as String?,
      type: json['type'] as String?,
      platformName: json['platformName'] as String?,
      meetingLink: (json['meetingLink'] ?? json['conferenceLink']) as String?,
      meetingCode: (json['meetingCode'] ?? json['zoomMeetingId'])?.toString(),
      phoneNumber: json['phoneNumber'] as String?,
      pin: json['pin'] as String?,
      conferencePassword: json['conferencePassword'] as String?,
    );
  }

  static String _norm(String? v) =>
      (v ?? '').trim().toLowerCase().replaceAll('_', '').replaceAll('-', '');

  bool get isGoogleMeet {
    final t = _norm(type);
    final p = _norm(platformName);
    final link = (meetingLink ?? '').toLowerCase();
    return t == 'meet' ||
        t == 'googlemeet' ||
        p.contains('googlemeet') ||
        p.contains('google') ||
        link.contains('meet.google.com');
  }

  bool get isZoom {
    final t = _norm(type);
    final p = _norm(platformName);
    final link = (meetingLink ?? '').toLowerCase();
    return t == 'zoom' || p.contains('zoom') || link.contains('zoom.us');
  }
}

class SubtaskModel {
  final String? id;
  final String subtask;
  final bool isDone;

  const SubtaskModel({
    this.id,
    required this.subtask,
    required this.isDone,
  });

  factory SubtaskModel.fromJson(Map<String, dynamic> json) {
    return SubtaskModel(
      id: json['id'] as String?,
      subtask: json['subtask'] as String? ?? '',
      isDone: json['isDone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'subtask': subtask,
        'isDone': isDone,
      };

  SubtaskModel copyWith({bool? isDone, String? subtask}) {
    return SubtaskModel(
        id: id,
        subtask: subtask ?? this.subtask,
        isDone: isDone ?? this.isDone);
  }
}

class NoteModel {
  final String id;
  final String content;
  final String createdAt;

  const NoteModel(
      {required this.id, required this.content, required this.createdAt});

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class MemberModel {
  final String id;
  final String email;
  final String? fullName;
  final bool isOwner;

  const MemberModel({
    required this.id,
    required this.email,
    this.fullName,
    required this.isOwner,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String?,
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }

  String get displayName => fullName?.isNotEmpty == true ? fullName! : email;
  String get initial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
}

class AttachmentModel {
  final String id;
  final String? title;
  final String? fileUrl;
  final String? mimeType;
  final int? fileSize;

  const AttachmentModel({
    required this.id,
    this.title,
    this.fileUrl,
    this.mimeType,
    this.fileSize,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String?,
      fileUrl: json['fileUrl'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: json['fileSize'] as int?,
    );
  }

  String get ext {
    final name = title ?? fileUrl ?? '';
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }
}

class EventModel {
  final String id;
  final String calendarId;
  final String title;
  final String? description;
  final String? type;
  final String? status;
  final String? colorHex;
  final bool allDay;
  final String? startTime; // ISO string
  final String? endTime; // ISO string
  final String? syncStatus;
  final LocationModel? location;
  final ConferenceModel? conference;
  final List<SubtaskModel> subtasks;
  final List<NoteModel> notes;
  final List<MemberModel> members;
  final List<AttachmentModel> attachments;
  final String createdAt;
  final String updatedAt;
  final bool virtual;
  final String? recurringGroupId;
  final bool isRecurring;

  const EventModel({
    required this.id,
    required this.calendarId,
    required this.title,
    this.description,
    this.type,
    this.status,
    this.colorHex,
    required this.allDay,
    this.startTime,
    this.endTime,
    this.syncStatus,
    this.location,
    this.conference,
    required this.subtasks,
    required this.notes,
    required this.members,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    this.virtual = false,
    this.recurringGroupId,
    this.isRecurring = false,
  });

  /// Prefer API `title`; fall back to common alternate keys (e.g. Google-style `summary`).
  static String _parseTitle(Map<String, dynamic> json) {
    final raw = json['title'] ??
        json['summary'] ??
        json['name'] ??
        json['subject'] ??
        json['eventTitle'];
    if (raw == null) return '';
    final s = raw.toString().trim();
    return s;
  }

  static String? _parseColorHex(Map<String, dynamic> json) {
    final raw = json['colorHex'] ?? json['color'];
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return s.startsWith('#') ? s : '#$s';
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final nestedCal = json['calendar'];
    final calId = json['calendarId'] as String?;
    final fromNested =
        nestedCal is Map<String, dynamic> ? nestedCal['id']?.toString() : null;

    String? parseInstant(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is Map) {
        try {
          final seconds = value['epochSecond'];
          final nanos = value['nano'] as int? ?? 0;
          if (seconds != null) {
            return DateTime.fromMillisecondsSinceEpoch(
              (seconds as int) * 1000 + nanos ~/ 1000000,
              isUtc: true,
            ).toIso8601String();
          }
        } catch (_) {}
      }
      return value.toString();
    }

    return EventModel(
      id: json['id'] as String? ?? '',
      calendarId: calId ?? fromNested ?? json['calendarId'] as String? ?? '',
      title: _parseTitle(json),
      description: json['description'] as String?,
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      colorHex: _parseColorHex(json),
      allDay: json['allDay'] as bool? ?? false,
      startTime: parseInstant(json['startTime'] ?? json['start']),
      endTime: parseInstant(json['endTime'] ?? json['end']),
      syncStatus: json['syncStatus'] as String?,
      location: json['location'] is Map
          ? LocationModel.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      conference: json['conference'] is Map
          ? ConferenceModel.fromJson(json['conference'] as Map<String, dynamic>)
          : null,
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((e) => SubtaskModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: (json['notes'] as List<dynamic>?)
              ?.map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => MemberModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      virtual: json['virtual'] as bool? ?? false,
      recurringGroupId: json['recurringGroupId'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? json['recurring'] as bool? ?? false,
    );
  }

  DateTime? get startDateTime =>
      startTime != null ? DateTime.tryParse(startTime!)?.toLocal() : null;
  DateTime? get endDateTime =>
      endTime != null ? DateTime.tryParse(endTime!)?.toLocal() : null;

  String get effectiveColor => colorHex ?? '#6366F1';

  /// Non-empty title for UI; avoids blank blocks when the API omits `title` but sets another field.
  String get displayTitle {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    return '(Untitled event)';
  }

  String? get meetingLink => conference?.meetingLink;
  String? get meetingPlatform => conference?.platformName;

  double get subtaskProgress {
    if (subtasks.isEmpty) return 0;
    return subtasks.where((s) => s.isDone).length / subtasks.length;
  }

  int get subtaskDone => subtasks.where((s) => s.isDone).length;

  EventModel copyWithTimes({
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? title,
    String? description,
    String? status,
    String? type,
  }) {
    return EventModel(
      id: id,
      calendarId: calendarId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      colorHex: colorHex,
      allDay: allDay,
      startTime: startDateTime?.toUtc().toIso8601String() ?? startTime,
      endTime: endDateTime?.toUtc().toIso8601String() ?? endTime,
      syncStatus: syncStatus,
      location: location,
      conference: conference,
      subtasks: subtasks,
      notes: notes,
      members: members,
      attachments: attachments,
      createdAt: createdAt,
      updatedAt: updatedAt,
      virtual: virtual,
      recurringGroupId: recurringGroupId,
      isRecurring: isRecurring,
    );
  }

  EventModel copyWithSubtasks(List<SubtaskModel> subtasks) {
    return EventModel(
      id: id,
      calendarId: calendarId,
      title: title,
      description: description,
      type: type,
      status: status,
      colorHex: colorHex,
      allDay: allDay,
      startTime: startTime,
      endTime: endTime,
      syncStatus: syncStatus,
      location: location,
      conference: conference,
      subtasks: subtasks,
      notes: notes,
      members: members,
      attachments: attachments,
      createdAt: createdAt,
      updatedAt: updatedAt,
      virtual: virtual,
      recurringGroupId: recurringGroupId,
      isRecurring: isRecurring,
    );
  }
}
