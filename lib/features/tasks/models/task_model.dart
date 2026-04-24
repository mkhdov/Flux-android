enum TaskStatus { todo, inProgress, done }
enum TaskPriority { low, medium, high }

extension TaskStatusExt on TaskStatus {
  String get value => switch (this) {
    TaskStatus.todo => 'TODO',
    TaskStatus.inProgress => 'IN_PROGRESS',
    TaskStatus.done => 'DONE',
  };
  String get label => switch (this) {
    TaskStatus.todo => 'To Do',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.done => 'Done',
  };
  static TaskStatus fromString(String v) => switch (v) {
    'IN_PROGRESS' => TaskStatus.inProgress,
    'DONE' => TaskStatus.done,
    _ => TaskStatus.todo,
  };
}

extension TaskPriorityExt on TaskPriority {
  String get value => switch (this) {
    TaskPriority.low => 'LOW',
    TaskPriority.medium => 'MEDIUM',
    TaskPriority.high => 'HIGH',
  };
  String get label => switch (this) {
    TaskPriority.low => 'Low',
    TaskPriority.medium => 'Medium',
    TaskPriority.high => 'High',
  };
  static TaskPriority fromString(String v) => switch (v) {
    'MEDIUM' => TaskPriority.medium,
    'HIGH' => TaskPriority.high,
    _ => TaskPriority.low,
  };
}

class TaskSubtask {
  final String? id;
  final String subtask;
  final bool isDone;

  const TaskSubtask({this.id, required this.subtask, required this.isDone});

  factory TaskSubtask.fromJson(Map<String, dynamic> json) => TaskSubtask(
    id: json['id'] as String?,
    subtask: json['subtask'] as String? ?? '',
    isDone: json['isDone'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'subtask': subtask,
    'isDone': isDone,
  };

  TaskSubtask copyWith({bool? isDone}) => TaskSubtask(id: id, subtask: subtask, isDone: isDone ?? this.isDone);
}

class TaskNote {
  final String id;
  final String content;
  final String createdAt;
  final String updatedAt;

  const TaskNote({required this.id, required this.content, required this.createdAt, required this.updatedAt});

  factory TaskNote.fromJson(Map<String, dynamic> json) => TaskNote(
    id: json['id'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdAt: json['createdAt'] as String? ?? '',
    updatedAt: json['updatedAt'] as String? ?? '',
  );
}

class TaskModel {
  final String id;
  final String calendarId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final String? date;
  final String? deadline;
  final List<TaskSubtask> subtasks;
  final List<TaskNote> notes;
  final String createdAt;
  final String updatedAt;

  const TaskModel({
    required this.id,
    required this.calendarId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.date,
    this.deadline,
    required this.subtasks,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'] as String? ?? '',
    calendarId: json['calendarId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    status: TaskStatusExt.fromString(json['status'] as String? ?? 'TODO'),
    priority: TaskPriorityExt.fromString(json['priority'] as String? ?? 'LOW'),
    date: json['date'] as String?,
    deadline: json['deadline'] as String?,
    subtasks: (json['subtasks'] as List<dynamic>?)?.map((e) => TaskSubtask.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    notes: (json['notes'] as List<dynamic>?)?.map((e) => TaskNote.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    createdAt: json['createdAt'] as String? ?? '',
    updatedAt: json['updatedAt'] as String? ?? '',
  );

  double get subtaskProgress {
    if (subtasks.isEmpty) return 0;
    return subtasks.where((s) => s.isDone).length / subtasks.length;
  }

  int get subtaskDone => subtasks.where((s) => s.isDone).length;

  DateTime? get deadlineDateTime => deadline != null ? DateTime.tryParse(deadline!)?.toLocal() : null;
  DateTime? get dateDateTime => date != null ? DateTime.tryParse(date!)?.toLocal() : null;
}
