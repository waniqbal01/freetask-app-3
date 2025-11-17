import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/service.dart';
import '../../services/http_client.dart';
import '../auth/auth_repository.dart';

class ServicesRepository {
  ServicesRepository({FlutterSecureStorage? secureStorage, Dio? dio})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _dio = dio ?? HttpClient().dio;

  final FlutterSecureStorage _secureStorage;
  final Dio _dio;

  Future<List<Service>> getServices({String? query, String? category}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/services',
        queryParameters: <String, dynamic>{
          if (query != null && query.isNotEmpty) 'q': query,
          if (category != null && category.isNotEmpty && category != 'Semua')
            'category': category,
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

  Future<Service?> getServiceById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/services/$id',
        options: await _authorizedOptions(requireAuth: false),
      );
      final data = response.data;
      if (data == null) {
        return null;
      }
      return Service.fromJson(data);
    } on DioException catch (error) {
      await _handleDioError(error);
      if (error.response?.statusCode == 404) {
        return null;
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
    final token = await _secureStorage.read(key: AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      if (requireAuth) {
        throw StateError('Token tidak ditemui. Sila log masuk semula.');
      }
      return Options();
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  Future<void> _handleDioError(DioException error) async {
    if (error.response?.statusCode == 401) {
      await authRepository.logout();
    }
  }
}

final servicesRepository = ServicesRepository();
