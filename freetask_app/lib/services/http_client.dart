import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
        _baseUrlManager = BaseUrlManager(storage: storage) {
    dio = _createDio(Env.defaultApiBaseUrl);
    _refreshDio = _createDio(Env.defaultApiBaseUrl);
    _attachInterceptors();
    _baseUrlFuture = _baseUrlManager.getBaseUrl();
    _baseUrlFuture!.then((value) {
      _currentBaseUrl = value;
      _applyBaseUrl(value);
    });
  }

  Future<void> updateBaseUrl(String value) async {
    if (_switchingBaseFuture != null) {
      await _switchingBaseFuture;
    }

    final messenger = notificationService.messengerKey.currentState;
    final banner = messenger?.showSnackBar(
      const SnackBar(
          content: Text('Menukar server… sila tunggu.'),
          duration: Duration(seconds: 2)),
    );

    _cancelInflight();
    final completer = Completer<void>();
    _switchingBaseFuture = completer.future;

    final resolved = await _baseUrlManager.setBaseUrl(value);
    _currentBaseUrl = resolved;
    await _swapClients(resolved);

    completer.complete();
    _switchingBaseFuture = null;
    banner?.close();
  }

  Future<String> currentBaseUrl() async {
    _currentBaseUrl ??= await _baseUrlManager.getBaseUrl();
    return _currentBaseUrl!;
  }

  Future<void> _clearStoredTokens() async {
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
    final currentLocation =
        appRouter.routerDelegate.currentConfiguration.uri.path;
    if (currentLocation != '/login') {
      appRouter.go('/login');
    }
  }

  Future<void> _handleSidMissing() async {
    if (_sessionHandled) {
      return;
    }
    _sessionHandled = true;
    notificationService.messengerKey.currentState?.showSnackBar(
      const SnackBar(
          content: Text('Sesi anda tidak sah. Sila log masuk semula.')),
    );
    await _clearStoredTokens();
    authRefreshNotifier.value = DateTime.now();
    if (appRouter.routerDelegate.currentConfiguration.uri.path != '/login') {
      appRouter.go('/login');
    }
  }

  void _showForbiddenMessage() {
    notificationService.messengerKey.currentState?.showSnackBar(
      const SnackBar(
          content: Text('Anda tidak dibenarkan untuk tindakan ini.')),
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
    return options.method.toUpperCase() == 'GET' &&
        options.path.startsWith('/services');
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
    final refreshToken =
        await _storage.read(AuthRepository.refreshTokenStorageKey);
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshing != null) {
      if (kDebugMode) {
        debugPrint('Reusing in-flight refresh token request');
      }
      return _refreshing!;
    }

    final refreshToken =
        await _storage.read(AuthRepository.refreshTokenStorageKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final completer = Completer<bool>();
    _refreshing = completer.future;
    try {
      final refreshBase = await _baseUrlManager.getBaseUrl();
      _applyBaseUrl(refreshBase, skipSwap: true);
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
      );

      final data = response.data;
      final newAccess = data?['accessToken']?.toString();
      final newRefresh = data?['refreshToken']?.toString();
      if (newAccess == null ||
          newAccess.isEmpty ||
          newRefresh == null ||
          newRefresh.isEmpty) {
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

  void _attachInterceptors() {
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) async {
          if (_switchingBaseFuture != null) {
            await _switchingBaseFuture;
          }
          _trackRequest(options);
          final resolvedBase = await _baseUrlManager.getBaseUrl();
          _currentBaseUrl = resolvedBase;
          options.baseUrl = resolvedBase;
          options.extra['__baseUrl'] = resolvedBase;

          final isPublicServicesGet = _isPublicRequest(options);
          final token = await _readTokenWithMigration();
          if (token != null && token.isNotEmpty && !isPublicServicesGet) {
            _sessionHandled = false;
            options.headers['Authorization'] = 'Bearer $token';
          } else if (isPublicServicesGet &&
              options.headers.containsKey('Authorization')) {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          _clearTrackedToken(response.requestOptions.cancelToken);
          handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          _clearTrackedToken(error.requestOptions.cancelToken);
          var status = error.response?.statusCode ?? 0;
          final isPublicRequest = _isPublicRequest(error.requestOptions);

          if (status == 401) {
            final errorCode = _extractErrorCode(error.response);
            if (errorCode == 'SID_MISSING') {
              await _handleSidMissing();
              return handler.next(error);
            }
            if (isPublicRequest &&
                error.requestOptions.extra['__retriedWithoutAuth'] != true) {
              await _clearStoredTokens();
              final retryOptions = error.requestOptions
                ..headers.remove('Authorization')
                ..extra['__retriedWithoutAuth'] = true
                ..cancelToken = CancelToken();

              try {
                final latestBase = await _baseUrlManager.getBaseUrl();
                retryOptions.baseUrl = latestBase;
                final retryResponse = await dio.fetch<dynamic>(retryOptions);
                return handler.resolve(retryResponse);
              } on DioException catch (retryError) {
                error = retryError;
                status = retryError.response?.statusCode ?? status;
              }
            }

            if (await _shouldAttemptRefresh(error.requestOptions)) {
              final refreshed = await _refreshAccessToken();
              if (refreshed) {
                try {
                  final latestBase = await _baseUrlManager.getBaseUrl();
                  _applyBaseUrl(latestBase, skipSwap: true);
                  final retryOptions = error.requestOptions
                    ..headers['Authorization'] =
                        'Bearer ${await _storage.read(AuthRepository.tokenStorageKey)}'
                    ..extra['__retriedAfterRefresh'] = true
                    ..baseUrl = latestBase
                    ..cancelToken = CancelToken();

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

  Dio _createDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
  }

  void _applyBaseUrl(String baseUrl, {bool skipSwap = false}) {
    _currentBaseUrl = baseUrl;
    dio.options.baseUrl = baseUrl;
    _refreshDio.options.baseUrl = baseUrl;
    if (!skipSwap) {
      _baseUrlFuture = Future.value(baseUrl);
    }
  }

  Future<void> _swapClients(String baseUrl) async {
    _cancelInflight();
    try {
      dio.close(force: true);
      _refreshDio.close(force: true);
    } catch (_) {
      // ignore close errors
    }
    dio = _createDio(baseUrl);
    _refreshDio = _createDio(baseUrl);
    _attachInterceptors();
  }

  void _cancelInflight() {
    for (final token in _inflightTokens.toList()) {
      if (!token.isCancelled) {
        token.cancel('Base URL changed');
      }
    }
    _inflightTokens.clear();
  }

  void _trackRequest(RequestOptions options) {
    final token = options.cancelToken ?? CancelToken();
    options.cancelToken = token;
    _inflightTokens.add(token);
  }

  void _clearTrackedToken(CancelToken? token) {
    if (token == null) return;
    _inflightTokens.removeWhere((tracked) => identical(tracked, token));
  }

  String? _extractErrorCode(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      final code = data['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
    return null;
  }

  static HttpClient? _instance;
  final BaseUrlManager _baseUrlManager;
  Future<String>? _baseUrlFuture;
  final AppStorage _storage;
  late Dio dio;
  late Dio _refreshDio;
  Future<bool>? _refreshing;
  String? _currentBaseUrl;
  bool _sessionHandled = false;
  Future<void>? _switchingBaseFuture;
  final List<CancelToken> _inflightTokens = <CancelToken>[];
}
