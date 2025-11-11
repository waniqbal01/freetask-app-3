import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../payments/escrow_service.dart';
import '../reviews/review_dialog.dart';
import '../reviews/reviews_repository.dart';
import 'jobs_repository.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key});

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  List<Job> _clientJobs = <Job>[];
  List<Job> _freelancerJobs = <Job>[];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _clientJobs = jobsRepository.getClientJobs();
    _freelancerJobs = jobsRepository.getFreelancerJobs();
  }

  void _refreshJobs() {
    setState(() {
      _clientJobs = jobsRepository.getClientJobs();
      _freelancerJobs = jobsRepository.getFreelancerJobs();
    });
  }

  Future<void> _handleAction(
    Future<bool> Function() action,
    String successMessage,
  ) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    final success = await action();

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (success) {
      _refreshJobs();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tindakan tidak berjaya. Cuba lagi.'),
        ),
      );
    }
  }

  Future<void> _openReviewDialog(Job job) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => ReviewDialog(
        jobId: job.id,
        serviceTitle: job.serviceTitle,
      ),
    );
    if (submitted == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terima kasih atas review anda!')),
      );
    }
  }

  String _statusLabel(JobStatus status) {
    switch (status) {
      case JobStatus.pending:
        return 'Pending';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.rejected:
        return 'Rejected';
    }
  }

  Color _statusColor(JobStatus status, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case JobStatus.pending:
        return scheme.secondary;
      case JobStatus.inProgress:
        return scheme.primary;
      case JobStatus.completed:
        return Colors.green;
      case JobStatus.rejected:
        return Colors.red;
    }
  }

  Widget _buildJobCard(Job job, {required bool isClientView}) {
    final statusText = _statusLabel(job.status);
    final statusColor = _statusColor(job.status, context);
    final alreadyReviewed = reviewsRepository.hasSubmittedReview(job.id);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.serviceTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text('Service ID: ${job.serviceId}'),
            const SizedBox(height: 8),
            Text('Jumlah: RM${job.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status: $statusText',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isClientView && job.status == JobStatus.inProgress)
                  FilledButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _handleAction(
                              () async {
                                final success =
                                    await jobsRepository.markCompleted(job.id);
                                if (success) {
                                  await escrowService.release(job.id);
                                }
                                return success;
                              },
                              'Job ditandakan selesai. Dana dilepaskan kepada freelancer.',
                            ),
                    child: const Text('Mark as Completed'),
                  )
                else if (!isClientView && job.status == JobStatus.pending)
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isProcessing
                            ? null
                            : () => _handleAction(
                                  () async {
                                    final success =
                                        await jobsRepository.rejectJob(job.id);
                                    if (success) {
                                      await escrowService.refund(job.id);
                                    }
                                    return success;
                                  },
                                  'Job telah ditolak dan dana dipulangkan.',
                                ),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isProcessing
                            ? null
                            : () => _handleAction(
                                  () => jobsRepository.acceptJob(job.id),
                                  'Job diterima! Status kini In Progress.',
                                ),
                        child: const Text('Accept'),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            if (job.isDisputed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Dispute: ${job.disputeReason ?? 'Tiada maklumat tambahan.'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.orange.shade700),
                ),
              ),
            if (isClientView && job.status == JobStatus.completed)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: alreadyReviewed
                      ? Chip(
                          avatar: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          label: const Text('Review dihantar'),
                        )
                      : TextButton.icon(
                          onPressed: () => _openReviewDialog(job),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Tulis review'),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jobs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Client Jobs'),
              Tab(text: 'Freelancer Jobs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _clientJobs.isEmpty
                ? const Center(child: Text('Tiada job sebagai client.'))
                : ListView.builder(
                    itemCount: _clientJobs.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildJobCard(
                        _clientJobs[index],
                        isClientView: true,
                      );
                    },
                  ),
            _freelancerJobs.isEmpty
                ? const Center(child: Text('Tiada job sebagai freelancer.'))
                : ListView.builder(
                    itemCount: _freelancerJobs.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildJobCard(
                        _freelancerJobs[index],
                        isClientView: false,
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
