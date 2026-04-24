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
    var list = _tasks.toList();
    if (_statusFilter != null) list = list.where((t) => t.status == _statusFilter).toList();
    if (_priorityFilter != null) list = list.where((t) => t.priority == _priorityFilter).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) => t.title.toLowerCase().contains(q) || (t.description?.toLowerCase().contains(q) ?? false)).toList();
    }
    const priorityWeight = {TaskPriority.high: 3, TaskPriority.medium: 2, TaskPriority.low: 1};
    list.sort((a, b) {
      if (_sortBy == 'priority') return (priorityWeight[b.priority] ?? 0) - (priorityWeight[a.priority] ?? 0);
      if (_sortBy == 'deadline') {
        if (a.deadline == null) return 1;
        if (b.deadline == null) return -1;
        return DateTime.parse(a.deadline!).compareTo(DateTime.parse(b.deadline!));
      }
      return DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt));
    });
    return list;
  }

  Map<String, int> get counts => {
    'ALL': _tasks.length,
    'TODO': _tasks.where((t) => t.status == TaskStatus.todo).length,
    'IN_PROGRESS': _tasks.where((t) => t.status == TaskStatus.inProgress).length,
    'DONE': _tasks.where((t) => t.status == TaskStatus.done).length,
  };

  void setStatusFilter(TaskStatus? status) { _statusFilter = status; notifyListeners(); }
  void setPriorityFilter(TaskPriority? priority) { _priorityFilter = priority; notifyListeners(); }
  void setSearchQuery(String q) { _searchQuery = q; notifyListeners(); }
  void setSortBy(String s) { _sortBy = s; notifyListeners(); }

  Future<void> fetchTasks(String calendarId) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      _tasks = await _repo.getTasksByCalendar(calendarId);
    } catch (_) {
      _error = 'Failed to load tasks.';
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> selectTask(String id) async {
    _isPanelLoading = true; _panelError = null; notifyListeners();
    try {
      _selectedTask = await _repo.getTaskById(id);
    } catch (_) {
      _panelError = 'Failed to load task details.';
    } finally {
      _isPanelLoading = false; notifyListeners();
    }
  }

  void clearSelectedTask() { _selectedTask = null; _panelError = null; notifyListeners(); }

  Future<bool> createTask(Map<String, dynamic> data) async {
    try {
      final task = await _repo.createTask(data);
      _tasks.insert(0, task);
      notifyListeners();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> data) async {
    try {
      final task = await _repo.updateTask(id, data);
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx != -1) _tasks[idx] = task;
      if (_selectedTask?.id == id) _selectedTask = task;
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
      notifyListeners();
      return true;
    } catch (_) { return false; }
  }

  Future<void> deleteTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id, orElse: () => throw Exception('Task not found'));
    _tasks.removeWhere((t) => t.id == id);
    if (_selectedTask?.id == id) _selectedTask = null;
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
      notifyListeners();
    }
  }
}
