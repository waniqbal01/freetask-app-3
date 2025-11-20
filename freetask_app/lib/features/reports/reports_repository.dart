import 'package:dio/dio.dart';

import '../../core/utils/error_utils.dart';
import '../../services/http_client.dart';
import '../../services/token_storage.dart';
import '../auth/auth_repository.dart';

class ReportsRepository {
  ReportsRepository({TokenStorage? tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio;

  final TokenStorage _tokenStorage;
  final Dio _dio;

  Future<void> createReport({int? reportedUserId, int? reportedServiceId, required String reason}) {
    return _guardRequest(() async {
      final payload = <String, dynamic>{
        if (reportedUserId != null) 'reportedUserId': reportedUserId,
        if (reportedServiceId != null) 'reportedServiceId': reportedServiceId,
        'reason': reason,
      };
      await _dio.post<void>(
        '/reports',
        data: payload,
        options: await _authorizedOptions(),
      );
    });
  }

  Future<Options> _authorizedOptions() async {
    final token = await _tokenStorage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      throw const AppException('Sila log masuk untuk menghantar laporan.');
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  Future<T> _guardRequest<T>(Future<T> Function() runner) async {
    try {
      return await runner();
    } on DioException catch (error) {
      final mapped = mapDioError(error);
      if (mapped.isUnauthorized) {
        await authRepository.logout();
      }
      throw mapped;
    }
  }
}

final reportsRepository = ReportsRepository();
