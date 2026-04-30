import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/models/user_model.dart';

class UserRepository {
  final _api = ApiClient.instance;

  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _api.get('/users/$userId');
      final data = response.data as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } on DioException {
      return null;
    }
  }

  Future<bool> updateUser({
    required String userId,
    required String firstname,
    required String lastname,
    required String email,
    required String birthday,
  }) async {
    try {
      await _api.put('/users/$userId', data: {
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'birthday': birthday,
      });
      // Clear cached user so it refreshes
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kCachedUserKey);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _api.delete('/users/$userId');
      // Clear cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kCachedUserKey);
      return true;
    } on DioException {
      return false;
    }
  }
}
