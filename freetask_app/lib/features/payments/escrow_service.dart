import 'dart:async';

import '../../core/notifications/notification_service.dart';

enum EscrowStatus { held, released, refunded }

class _EscrowRecord {
  _EscrowRecord({
    required this.amount,
    required this.status,
    required this.updatedAt,
  });

  final double amount;
  final EscrowStatus status;
  final DateTime updatedAt;

  _EscrowRecord copyWith({
    double? amount,
    EscrowStatus? status,
    DateTime? updatedAt,
  }) {
    return _EscrowRecord(
      amount: amount ?? this.amount,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EscrowService {
  EscrowService();

  final Map<String, _EscrowRecord> _records = <String, _EscrowRecord>{};

  Future<void> hold(String jobId, double amount) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _records[jobId] = _EscrowRecord(
      amount: amount,
      status: EscrowStatus.held,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> release(String jobId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final record = _records[jobId];
    if (record == null) {
      return;
    }

    _records[jobId] = record.copyWith(
      status: EscrowStatus.released,
      updatedAt: DateTime.now(),
    );
    notificationService.pushLocal(
      'Pembayaran Dilepaskan',
      'Dana untuk job $jobId telah dilepaskan.',
    );
  }

  Future<void> refund(String jobId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final record = _records[jobId];
    if (record == null) {
      return;
    }

    _records[jobId] = record.copyWith(
      status: EscrowStatus.refunded,
      updatedAt: DateTime.now(),
    );
  }

  EscrowStatus? getStatus(String jobId) {
    return _records[jobId]?.status;
  }

  double? getAmount(String jobId) {
    return _records[jobId]?.amount;
  }

  bool get isEmpty => _records.isEmpty;
}

final escrowService = EscrowService();
