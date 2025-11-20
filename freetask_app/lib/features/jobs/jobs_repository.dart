import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/job.dart';
import '../../models/job_history.dart';
import '../../services/http_client.dart';
import '../../services/token_storage.dart';
import '../auth/auth_repository.dart';

class JobsRepository {
  JobsRepository({TokenStorage? tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio;

  final TokenStorage _tokenStorage;
  final Dio _dio;

  Future<Job> createOrder(
    String serviceId,
    double? amount,
    String description, {
    String? title,
  }) {
    return _guardRequest(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/jobs',
        data: <String, dynamic>{
          'serviceId': int.tryParse(serviceId) ?? serviceId,
          if (title != null && title.isNotEmpty) 'title': title,
          if (amount != null) 'amount': amount,
          'description': description,
        },
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <String, dynamic>{};
      return Job.fromJson(data);
    });
  }

  Future<bool> startJob(String jobId) async {
    try {
      await _guardRequest(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          '/jobs/$jobId/start',
          options: await _authorizedOptions(),
        );
        final data = response.data;
        if (data != null) {
          final job = Job.fromJson(data);
          notificationService.pushLocal(
            'Job Dimulakan',
            'Job ${job.serviceTitle} kini In Progress.',
          );
        }
        return true;
      });
      return true;
    } on AppException catch (error) {
      if (error.statusCode == 409) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> rejectJob(String jobId) async {
    try {
      await _guardRequest(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          '/jobs/$jobId/reject',
          options: await _authorizedOptions(),
        );
        final data = response.data;
        if (data != null) {
          final job = Job.fromJson(data);
          notificationService.pushLocal(
            'Job Ditolak',
            'Job ${job.serviceTitle} telah ditolak oleh freelancer.',
          );
        }
        return true;
      });
      return true;
    } on AppException catch (error) {
      if (error.statusCode == 409) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> markCompleted(String jobId) async {
    try {
      await _guardRequest(() async {
        await _dio.patch<void>(
          '/jobs/$jobId/complete',
          options: await _authorizedOptions(),
        );
        return true;
      });
      return true;
    } on AppException catch (error) {
      if (error.statusCode == 409) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> setDispute(String jobId, String reason) {
    return _guardRequest(() async {
      await _dio.patch<void>(
        '/jobs/$jobId/dispute',
        data: <String, dynamic>{'reason': reason},
        options: await _authorizedOptions(),
      );
      return true;
    });
  }

  Future<List<Job>> getClientJobs() {
    return _fetchJobs(<String, dynamic>{'filter': 'client'});
  }

  Future<List<Job>> getFreelancerJobs() {
    return _fetchJobs(<String, dynamic>{'filter': 'freelancer'});
  }

  Future<List<Job>> getAllJobs() {
    return _fetchJobs(<String, dynamic>{'filter': 'all'});
  }

  Future<Job?> getJobById(String jobId) async {
    try {
      return await _guardRequest(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/jobs/$jobId',
          options: await _authorizedOptions(),
        );
        final data = response.data;
        if (data == null) {
          return null;
        }
        return Job.fromJson(data);
      });
    } on AppException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<Job>> _fetchJobs(Map<String, dynamic> queryParameters) {
    return _guardRequest(() async {
      final response = await _dio.get<List<dynamic>>(
        '/jobs',
        queryParameters: queryParameters,
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Job.fromJson)
          .toList(growable: false);
    });
  }

  Future<List<JobHistory>> getJobHistory(String jobId) {
    return _guardRequest(() async {
      final response = await _dio.get<List<dynamic>>(
        '/jobs/$jobId/history',
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(JobHistory.fromJson)
          .toList(growable: false);
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

final jobsRepository = JobsRepository();
