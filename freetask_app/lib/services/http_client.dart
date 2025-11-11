import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/env.dart';
import '../core/router.dart';

class HttpClient {
  HttpClient({FlutterSecureStorage? secureStorage})
      : _storage = secureStorage ?? const FlutterSecureStorage(),
        dio = Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final token = await _storage.read(key: _authTokenKey) ??
              await _storage.read(key: _legacyAccessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 401) {
            await _clearStoredTokens();
            appRouter.go('/login');
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<void> _clearStoredTokens() async {
    await _storage.delete(key: _authTokenKey);
    await _storage.delete(key: _legacyAccessTokenKey);
  }

  static const String _authTokenKey = 'auth_token';
  static const String _legacyAccessTokenKey = 'access_token';

  final FlutterSecureStorage _storage;
  final Dio dio;
}
