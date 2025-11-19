import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../models/job.dart';
import 'chat_socket_service.dart';

class JobStatusUpdate {
  JobStatusUpdate({
    required this.jobId,
    required this.status,
    this.title,
    this.updatedAt,
    this.disputeReason,
  });

  final String jobId;
  final JobStatus status;
  final String? title;
  final DateTime? updatedAt;
  final String? disputeReason;
}

final jobUpdatesSocketProvider = Provider<JobUpdatesSocketService>((Ref ref) {
  final service = JobUpdatesSocketService(ref.watch(chatSocketServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});

class JobUpdatesSocketService {
  JobUpdatesSocketService(this._socketService) {
    _subscription = _socketService.jobUpdates.listen(_handleUpdate);
  }

  final ChatSocketService _socketService;
  late final StreamSubscription<JobSocketStatusEvent> _subscription;
  final StreamController<JobStatusUpdate> _controller =
      StreamController<JobStatusUpdate>.broadcast();

  Stream<JobStatusUpdate> get updates => _controller.stream;

  Future<void> registerJobs(Iterable<String> jobIds) async {
    for (final jobId in jobIds) {
      if (jobId.isEmpty) {
        continue;
      }
      await _socketService.joinJobRoom(jobId);
    }
  }

  void dispose() {
    _subscription.cancel();
    _controller.close();
  }

  void _handleUpdate(JobSocketStatusEvent event) {
    final status = _mapStatus(event.status);
    final update = JobStatusUpdate(
      jobId: event.jobId,
      status: status,
      title: event.title,
      updatedAt: event.updatedAt,
      disputeReason: event.disputeReason,
    );
    _controller.add(update);
    final statusLabel = _statusLabel(status);
    final title = event.title ?? 'Job';
    notificationService.pushLocal(
      'Status job dikemas kini',
      '$title kini $statusLabel.',
    );
  }

  JobStatus _mapStatus(String raw) {
    switch (raw.toUpperCase()) {
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
        return JobStatus.pending;
    }
  }

  String _statusLabel(JobStatus status) {
    switch (status) {
      case JobStatus.pending:
        return 'menunggu pengesahan';
      case JobStatus.accepted:
        return 'telah diterima';
      case JobStatus.inProgress:
        return 'sedang dijalankan';
      case JobStatus.completed:
        return 'telah siap';
      case JobStatus.cancelled:
        return 'telah dibatalkan';
      case JobStatus.rejected:
        return 'telah ditolak';
      case JobStatus.disputed:
        return 'dalam pertikaian';
    }
  }
}
