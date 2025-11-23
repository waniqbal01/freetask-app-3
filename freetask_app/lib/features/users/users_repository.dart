import 'package:dio/dio.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/router.dart';
import '../../core/utils/api_error_handler.dart';
import '../../core/storage/storage.dart';
import '../../services/http_client.dart';
import '../auth/auth_repository.dart';

class UsersRepository {
  UsersRepository({Dio? dio})
      : _dio = dio ?? HttpClient().dio,
        _storage = appStorage;

  final Dio _dio;
  final AppStorage _storage;

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? bio,
    List<String>? skills,
    num? rate,
  }) async {
    final payload = <String, dynamic>{};

    void addIfPresent(String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is Iterable && value.isEmpty) return;
      payload[key] = value;
    }

    addIfPresent('name', name);
    addIfPresent('avatarUrl', avatarUrl);
    addIfPresent('bio', bio);
    addIfPresent('skills', skills);
    addIfPresent('rate', rate);

    if (payload.isEmpty) {
      return;
    }

    final token = await _storage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      notificationService.messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Sesi tamat. Sila log masuk semula.')),
      );
      await authRepository.logout();
      authRefreshNotifier.value = DateTime.now();
      appRouter.go('/login');
      throw StateError('Sesi tamat');
    }

    try {
      await _dio.patch<void>(
        '/users/me',
        data: payload,
      );
    } on DioException catch (error) {
      await handleApiError(error);
      rethrow;
    }
  }
}

final usersRepository = UsersRepository();
