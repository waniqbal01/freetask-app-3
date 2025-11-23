import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../models/job.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';
import '../auth/auth_repository.dart';
import 'jobs_repository.dart';
import 'widgets/job_status_badge.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({
    super.key,
    required this.jobId,
    this.initialJob,
    required this.isClientView,
  });

  final String jobId;
  final Job? initialJob;
  final bool isClientView;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _userRole;
  late bool _isClientView;

  @override
  void initState() {
    super.initState();
    _isClientView = widget.isClientView;
    _job = widget.initialJob;
    _hydrateUser();
    _loadJobIfNeeded();
  }

  Future<void> _hydrateUser() async {
    try {
      final user = await authRepository.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _userRole = user?.role;
        if (user != null) {
          _isClientView = user.role.toUpperCase() == 'CLIENT';
        }
      });
    } catch (_) {
      // best effort only
    }
  }

  Future<void> _loadJobIfNeeded() async {
    if (_job != null) return;
    await _fetchJob();
  }

  Future<void> _fetchJob() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final job = await jobsRepository.getJobById(widget.jobId);
      if (!mounted) return;
      if (job == null) {
        setState(() {
          _errorMessage = 'Job tidak ditemui atau telah dipadam.';
        });
      }
      setState(() {
        _job = job;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = resolveDioErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat maklumat job: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAction(
    Future<Job?> Function() action,
    String successMessage,
  ) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final updatedJob = await action();
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      if (updatedJob != null) {
        setState(() {
          _job = updatedJob;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } on JobStatusConflict catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      showErrorSnackBar(context, error.message);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      showErrorSnackBar(context, resolveDioErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      showErrorSnackBar(context, 'Ralat melaksanakan tindakan: $error');
    } finally {
      await _fetchJob();
    }
  }

  Future<String?> _promptDisputeReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nyatakan sebab dispute'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Contoh: Kerja tidak memenuhi skop.',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Hantar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) {
      return null;
    }
    return reason;
  }

  JobStatusVisual _statusVisual(JobStatus status) {
    return mapJobStatusVisual(status);
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Tarikh tidak tersedia';
    }

    return DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());
  }

  List<Widget> _buildActions(Job job) {
    final role = (_userRole ?? (_isClientView ? 'CLIENT' : 'FREELANCER')).toUpperCase();
    final actions = <Widget>[];

    if (role == 'FREELANCER') {
      if (job.status == JobStatus.pending) {
        actions.addAll([
          FTButton(
            label: 'Reject',
            isLoading: _isProcessing,
            onPressed: () => _handleAction(
              () => jobsRepository.rejectJob(job.id),
              'Job telah ditolak dan dikemas kini.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
          const SizedBox(width: AppSpacing.s8),
          FTButton(
            label: 'Accept',
            isLoading: _isProcessing,
            onPressed: () => _handleAction(
              () => jobsRepository.acceptJob(job.id),
              'Job diterima. Anda boleh mulakan apabila bersedia.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
        ]);
      } else if (job.status == JobStatus.accepted) {
        actions.add(
          FTButton(
            label: 'Start',
            isLoading: _isProcessing,
            onPressed: () => _handleAction(
              () => jobsRepository.startJob(job.id),
              'Job dimulakan! Status kini In Progress.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
        );
      } else if (job.status == JobStatus.inProgress) {
        actions.addAll([
          FTButton(
            label: 'Complete',
            isLoading: _isProcessing,
            onPressed: () => _handleAction(
              () => jobsRepository.markCompleted(job.id),
              'Job ditandakan selesai. Status kini Completed.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
          const SizedBox(width: AppSpacing.s8),
          FTButton(
            label: 'Dispute',
            isLoading: _isProcessing,
            onPressed: () async {
              final reason = await _promptDisputeReason();
              if (reason == null) return;
              await _handleAction(
                () => jobsRepository.disputeJob(job.id, reason),
                'Dispute dihantar.',
              );
            },
            expanded: false,
            size: FTButtonSize.small,
          ),
        ]);
      }
    }

    if (role == 'CLIENT') {
      if (job.status == JobStatus.pending) {
        actions.add(
          FTButton(
            label: 'Batalkan',
            isLoading: _isProcessing,
            onPressed: () => _handleAction(
              () => jobsRepository.cancelJob(job.id),
              'Job dibatalkan.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
        );
      } else if (job.status == JobStatus.inProgress || job.status == JobStatus.completed) {
        actions.add(
          FTButton(
            label: 'Dispute',
            isLoading: _isProcessing,
            onPressed: () async {
              final reason = await _promptDisputeReason();
              if (reason == null) return;
              await _handleAction(
                () => jobsRepository.disputeJob(job.id, reason),
                'Dispute dihantar.',
              );
            },
            expanded: false,
            size: FTButtonSize.small,
          ),
        );
      }
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final job = _job;

    Widget body;

    if (_isLoading && job == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null && job == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.s12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s16),
              FTButton(
                label: 'Cuba lagi',
                onPressed: _fetchJob,
                expanded: false,
              ),
            ],
          ),
        ),
      );
    } else if (job != null) {
      final statusVisual = _statusVisual(job.status);
      final actions = _buildActions(job);

      body = SafeArea(
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
                    style:
                        textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
                        if (actions.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.s8),
                          Wrap(
                            spacing: AppSpacing.s8,
                            runSpacing: AppSpacing.s8,
                            children: actions,
                          ),
                        ],
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
                      label: _isClientView ? 'Freelancer ID' : 'Client ID',
                      value: _isClientView ? job.freelancerId : job.clientId,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = const SizedBox.shrink();
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
        child: Stack(
          children: [
            body,
            if (_isProcessing) ...[
              const LoadingOverlay(
                message: 'Memproses tindakan...',
                backgroundOpacity: 0.3,
              ),
            ],
          ],
        ),
      ),
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
