import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/utils/api_error_handler.dart';
import '../../core/utils/query_utils.dart';
import '../../core/router.dart';
import '../../core/storage/storage.dart';
import '../../models/job.dart';
import '../../services/http_client.dart';
import '../auth/auth_repository.dart';
import 'job_constants.dart';

class JobsRepository {
  JobsRepository({AppStorage? storage, Dio? dio})
      : _storage = storage ?? appStorage,
        _dio = dio ?? HttpClient().dio;

  final AppStorage _storage;
  final Dio _dio;

  Future<Job> createOrder(
    String serviceId,
    double amount,
    String description,
    {String? serviceTitle},
  ) async {
    try {
      final parsedServiceId = int.tryParse(serviceId.toString());
      if (parsedServiceId == null) {
        throw StateError('ID servis tidak sah.');
      }

      final trimmedDescription = description.trim();
      final normalizedAmount = double.parse(amount.toStringAsFixed(2));

      if (trimmedDescription.length < jobMinDescLen) {
        throw StateError('Penerangan perlu sekurang-kurangnya $jobMinDescLen aksara.');
      }

      if (normalizedAmount < jobMinAmount) {
        throw StateError('Jumlah minima ialah RM${jobMinAmount.toStringAsFixed(2)}.');
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/jobs',
        data: <String, dynamic>{
          'serviceId': parsedServiceId,
          'amount': normalizedAmount,
          'description': trimmedDescription,
          'title': (serviceTitle == null || serviceTitle.isEmpty)
              ? null
              : serviceTitle,
        },
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <String, dynamic>{};
      final job = Job.fromJson(data);
      return job;
    } on DioException catch (error) {
      await _handleDioError(error, suppressClientErrorSnackbar: true);
      rethrow;
    }
  }

  Future<Job?> acceptJob(String jobId) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/jobs/$jobId/accept',
        options: await _authorizedOptions(),
      );
      final data = response.data;
      return data != null ? Job.fromJson(data) : null;
    } on DioException catch (error) {
      await _handleStatusError(error);
      rethrow;
    }
  }

  Future<Job?> startJob(String jobId) async {
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
        return job;
      }
      return null;
    } on DioException catch (error) {
      await _handleStatusError(error);
      rethrow;
    }
  }

  Future<Job?> cancelJob(String jobId) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/jobs/$jobId/cancel',
        options: await _authorizedOptions(),
      );
      return response.data != null ? Job.fromJson(response.data!) : null;
    } on DioException catch (error) {
      await _handleStatusError(error);
      rethrow;
    }
  }

  Future<Job?> disputeJob(String jobId, String reason) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/jobs/$jobId/dispute',
        data: <String, dynamic>{'reason': reason},
        options: await _authorizedOptions(),
      );
      return response.data != null ? Job.fromJson(response.data!) : null;
    } on DioException catch (error) {
      if (error.response?.statusCode == 403) {
        throw JobStatusConflict(
          'Client tidak dibenarkan dispute. Sila hubungi support.',
        );
      }
      await _handleStatusError(error);
      rethrow;
    }
  }

  Future<Job?> rejectJob(String jobId) async {
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
        return job;
      }
      return null;
    } on DioException catch (error) {
      await _handleStatusError(error);
      rethrow;
    }
  }

  Future<Job?> markCompleted(String jobId) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/jobs/$jobId/complete',
        options: await _authorizedOptions(),
      );
      return response.data != null ? Job.fromJson(response.data!) : null;
    } on DioException catch (error) {
      await _handleStatusError(error);
      rethrow;
    }
  }

  Future<List<Job>> getClientJobs({String? limit, String? offset}) async {
    return _fetchJobs(_buildQuery(<String, dynamic>{'filter': 'client'}, limit: limit, offset: offset));
  }

  Future<List<Job>> getFreelancerJobs({String? limit, String? offset}) async {
    return _fetchJobs(_buildQuery(<String, dynamic>{'filter': 'freelancer'}, limit: limit, offset: offset));
  }

  Future<List<Job>> getAllJobs({String? limit, String? offset}) async {
    final currentUser = await authRepository.getCurrentUser();
    if (currentUser == null || currentUser.role.toUpperCase() != 'ADMIN') {
      throw StateError('Hanya admin boleh melihat semua job.');
    }
    return _fetchJobs(_buildQuery(<String, dynamic>{'filter': 'all'}, limit: limit, offset: offset));
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

  Map<String, dynamic> _buildQuery(
    Map<String, dynamic> base, {
    String? limit,
    String? offset,
  }) {
    final parsedLimit = parsePositiveInt(limit);
    final parsedOffset = parsePositiveInt(offset);
    if (parsedLimit != null) {
      base['limit'] = min(parsedLimit, 50);
    }
    if (parsedOffset != null) {
      base['offset'] = parsedOffset;
    }
    return base;
  }

  Future<Options> _authorizedOptions() async {
    final token = await _storage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      await _handleMissingToken();
      return Options();
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  Future<void> _handleMissingToken() async {
    notificationService.messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Sesi tamat. Sila log masuk semula.')),
    );
    await authRepository.logout();
    authRefreshNotifier.value = DateTime.now();
    appRouter.go('/login');
  }

  Future<void> _handleDioError(
    DioException error, {
    bool suppressClientErrorSnackbar = false,
  }) async {
    await handleApiError(error);

    if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
      return;
    }

    if (!suppressClientErrorSnackbar &&
        (error.response?.statusCode == 400 || error.response?.statusCode == 404)) {
      final message = _extractErrorMessage(error);
      notificationService.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'Permintaan tidak sah.' : message)),
      );
    }
  }

  Future<void> _handleStatusError(DioException error) async {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      await handleApiError(error);
      return;
    }

    if (statusCode == 403) {
      throw JobStatusConflict('Akses tidak dibenarkan untuk role anda.');
    }

    if (statusCode == 409) {
      final message = _extractErrorMessage(error);
      final fallback = 'Status job tidak membenarkan tindakan ini.';
      throw JobStatusConflict(message.isEmpty ? fallback : message);
    }

    if (statusCode == 400) {
      final message = _extractErrorMessage(error);
      throw JobStatusConflict(message.isEmpty ? 'Permintaan tidak sah.' : message);
    }

    await _handleDioError(error);
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message is List) {
        final joined = message
            .whereType<String>()
            .map((String item) => item.trim())
            .where((String item) => item.isNotEmpty)
            .join('\n');
        if (joined.isNotEmpty) {
          return joined;
        }
      }
    }
    return error.message ?? 'Tindakan tidak dibenarkan.';
  }
}

final jobsRepository = JobsRepository();

class JobStatusConflict implements Exception {
  JobStatusConflict(this.message);
  final String message;

  @override
  String toString() => message;
}
