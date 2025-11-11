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
  });

  Job copyWith({JobStatus? status}) {
    return Job(
      id: id,
      clientId: clientId,
      freelancerId: freelancerId,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      amount: amount,
      status: status ?? this.status,
    );
  }

  final String id;
  final String clientId;
  final String freelancerId;
  final String serviceId;
  final String serviceTitle;
  final double amount;
  final JobStatus status;
}
