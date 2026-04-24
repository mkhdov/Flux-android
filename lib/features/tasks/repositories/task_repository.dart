import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/task_model.dart';

class TaskRepository {
  final _api = ApiClient.instance;

  Future<List<TaskModel>> getTasksByCalendar(String calendarId) async {
    final response = await _api.get(kTasksEndpoint, queryParameters: {'calendarId': calendarId});
    final data = response.data;
    if (data is List) {
      return data.map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<TaskModel> getTaskById(String id) async {
    final response = await _api.get('$kTasksEndpoint/$id');
    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TaskModel> createTask(Map<String, dynamic> data) async {
    final response = await _api.post(kTasksEndpoint, data: data);
    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TaskModel> updateTask(String id, Map<String, dynamic> data) async {
    final response = await _api.patch('$kTasksEndpoint/$id', data: data);
    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteTask(String id) async {
    await _api.delete('$kTasksEndpoint/$id');
  }

  Future<TaskModel> quickStatus(String id, String status) async {
    final response = await _api.patch('$kTasksEndpoint/$id', data: {'status': status});
    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }
}
