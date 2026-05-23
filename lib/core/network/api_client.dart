import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Bypass SSL certificate validation for local development (e.g. using IP addresses)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };

    // Auth interceptor — adds Bearer token and X-User-Id
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getAccessToken();
        final isLoginRequest = options.path.contains('/auth/login');

        if (token != null && token.isNotEmpty && !isLoginRequest) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Add X-User-Id from cached user if present
        try {
          // FORCE Host header for local K8s ingress routing via adb reverse
          options.headers['Host'] = 'api.flux-cal.com';

          final prefs = await SharedPreferences.getInstance();
          final cachedUserJson = prefs.getString(kCachedUserKey);
          if (cachedUserJson != null) {
            final user = jsonDecode(cachedUserJson) as Map<String, dynamic>;
            final userId = user['id'];
            if (userId != null) {
              options.headers['X-User-Id'] = userId.toString();
            }
          }
        } catch (e) {
          // Log error but don't block the request
          print('Error adding X-User-Id header: $e');
        }

        return handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final isLoginRequest = error.requestOptions.path.contains('/auth/login');
        final isAuthMeRequest = error.requestOptions.path.contains('/auth/me');

        // 401 on non-login, non-/me requests → clear tokens (mirrors web behavior)
        if (status == 401 && !isLoginRequest && !isAuthMeRequest) {
          await TokenStorage.clearTokens();
          // Signal that we need to navigate to login (handled by auth provider)
          _authErrorCallback?.call();
        }
        return handler.next(error);
      },
    ));
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  static Function()? _authErrorCallback;

  static void setAuthErrorCallback(Function() callback) {
    _authErrorCallback = callback;
  }

  Dio get dio => _dio;

  // Convenience methods
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) {
    return _dio.get<T>(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) {
    return _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> patch<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) {
    return _dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) {
    return _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);
  }
}
