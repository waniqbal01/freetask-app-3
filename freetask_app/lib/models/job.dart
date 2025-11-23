enum JobStatus {
  pending,
  accepted,
  inProgress,
  completed,
  cancelled,
  rejected,
  disputed
}

class Job {
  Job({
    required this.id,
    required this.clientId,
    required this.freelancerId,
    required this.serviceId,
    required this.serviceTitle,
    required this.amount,
    this.status = JobStatus.pending,
    this.isDisputed = false,
    this.disputeReason,
    this.createdAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final serviceObj = json['service'];
    final clientObj = json['client'];
    final freelancerObj = json['freelancer'];

    return Job(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ??
          json['clientId']?.toString() ??
          clientObj?['id']?.toString() ??
          '',
      freelancerId: json['freelancer_id']?.toString() ??
          json['freelancerId']?.toString() ??
          freelancerObj?['id']?.toString() ??
          '',
      serviceId: json['service_id']?.toString() ??
          json['serviceId']?.toString() ??
          serviceObj?['id']?.toString() ??
          '',
      serviceTitle: json['serviceTitle']?.toString() ??
          json['service_title']?.toString() ??
          serviceObj?['title']?.toString() ??
          'Servis ${json['service_id']?.toString() ?? json['serviceId']?.toString() ?? ''}',
      amount: _parseAmount(json['amount']),
      status: _parseStatus(json['status']),
      isDisputed: _calculateDisputed(
        json['status'],
        json['dispute_reason'] ?? json['disputeReason'],
      ),
      disputeReason: json['dispute_reason']?.toString() ??
          json['disputeReason']?.toString(),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Job copyWith({
    JobStatus? status,
    bool? isDisputed,
    String? disputeReason,
    DateTime? createdAt,
  }) {
    return Job(
      id: id,
      clientId: clientId,
      freelancerId: freelancerId,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      amount: amount,
      status: status ?? this.status,
      isDisputed: isDisputed ?? this.isDisputed,
      disputeReason: disputeReason ?? this.disputeReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  final String id;
  final String clientId;
  final String freelancerId;
  final String serviceId;
  final String serviceTitle;
  final double amount;
  final JobStatus status;
  final bool isDisputed;
  final String? disputeReason;
  final DateTime? createdAt;

  static JobStatus _parseStatus(dynamic value) {
    if (value is JobStatus) {
      return value;
    }
    final normalized = value?.toString().toUpperCase();
    switch (normalized) {
      case 'PENDING':
        return JobStatus.pending;
      case 'ACCEPTED':
        return JobStatus.accepted;
      case 'IN_PROGRESS':
      case 'IN-PROGRESS':
      case 'INPROGRESS':
        return JobStatus.inProgress;
      case 'COMPLETED':
        return JobStatus.completed;
      case 'CANCELLED':
        return JobStatus.cancelled;
      case 'REJECTED':
        return JobStatus.rejected;
      case 'DISPUTED':
        return JobStatus.disputed;
      default:
        print('Unknown job status received: $value. Falling back to pending.');
        return JobStatus.pending;
    }
  }

  static double _parseAmount(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static bool _calculateDisputed(dynamic statusValue, dynamic disputeReason) {
    final status = _parseStatus(statusValue);
    final hasReason = (disputeReason?.toString().isNotEmpty ?? false);
    return status == JobStatus.disputed || hasReason;
  }
}
