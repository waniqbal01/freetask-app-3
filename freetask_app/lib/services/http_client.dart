import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/env.dart';
import '../core/router.dart';
import '../core/notifications/notification_service.dart';
import '../features/auth/auth_repository.dart';

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
          final isPublicServicesGet =
              options.method.toUpperCase() == 'GET' && options.path.startsWith('/services');
          final token = await _readTokenWithMigration();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else if (isPublicServicesGet) {
            // Allow unauthenticated access to public services endpoints.
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final isPublicServicesGet = error.requestOptions.method.toUpperCase() == 'GET' &&
              error.requestOptions.path.startsWith('/services');
          final hadAuthHeader =
              error.requestOptions.headers['Authorization']?.toString().isNotEmpty ?? false;
          final status = error.response?.statusCode ?? 0;
          if ((status == 401 || status == 403 || status == 419) && !isPublicServicesGet && hadAuthHeader) {
            notificationService.messengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(status == 403
                    ? 'Anda tidak dibenarkan untuk tindakan ini.'
                    : 'Session expired, please login again.'),
                duration: const Duration(seconds: 3),
              ),
            );
            await _clearStoredTokens();
            authRefreshNotifier.value = DateTime.now();
            appRouter.go('/login');
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<void> _clearStoredTokens() async {
    await _storage.delete(key: AuthRepository.tokenStorageKey);
    await _storage.delete(key: AuthRepository.legacyTokenStorageKey);
  }

  Future<String?> _readTokenWithMigration() async {
    final token = await _storage.read(key: AuthRepository.tokenStorageKey);
    if (token != null && token.isNotEmpty) {
      return token;
    }

    final legacy = await _storage.read(key: AuthRepository.legacyTokenStorageKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(key: AuthRepository.tokenStorageKey, value: legacy);
      await _storage.delete(key: AuthRepository.legacyTokenStorageKey);
      return legacy;
    }

    return token;
  }

  final FlutterSecureStorage _storage;
  final Dio dio;
}
