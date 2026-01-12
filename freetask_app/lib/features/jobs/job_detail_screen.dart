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
    this.fromCheckout, // UX-C-05: Flag to show success banner
  });

  final String jobId;
  final Job? initialJob;
  final bool? isClientView;
  final bool? fromCheckout;

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
  bool _showSuccessBanner = false; // UX-C-05: Track if from checkout

  @override
  void initState() {
    super.initState();
    _isClientView = resolveClientViewMode(
      navigationFlag: widget.isClientView,
      role: null,
    );
    _job = widget.initialJob;
    _showSuccessBanner = widget.fromCheckout == true; // UX-C-05
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

    if (!canMutateEscrow(_userRole)) {
      if (mounted) {
        showErrorSnackBar(context, 'Hanya admin boleh mengubah status escrow.');
      }
      setState(() {
        _isEscrowProcessing = false;
      });
      return;
    }

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
            final helper =
                '${trimmed.length}/$jobMaxDisputeReasonLen aksara (min $jobMinDisputeReasonLen)';

            return AlertDialog(
              title: const Text('Nyatakan sebab dispute'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kongsikan ringkasan jelas tentang isu. Sertakan fakta penting tetapi elak maklumat sensitif.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Kerja tidak memenuhi skop.',
                      errorText: controller.text.isEmpty || isValid
                          ? null
                          : 'Minimum $jobMinDisputeReasonLen aksara diperlukan.',
                      helperText: helper,
                    ),
                    maxLength: jobMaxDisputeReasonLen,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.neutral600,
                  ),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed:
                      isValid ? () => Navigator.of(context).pop(trimmed) : null,
                  child: const Text('Hantar Dispute'),
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
    final role = _userRole!.toUpperCase();
    final isJobClient = _userId != null && job.clientId == _userId;
    final isJobFreelancer = _userId != null && job.freelancerId == _userId;
    // status is already available from job object

    final actions = <Widget>[];

    if (role == 'FREELANCER' && isJobFreelancer) {
      if (job.status == JobStatus.pending) {
        actions.add(FTButton(
            label: 'Accept',
            onPressed: () => _guardedJobAction(
                allowed: true,
                action: () => jobsRepository.acceptJob(job.id),
                successMessage: 'Job accepted'),
            size: FTButtonSize.small,
            expanded: false,
            isLoading: _isProcessing));
        actions.add(const SizedBox(width: 8));
        actions.add(FTButton(
            label: 'Reject',
            onPressed: () => _guardedJobAction(
                allowed: true,
                action: () => jobsRepository.rejectJob(job.id),
                successMessage: 'Job rejected'),
            size: FTButtonSize.small,
            isLoading: _isProcessing,
            expanded: false,
            variant: FTButtonVariant.outline));
      } else if (job.status == JobStatus.accepted) {
        actions.add(FTButton(
            label: 'Start Job',
            onPressed: () => _guardedJobAction(
                allowed: true,
                action: () => jobsRepository.startJob(job.id),
                successMessage: 'Job started'),
            size: FTButtonSize.small,
            expanded: false,
            isLoading: _isProcessing));
      } else if (job.status == JobStatus.inProgress) {
        actions.add(FTButton(
            label: 'Submit Work',
            onPressed: () => _showSubmitDialog(job),
            size: FTButtonSize.small,
            expanded: false,
            isLoading: _isProcessing));
        actions.add(const SizedBox(width: 8));
        actions.add(FTButton(
            label: 'Dispute',
            onPressed: _handleDispute,
            size: FTButtonSize.small,
            isLoading: _isProcessing,
            expanded: false,
            variant: FTButtonVariant.outline));
      }
    } else if (role == 'CLIENT' && isJobClient) {
      if (job.status == JobStatus.inReview) {
        actions.add(FTButton(
            label: 'Confirm Completion',
            onPressed: () => _guardedJobAction(
                allowed: true,
                action: () => jobsRepository.confirmJob(job.id),
                successMessage: 'Job confirmed'),
            size: FTButtonSize.small,
            expanded: false,
            isLoading: _isProcessing));
        actions.add(const SizedBox(width: 8));
        actions.add(FTButton(
            label: 'Request Revision',
            onPressed: () => _showRevisionDialog(job),
            size: FTButtonSize.small,
            isLoading: _isProcessing,
            expanded: false,
            variant: FTButtonVariant.outline));
      }
      // Add other client actions like Cancel/Dispute
      if (canClientCancel(job.status)) {
        if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
        actions.add(FTButton(
            label: 'Cancel',
            onPressed: () => _guardedJobAction(
                allowed: true,
                action: () => jobsRepository.cancelJob(job.id),
                successMessage: 'Job cancelled'),
            size: FTButtonSize.small,
            isLoading: _isProcessing,
            expanded: false,
            variant: FTButtonVariant.outline));
      }
      if (canRaiseDispute(job.status) && job.status != JobStatus.inReview) {
        // Prevent duplicate dispute button in review? No, allow it.
        if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
        actions.add(FTButton(
            label: 'Dispute',
            onPressed: _handleDispute,
            size: FTButtonSize.small,
            isLoading: _isProcessing,
            expanded: false,
            variant: FTButtonVariant.outline));
      }
    }

    return actions;
  }

  void _handleDispute() async {
    final reason = await _promptDisputeReason();
    if (reason == null) return;
    _guardedJobAction(
      allowed: true,
      action: () => jobsRepository.disputeJob(_job!.id, reason),
      successMessage: 'Dispute sent',
    );
  }

  Future<void> _showSubmitDialog(Job job) async {
    final messageController = TextEditingController();
    List<String> attachments = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Submit Work'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                        labelText: 'Message / Description',
                        hintText: 'Describe your work...'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  if (attachments.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: attachments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final url = entry.value;
                        return Chip(
                          label: Text(
                            url.length > 20
                                ? '${url.substring(0, 20)}...'
                                : url,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: () {
                            setState(() {
                              attachments.removeAt(index);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      final urlController = TextEditingController();
                      final url = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Add Link'),
                          content: TextField(
                            controller: urlController,
                            decoration: const InputDecoration(
                              labelText: 'URL',
                              hintText: 'https://...',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, urlController.text),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      );
                      if (url != null && url.trim().isNotEmpty) {
                        setState(() {
                          attachments.add(url.trim());
                        });
                      }
                    },
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Add Link'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _guardedJobAction(
                          allowed: true,
                          action: () => jobsRepository.submitJob(
                              job.id, messageController.text,
                              attachments:
                                  attachments.isNotEmpty ? attachments : null),
                          successMessage: 'Work submitted for review');
                    },
                    child: const Text('Submit')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRevisionDialog(Job job) async {
    final reasonController = TextEditingController();
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Request Revision'),
              content: TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                    labelText: 'Revision Details',
                    hintText: 'What needs to be changed?'),
                maxLines: 3,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () async {
                      if (reasonController.text.trim().isEmpty) return;
                      Navigator.pop(context);
                      await _guardedJobAction(
                          allowed: true,
                          action: () => jobsRepository.requestRevision(
                              job.id, reasonController.text),
                          successMessage: 'Revision requested');
                    },
                    child: const Text('Request')),
              ],
            ));
  }

  Widget? _buildBottomActionBar(Job job) {
    if (_isUserLoading || _userRole == null || _userId == null) {
      return null;
    }

    final role = _userRole!.toUpperCase();
    final isJobClient = job.clientId == _userId;
    final isJobFreelancer = job.freelancerId == _userId;

    final expectedRole = _isClientView ? 'CLIENT' : 'FREELANCER';
    if (role != expectedRole) {
      return const _ActionBarLabel(
        text: 'Mod paparan read-only. Tukar role untuk tindakan.',
      );
    }

    if (role == 'FREELANCER' && isJobFreelancer) {
      if (canFreelancerAccept(job.status)) {
        return _ActionBarButton(
          label: 'Accept Job',
          isLoading: _isProcessing,
          onPressed: () => _guardedJobAction(
            allowed: true,
            action: () => jobsRepository.acceptJob(job.id),
            successMessage:
                'Job diterima. Anda boleh mulakan apabila bersedia.',
          ),
        );
      }
      if (canFreelancerStart(job.status)) {
        return _ActionBarButton(
          label: 'Mulakan Kerja',
          isLoading: _isProcessing,
          onPressed: () => _guardedJobAction(
            allowed: true,
            action: () => jobsRepository.startJob(job.id),
            successMessage: 'Job dimulakan! Status kini In Progress.',
          ),
        );
      }
      if (canFreelancerComplete(job.status)) {
        return _ActionBarButton(
          label: 'Hantar & Tandakan Selesai',
          isLoading: _isProcessing,
          onPressed: () => _guardedJobAction(
            allowed: true,
            action: () => jobsRepository.markCompleted(job.id),
            successMessage: 'Job ditandakan selesai. Status kini Completed.',
          ),
        );
      }
      if (job.status == JobStatus.completed) {
        return const _ActionBarLabel(text: 'Status: Completed');
      }
      if (job.status == JobStatus.disputed) {
        return _ActionBarLabelButton(
          label: 'Lihat status dispute',
          onTap: () {},
        );
      }
    }

    if (role == 'CLIENT' && isJobClient) {
      if (canClientCancel(job.status)) {
        return _ActionBarButton(
          label: 'Batalkan Job',
          isLoading: _isProcessing,
          onPressed: () => _guardedJobAction(
            allowed: true,
            action: () => jobsRepository.cancelJob(job.id),
            successMessage: 'Job dibatalkan.',
          ),
          variant: FTButtonVariant.outline,
        );
      }
      if (job.status == JobStatus.inReview) {
        return _ActionBarButton(
          label: 'Confirm / Revision',
          isLoading: _isProcessing,
          onPressed: () {
            // Scroll to actions or show dialog?
            // Ideally we just point them to use the main action buttons in the body
            // But let's put a primary action here
            _guardedJobAction(
                allowed: true,
                action: () => jobsRepository.confirmJob(job.id),
                successMessage: 'Job confirmed');
          },
          variant: FTButtonVariant.filled,
        );
      }
      // ... existing logic
      if (job.status == JobStatus.disputed) {
        return const _ActionBarLabel(text: 'Dispute sedang berjalan');
      }
      if (job.status == JobStatus.completed) {
        return const _ActionBarLabel(text: 'Status: Completed');
      }
    }

    return null;
  }

  Widget _buildEscrowSection(TextTheme textTheme) {
    final isAdmin = canMutateEscrow(_userRole);
    final record = _escrow;
    final statusLabel = _escrowStatusLabel(record?.status);
    final statusColor = _escrowStatusColor(record?.status);
    final bool isEscrowUnavailable = _escrowError != null;
    final jobStatus = _job?.status;
    final bool showActions =
        isAdmin && !isEscrowUnavailable && !_isEscrowLoading;
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

    final holdAllowedStatuses = {
      JobStatus.pending,
      JobStatus.accepted,
      JobStatus.inProgress
    }.contains(jobStatus);
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

    final List<Widget> visibleActions = actions;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Escrow',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: AppRadius.mediumRadius,
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        _escrowError!,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: Colors.orange.shade800),
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
                style:
                    textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
            ),
          if (visibleActions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: visibleActions,
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
      final viewLabel = _isClientView ? 'Client' : 'Freelancer';
      final roleMismatch = _userRole != null &&
          ((_isClientView && _userRole!.toUpperCase() != 'CLIENT') ||
              (!_isClientView && _userRole!.toUpperCase() != 'FREELANCER'));

      body = SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s24),
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
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            // UX-C-06: Auto-completion Timer Banner for InReview
            if (job.status == JobStatus.inReview &&
                job.autoCompleteAt != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: AppRadius.mediumRadius,
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        color: Colors.blue.shade700, size: 28),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'In Review (Auto-complete)',
                            style: textTheme.titleSmall?.copyWith(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Job will complete automatically on ${_formatDate(job.autoCompleteAt)} unless revised.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: Colors.blue.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            // UX-C-05: Success banner after checkout
            if (_showSuccessBanner) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: AppRadius.mediumRadius,
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.green.shade700, size: 28),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Job berjaya dicipta!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ).copyWith(color: Colors.green.shade900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Anda boleh track progress dan chat dengan freelancer di sini.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.green.shade700,
                      onPressed: () {
                        setState(() {
                          _showSuccessBanner = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: AppRadius.mediumRadius,
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        'Anda melihat job ini sebagai: $viewLabel',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    _isClientView
                        ? 'Anda boleh semak progress, berhubung dengan freelancer dan sahkan hasil kerja.'
                        : 'Pastikan anda menyiapkan kerja dan kemas kini status (Terima, Mula, Lengkap) mengikut perkembangan.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                  if (roleMismatch) ...[
                    const SizedBox(height: AppSpacing.s6),
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: Colors.redAccent),
                        const SizedBox(width: AppSpacing.s6),
                        Expanded(
                          child: Text(
                            'Akaun aktif bukan $viewLabel. Paparan adalah read-only untuk elak tindakan tidak sah.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
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
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.shield_moon_outlined,
                                    size: 18, color: AppColors.neutral500),
                                const SizedBox(width: 6),
                                Text(
                                  'Status pembayaran / escrow:',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_isEscrowLoading)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else if (_escrowError != null)
                                  Tooltip(
                                    message: _escrowError,
                                    child: Chip(
                                      label: const Text('Info escrow tiada'),
                                      backgroundColor: Colors.orange.shade50,
                                    ),
                                  )
                                else
                                  Chip(
                                    label: Text(
                                        _escrowStatusLabel(_escrow?.status)),
                                    backgroundColor:
                                        _escrowStatusColor(_escrow?.status)
                                            .withValues(alpha: 0.12),
                                    labelStyle: TextStyle(
                                      color:
                                          _escrowStatusColor(_escrow?.status),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
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
                  if (job.hasAmountIssue) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: AppRadius.mediumRadius,
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 18),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              'Price data unavailable or corrupted. Contact support.',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
            if ((job.description?.isNotEmpty ?? false) ||
                (job.orderAttachments?.isNotEmpty ?? false)) ...[
              const SizedBox(height: AppSpacing.s16),
              SectionCard(
                title: 'Maklumat / Arahan',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (job.description?.isNotEmpty ?? false) ...[
                      Text('Mesej:',
                          style: textTheme.labelLarge
                              ?.copyWith(color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: AppRadius.mediumRadius,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child:
                            Text(job.description!, style: textTheme.bodyMedium),
                      ),
                    ],
                    if (job.orderAttachments?.isNotEmpty ?? false) ...[
                      if (job.description?.isNotEmpty ?? false)
                        const SizedBox(height: AppSpacing.s12),
                      Text('Lampiran:',
                          style: textTheme.labelLarge
                              ?.copyWith(color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      ...job.orderAttachments!.map((url) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.link,
                                    size: 18, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    url,
                                    style: textTheme.bodySmall?.copyWith(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ]
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            _buildEscrowSection(textTheme),
          ],
        ),
      );
    } else {
      body = const SizedBox.shrink();
    }

    return Scaffold(
      bottomNavigationBar: job != null ? _buildBottomActionBar(job) : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF3FC), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
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

class _ActionBarButton extends StatelessWidget {
  const _ActionBarButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = FTButtonVariant.filled,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final FTButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: FTButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          expanded: true,
          variant: variant,
        ),
      ),
    );
  }
}

class _ActionBarLabel extends StatelessWidget {
  const _ActionBarLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        color: Colors.grey.shade100,
        child: Center(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _ActionBarLabelButton extends StatelessWidget {
  const _ActionBarLabelButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.info_outline),
          label: Text(label),
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
    );
  }
}
