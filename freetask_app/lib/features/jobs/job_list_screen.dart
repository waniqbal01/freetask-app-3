import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../models/job.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_repository.dart';
import '../reviews/review_dialog.dart';
import '../reviews/reviews_repository.dart';
import 'job_constants.dart';
import 'job_transition_rules.dart';
import 'jobs_repository.dart';
import 'widgets/job_card_skeleton.dart';
import 'widgets/job_status_badge.dart';
import '../../widgets/active_role_banner.dart';
import '../../widgets/app_bottom_nav.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key, this.limitQuery, this.offsetQuery});

  final String? limitQuery;
  final String? offsetQuery;

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
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _primeReviews();
    _loadJobs();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await authRepository.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
      });
    } catch (_) {
      // Ignore user fetch failures for now; UI will remain in guest mode.
    }
  }

  Future<void> _loadJobs() async {
    await Future.wait([_fetchClientJobs(), _fetchFreelancerJobs()]);
  }

  Future<void> _primeReviews() async {
    try {
      await reviewsRepository.getMyReviews();
    } catch (_) {
      // Ignore cache warm failures; UI will surface errors on demand.
    }
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
      final jobs = await jobsRepository.getClientJobs(
        limit: widget.limitQuery,
        offset: widget.offsetQuery,
      );
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
      final jobs = await jobsRepository.getFreelancerJobs(
        limit: widget.limitQuery,
        offset: widget.offsetQuery,
      );
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
    Future<Job?> Function() action,
    String successMessage,
  ) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await action();

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      if (result != null) {
        await _loadJobs();
        if (!mounted) return;
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
    } on JobStatusConflict catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      showErrorSnackBar(context, error.message);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      showErrorSnackBar(context, resolveDioErrorMessage(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      showErrorSnackBar(context, 'Ralat melaksanakan tindakan.');
    }
  }

  Future<void> _openReviewDialog(Job job) async {
    // Determine reviewee: if current user is client, review freelancer; otherwise review client
    final currentUserId = _currentUser?.id;
    final isClient = currentUserId == job.clientId;
    final revieweeId = isClient ? job.freelancerId : job.clientId;

    if (revieweeId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tidak dapat menentukan penerima review.')),
        );
      }
      return;
    }

    final submitted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => ReviewDialog(
        jobId: job.id,
        revieweeId: revieweeId,
        serviceTitle: job.serviceTitle,
      ),
    );
    if (submitted == true && mounted) {
      final jobId = int.tryParse(job.id);
      if (jobId != null) {
        await reviewsRepository.getReviewsForJob(jobId);
      }
      await _loadJobs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terima kasih atas review anda!')),
      );
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
                      helperText: helper,
                      errorText: controller.text.isEmpty || isValid
                          ? null
                          : 'Minimum $jobMinDisputeReasonLen aksara diperlukan.',
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

  String _formatJobDate(DateTime? date) {
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

  void _openJobDetail(Job job, {required bool isClientView}) {
    context.push(
      '/jobs/${job.id}',
      extra: <String, dynamic>{
        'job': job,
        'isClientView': isClientView,
      },
    );
  }

  Widget _buildJobCard(Job job, {required bool isClientView}) {
    final statusVisual = _statusVisual(job.status);
    final alreadyReviewed = reviewsRepository.hasSubmittedReview(job.id);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final dateText = _formatJobDate(job.createdAt);
    final amountText = _formatAmount(job);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: AppRadius.largeRadius,
        onTap: () => _openJobDetail(job, isClientView: isClientView),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.largeRadius,
            boxShadow: AppShadows.card,
          ),
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusVisual.color.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      statusVisual.icon,
                      color: statusVisual.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.serviceTitle,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            JobStatusBadge(visual: statusVisual),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.neutral300,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.neutral300,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateText,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: AppColors.neutral300,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amountText,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: job.hasAmountIssue ? Colors.red.shade700 : null,
                    ),
                  ),
                  if (job.hasAmountIssue) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Amount could not be parsed. Contact support.',
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ID Servis: ${job.serviceId}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/chats/${job.id}/messages'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Buka Chat'),
                ),
              ),
              if (job.isDisputed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.report_problem_outlined,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Dispute: ${job.disputeReason ?? 'Tiada maklumat tambahan.'}',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _buildActionSection(
                job,
                isClientView: isClientView,
                alreadyReviewed: alreadyReviewed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionSection(
    Job job, {
    required bool isClientView,
    required bool alreadyReviewed,
  }) {
    final role = _currentUser?.role.toUpperCase();
    final isClientOwner = _currentUser?.id == job.clientId;
    final isFreelancerOwner = _currentUser?.id == job.freelancerId;
    final canDispute = canRaiseDispute(job.status);

    if (isClientView && role == 'CLIENT' && isClientOwner) {
      final List<Widget> actions = <Widget>[];
      if ({JobStatus.pending, JobStatus.accepted, JobStatus.inProgress}
          .contains(job.status)) {
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

      if (actions.isNotEmpty) {
        return Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: AppSpacing.s8,
            children: actions,
          ),
        );
      }
    }

    if (!isClientView && job.status == JobStatus.pending) {
      if (role != 'FREELANCER' || !isFreelancerOwner) {
        return const SizedBox.shrink();
      }
      return Row(
        children: [
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
          const SizedBox(width: 8),
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
        ],
      );
    }

    if (!isClientView && job.status == JobStatus.accepted) {
      if (role != 'FREELANCER' || !isFreelancerOwner) {
        return const SizedBox.shrink();
      }
      return Align(
        alignment: Alignment.centerRight,
        child: FTButton(
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
    }

    if (!isClientView && job.status == JobStatus.inProgress) {
      if (role != 'FREELANCER' || !isFreelancerOwner) {
        return const SizedBox.shrink();
      }
      return Row(
        children: [
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
          const SizedBox(width: 8),
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
        ],
      );
    }

    if (isClientView &&
        job.status == JobStatus.completed &&
        role == 'CLIENT' &&
        isClientOwner) {
      return Align(
        alignment: Alignment.centerRight,
        child: alreadyReviewed
            ? const Chip(
                avatar: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                label: Text('Review dihantar'),
              )
            : FTButton(
                label: 'Tulis review',
                onPressed: () => _openReviewDialog(job),
                expanded: false,
                size: FTButtonSize.small,
              ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildJobsTab({
    required List<Job> jobs,
    required bool isClientView,
    required bool isLoading,
    required String? errorMessage,
    required Future<void> Function() onRefresh,
  }) {
    if (isLoading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (_, __) => const JobCardSkeleton(),
        separatorBuilder: (_, __) => const SizedBox.shrink(),
        itemCount: 4,
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 38,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
              FTButton(
                label: 'Cuba Lagi',
                onPressed: onRefresh,
                expanded: false,
              ),
            ],
          ),
        ),
      );
    }

    if (jobs.isEmpty) {
      final title =
          isClientView ? 'Tiada job sebagai client' : 'Tiada job sebagai freelancer';
      final subtitle = isClientView
          ? 'Buka marketplace untuk hire freelancer atau cuba refresh sekiranya anda baru selesai membuat tempahan.'
          : 'Belum ada job aktif. Semak Job Board atau kekalkan status sedia menerima kerja.';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.neutral500),
              ),
              const SizedBox(height: 16),
              FTButton(
                label: isClientView ? 'Cari Servis' : 'Pergi ke Job Board',
                onPressed: () => context.go('/home'),
                expanded: false,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh senarai'),
              ),
            ],
          ),
        ),
      );
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
    final role = _currentUser?.role.toUpperCase();
    String? actionLabel;
    VoidCallback? onAction;
    String? subtitle;

    if (role == 'CLIENT') {
      actionLabel = 'Lihat Home';
      onAction = () => context.go('/home');
      subtitle = 'Fokus pada tempahan anda dan teruskan chat.';
    } else if (role == 'FREELANCER') {
      actionLabel = 'Browse Services';
      onAction = () => context.go('/home');
      subtitle = 'Semak job yang perlu diterima atau ditolak.';
    } else if (role == 'ADMIN') {
      actionLabel = 'Admin';
      onAction = () => context.go('/admin');
      subtitle = 'Pantau job dan escrow yang aktif.';
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        bottomNavigationBar: const AppBottomNav(currentTab: AppTab.jobs),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEEF3FC), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Jobs & Orders',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (_currentUser != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ActiveRoleBanner(
                      user: _currentUser,
                      actionLabel: actionLabel,
                      onAction: onAction,
                      subtitle: subtitle,
                      switchLabel: 'Tukar role/akun',
                      onSwitch: () => context.go('/settings'),
                    ),
                  ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Client Jobs'),
                    Tab(text: 'Freelancer Jobs'),
                  ],
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Paparan dihadkan kepada ${JobsRepository.defaultPageSize} item setiap tab (maks 50). Nilai limit/offset disanitasi ke had API.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      TabBarView(
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
                      if (_isProcessing)
                        const LoadingOverlay(
                          message: 'Memproses tindakan...',
                          backgroundOpacity: 0.4,
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
