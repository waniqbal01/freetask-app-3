import '../../models/job.dart';

/// Helper class to determine available job actions based on current status and user role
class JobActions {
  /// Returns list of available actions for a job given its status and the user's role
  /// Mirrors backend transition matrix from jobs.service.ts:179-198
  static List<JobAction> getAvailableActions(JobStatus status, String userRole) {
    final role = userRole.toUpperCase();
    final actions = <JobAction>[];

    switch (status) {
      case JobStatus.pending:
        if (role == 'FREELANCER') {
          actions.add(JobAction.accept);
          actions.add(JobAction.reject);
        } else if (role == 'CLIENT') {
          actions.add(JobAction.cancel);
        }
        break;

      case JobStatus.accepted:
        if (role == 'FREELANCER') {
          actions.add(JobAction.start);
        }
        if (role == 'CLIENT') {
          actions.add(JobAction.cancel);
        }
        break;

      case JobStatus.inProgress:
        if (role == 'FREELANCER') {
          actions.add(JobAction.complete);
          actions.add(JobAction.dispute);
        }
        if (role == 'CLIENT') {
          actions.add(JobAction.cancel);
          actions.add(JobAction.dispute);
        }
        break;

      case JobStatus.completed:
        // Both can dispute a completed job
        if (role == 'FREELANCER' || role == 'CLIENT') {
          actions.add(JobAction.dispute);
        }
        break;

      case JobStatus.rejected:
        if (role == 'CLIENT') {
          actions.add(JobAction.cancel);
        }
        break;

      case JobStatus.cancelled:
      case JobStatus.disputed:
        // No actions available for cancelled or disputed jobs
        break;
    }

    return actions;
  }

  /// Checks if a specific action is available for the given status and role
  static bool isActionAvailable(
    JobAction action,
    JobStatus status,
    String userRole,
  ) {
    final available = getAvailableActions(status, userRole);
    return available.contains(action);
  }
}

/// Enum representing possible job actions
enum JobAction {
  accept,
  reject,
  start,
  complete,
  cancel,
  dispute,
}

/// Extension to get human-readable labels for job actions
extension JobActionLabel on JobAction {
  String get label {
    switch (this) {
      case JobAction.accept:
        return 'Accept';
      case JobAction.reject:
        return 'Reject';
      case JobAction.start:
        return 'Start';
      case JobAction.complete:
        return 'Complete';
      case JobAction.cancel:
        return 'Cancel';
      case JobAction.dispute:
        return 'Dispute';
    }
  }

  String get labelMalay {
    switch (this) {
      case JobAction.accept:
        return 'Terima';
      case JobAction.reject:
        return 'Tolak';
      case JobAction.start:
        return 'Mula';
      case JobAction.complete:
        return 'Selesai';
      case JobAction.cancel:
        return 'Batal';
      case JobAction.dispute:
        return 'Pertikaian';
    }
  }
}
