import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_formatters.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/error_utils.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../models/job.dart';
import '../auth/auth_repository.dart';
import '../escrow/escrow_repository.dart';
import '../jobs/jobs_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<List<Job>> _jobsFuture;
  List<EscrowRecord> _escrowRecords = <EscrowRecord>[];
  Map<String, EscrowRecord> _escrowByJob = <String, EscrowRecord>{};
  String? _escrowError;
  bool _isEscrowLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _jobsFuture = _fetchJobs();
  }

  Future<void> _refreshDashboard() async {
    setState(_loadData);
    await _jobsFuture;
  }

  Future<List<Job>> _fetchJobs() async {
    final user = await authRepository.getCurrentUser();
    if (user == null || user.role.toUpperCase() != 'ADMIN') {
      if (mounted) {
        showErrorSnackBar(context, AppStrings.adminOnly);
      }
      return <Job>[];
    }

    final jobs = await jobsRepository.getAllJobs(filter: 'all');
    await _hydrateEscrow(jobs);
    return jobs;
  }

  Future<void> _hydrateEscrow(List<Job> jobs) async {
    setState(() {
      _isEscrowLoading = true;
      _escrowError = null;
    });

    try {
      final records = <EscrowRecord>[];
      for (final job in jobs) {
        final record = await escrowRepository.getEscrow(job.id);
        if (record != null) {
          records.add(record);
        }
      }

      if (!mounted) return;
      setState(() {
        _escrowRecords = records;
        _escrowByJob = <String, EscrowRecord>{
          for (final record in records) record.jobId: record,
        };
        _escrowError = null;
      });
    } on EscrowUnavailable catch (error) {
      if (!mounted) return;
      setState(() {
        _escrowError = error.message;
        _escrowRecords = <EscrowRecord>[];
        _escrowByJob = <String, EscrowRecord>{};
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _escrowError = AppStrings.errorLoadingEscrow;
        _escrowRecords = <EscrowRecord>[];
        _escrowByJob = <String, EscrowRecord>{};
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEscrowLoading = false;
        });
      }
    }
  }

  String _jobStatusLabel(JobStatus status) {
    switch (status) {
      case JobStatus.inquiry:
        return 'Inquiry';
      case JobStatus.pending:
        return AppStrings.jobStatusPending;
      case JobStatus.awaitingPayment:
        return 'Awaiting Payment';
      case JobStatus.accepted:
        return AppStrings.jobStatusAccepted;
      case JobStatus.inProgress:
        return AppStrings.jobStatusInProgress;
      case JobStatus.inReview:
        return 'In Review';
      case JobStatus.completed:
        return AppStrings.jobStatusCompleted;
      case JobStatus.cancelled:
        return AppStrings.jobStatusCancelled;
      case JobStatus.rejected:
        return AppStrings.jobStatusRejected;
      case JobStatus.disputed:
        return AppStrings.jobStatusDisputed;
      case JobStatus.payoutProcessing:
        return 'Payout Processing';
      case JobStatus.paidOut:
        return 'Paid Out';
      case JobStatus.payoutFailed:
        return 'Payout Failed';
      case JobStatus.payoutHold:
        return 'Payout On Hold';
    }
  }

  Color _jobStatusColor(JobStatus status, BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    switch (status) {
      case JobStatus.inquiry:
        return Colors.blueAccent;
      case JobStatus.pending:
        return scheme.secondary;
      case JobStatus.awaitingPayment:
        return Colors.orange;
      case JobStatus.accepted:
        return scheme.primary;
      case JobStatus.inProgress:
        return scheme.primary;
      case JobStatus.inReview:
        return Colors.purple;
      case JobStatus.completed:
        return Colors.green;
      case JobStatus.cancelled:
        return Colors.orange;
      case JobStatus.rejected:
        return Colors.redAccent;
      case JobStatus.disputed:
        return Colors.orange;
      case JobStatus.payoutProcessing:
        return Colors.purple.shade300;
      case JobStatus.paidOut:
        return Colors.teal;
      case JobStatus.payoutFailed:
        return Colors.red;
      case JobStatus.payoutHold:
        return Colors.orange.shade900;
    }
  }

  String _escrowStatusLabel(EscrowStatus status) {
    switch (status) {
      case EscrowStatus.pending:
        return AppStrings.escrowStatusPending;
      case EscrowStatus.held:
        return AppStrings.escrowStatusHeld;
      case EscrowStatus.disputed:
        return AppStrings.escrowStatusDisputed;
      case EscrowStatus.released:
        return AppStrings.escrowStatusReleased;
      case EscrowStatus.refunded:
        return AppStrings.escrowStatusRefunded;
      case EscrowStatus.cancelled:
        return AppStrings.escrowStatusCancelled;
    }
  }

  Color _escrowStatusColor(EscrowStatus status) {
    switch (status) {
      case EscrowStatus.pending:
        return Colors.blueGrey;
      case EscrowStatus.held:
        return Colors.orange;
      case EscrowStatus.disputed:
        return Colors.deepOrange;
      case EscrowStatus.released:
        return Colors.green;
      case EscrowStatus.refunded:
        return Colors.redAccent;
      case EscrowStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatAmount(Job job) {
    return AppFormatters.formatAmount(
      job.hasAmountIssue || job.amount <= 0 ? null : job.amount,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildJobsSection(List<Job> jobs) {
    if (jobs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tiada job untuk dipaparkan.'),
        ),
      );
    }

    final Map<JobStatus, int> statusCounts = <JobStatus, int>{
      for (final status in JobStatus.values) status: 0,
    };
    for (final job in jobs) {
      statusCounts[job.status] = (statusCounts[job.status] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statusCounts.entries
                  .map(
                    (MapEntry<JobStatus, int> entry) => Chip(
                      label: Text(
                        '${_jobStatusLabel(entry.key)} (${entry.value})',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _jobStatusColor(entry.key, context),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            ...jobs.map((Job job) {
              final EscrowRecord? escrow = _escrowByJob[job.id];
              final String escrowLabel = escrow != null
                  ? _escrowStatusLabel(escrow.status)
                  : (_escrowError != null ? 'Tidak tersedia' : 'Tiada');
              final Color? escrowColor =
                  escrow != null ? _escrowStatusColor(escrow.status) : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.serviceTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text('Job ID: ${job.id}'),
                  Text('Client: ${job.clientId}'),
                  Text('Freelancer: ${job.freelancerId}'),
                  const SizedBox(height: 4),
                  Text('Jumlah: ${_formatAmount(job)}'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(_jobStatusLabel(job.status)),
                        backgroundColor: _jobStatusColor(job.status, context)
                            .withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _jobStatusColor(job.status, context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Chip(
                        label: Text('Escrow: $escrowLabel'),
                        backgroundColor: escrowColor?.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: escrowColor ?? Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (job.isDisputed && job.disputeReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Dispute: ${job.disputeReason}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.redAccent),
                      ),
                    ),
                  if (escrow != null && _escrowError == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildEscrowActions(job, escrow),
                    ),
                  const Divider(height: 24),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEscrowActions(Job job, EscrowRecord escrow) {
    final List<Widget> actions = <Widget>[];
    final jobStatus = job.status;

    // Hold: only from PENDING escrow status
    if (escrow.status == EscrowStatus.pending) {
      final canHold =
          {JobStatus.pending, JobStatus.accepted}.contains(jobStatus);
      actions.add(
        Tooltip(
          message: canHold
              ? 'Hold escrow untuk job ini'
              : 'Hold hanya untuk job PENDING/ACCEPTED',
          child: ElevatedButton.icon(
            onPressed: canHold
                ? () async {
                    final confirmed = await showConfirmationDialog(
                      context: context,
                      title: AppStrings.confirmEscrowActionTitle,
                      message: AppStrings.confirmEscrowHoldMessage,
                      confirmText: 'Hold',
                      isDangerous: false,
                    );
                    if (confirmed != true) return;
                    await _handleEscrowAction(
                      () => escrowRepository.hold(job.id),
                      job.id,
                    );
                  }
                : null,
            icon: const Icon(Icons.pause_circle, size: 16),
            label: const Text('Hold'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ),
      );
    }

    // Release & Refund: only from HELD escrow status
    if (escrow.status == EscrowStatus.held) {
      final canRelease =
          {JobStatus.completed, JobStatus.disputed}.contains(jobStatus);
      final canRefund = {
        JobStatus.cancelled,
        JobStatus.rejected,
        JobStatus.disputed,
      }.contains(jobStatus);

      actions.add(
        Tooltip(
          message: canRelease
              ? 'Lepaskan dana kepada freelancer'
              : 'Release untuk job COMPLETED/DISPUTED',
          child: ElevatedButton.icon(
            onPressed: canRelease
                ? () async {
                    final confirmed = await showConfirmationDialog(
                      context: context,
                      title: AppStrings.confirmEscrowActionTitle,
                      message: AppStrings.confirmEscrowReleaseMessage,
                      confirmText: 'Release',
                      isDangerous: true,
                    );
                    if (confirmed != true) return;
                    await _handleEscrowAction(
                      () => escrowRepository.release(job.id),
                      job.id,
                    );
                  }
                : null,
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Release'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ),
      );

      actions.add(const SizedBox(width: 8));

      actions.add(
        Tooltip(
          message: canRefund
              ? 'Pulangkan dana kepada client'
              : 'Refund untuk job CANCELLED/REJECTED/DISPUTED',
          child: ElevatedButton.icon(
            onPressed: canRefund
                ? () async {
                    final confirmed = await showConfirmationDialog(
                      context: context,
                      title: AppStrings.confirmEscrowActionTitle,
                      message: AppStrings.confirmEscrowRefundMessage,
                      confirmText: 'Refund',
                      isDangerous: true,
                    );
                    if (confirmed != true) return;
                    await _handleEscrowAction(
                      () => escrowRepository.refund(job.id),
                      job.id,
                    );
                  }
                : null,
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('Refund'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }

  Future<void> _handleEscrowAction(
    Future<EscrowRecord?> Function() action,
    String jobId,
  ) async {
    final user = await authRepository.getCurrentUser();
    if (user?.role.toUpperCase() != 'ADMIN') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya admin boleh mengubah escrow.')),
      );
      return;
    }
    try {
      final updated = await action();
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _escrowByJob[jobId] = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Escrow status dikemas kini: ${_escrowStatusLabel(updated.status)}'),
          ),
        );
        await _refreshDashboard();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat: $error')),
      );
    }
  }

  Widget _buildPaymentsSection() {
    if (_escrowError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _escrowError!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _refreshDashboard,
                child: const Text('Cuba semula'),
              ),
            ],
          ),
        ),
      );
    }

    if (_escrowRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_isEscrowLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Text(_isEscrowLoading ? 'Memuat status escrow...' : 'Tiada data'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _escrowRecords.map((EscrowRecord record) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job ${record.jobId}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  record.amount != null
                      ? 'Jumlah dipegang: RM${record.amount!.toStringAsFixed(2)}'
                      : 'Jumlah tidak tersedia',
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(_escrowStatusLabel(record.status)),
                      backgroundColor: _escrowStatusColor(record.status)
                          .withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _escrowStatusColor(record.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.updatedAt != null
                            ? 'Dikemas kini: ${record.updatedAt!.toLocal()}'
                            : 'Tarikh belum tersedia',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDisputesSection(List<Job> jobs) {
    final List<Job> disputes =
        jobs.where((Job job) => job.isDisputed).toList(growable: false);

    if (disputes.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tiada data'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: disputes.map((Job job) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.serviceTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('Job ID: ${job.id}'),
                Text('Client: ${job.clientId}'),
                Text('Freelancer: ${job.freelancerId}'),
                const SizedBox(height: 6),
                Text(
                  job.disputeReason ?? 'Tiada maklumat tambahan.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.redAccent),
                ),
                const Divider(height: 24),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: FutureBuilder<List<Job>>(
        future: _jobsFuture,
        builder: (BuildContext context, AsyncSnapshot<List<Job>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<Job> jobs = snapshot.data ?? <Job>[];

          return RefreshIndicator(
            onRefresh: _refreshDashboard,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildSectionTitle('Jobs'),
                if (snapshot.hasError)
                  Builder(
                    builder: (BuildContext context) {
                      final error = snapshot.error;
                      if (error is DioException) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          if (messenger != null) {
                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text(resolveDioErrorMessage(error))),
                            );
                          }
                        });
                      }
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Ralat memuat job.'),
                        ),
                      );
                    },
                  )
                else
                  _buildJobsSection(jobs),
                const SizedBox(height: 24),
                _buildSectionTitle('Payments'),
                _buildPaymentsSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Disputes'),
                _buildDisputesSection(jobs),
              ],
            ),
          );
        },
      ),
    );
  }
}
