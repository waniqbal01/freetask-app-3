import '../../models/job.dart';

bool canFreelancerAccept(JobStatus status) => status == JobStatus.pending;

bool canFreelancerReject(JobStatus status) => status == JobStatus.pending;

bool canFreelancerStart(JobStatus status) => status == JobStatus.accepted;

bool canFreelancerComplete(JobStatus status) =>
    status == JobStatus.inProgress || status == JobStatus.inRevision;

bool canClientCancel(JobStatus status) => {
      JobStatus.pending,
      JobStatus.accepted,
      JobStatus.inProgress
    }.contains(status);

bool canRaiseDispute(JobStatus status) =>
    status == JobStatus.inProgress || status == JobStatus.completed;
