enum JobStatus { pending, inProgress, completed, rejected }

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
}
