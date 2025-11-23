import 'dart:async';

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
        ),
        _refreshDio = Dio(
          BaseOptions(
            baseUrl: Env.defaultApiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        ) {
    _baseUrlFuture = _baseUrlStore.readBaseUrl();
    _baseUrlFuture.then((base) {
      dio.options.baseUrl = base;
      _refreshDio.options.baseUrl = base;
    });

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final resolvedBase = await _baseUrlFuture;
          options.baseUrl = resolvedBase;
          options.extra['__baseUrl'] = resolvedBase;

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

          if (status == 401) {
            if (await _shouldAttemptRefresh(error.requestOptions)) {
              final refreshed = await _refreshAccessToken();
              if (refreshed) {
                try {
                  final stableBaseUrl =
                      error.requestOptions.extra['__baseUrl']?.toString() ?? error.requestOptions.baseUrl;
                  final retryOptions = error.requestOptions
                    ..headers['Authorization'] =
                        'Bearer ${await _storage.read(AuthRepository.tokenStorageKey)}'
                    ..extra['__retriedAfterRefresh'] = true
                    ..baseUrl = stableBaseUrl;

                  final retryResponse = await dio.fetch<dynamic>(retryOptions);
                  return handler.resolve(retryResponse);
                } on DioException catch (retryError) {
                  return handler.next(retryError);
                }
              }
            }

            if (!_isAuthEndpoint(error.requestOptions)) {
              await _handleSessionExpired();
            }
          } else if (status == 403) {
            _showForbiddenMessage();
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
    _refreshDio.options.baseUrl = dio.options.baseUrl;
  }

  Future<String> currentBaseUrl() async {
    return await _baseUrlFuture;
  }

  Future<void> _clearStoredTokens() async {
    _sessionHandled = false;
    await _storage.delete(AuthRepository.tokenStorageKey);
    await _storage.delete(AuthRepository.legacyTokenStorageKey);
    await _storage.delete(AuthRepository.refreshTokenStorageKey);
  }

  Future<void> _handleSessionExpired() async {
    if (_sessionHandled) {
      return;
    }
    _sessionHandled = true;
    notificationService.messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Sesi tamat. Sila log masuk semula.')),
    );
    await _clearStoredTokens();
    authRefreshNotifier.value = DateTime.now();
    final currentLocation = appRouter.location;
    if (currentLocation != '/login') {
      appRouter.go('/login');
    }
  }

  void _showForbiddenMessage() {
    notificationService.messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Anda tidak dibenarkan untuk tindakan ini.')),
    );
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

  bool _isAuthEndpoint(RequestOptions options) {
    return options.path.startsWith('/auth/login') ||
        options.path.startsWith('/auth/register') ||
        options.path.startsWith('/auth/refresh');
  }

  Future<bool> _shouldAttemptRefresh(RequestOptions requestOptions) async {
    if (requestOptions.extra['__retriedAfterRefresh'] == true) {
      return false;
    }
    if (_isAuthEndpoint(requestOptions) || _isPublicRequest(requestOptions)) {
      return false;
    }
    final refreshToken = await _storage.read(AuthRepository.refreshTokenStorageKey);
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshing != null) {
      if (kDebugMode) {
        debugPrint('Reusing in-flight refresh token request');
      }
      return _refreshing!;
    }

    final refreshToken = await _storage.read(AuthRepository.refreshTokenStorageKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final completer = Completer<bool>();
    _refreshing = completer.future;
    try {
      final refreshBase = await _baseUrlFuture;
      _refreshDio.options.baseUrl = refreshBase;
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
      );

      final data = response.data;
      final newAccess = data?['accessToken']?.toString();
      final newRefresh = data?['refreshToken']?.toString();
      if (newAccess == null || newAccess.isEmpty || newRefresh == null || newRefresh.isEmpty) {
        completer.complete(false);
        return completer.future;
      }

      await _storage.write(AuthRepository.tokenStorageKey, newAccess);
      await _storage.write(AuthRepository.refreshTokenStorageKey, newRefresh);
      _sessionHandled = false;
      authRefreshNotifier.value = DateTime.now();
      completer.complete(true);
    } catch (_) {
      completer.complete(false);
    } finally {
      _refreshing = null;
    }

    return completer.future;
  }

  static HttpClient? _instance;
  late Future<String> _baseUrlFuture;
  final BaseUrlStore _baseUrlStore;
  final AppStorage _storage;
  final Dio dio;
  final Dio _refreshDio;
  Future<bool>? _refreshing;
  bool _sessionHandled = false;
}
