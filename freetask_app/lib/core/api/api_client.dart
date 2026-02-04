import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../storage/storage.dart';
import '../../features/auth/auth_repository.dart';

import '../../env.dart';

class ApiClient {
  late final Dio dio;
  String _baseUrl = Env.defaultApiBaseUrl;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ));

    // Add interceptor to include auth token
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await appStorage.read(AuthRepository.tokenStorageKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Update base URL from storage if available (ONLY IN DEBUG MODE)
        if (!kReleaseMode) {
          final apiUrl = await appStorage.read('api_url');
          if (apiUrl != null && apiUrl.isNotEmpty) {
            _baseUrl = apiUrl;
            options.baseUrl = apiUrl;
          }
        }

        return handler.next(options);
      },
    ));
  }

  String get baseUrl => _baseUrl;
}
