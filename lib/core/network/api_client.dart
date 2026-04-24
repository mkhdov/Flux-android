import 'package:dio/dio.dart';
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

    // Auth interceptor — adds Bearer token (mirrors web api.ts interceptor)
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getAccessToken();
        final isLoginRequest = options.path.contains('/auth/login');

        if (token != null && token.isNotEmpty && !isLoginRequest) {
          options.headers['Authorization'] = 'Bearer $token';
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

  Future<Response<T>> post<T>(String path, {dynamic data, Options? options}) {
    return _dio.post<T>(path, data: data, options: options);
  }

  Future<Response<T>> put<T>(String path, {dynamic data, Options? options}) {
    return _dio.put<T>(path, data: data, options: options);
  }

  Future<Response<T>> patch<T>(String path, {dynamic data, Options? options}) {
    return _dio.patch<T>(path, data: data, options: options);
  }

  Future<Response<T>> delete<T>(String path, {dynamic data, Options? options}) {
    return _dio.delete<T>(path, data: data, options: options);
  }
}
