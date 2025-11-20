import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/utils/error_utils.dart';
import '../../models/service.dart';
import '../../services/http_client.dart';
import '../../services/token_storage.dart';
import '../auth/auth_repository.dart';

class ServicesRepository {
  ServicesRepository({TokenStorage? tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio;

  final TokenStorage _tokenStorage;
  final Dio _dio;

  Future<List<Service>> getServices({
    String? q,
    String? category,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? maxDeliveryDays,
  }) async {
    return _guardRequest(() async {
      final response = await _dio.get<List<dynamic>>(
        '/services',
        queryParameters: <String, dynamic>{
          if (q != null && q.isNotEmpty) 'q': q,
          if (category != null && category.isNotEmpty && category != 'Semua')
            'category': category,
          if (minPrice != null) 'minPrice': minPrice,
          if (maxPrice != null) 'maxPrice': maxPrice,
          if (minRating != null) 'minRating': minRating,
          if (maxDeliveryDays != null) 'maxDeliveryDays': maxDeliveryDays,
        },
        options: await _authorizedOptions(requireAuth: false),
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Service.fromJson)
          .toList(growable: false);
    });
  }

  Future<Service> getServiceById(String id) async {
    return _guardRequest(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/services/$id',
        options: await _authorizedOptions(requireAuth: false),
      );
      final data = response.data;
      if (data == null) {
        throw const AppException('Servis tidak ditemui.', type: AppErrorType.notFound);
      }
      return Service.fromJson(data);
    });
  }

  Future<List<String>> getCategories() async {
    return _guardRequest(() async {
      final response = await _dio.get<List<dynamic>>(
        '/services/categories',
        options: await _authorizedOptions(requireAuth: false),
      );
      final categories = response.data ?? <dynamic>[];
      return categories
          .map((dynamic value) => value.toString())
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
    });
  }

  Future<List<Service>> fetchMyServices() {
    return _guardRequest(() async {
      final response = await _dio.get<List<dynamic>>(
        '/services/mine',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Service.fromJson)
          .toList(growable: false);
    });
  }

  Future<Service> createService(ServiceRequestPayload payload) {
    return _mutateService(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/services',
        data: payload.toJson(),
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <String, dynamic>{};
      return Service.fromJson(data);
    });
  }

  Future<Service> updateService(String id, ServiceRequestPayload payload) {
    return _mutateService(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/services/$id',
        data: payload.toJson(),
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <String, dynamic>{};
      return Service.fromJson(data);
    });
  }

  Future<void> deleteService(String id) {
    return _mutateService(() async {
      await _dio.delete<void>(
        '/services/$id',
        options: await _authorizedOptions(),
      );
      return null;
    });
  }

  Future<Options> _authorizedOptions({bool requireAuth = true}) async {
    final token = await _tokenStorage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      if (requireAuth) {
        throw const AppException(
          'Token tidak ditemui. Sila log masuk semula.',
          type: AppErrorType.unauthorized,
        );
      }
      return Options();
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

  Future<T> _mutateService<T>(Future<T> Function() runner) {
    return _guardRequest(runner);
  }
}

final servicesRepository = ServicesRepository();

class ServiceRequestPayload {
  const ServiceRequestPayload({
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    this.deliveryDays,
  });

  final String title;
  final String description;
  final double price;
  final String category;
  final int? deliveryDays;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      if (deliveryDays != null) 'deliveryDays': deliveryDays,
    };
  }
}
