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
  const JobDetailScreen({
    super.key,
    required this.jobId,
    required this.isClientView,
    this.job,
  });

  final String jobId;
  final Job? job;
  final bool isClientView;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  bool _isLoading = false;
  bool _isProcessingAction = false;
  String? _errorMessage;
  int _historyReloadKey = 0;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    if (_job == null && widget.jobId.isNotEmpty) {
      _loadJob();
    } else if (_job == null && widget.jobId.isEmpty) {
      _errorMessage = 'Maklumat job tidak tersedia. Sila kembali ke senarai job.';
    }
  }

  JobStatusVisual get _statusVisual =>
      mapJobStatusVisual(_job?.status ?? JobStatus.pending);

  Future<void> _loadJob() async {
    if (widget.jobId.isEmpty) {
      setState(() {
        _errorMessage = 'Maklumat job tidak tersedia. Sila kembali ke senarai job.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetched = await jobsRepository.getJobById(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = fetched;
        _isLoading = false;
        _historyReloadKey++;
        _errorMessage = fetched == null
            ? 'Job tidak ditemui. Sila buka semula daripada senarai job.'
            : null;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuatkan job. Cuba lagi.';
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Tarikh tidak tersedia';
    }

    return DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());
  }

  List<Widget> _buildActionButtons(Job job, bool isClientView) {
    final List<Widget> actions = <Widget>[];
    final canAccept = isClientView && job.status == JobStatus.pending;
    final canReject = !isClientView && job.status == JobStatus.pending;
    final canStart = !isClientView && job.status == JobStatus.accepted;
    final canComplete = job.status == JobStatus.inProgress;
    final canDispute = <JobStatus>{
      JobStatus.accepted,
      JobStatus.inProgress,
      JobStatus.completed,
    }.contains(job.status);

    if (canAccept) {
      actions.add(
        FTButton(
          label: 'Accept Job',
          isLoading: _isProcessingAction,
          onPressed: () => _performJobUpdate(
            () => jobsRepository.acceptJob(job.id),
            'Job diterima. Freelancer boleh mula bekerja.',
          ),
          expanded: true,
        ),
      );
    }

    if (canReject) {
      actions.add(
        FTButton(
          label: 'Reject Job',
          isLoading: _isProcessingAction,
          onPressed: () => _performJobUpdate(
            () => jobsRepository.rejectJob(job.id),
            'Job telah ditolak.',
          ),
          expanded: true,
          type: FTButtonType.secondary,
        ),
      );
    }

    if (canStart) {
      actions.add(
        FTButton(
          label: 'Start Job',
          isLoading: _isProcessingAction,
          onPressed: () => _performJobUpdate(
            () => jobsRepository.startJob(job.id),
            'Job dimulakan! Status kini In Progress.',
          ),
          expanded: true,
        ),
      );
    }

    if (canComplete && canDispute) {
      actions.add(
        Row(
          children: [
            Expanded(
              child: FTButton(
                label: 'Raise Dispute',
                isLoading: _isProcessingAction,
                onPressed: _promptDispute,
                type: FTButtonType.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: FTButton(
                label: 'Mark as Completed',
                isLoading: _isProcessingAction,
                onPressed: () => _performJobUpdate(
                  () => jobsRepository.markCompleted(job.id),
                  'Job ditandakan selesai.',
                ),
              ),
            ),
          ],
        ),
      );
    } else if (canDispute) {
      actions.add(
        FTButton(
          label: 'Raise Dispute',
          isLoading: _isProcessingAction,
          onPressed: _promptDispute,
          expanded: true,
          type: FTButtonType.secondary,
        ),
      );
    }

    if (actions.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      const SizedBox(height: AppSpacing.s16),
      ...actions.expand<Widget>((Widget button) => <Widget>[button, const SizedBox(height: AppSpacing.s12)]),
    ];
  }

  Future<void> _performJobUpdate(
    Future<Job> Function() action,
    String successMessage,
  ) async {
    if (_isProcessingAction) return;
    setState(() {
      _isProcessingAction = true;
    });

    try {
      final updatedJob = await action();
      if (!mounted) return;
      setState(() {
        _job = updatedJob;
        _historyReloadKey++;
        _isProcessingAction = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessingAction = false;
      });
      showErrorSnackBar(context, error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessingAction = false;
      });
      showErrorSnackBar(context, 'Tindakan tidak berjaya. Cuba lagi.');
    }
  }

  Future<void> _promptDispute() async {
    final job = _job;
    if (job == null) return;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Buka Dispute'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Sebab',
                hintText: 'Terangkan isu yang dialami...',
              ),
              maxLength: 280,
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Sila masukkan sebab.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Hantar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _performJobUpdate(
        () => jobsRepository.setDispute(job.id, controller.text.trim()),
        'Dispute dibuka untuk job ini.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final statusVisual = _statusVisual;
    final isClientView = widget.isClientView;

    final job = _job;
    if (job == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Maklumat Job'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.s12),
                  const Text('Memuatkan maklumat job...'),
                ] else ...[
                  const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    _errorMessage ??
                        'Maklumat job tidak tersedia. Sila buka job melalui senarai Job.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  if (widget.jobId.isNotEmpty)
                    FTButton(
                      label: 'Cuba Semula',
                      onPressed: _loadJob,
                      expanded: false,
                    ),
                  if (widget.jobId.isEmpty)
                    FTButton(
                      label: 'Kembali ke Senarai Job',
                      onPressed: () => Navigator.of(context).maybePop(),
                      expanded: false,
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    }

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
                                job.serviceTitle,
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
                        value: _formatDate(job.createdAt),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.title_outlined,
                        label: 'Tajuk Job',
                        value: job.title,
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.notes_outlined,
                        label: 'Deskripsi',
                        value: job.description.isNotEmpty
                            ? job.description
                            : 'Tiada deskripsi',
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Service ID',
                        value: job.serviceId,
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        label: 'Jumlah',
                        value: 'RM${job.amount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: isClientView ? 'Freelancer' : 'Client',
                        value: isClientView
                            ? (job.freelancerName.isNotEmpty
                                ? '${job.freelancerName} (ID: ${job.freelancerId})'
                                : job.freelancerId)
                            : (job.clientName.isNotEmpty
                                ? '${job.clientName} (ID: ${job.clientId})'
                                : job.clientId),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Job ID',
                        value: job.id,
                      ),
                      if (job.isDisputed) ...[
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
                                job.disputeReason ?? 'Tiada maklumat tambahan.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      ..._buildActionButtons(job, isClientView),
                      const Divider(),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        'Timeline Aktiviti',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      _JobHistoryTimeline(
                        key: ValueKey(_historyReloadKey),
                        jobId: job.id,
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
