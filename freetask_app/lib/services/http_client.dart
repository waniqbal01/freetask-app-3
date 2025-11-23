import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/base_url_store.dart';
import '../core/env.dart';
import '../core/router.dart';
import '../core/notifications/notification_service.dart';
import '../features/auth/auth_repository.dart';

class HttpClient {
  factory HttpClient({FlutterSecureStorage? secureStorage}) {
    _instance ??= HttpClient._(secureStorage: secureStorage);
    return _instance!;
  }

  HttpClient._({FlutterSecureStorage? secureStorage})
      : _storage = secureStorage ?? const FlutterSecureStorage(),
        _baseUrlStore = BaseUrlStore(secureStorage: secureStorage),
        dio = Dio(
          BaseOptions(
            baseUrl: Env.defaultApiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        ) {
    _baseUrlFuture = _baseUrlStore.readBaseUrl();
    _baseUrlFuture.then((base) => dio.options.baseUrl = base);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final resolvedBase = await _baseUrlFuture;
          options.baseUrl = resolvedBase;

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

  Future<void> updateBaseUrl(String value) async {
    await _baseUrlStore.saveBaseUrl(value);
    _baseUrlFuture = _baseUrlStore.readBaseUrl();
    dio.options.baseUrl = await _baseUrlFuture;
  }

  Future<String> currentBaseUrl() async {
    return await _baseUrlFuture;
  }

  Future<void> _clearStoredTokens() async {
    await _storage.delete(key: AuthRepository.tokenStorageKey);
    await _storage.delete(key: AuthRepository.legacyTokenStorageKey);
  }

  Future<void> _handleMissingToken() async {
    notificationService.messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Sesi tamat. Sila log masuk semula.')),
    );
    await _clearStoredTokens();
    authRefreshNotifier.value = DateTime.now();
    appRouter.go('/login');
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

  static HttpClient? _instance;
  late Future<String> _baseUrlFuture;
  final BaseUrlStore _baseUrlStore;
  final FlutterSecureStorage _storage;
  final Dio dio;
}
