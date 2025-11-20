import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/env.dart';
import '../core/router.dart';
import 'token_storage.dart';

class HttpClient {
  HttpClient({TokenStorage? tokenStorage})
      : _storage = tokenStorage ?? createTokenStorage(),
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
          final token = await _storage.read(_authTokenKey) ??
              await _storage.read(_legacyAccessTokenKey);
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
          if (error.response?.statusCode == 401 && !isPublicServicesGet) {
            await _handleUnauthorized();
          }
          handler.next(error);
        },
      ),
    );
  }

  static bool _handlingUnauthorized = false;

  Future<void> _handleUnauthorized() async {
    if (_handlingUnauthorized) {
      return;
    }
    _handlingUnauthorized = true;
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi anda telah tamat. Sila log masuk semula.')),
      );
    }
    await _clearStoredTokens();
    appRouter.go('/login');
    _handlingUnauthorized = false;
  }

  Future<void> _clearStoredTokens() async {
    await _storage.delete(_authTokenKey);
    await _storage.delete(_legacyAccessTokenKey);
  }

  static const String _authTokenKey = 'auth_token';
  static const String _legacyAccessTokenKey = 'access_token';

  final TokenStorage _storage;
  final Dio dio;
}
