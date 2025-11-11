enum JobStatus { pending, inProgress, completed }

class Job {
  Job({
    required this.id,
    required this.clientId,
    required this.freelancerId,
    required this.serviceId,
    required this.status,
    required this.amount,
  });

  final String id;
  final String clientId;
  final String freelancerId;
  final String serviceId;
  final JobStatus status;
  final double amount;
}
