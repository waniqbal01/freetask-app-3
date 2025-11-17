import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/notifications/notification_service.dart';
import '../../models/job.dart';
import '../../services/http_client.dart';
import '../auth/auth_repository.dart';

class JobsRepository {
  JobsRepository({FlutterSecureStorage? secureStorage, Dio? dio})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _dio = dio ?? HttpClient().dio;

  final FlutterSecureStorage _secureStorage;
  final Dio _dio;

  Future<Job> createOrder(
    String serviceId,
    double amount,
    String description,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/jobs',
        data: <String, dynamic>{
          'serviceId': serviceId,
          'amount': amount,
          'description': description,
        },
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <String, dynamic>{};
      final job = Job.fromJson(data);
      return job;
    } on DioException catch (error) {
      await _handleDioError(error);
      rethrow;
    }
  }

  Future<bool> startJob(String jobId) async {
    try {
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
    } on DioException catch (error) {
      await _handleDioError(error);
      if (error.response?.statusCode == 409) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> rejectJob(String jobId) async {
    try {
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
    } on DioException catch (error) {
      await _handleDioError(error);
      if (error.response?.statusCode == 409) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> markCompleted(String jobId) async {
    try {
      await _dio.patch<void>(
        '/jobs/$jobId/complete',
        options: await _authorizedOptions(),
      );
      return true;
    } on DioException catch (error) {
      await _handleDioError(error);
      if (error.response?.statusCode == 409) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> setDispute(String jobId, String reason) async {
    try {
      await _dio.patch<void>(
        '/jobs/$jobId/dispute',
        data: <String, dynamic>{'reason': reason},
        options: await _authorizedOptions(),
      );
      return true;
    } on DioException catch (error) {
      await _handleDioError(error);
      rethrow;
    }
  }

  Future<List<Job>> getClientJobs() async {
    return _fetchJobs(<String, dynamic>{'filter': 'client'});
  }

  Future<List<Job>> getFreelancerJobs() async {
    return _fetchJobs(<String, dynamic>{'filter': 'freelancer'});
  }

  Future<List<Job>> getAllJobs() async {
    return _fetchJobs(<String, dynamic>{'filter': 'all'});
  }

  Future<Job?> getJobById(String jobId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/jobs/$jobId',
        options: await _authorizedOptions(),
      );
      final data = response.data;
      if (data == null) {
        return null;
      }
      return Job.fromJson(data);
    } on DioException catch (error) {
      await _handleDioError(error);
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<Job>> _fetchJobs(Map<String, dynamic> queryParameters) async {
    try {
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
    } on DioException catch (error) {
      await _handleDioError(error);
      rethrow;
    }
  }

  Future<Options> _authorizedOptions() async {
    final token = await _secureStorage.read(key: AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      throw StateError('Token tidak ditemui. Sila log masuk semula.');
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  Future<void> _handleDioError(DioException error) async {
    if (error.response?.statusCode == 401) {
      await authRepository.logout();
    }
  }
}

final jobsRepository = JobsRepository();
