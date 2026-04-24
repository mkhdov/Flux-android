class CalendarModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String colorHex;
  final String timezone;
  final bool isPrimary;
  final bool isDeleted;
  final String createdAt;
  final String updatedAt;

  const CalendarModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.colorHex,
    required this.timezone,
    required this.isPrimary,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '#4285F4',
      timezone: json['timezone'] as String? ?? 'UTC',
      isPrimary: json['isPrimary'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'colorHex': colorHex,
    'timezone': timezone,
    'isPrimary': isPrimary,
    'isDeleted': isDeleted,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  bool get isGoogleSyncCalendar => description.startsWith('Google sync calendar for ');

  CalendarModel copyWith({
    String? title,
    String? description,
    String? colorHex,
    String? timezone,
    bool? isPrimary,
  }) {
    return CalendarModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      timezone: timezone ?? this.timezone,
      isPrimary: isPrimary ?? this.isPrimary,
      isDeleted: isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
