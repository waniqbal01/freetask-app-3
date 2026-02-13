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
  static const int defaultPageSize = 20;

  JobsRepository({AppStorage? storage, Dio? dio})
      : _storage = storage ?? appStorage,
        _dio = dio ?? HttpClient().dio;

  final AppStorage _storage;
  final Dio _dio;

  Future<Job> createOrder(
    String serviceId,
    double amount,
    String description, {
    String? serviceTitle,
    List<String>? attachments,
  }) async {
    try {
      final parsedServiceId = int.tryParse(serviceId.toString());
      if (parsedServiceId == null) {
        throw StateError('ID servis tidak sah.');
      }

      final trimmedDescription = description.trim();

      // Validate decimal precision (max 2 decimal places)
      final amountString = amount.toString();
      if (amountString.contains('.')) {
        final decimalPart = amountString.split('.')[1];
        if (decimalPart.length > 2) {
          throw StateError(
              'Jumlah hanya boleh mempunyai maksimum 2 tempat perpuluhan.');
        }
      }

      final normalizedAmount = double.parse(amount.toStringAsFixed(2));

      if (trimmedDescription.length < jobMinDescLen) {
        throw StateError(
            'Penerangan perlu sekurang-kurangnya $jobMinDescLen aksara.');
      }

      if (normalizedAmount < jobMinAmount) {
        throw StateError(
            'Jumlah minima ialah RM${jobMinAmount.toStringAsFixed(2)}.');
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
          if (attachments != null) 'attachments': attachments,
        },
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <String, dynamic>{};
      final job = Job.fromJson(data);

      debugPrint('✅ Job created successfully: ${job.id}');
      return job;
    } on DioException catch (error) {
      debugPrint('🔴 FAILED TO CREATE JOB');
      debugPrint('Service ID: $serviceId');
      debugPrint('Amount: $amount');
      debugPrint('Status: ${error.response?.statusCode}');
      debugPrint('Response: ${error.response?.data}');

      await _handleDioError(error, suppressClientErrorSnackbar: true);
      rethrow;
    }
  }

  Future<Job> createInquiry(String serviceId, String message) async {
    try {
      final parsedServiceId = int.tryParse(serviceId.toString());
      if (parsedServiceId == null) {
        throw StateError('ID servis tidak sah.');
      }
      final trimmedMessage = message.trim();
      if (trimmedMessage.isEmpty) {
        throw StateError('Mesej tidak boleh kosong.');
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/jobs/inquiry',
        data: <String, dynamic>{
          'serviceId': parsedServiceId,
          'message': trimmedMessage,
        },
        options: await _authorizedOptions(),
      );
      final data = response.data ?? <String, dynamic>{};

      debugPrint('✅ Inquiry created successfully');
      return Job.fromJson(data);
    } on DioException catch (error) {
      debugPrint('🔴 FAILED TO CREATE INQUIRY');
      debugPrint('Service ID: $serviceId');
      debugPrint('Status: ${error.response?.statusCode}');
      debugPrint('Response: ${error.response?.data}');

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
    // Deprecated workflow - try submit flow instead or keep for legacy/manual
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

  Future<Job?> submitJob(String jobId, String message,
      {List<String>? attachments}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/jobs/$jobId/submit',
        data: {
          'message': message,
          if (attachments != null) 'attachments': attachments,
        },
        options: await _authorizedOptions(),
      );
      return response.data != null ? Job.fromJson(response.data!) : null;
    } on DioException catch (error) {
      await _handleStatusError(error);
      rethrow;
    }
  }

  Future<Job?> confirmJob(String jobId) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/jobs/$jobId/confirm',
        options: await _authorizedOptions(),
      );
      return response.data != null ? Job.fromJson(response.data!) : null;
    } on DioException catch (error) {
      await _handleStatusError(error);
      rethrow;
    }
  }

  Future<Job?> requestRevision(String jobId, String reason) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/jobs/$jobId/revision',
        data: {'reason': reason},
        options: await _authorizedOptions(),
      );
      return response.data != null ? Job.fromJson(response.data!) : null;
    } on DioException catch (error) {
      await _handleStatusError(error);
      rethrow;
    }
  }

  Future<List<Job>> getClientJobs(
      {String? limit, String? offset, List<String>? status}) async {
    final query = _buildQuery(<String, dynamic>{'filter': 'client'},
        limit: limit, offset: offset);
    if (status != null && status.isNotEmpty) {
      query['status'] = status.join(',');
    }
    return _fetchJobs(query);
  }

  Future<List<Job>> getFreelancerJobs(
      {String? limit, String? offset, List<String>? status}) async {
    final query = _buildQuery(<String, dynamic>{'filter': 'freelancer'},
        limit: limit, offset: offset);
    if (status != null && status.isNotEmpty) {
      query['status'] = status.join(',');
    }
    return _fetchJobs(query);
  }

  Future<List<Job>> getAllJobs(
      {String? limit, String? offset, String? filter}) async {
    final currentUser = await authRepository.getCurrentUser();
    if (currentUser == null || currentUser.role.toUpperCase() != 'ADMIN') {
      throw StateError('Hanya admin boleh melihat semua job.');
    }
    final Map<String, dynamic> params = <String, dynamic>{};
    if (filter != null) {
      params['filter'] = filter;
    }
    final baseParams =
        params.isEmpty ? <String, dynamic>{'filter': 'all'} : params;
    return _fetchJobs(_buildQuery(baseParams, limit: limit, offset: offset));
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
      // Log detailed error information for debugging
      debugPrint('🔴 FAILED TO FETCH JOBS');
      debugPrint('Query: $queryParameters');
      debugPrint('Status: ${error.response?.statusCode}');
      debugPrint('Path: ${error.requestOptions.path}');
      debugPrint('Response: ${error.response?.data}');
      debugPrint('Error Type: ${error.type}');

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
    base['limit'] = min(parsedLimit ?? defaultPageSize, 50);
    base['offset'] = max(parsedOffset ?? 0, 0);
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

    if (error.response?.statusCode == 401 ||
        error.response?.statusCode == 403) {
      return;
    }

    if (!suppressClientErrorSnackbar &&
        (error.response?.statusCode == 400 ||
            error.response?.statusCode == 404)) {
      final message = _extractErrorMessage(error);
      notificationService.messengerKey.currentState?.showSnackBar(
        SnackBar(
            content: Text(message.isEmpty ? 'Permintaan tidak sah.' : message)),
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
      const fallback = 'Status job tidak membenarkan tindakan ini.';
      throw JobStatusConflict(message.isEmpty ? fallback : message);
    }

    if (statusCode == 400) {
      final message = _extractErrorMessage(error);
      throw JobStatusConflict(
          message.isEmpty ? 'Permintaan tidak sah.' : message);
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
