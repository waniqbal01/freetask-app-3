import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../reviews/review_dialog.dart';
import '../reviews/reviews_repository.dart';
import 'jobs_repository.dart';
import '../../core/utils/error_utils.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key});

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  final List<Job> _clientJobs = <Job>[];
  final List<Job> _freelancerJobs = <Job>[];
  bool _isLoadingClient = false;
  bool _isLoadingFreelancer = false;
  String? _clientErrorMessage;
  String? _freelancerErrorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    await Future.wait([_fetchClientJobs(), _fetchFreelancerJobs()]);
  }

  void _refreshJobs() {
    _loadJobs();
  }

  Future<void> _refreshClientJobs() async {
    await _fetchClientJobs();
  }

  Future<void> _refreshFreelancerJobs() async {
    await _fetchFreelancerJobs();
  }

  Future<void> _fetchClientJobs() async {
    setState(() {
      _isLoadingClient = true;
      _clientErrorMessage = null;
    });

    try {
      final jobs = await jobsRepository.getClientJobs();
      if (!mounted) return;
      setState(() {
        _clientJobs
          ..clear()
          ..addAll(jobs);
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final message = resolveDioErrorMessage(error);
      setState(() {
        _clientErrorMessage = message;
      });
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      const message = 'Ralat memuat job pelanggan.';
      setState(() {
        _clientErrorMessage = message;
      });
      showErrorSnackBar(context, '$message $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingClient = false;
        });
      }
    }
  }

  Future<void> _fetchFreelancerJobs() async {
    setState(() {
      _isLoadingFreelancer = true;
      _freelancerErrorMessage = null;
    });

    try {
      final jobs = await jobsRepository.getFreelancerJobs();
      if (!mounted) return;
      setState(() {
        _freelancerJobs
          ..clear()
          ..addAll(jobs);
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final message = resolveDioErrorMessage(error);
      setState(() {
        _freelancerErrorMessage = message;
      });
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      const message = 'Ralat memuat job freelancer.';
      setState(() {
        _freelancerErrorMessage = message;
      });
      showErrorSnackBar(context, '$message $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFreelancer = false;
        });
      }
    }
  }

  Future<void> _handleAction(
    Future<bool> Function() action,
    String successMessage,
  ) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await action();

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      if (success) {
        await _loadJobs();
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
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resolveDioErrorMessage(error))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ralat melaksanakan tindakan.'),
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
        return 'Booked';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.rejected:
        return 'Rejected';
      case JobStatus.disputed:
        return 'Disputed';
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
      case JobStatus.disputed:
        return Colors.orange;
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
                                return jobsRepository.markCompleted(job.id);
                              },
                              'Job ditandakan selesai. Status kini Completed.',
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
                                return success;
                              },
                              'Job telah ditolak dan dikemas kini.',
                            ),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isProcessing
                            ? null
                            : () => _handleAction(
                                  () => jobsRepository.startJob(job.id),
                                  'Job dimulakan! Status kini In Progress.',
                                ),
                        child: const Text('Start Job'),
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

  Widget _buildJobsTab({
    required List<Job> jobs,
    required bool isClientView,
    required bool isLoading,
    required String? errorMessage,
    required Future<void> Function() onRefresh,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onRefresh,
                child: const Text('Cuba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (jobs.isEmpty) {
      return const Center(child: Text('Tiada data'));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: jobs.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildJobCard(
            jobs[index],
            isClientView: isClientView,
          );
        },
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
            _buildJobsTab(
              jobs: _clientJobs,
              isClientView: true,
              isLoading: _isLoadingClient,
              errorMessage: _clientErrorMessage,
              onRefresh: _refreshClientJobs,
            ),
            _buildJobsTab(
              jobs: _freelancerJobs,
              isClientView: false,
              isLoading: _isLoadingFreelancer,
              errorMessage: _freelancerErrorMessage,
              onRefresh: _refreshFreelancerJobs,
            ),
          ],
        ),
      ),
    );
  }
}
