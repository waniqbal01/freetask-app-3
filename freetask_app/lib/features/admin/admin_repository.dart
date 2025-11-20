import 'package:dio/dio.dart';

import '../../core/utils/error_utils.dart';
import '../../services/http_client.dart';
import '../../services/token_storage.dart';
import '../auth/auth_repository.dart';
import 'admin_job_model.dart';
import 'overview_stats_model.dart';
import 'report_model.dart';
import 'trend_metrics.dart';

class AdminRepository {
  AdminRepository({TokenStorage? tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio;

  final TokenStorage _tokenStorage;
  final Dio _dio;

  Future<OverviewStats> getOverview() {
    return _guardRequest(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/overview',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <String, dynamic>{};
      return OverviewStats.fromJson(data);
    });
  }

  Future<List<AdminJob>> getDisputedJobs() {
    return _guardRequest(() async {
      final response = await _dio.get<List<dynamic>>(
        '/admin/jobs/disputes',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AdminJob.fromJson)
          .toList(growable: false);
    });
  }

  Future<void> resolveDispute(int jobId, String status) {
    return _guardRequest(() async {
      await _dio.patch<void>(
        '/admin/jobs/$jobId/resolve',
        data: <String, dynamic>{'status': status},
        options: await _authorizedOptions(),
      );
    });
  }

  Future<List<AdminReport>> getOpenReports() {
    return _guardRequest(() async {
      final response = await _dio.get<List<dynamic>>(
        '/admin/reports',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AdminReport.fromJson)
          .toList(growable: false);
    });
  }

  Future<void> updateReportStatus(int reportId, String status) {
    return _guardRequest(() async {
      await _dio.patch<void>(
        '/admin/reports/$reportId/status',
        data: <String, dynamic>{'status': status},
        options: await _authorizedOptions(),
      );
    });
  }

  Future<void> deactivateService(int serviceId) {
    return _guardRequest(() async {
      await _dio.patch<void>(
        '/admin/services/$serviceId/deactivate',
        options: await _authorizedOptions(),
      );
    });
  }

  Future<void> disableUser(int userId) {
    return _guardRequest(() async {
      await _dio.patch<void>(
        '/admin/users/$userId/disable',
        options: await _authorizedOptions(),
      );
    });
  }

  Future<TrendMetrics> get7DayMetrics() {
    return _guardRequest(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/metrics/7d',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <String, dynamic>{};
      return TrendMetrics.fromJson(data);
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

final adminRepository = AdminRepository();
