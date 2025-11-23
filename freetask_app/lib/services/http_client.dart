import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/base_url_store.dart';
import '../core/env.dart';
import '../core/router.dart';
import '../core/notifications/notification_service.dart';
import '../features/auth/auth_repository.dart';
import '../core/storage/storage.dart';

class HttpClient {
  factory HttpClient({AppStorage? storage}) {
    _instance ??= HttpClient._(storage: storage);
    return _instance!;
  }

  HttpClient._({AppStorage? storage})
      : _storage = storage ?? appStorage,
        _baseUrlStore = BaseUrlStore(storage: storage),
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

          final isPublicServicesGet = _isPublicRequest(options);
          final token = await _readTokenWithMigration();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else if (isPublicServicesGet) {
            // Allow unauthenticated access to public services endpoints.
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final status = error.response?.statusCode ?? 0;
          final isPublicRequest = _isPublicRequest(error.requestOptions);
          final hadAuthHeader =
              error.requestOptions.headers['Authorization']?.toString().isNotEmpty ?? false;
          final alreadyRetried = error.requestOptions.extra['__retried'] == true;
          final isAuthRelevant = !isPublicRequest && (hadAuthHeader || !_isNetworkFailure(error));

          if ((status == 401 || status == 403 || status == 419) && isAuthRelevant) {
            if (!alreadyRetried) {
              try {
                await Future<void>.delayed(const Duration(milliseconds: 450));
                final retryResponse = await dio.fetch<dynamic>(
                  error.requestOptions..extra['__retried'] = true,
                );
                return handler.resolve(retryResponse);
              } on DioException catch (retryError) {
                final retryStatus = retryError.response?.statusCode ?? status;
                if (retryStatus == 401 || retryStatus == 403 || retryStatus == 419) {
                  await _handleAuthFailure(retryStatus);
                  return handler.next(retryError);
                }
                return handler.next(retryError);
              } catch (_) {
                await _handleAuthFailure(status);
                return handler.next(error);
              }
            }

            await _handleAuthFailure(status);
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
    await _storage.delete(AuthRepository.tokenStorageKey);
    await _storage.delete(AuthRepository.legacyTokenStorageKey);
  }

  Future<void> _handleMissingToken() async {
    notificationService.messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Sesi tamat. Sila log masuk semula.')),
    );
    await _clearStoredTokens();
    authRefreshNotifier.value = DateTime.now();
    appRouter.go('/login');
  }

  Future<void> _handleAuthFailure(int status) async {
    notificationService.messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(status == 403
            ? 'Anda tidak dibenarkan untuk tindakan ini.'
            : 'Sesi tamat, sila log masuk semula.'),
        duration: const Duration(seconds: 3),
      ),
    );
    await _clearStoredTokens();
    authRefreshNotifier.value = DateTime.now();
    if (!kIsWeb || appRouter.canPop()) {
      appRouter.go('/login');
    }
  }

  Future<String?> _readTokenWithMigration() async {
    final token = await _storage.read(AuthRepository.tokenStorageKey);
    if (token != null && token.isNotEmpty) {
      return token;
    }

    final legacy = await _storage.read(AuthRepository.legacyTokenStorageKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(AuthRepository.tokenStorageKey, legacy);
      await _storage.delete(AuthRepository.legacyTokenStorageKey);
      return legacy;
    }

    return token;
  }

  bool _isPublicRequest(RequestOptions options) {
    return options.method.toUpperCase() == 'GET' && options.path.startsWith('/services');
  }

  bool _isNetworkFailure(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  static HttpClient? _instance;
  late Future<String> _baseUrlFuture;
  final BaseUrlStore _baseUrlStore;
  final AppStorage _storage;
  final Dio dio;
}
