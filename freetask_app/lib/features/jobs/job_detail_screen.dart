import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/job.dart';
import '../../models/job_history.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';
import 'jobs_repository.dart';
import 'widgets/job_status_badge.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.job, required this.isClientView});

  final Job job;
  final bool isClientView;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Job _job;
  bool _isAccepting = false;
  int _historyReloadKey = 0;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
  }

  JobStatusVisual get _statusVisual => mapJobStatusVisual(_job.status);

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Tarikh tidak tersedia';
    }

    return DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());
  }

  Future<void> _handleAccept(BuildContext context) async {
    if (_isAccepting || _job.status != JobStatus.pending) {
      return;
    }
    setState(() {
      _isAccepting = true;
    });

    try {
      final updatedJob = await jobsRepository.acceptJob(_job.id);
      if (!mounted) return;
      setState(() {
        _job = updatedJob;
        _isAccepting = false;
        _historyReloadKey++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job accepted successfully.')),
      );
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _isAccepting = false;
      });
      showErrorSnackBar(context, error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAccepting = false;
      });
      showErrorSnackBar(context, 'Gagal menerima job. Cuba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final statusVisual = _statusVisual;
    final isClientView = widget.isClientView;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF3FC), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      'Maklumat Job',
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusVisual.color.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              statusVisual.icon,
                              color: statusVisual.color,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _job.serviceTitle,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.neutral900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                JobStatusBadge(visual: statusVisual),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      const Divider(),
                      const SizedBox(height: AppSpacing.s12),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Tarikh / Masa',
                        value: _formatDate(_job.createdAt),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.title_outlined,
                        label: 'Tajuk Job',
                        value: _job.title,
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.notes_outlined,
                        label: 'Deskripsi',
                        value: _job.description.isNotEmpty
                            ? _job.description
                            : 'Tiada deskripsi',
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Service ID',
                        value: _job.serviceId,
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        label: 'Jumlah',
                        value: 'RM${_job.amount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: isClientView ? 'Freelancer' : 'Client',
                        value: isClientView
                            ? (_job.freelancerName.isNotEmpty
                                ? '${_job.freelancerName} (ID: ${_job.freelancerId})'
                                : _job.freelancerId)
                            : (_job.clientName.isNotEmpty
                                ? '${_job.clientName} (ID: ${_job.clientId})'
                                : _job.clientId),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Job ID',
                        value: _job.id,
                      ),
                      if (_job.isDisputed) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: AppRadius.mediumRadius,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dispute',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _job.disputeReason ?? 'Tiada maklumat tambahan.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s16),
                      if (isClientView && _job.status == JobStatus.pending) ...[
                        FTButton(
                          label: 'Accept Job',
                          onPressed: () => _handleAccept(context),
                          isLoading: _isAccepting,
                          expanded: true,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                      ],
                      const Divider(),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        'Timeline Aktiviti',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      _JobHistoryTimeline(
                        key: ValueKey(_historyReloadKey),
                        jobId: _job.id,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JobHistoryTimeline extends StatelessWidget {
  const _JobHistoryTimeline({super.key, required this.jobId});

  final String jobId;

  String _actionLabel(JobHistory history) {
    switch (history.action) {
      case 'JOB_CREATED':
        return 'Job dicipta';
      case 'JOB_ACCEPTED':
        return 'Job diterima';
      case 'JOB_STARTED':
        return 'Kerja bermula';
      case 'JOB_COMPLETED':
        return 'Job ditandakan selesai';
      case 'JOB_DISPUTED':
        return 'Pertikaian dibuka';
      case 'JOB_RESOLVED_ADMIN':
        return 'Diselesaikan oleh admin';
      case 'JOB_REJECTED':
        return 'Job ditolak/batal';
      default:
        return history.action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<List<JobHistory>>(
      future: jobsRepository.getJobHistory(jobId),
      builder: (BuildContext context, AsyncSnapshot<List<JobHistory>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text(
            'Gagal memuatkan timeline.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
          );
        }

        final histories = snapshot.data ?? <JobHistory>[];
        if (histories.isEmpty) {
          return Text(
            'Tiada aktiviti direkodkan lagi.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.neutral500),
          );
        }

        return Column(
          children: histories.map((history) {
            final label = _actionLabel(history);
            final timestamp = DateFormat('dd MMM yyyy, h:mm a').format(history.createdAt.toLocal());
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timestamp,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.neutral500),
                        ),
                        if (history.message?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(history.message!, style: textTheme.bodyMedium),
                        ],
                        if (history.actorName?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Oleh: ${history.actorName}',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.neutral500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
