import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_utils.dart';
import '../../services/http_client.dart';
import '../../services/token_storage.dart';
import '../auth/auth_repository.dart';
import 'app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((Ref ref) {
  return NotificationRepository();
});

class NotificationRepository {
  NotificationRepository({TokenStorage? tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio;

  final TokenStorage _tokenStorage;
  final Dio _dio;

  Future<List<AppNotification>> fetchNotifications() async {
    return _guardRequest(() async {
      final response = await _dio.get<List<dynamic>>(
        '/notifications',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(growable: false);
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _guardRequest(() async {
      await _dio.patch<void>(
        '/notifications/$notificationId/read',
        options: await _authorizedOptions(),
      );
    });
  }

  Future<Options> _authorizedOptions() async {
    final token = await _tokenStorage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      throw const AppException(
        'Token tidak ditemui. Sila log masuk semula.',
        type: AppErrorType.unauthorized,
      );
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
