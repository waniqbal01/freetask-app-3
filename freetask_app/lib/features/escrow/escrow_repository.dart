import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/storage/storage.dart';
import '../../services/http_client.dart';
import '../auth/auth_repository.dart';
import 'escrow_policy.dart';

enum EscrowStatus { pending, held, disputed, released, refunded, cancelled }

class EscrowRecord {
  EscrowRecord({
    required this.id,
    required this.jobId,
    required this.status,
    required this.amount,
    this.createdAt,
    this.updatedAt,
  });

  factory EscrowRecord.fromJson(Map<String, dynamic> json) {
    return EscrowRecord(
      id: json['id']?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? json['job_id']?.toString() ?? '',
      status: _parseStatus(json['status']),
      amount: _parseAmount(json['amount']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  final String id;
  final String jobId;
  final EscrowStatus status;
  final double? amount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static EscrowStatus _parseStatus(dynamic status) {
    final normalized = status?.toString().toUpperCase();
    switch (normalized) {
      case 'PENDING':
        return EscrowStatus.pending;
      case 'HELD':
        return EscrowStatus.held;
      case 'DISPUTED':
        return EscrowStatus.disputed;
      case 'RELEASED':
        return EscrowStatus.released;
      case 'REFUNDED':
        return EscrowStatus.refunded;
      case 'CANCELLED':
        return EscrowStatus.cancelled;
      default:
        return EscrowStatus.pending;
    }
  }

  static double? _parseAmount(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String && value.isNotEmpty) {
      return double.tryParse(value);
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class EscrowUnavailable implements Exception {
  EscrowUnavailable(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class EscrowRepository {
  EscrowRepository({Dio? dio, AppStorage? storage, AuthRepository? auth})
      : _dio = dio ?? HttpClient().dio,
        _storage = storage ?? appStorage,
        _auth = auth ?? authRepository;

  final Dio _dio;
  final AppStorage _storage;
  final AuthRepository _auth;

  Future<EscrowRecord?> getEscrow(String jobId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/escrow/$jobId',
        options: await _authorizedOptions(),
      );
      final data = response.data;
      if (data == null) return null;
      return EscrowRecord.fromJson(data);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 403) {
        throw EscrowUnavailable('Admin sahaja boleh urus escrow.', statusCode: status);
      }
      if (status == 404) {
        throw EscrowUnavailable('Escrow belum dibuat lagi.', statusCode: status);
      }
      rethrow;
    }
  }

  Future<EscrowRecord?> hold(String jobId) async {
    return _mutate('/escrow/$jobId/hold', 'Dana dipegang untuk job $jobId.');
  }

  Future<EscrowRecord?> release(String jobId) async {
    return _mutate('/escrow/$jobId/release', 'Dana dilepaskan untuk job $jobId.');
  }

  Future<EscrowRecord?> refund(String jobId) async {
    return _mutate('/escrow/$jobId/refund', 'Dana dipulangkan untuk job $jobId.');
  }

  Future<EscrowRecord?> _mutate(String path, String notificationMessage) async {
    final role = await _resolveRole();
    if (!canMutateEscrow(role)) {
      const message = 'Admin sahaja boleh urus escrow.';
      notificationService.messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text(message)),
      );
      throw EscrowUnavailable(message, statusCode: 403);
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        options: await _authorizedOptions(),
      );
      final data = response.data;
      if (data == null) return null;
      final record = EscrowRecord.fromJson(data);
      notificationService.pushLocal('Escrow', notificationMessage);
      return record;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 409) {
        final message = error.response?.data is Map
            ? (error.response?.data['message']?.toString() ?? '')
            : error.response?.statusMessage;
        final friendly = message?.isNotEmpty == true
            ? message!
            : 'Status escrow tidak membenarkan tindakan ini.';
        notificationService.messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(friendly)),
        );
        throw EscrowUnavailable(friendly, statusCode: status);
      }
      if (status == 403) {
        const friendly = 'Admin sahaja boleh urus escrow.';
        notificationService.messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text(friendly)),
        );
        throw EscrowUnavailable(friendly, statusCode: status);
      }
      if (status == 404) {
        const friendly = 'Rekod escrow belum wujud untuk job ini.';
        notificationService.messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text(friendly)),
        );
        throw EscrowUnavailable(friendly, statusCode: status);
      }
      rethrow;
    }
  }

  Future<Options> _authorizedOptions() async {
    final token = await _storage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      throw EscrowUnavailable('Token tidak ditemui. Sila log masuk semula.');
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $token'});
  }

  Future<String?> _resolveRole() async {
    final cached = _auth.currentUser;
    if (cached != null && cached.role.isNotEmpty) {
      return cached.role;
    }
    final user = await _auth.getCurrentUser();
    return user?.role;
  }
}

final escrowRepository = EscrowRepository();
