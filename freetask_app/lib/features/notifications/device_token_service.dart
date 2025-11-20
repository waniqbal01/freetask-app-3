import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/device_token/device_token_provider.dart';
import '../../core/utils/error_utils.dart';
import '../../services/http_client.dart';
import '../../services/token_storage.dart';
import '../auth/auth_repository.dart';

class DeviceTokenService {
  DeviceTokenService({
    TokenStorage? tokenStorage,
    Dio? dio,
    DeviceTokenProvider? deviceTokenProvider,
  })  : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio,
        _deviceTokenProvider = deviceTokenProvider ??
            const DummyDeviceTokenProvider();

  final TokenStorage _tokenStorage;
  final Dio _dio;
  final DeviceTokenProvider _deviceTokenProvider;

  Future<void> syncDeviceToken() async {
    try {
      final token = await _deviceTokenProvider.getDeviceToken();
      await registerDeviceToken(token);
    } catch (error, stackTrace) {
      debugPrint('Skipping device token sync: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> registerDeviceToken(String? token) async {
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final savedToken = await _tokenStorage.read(AuthRepository.tokenStorageKey);
      if (savedToken == null || savedToken.isEmpty) return;

      await _dio.patch<void>(
        '/users/me/device-token',
        data: <String, dynamic>{'deviceToken': token},
        options: Options(headers: <String, String>{'Authorization': 'Bearer $savedToken'}),
      );
    } on DioException catch (error) {
      final mapped = mapDioError(error);
      debugPrint('Failed to register device token: ${mapped.message}');
    }
  }
}

final deviceTokenService = DeviceTokenService();
