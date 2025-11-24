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
import '../escrow/escrow_policy.dart';
import '../escrow/escrow_repository.dart';
import 'job_constants.dart';
import 'jobs_repository.dart';
import 'job_transition_rules.dart';
import 'widgets/job_status_badge.dart';

bool resolveClientViewMode({bool? navigationFlag, String? role}) {
  if (navigationFlag != null) {
    return navigationFlag;
  }

  return role?.toUpperCase() == 'CLIENT';
}

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({
    super.key,
    required this.jobId,
    this.initialJob,
    this.isClientView,
  });

  final String jobId;
  final Job? initialJob;
  final bool? isClientView;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  bool _isLoading = false;
  bool _isProcessing = false;
  bool _isEscrowProcessing = false;
  bool _isEscrowLoading = false;
  String? _errorMessage;
  String? _escrowError;
  EscrowRecord? _escrow;
  String? _userRole;
  String? _userId;
  bool _isUserLoading = true;
  late bool _isClientView;

  @override
  void initState() {
    super.initState();
    _isClientView = resolveClientViewMode(
      navigationFlag: widget.isClientView,
      role: null,
    );
    _job = widget.initialJob;
    _hydrateUser();
    _loadJobIfNeeded();
    _fetchEscrow();
  }

  Future<void> _hydrateUser() async {
    setState(() {
      _isUserLoading = true;
    });
    try {
      final user = await authRepository.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _userRole = user?.role;
        _userId = user?.id;
        _isClientView = resolveClientViewMode(
          navigationFlag: widget.isClientView,
          role: user?.role,
        );
      });
    } catch (_) {
      // best effort only
    } finally {
      if (mounted) {
        setState(() {
          _isUserLoading = false;
        });
      }
    }
  }

  Future<void> _loadJobIfNeeded() async {
    if (_job != null) return;
    await _fetchJob();
  }

  Future<void> _fetchEscrow() async {
    setState(() {
      _isEscrowLoading = true;
      _escrowError = null;
    });

    try {
      final record = await escrowRepository.getEscrow(widget.jobId);
      if (!mounted) return;
      setState(() {
        _escrow = record;
      });
    } on EscrowUnavailable catch (error) {
      if (!mounted) return;
      setState(() {
        _escrow = null;
        _escrowError = error.message;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _escrowError = resolveDioErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _escrowError = 'Gagal memuat escrow: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEscrowLoading = false;
        });
      }
    }
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
      await _fetchEscrow();
    } on DioException catch (error) {
      if (!mounted) return;
      final status = error.response?.statusCode;
      setState(() {
        _errorMessage = (status == 403 || status == 404)
            ? 'Admin access blocked atau job tidak sah.'
            : resolveDioErrorMessage(error);
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
      showErrorSnackBar(context, error.message);
    } on DioException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, resolveDioErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Ralat melaksanakan tindakan: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      await _fetchJob();
    }
  }

  Future<void> _guardedJobAction({
    required bool allowed,
    required Future<Job?> Function() action,
    required String successMessage,
    String blockedMessage = 'Status semasa tidak membenarkan tindakan ini.',
  }) async {
    if (!allowed) {
      if (!mounted) return;
      showErrorSnackBar(context, blockedMessage);
      return;
    }

    await _handleAction(action, successMessage);
  }

  Future<void> _handleEscrowAction(
    Future<EscrowRecord?> Function() action,
    String successMessage,
  ) async {
    if (_isEscrowProcessing) return;
    setState(() {
      _isEscrowProcessing = true;
      _escrowError = null;
    });

    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _escrow = updated ?? _escrow;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on EscrowUnavailable catch (error) {
      if (!mounted) return;
      setState(() {
        _escrowError = error.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _escrowError = resolveDioErrorMessage(error);
      });
      showErrorSnackBar(context, resolveDioErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _escrowError = 'Ralat escrow: $error';
      });
      showErrorSnackBar(context, 'Ralat escrow: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isEscrowProcessing = false;
        });
      }
      await _fetchEscrow();
    }
  }

  Future<String?> _promptDisputeReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final trimmed = controller.text.trim();
            final isValid = trimmed.length >= jobMinDisputeReasonLen;
            final helper = '${trimmed.length}/$jobMinDisputeReasonLen aksara';

            return AlertDialog(
              title: const Text('Nyatakan sebab dispute'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Kerja tidak memenuhi skop.',
                      errorText: controller.text.isEmpty || isValid
                          ? null
                          : 'Minimum $jobMinDisputeReasonLen aksara diperlukan.',
                      helperText: helper,
                    ),
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed:
                      isValid ? () => Navigator.of(context).pop(trimmed) : null,
                  child: const Text('Hantar'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
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

  String _formatAmount(Job job) {
    if (job.hasAmountIssue || job.amount <= 0) {
      return 'Jumlah tidak sah / sila refresh';
    }
    return 'RM${job.amount.toStringAsFixed(2)}';
  }

  String _escrowStatusLabel(EscrowStatus? status) {
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
      default:
        return '—';
    }
  }

  Color _escrowStatusColor(EscrowStatus? status) {
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
      default:
        return Colors.grey;
    }
  }

  List<Widget> _buildActions(Job job) {
    if (_isUserLoading || _userRole == null) {
      return const <Widget>[];
    }
    final textTheme = Theme.of(context).textTheme;
    final role = _userRole!.toUpperCase();
    final isJobClient = _userId != null && job.clientId == _userId;
    final isJobFreelancer = _userId != null && job.freelancerId == _userId;
    final status = job.status;
    final actions = <Widget>[];

    if (role == 'FREELANCER' && isJobFreelancer) {
      final canAccept = canFreelancerAccept(status);
      final canReject = canFreelancerReject(status);
      final canStart = canFreelancerStart(status);
      final canComplete = canFreelancerComplete(status);
      final canDispute = canRaiseDispute(status);

      if (canReject) {
        actions.add(
          FTButton(
            label: 'Reject',
            isLoading: _isProcessing,
            onPressed: () => _guardedJobAction(
              allowed: canReject,
              action: () => jobsRepository.rejectJob(job.id),
              successMessage: 'Job telah ditolak dan dikemas kini.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
        );
      }

      if (canAccept) {
        if (actions.isNotEmpty) {
          actions.add(const SizedBox(width: AppSpacing.s8));
        }
        actions.add(
          FTButton(
            label: 'Accept',
            isLoading: _isProcessing,
            onPressed: () => _guardedJobAction(
              allowed: canAccept,
              action: () => jobsRepository.acceptJob(job.id),
              successMessage: 'Job diterima. Anda boleh mulakan apabila bersedia.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
        );
      }

      if (canStart) {
        actions.add(
          FTButton(
            label: 'Start',
            isLoading: _isProcessing,
            onPressed: () => _guardedJobAction(
              allowed: canStart,
              action: () => jobsRepository.startJob(job.id),
              successMessage: 'Job dimulakan! Status kini In Progress.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
        );
      }

      if (canComplete) {
        actions.add(
          FTButton(
            label: 'Complete',
            isLoading: _isProcessing,
            onPressed: () => _guardedJobAction(
              allowed: canComplete,
              action: () => jobsRepository.markCompleted(job.id),
              successMessage: 'Job ditandakan selesai. Status kini Completed.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
        );
      }

      if (canDispute) {
        if (actions.isNotEmpty) {
          actions.add(const SizedBox(width: AppSpacing.s8));
        }
        actions.add(
          FTButton(
            label: 'Dispute',
            isLoading: _isProcessing,
            onPressed: () async {
              final reason = await _promptDisputeReason();
              if (reason == null) return;
              await _guardedJobAction(
                allowed: canDispute,
                action: () => jobsRepository.disputeJob(job.id, reason),
                successMessage: 'Dispute dihantar.',
              );
            },
            expanded: false,
            size: FTButtonSize.small,
          ),
        );
      }
    }

    if (role == 'CLIENT' && isJobClient) {
      final canCancel = canClientCancel(status);
      final canDispute = canRaiseDispute(status);

      if (canCancel) {
        actions.add(
          FTButton(
            label: 'Batalkan',
            isLoading: _isProcessing,
            onPressed: () => _guardedJobAction(
              allowed: canCancel,
              action: () => jobsRepository.cancelJob(job.id),
              successMessage: 'Job dibatalkan.',
            ),
            expanded: false,
            size: FTButtonSize.small,
          ),
        );
      }

      if (canDispute) {
        actions.add(Text(
          'Hanya freelancer boleh buat dispute.',
          style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
        ));
      }
    }

    return actions;
  }

  Widget _buildEscrowSection(TextTheme textTheme) {
    final isAdmin = canMutateEscrow(_userRole);
    final record = _escrow;
    final statusLabel = _escrowStatusLabel(record?.status);
    final statusColor = _escrowStatusColor(record?.status);
    final bool isEscrowUnavailable = _escrowError != null;
    final jobStatus = _job?.status;
    final bool showActions = isAdmin && !isEscrowUnavailable && !_isEscrowLoading;
    final List<Widget> actions = <Widget>[];

    Widget escrowButton({
      required String label,
      required bool enabled,
      required VoidCallback onPressed,
      required String disabledReason,
    }) {
      final button = FTButton(
        label: label,
        size: FTButtonSize.small,
        expanded: false,
        isLoading: _isEscrowProcessing,
        onPressed: enabled ? onPressed : null,
      );

      if (enabled) return button;
      return Tooltip(message: disabledReason, child: button);
    }

    final holdAllowedStatuses =
        {JobStatus.pending, JobStatus.accepted, JobStatus.inProgress}.contains(jobStatus);
    final releaseAllowedStatuses =
        {JobStatus.completed, JobStatus.disputed}.contains(jobStatus);
    final refundAllowedStatuses = {
      JobStatus.cancelled,
      JobStatus.rejected,
      JobStatus.disputed,
      JobStatus.completed,
      JobStatus.accepted,
    }.contains(jobStatus);

    if (showActions) {
      if (record?.status == EscrowStatus.pending) {
        final enabled = holdAllowedStatuses && jobStatus != null;
        final reason = jobStatus == null
            ? 'Status job belum dimuat.'
            : holdAllowedStatuses
                ? 'Escrow boleh dipegang sekarang.'
                : 'Hold hanya dibenarkan ketika job Pending/Accepted/In Progress.';
        actions.add(
          escrowButton(
            label: 'Hold',
            enabled: enabled,
            disabledReason: reason,
            onPressed: () => _handleEscrowAction(
              () => escrowRepository.hold(widget.jobId),
              'Dana dipegang untuk job ${widget.jobId}.',
            ),
          ),
        );
      }
      if (record?.status == EscrowStatus.held) {
        final releaseEnabled = releaseAllowedStatuses && jobStatus != null;
        final refundEnabled = refundAllowedStatuses && jobStatus != null;
        final releaseReason = jobStatus == null
            ? 'Status job belum dimuat.'
            : releaseAllowedStatuses
                ? 'Boleh dilepaskan apabila job selesai/dispute.'
                : 'Release hanya dibenarkan selepas job selesai atau dispute.';
        final refundReason = jobStatus == null
            ? 'Status job belum dimuat.'
            : refundAllowedStatuses
                ? 'Boleh refund untuk job dibatalkan/ditolak/dispute.'
                : 'Refund hanya dibenarkan apabila job dibatalkan, dispute, atau ditolak.';
        actions.addAll([
          escrowButton(
            label: 'Release',
            enabled: releaseEnabled,
            disabledReason: releaseReason,
            onPressed: () => _handleEscrowAction(
              () => escrowRepository.release(widget.jobId),
              'Dana dilepaskan.',
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          escrowButton(
            label: 'Refund',
            enabled: refundEnabled,
            disabledReason: refundReason,
            onPressed: () => _handleEscrowAction(
              () => escrowRepository.refund(widget.jobId),
              'Dana dipulangkan.',
            ),
          ),
        ]);
      }
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Escrow',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (_isEscrowLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              Chip(
                label: Text(statusLabel),
                backgroundColor: statusColor.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Chip(
                label: Text(
                  record?.amount != null
                      ? 'Jumlah: RM${record!.amount!.toStringAsFixed(2)}'
                      : 'Jumlah belum tersedia',
                ),
              ),
            ],
          ),
          if (_escrowError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: AppRadius.smallRadius,
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline, color: Colors.orange, size: 18),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        _escrowError!,
                        style: textTheme.bodyMedium?.copyWith(color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_escrowError == null && !isAdmin)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Text(
                'Escrow actions hanya untuk admin.',
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
            ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: actions,
            ),
          ]
        ],
      ),
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Kembali'),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  FTButton(
                    label: 'Cuba lagi',
                    onPressed: _fetchJob,
                    expanded: false,
                  ),
                ],
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
                        if (_isUserLoading) ...[
                          const SizedBox(width: AppSpacing.s8),
                          const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ] else if (actions.isNotEmpty) ...[
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
                      value: _formatAmount(job),
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
              const SizedBox(height: AppSpacing.s16),
              _buildEscrowSection(textTheme),
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
            if (_isProcessing || _isEscrowProcessing) ...[
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
