import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../jobs/jobs_repository.dart';
import '../escrow/escrow_repository.dart';
import '../../core/utils/error_utils.dart';
import '../auth/auth_repository.dart';

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
        showErrorSnackBar(context, 'Admin only');
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
        _escrowError = 'Gagal memuat escrow: $error';
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
      case JobStatus.pending:
        return 'Booked';
      case JobStatus.accepted:
        return 'Accepted';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
      case JobStatus.rejected:
        return 'Rejected';
      case JobStatus.disputed:
        return 'Disputed';
    }
  }

  Color _jobStatusColor(JobStatus status, BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    switch (status) {
      case JobStatus.pending:
        return scheme.secondary;
      case JobStatus.accepted:
        return scheme.primary;
      case JobStatus.inProgress:
        return scheme.primary;
      case JobStatus.completed:
        return Colors.green;
      case JobStatus.cancelled:
        return Colors.orange;
      case JobStatus.rejected:
        return Colors.redAccent;
      case JobStatus.disputed:
        return Colors.orange;
    }
  }

  String _escrowStatusLabel(EscrowStatus status) {
    switch (status) {
      case EscrowStatus.pending:
        return 'Pending';
      case EscrowStatus.held:
        return 'Held';
      case EscrowStatus.disputed:
        return 'Disputed';
      case EscrowStatus.released:
        return 'Released';
      case EscrowStatus.refunded:
        return 'Refunded';
      case EscrowStatus.cancelled:
        return 'Cancelled';
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
    if (job.hasAmountIssue || job.amount <= 0) {
      return 'Jumlah tidak sah / sila refresh';
    }
    return 'RM${job.amount.toStringAsFixed(2)}';
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
                  const Divider(height: 24),
                ],
              );
            }),
          ],
        ),
      ),
    );
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
                      backgroundColor:
                          _escrowStatusColor(record.status).withValues(alpha: 0.15),
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
                              SnackBar(content: Text(resolveDioErrorMessage(error))),
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
