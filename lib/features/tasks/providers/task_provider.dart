import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';

class _PendingTaskDelete {
  final TaskModel task;
  final Future<void> Function() action;
  _PendingTaskDelete(this.task, this.action);
}

class TaskProvider extends ChangeNotifier {
  final TaskRepository _repo;

  List<TaskModel> _tasks = [];
  TaskModel? _selectedTask;
  bool _isLoading = false;
  bool _isPanelLoading = false;
  String? _error;
  String? _panelError;
  final Map<String, _PendingTaskDelete> _pendingDeletes = {};

  TaskStatus? _statusFilter;
  TaskPriority? _priorityFilter;
  String _searchQuery = '';
  String _sortBy = 'createdAt';
  List<TaskModel>? _filteredTasksCache;
  Map<String, int>? _countsCache;

  TaskProvider(this._repo);

  List<TaskModel> get tasks => _tasks;
  TaskModel? get selectedTask => _selectedTask;
  bool get isLoading => _isLoading;
  bool get isPanelLoading => _isPanelLoading;
  String? get error => _error;
  String? get panelError => _panelError;
  TaskStatus? get statusFilter => _statusFilter;
  TaskPriority? get priorityFilter => _priorityFilter;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;

  List<TaskModel> get filteredTasks {
    final cached = _filteredTasksCache;
    if (cached != null) return cached;

    var list = _tasks.toList();
    if (_statusFilter != null)
      list = list.where((t) => t.status == _statusFilter).toList();
    if (_priorityFilter != null)
      list = list.where((t) => t.priority == _priorityFilter).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    const priorityWeight = {
      TaskPriority.high: 3,
      TaskPriority.medium: 2,
      TaskPriority.low: 1
    };
    list.sort((a, b) {
      if (_sortBy == 'priority')
        return (priorityWeight[b.priority] ?? 0) -
            (priorityWeight[a.priority] ?? 0);
      if (_sortBy == 'deadline') {
        if (a.deadline == null) return 1;
        if (b.deadline == null) return -1;
        return DateTime.parse(a.deadline!)
            .compareTo(DateTime.parse(b.deadline!));
      }
      return DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt));
    });
    _filteredTasksCache = List<TaskModel>.unmodifiable(list);
    return _filteredTasksCache!;
  }

  Map<String, int> get counts {
    final cached = _countsCache;
    if (cached != null) return cached;
    var todo = 0;
    var inProgress = 0;
    var done = 0;
    for (final task in _tasks) {
      switch (task.status) {
        case TaskStatus.todo:
          todo++;
          break;
        case TaskStatus.inProgress:
          inProgress++;
          break;
        case TaskStatus.done:
          done++;
          break;
      }
    }
    _countsCache = {
      'ALL': _tasks.length,
      'TODO': todo,
      'IN_PROGRESS': inProgress,
      'DONE': done,
    };
    return _countsCache!;
  }

  void _invalidateDerivedData() {
    _filteredTasksCache = null;
    _countsCache = null;
  }

  void setStatusFilter(TaskStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    _filteredTasksCache = null;
    notifyListeners();
  }

  void setPriorityFilter(TaskPriority? priority) {
    if (_priorityFilter == priority) return;
    _priorityFilter = priority;
    _filteredTasksCache = null;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    if (_searchQuery == q) return;
    _searchQuery = q;
    _filteredTasksCache = null;
    notifyListeners();
  }

  void setSortBy(String s) {
    if (_sortBy == s) return;
    _sortBy = s;
    _filteredTasksCache = null;
    notifyListeners();
  }

  Future<void> fetchTasks(String calendarId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tasks = await _repo.getTasksByCalendar(calendarId);
      _invalidateDerivedData();
    } catch (_) {
      _error = 'Failed to load tasks.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectTask(String id) async {
    _isPanelLoading = true;
    _panelError = null;
    notifyListeners();
    try {
      _selectedTask = await _repo.getTaskById(id);
    } catch (_) {
      _panelError = 'Failed to load task details.';
    } finally {
      _isPanelLoading = false;
      notifyListeners();
    }
  }

  void clearSelectedTask() {
    _selectedTask = null;
    _panelError = null;
    notifyListeners();
  }

  Future<bool> createTask(Map<String, dynamic> data) async {
    try {
      final task = await _repo.createTask(data);
      _tasks.insert(0, task);
      _invalidateDerivedData();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> data) async {
    try {
      final task = await _repo.updateTask(id, data);
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx != -1) _tasks[idx] = task;
      if (_selectedTask?.id == id) _selectedTask = task;
      _invalidateDerivedData();
      notifyListeners();
      return true;
    } catch (_) {
      _panelError = 'Failed to update task.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> quickStatus(String id, TaskStatus status) async {
    try {
      final task = await _repo.quickStatus(id, status.value);
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx != -1) _tasks[idx] = task;
      if (_selectedTask?.id == id) _selectedTask = task;
      _invalidateDerivedData();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id,
        orElse: () => throw Exception('Task not found'));
    _tasks.removeWhere((t) => t.id == id);
    if (_selectedTask?.id == id) _selectedTask = null;
    _invalidateDerivedData();
    notifyListeners();

    Future<void> action() async {
      if (_pendingDeletes.containsKey(id)) {
        await _repo.deleteTask(id);
        _pendingDeletes.remove(id);
      }
    }

    _pendingDeletes[id] = _PendingTaskDelete(task, action);
    Future.delayed(const Duration(seconds: 5), () {
      if (_pendingDeletes.containsKey(id)) _pendingDeletes[id]!.action();
    });
  }

  void undoDeleteTask(String id) {
    if (_pendingDeletes.containsKey(id)) {
      final item = _pendingDeletes.remove(id);
      _tasks.insert(0, item!.task);
      _invalidateDerivedData();
      notifyListeners();
    }
  }
}
