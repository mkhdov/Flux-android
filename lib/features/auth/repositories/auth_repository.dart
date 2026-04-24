import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.post(kLoginEndpoint, data: {
        'email': email,
        'password': password,
      });

      final data = response.data as Map<String, dynamic>;
      final token = data['accessToken'] ?? data['token'];
      final type = data['tokenType'] ?? data['type'];

      if (token == null) {
        throw Exception('Login succeeded but no access token was returned by the server.');
      }

      await TokenStorage.saveTokens(
        accessToken: token.toString(),
        tokenType: type?.toString(),
      );

      return data;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String message = 'Login failed. Please check your credentials and try again.';
      if (responseData is Map) {
        message = responseData['message']?.toString() ??
            responseData['errors']?['details']?.toString() ??
            message;
      }
      throw Exception(message);
    }
  }

  Future<void> signup({
    required String firstName,
    required String lastName,
    required String birthday,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.post(kSignupEndpoint, data: {
        'firstName': firstName,
        'lastName': lastName,
        'birthday': birthday,
        'email': email,
        'password': password,
      });

      final data = response.data;
      if (data is Map && data['success'] == false) {
        throw Exception(data['message']?.toString() ?? 'Registration failed.');
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final responseData = e.response?.data;
      if (status == 409) {
        throw Exception('Email already exists.');
      } else if (status == 400) {
        final msg = responseData is Map ? responseData['message']?.toString() : null;
        throw Exception(msg ?? 'Invalid data.');
      }
      throw Exception('Something went wrong. Please try again.');
    }
  }

  Future<void> resendVerification(String email) async {
    try {
      await _api.post(kResendVerificationEndpoint, data: {'email': email});
    } on DioException {
      throw Exception('Failed to resend verification email.');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    // Try cache first
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(kCachedUserKey);
    if (cachedJson != null) {
      try {
        final json = jsonDecode(cachedJson) as Map<String, dynamic>;
        return UserModel.fromJson(json);
      } catch (_) {
        await prefs.remove(kCachedUserKey);
      }
    }

    // Fetch from API
    final token = await TokenStorage.getAccessToken();
    if (token == null) return null;

    try {
      final response = await _api.get(kMeEndpoint);
      final user = UserModel.fromJson(response.data as Map<String, dynamic>);
      await prefs.setString(kCachedUserKey, jsonEncode(user.toJson()));
      return user;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 400) {
        // Don't clear token (matches web behavior)
        return null;
      }
      return null;
    }
  }

  Future<String?> getUserEmailById(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return null;

    try {
      final response = await _api.get(userEmailByIdEndpoint(Uri.encodeComponent(id)));
      final data = response.data;
      if (data is Map && data['email'] != null) {
        final email = data['email'].toString().trim();
        return email.isEmpty ? null : email;
      }
      return null;
    } on DioException {
      return null;
    }
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kCachedUserKey);
    await prefs.remove('user');
  }

  Future<bool> isLoggedIn() async {
    return await TokenStorage.hasToken();
  }
}
