import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/service.dart';
import '../../services/http_client.dart';
import '../auth/auth_repository.dart';
import '../../core/storage/storage.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/router.dart';
import '../../core/utils/api_error_handler.dart';

class ServicesRepository {
  ServicesRepository({AppStorage? storage, Dio? dio})
      : _storage = storage ?? appStorage,
        _dio = dio ?? HttpClient().dio;

  final AppStorage _storage;
  final Dio _dio;

  Future<List<Service>> getServices({String? q, String? category}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/services',
        queryParameters: <String, dynamic>{
          if (q != null && q.isNotEmpty) 'q': q,
          if (category != null && category.isNotEmpty) 'category': category,
        },
        options: await _authorizedOptions(requireAuth: false),
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Service.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      await _handleDioError(error);
      rethrow;
    }
  }

  Future<Service> getServiceById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/services/$id',
        options: await _authorizedOptions(requireAuth: false),
      );
      final data = response.data;
      if (data == null) {
        throw StateError('Servis tidak ditemui.');
      }
      return Service.fromJson(data);
    } on DioException catch (error) {
      await _handleDioError(error);
      if (error.response?.statusCode == 404) {
        throw StateError('Servis tidak ditemui.');
      }
      rethrow;
    }
  }

  Future<List<String>> getCategories() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/services/categories',
        options: await _authorizedOptions(requireAuth: false),
      );
      final categories = response.data ?? <dynamic>[];
      return categories
          .map((dynamic value) => value.toString())
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      await _handleDioError(error);
      rethrow;
    }
  }

  Future<Options> _authorizedOptions({bool requireAuth = true}) async {
    final token = await _storage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      if (requireAuth) {
        notificationService.messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Sesi tamat. Sila log masuk semula.')),
        );
        await authRepository.logout();
        authRefreshNotifier.value = DateTime.now();
        appRouter.go('/login');
        throw StateError('Token tidak ditemui. Sila log masuk semula.');
      }
      return Options();
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  Future<void> createService({
    required String title,
    required String description,
    required double price,
    required String category,
    String? thumbnailUrl,
  }) async {
    try {
      await _dio.post<void>(
        '/services',
        data: {
          'title': title,
          'description': description,
          'price': price,
          'category': category,
          'thumbnailUrl': thumbnailUrl,
        },
        options: await _authorizedOptions(),
      );
    } on DioException catch (error) {
      await _handleDioError(error);
      rethrow;
    }
  }

  Future<String> uploadServiceImage(dynamic file) async {
    // Determine if file is File (mobile) or something else (web not supported yet fully)
    // For now assuming dart:io File

    // Import dart:io is needed in repository or use a cross-platform solution
    // But since CreateServiceScreen passes File, we need to handle it.
    // However, repository shouldn't depend on dart:io directly if we want web support later.
    // But for now sticking to mobile.

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/uploads',
        data: formData,
        options: await _authorizedOptions(),
      );

      final data = response.data;
      if (data != null && data['url'] != null) {
        return data['url'] as String;
      }
      throw StateError('Upload failed: No URL returned');
    } on DioException catch (error) {
      await _handleDioError(error);
      rethrow;
    }
  }

  Future<void> _handleDioError(DioException error) async {
    await handleApiError(error);
  }
}

final servicesRepository = ServicesRepository();
