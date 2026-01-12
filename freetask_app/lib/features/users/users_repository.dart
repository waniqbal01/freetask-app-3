import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

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
    String? phoneNumber,
    String? location,
    bool? isAvailable,
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
    addIfPresent('phoneNumber', phoneNumber);
    addIfPresent('location', location);
    if (isAvailable != null) payload['isAvailable'] = isAvailable;

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

  Future<Map<String, dynamic>> getPublicProfile(String userId) async {
    // Basic validation to prevent unnecessary calls
    if (userId.isEmpty || userId == 'null') {
      throw ArgumentError('Invalid user ID');
    }

    try {
      // Use _authorizedOptions(requireAuth: false) if we want public access without login
      // But typically we do want them logged in to see details
      final token = await _storage.read(AuthRepository.tokenStorageKey);
      final options = token != null && token.isNotEmpty
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null;

      final response = await _dio.get<Map<String, dynamic>>(
        '/users/$userId',
        options: options,
      );

      final data = response.data;
      if (data == null) {
        throw StateError('Pengguna tidak ditemui');
      }
      return data;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw StateError('Pengguna tidak ditemui');
      }
      await handleApiError(error);
      rethrow;
    }
  }
}

final usersRepository = UsersRepository();
