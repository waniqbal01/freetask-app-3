enum JobStatus { pending, inProgress, completed, rejected, disputed }

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
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ??
          json['clientId']?.toString() ??
          '',
      freelancerId: json['freelancer_id']?.toString() ??
          json['freelancerId']?.toString() ??
          '',
      serviceId: json['service_id']?.toString() ??
          json['serviceId']?.toString() ??
          '',
      serviceTitle: json['service_title']?.toString() ??
          json['serviceTitle']?.toString() ??
          'Servis ${json['service_id']?.toString() ?? json['serviceId']?.toString() ?? ''}',
      amount: _parseAmount(json['amount']),
      status: _parseStatus(json['status']),
      isDisputed: json['is_disputed'] as bool? ??
          json['isDisputed'] as bool? ??
          false,
      disputeReason: json['dispute_reason']?.toString() ??
          json['disputeReason']?.toString(),
    );
  }

  Job copyWith({
    JobStatus? status,
    bool? isDisputed,
    String? disputeReason,
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

  static JobStatus _parseStatus(dynamic value) {
    if (value is JobStatus) {
      return value;
    }
    final normalized = value?.toString().toUpperCase();
    switch (normalized) {
      case 'PENDING':
        return JobStatus.pending;
      case 'IN_PROGRESS':
      case 'IN-PROGRESS':
      case 'INPROGRESS':
        return JobStatus.inProgress;
      case 'COMPLETED':
        return JobStatus.completed;
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
}
