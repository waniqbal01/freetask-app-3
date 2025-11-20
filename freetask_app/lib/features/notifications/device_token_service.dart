import 'package:dio/dio.dart';

import '../../core/utils/error_utils.dart';
import '../../services/http_client.dart';
import '../../services/token_storage.dart';
import '../auth/auth_repository.dart';

class DeviceTokenService {
  DeviceTokenService({TokenStorage? tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio;

  final TokenStorage _tokenStorage;
  final Dio _dio;

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
      throw mapDioError(error);
    }
  }
}

final deviceTokenService = DeviceTokenService();
