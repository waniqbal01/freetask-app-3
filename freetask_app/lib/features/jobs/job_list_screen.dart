import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_formatters.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/error_utils.dart';
import '../../core/utils/url_utils.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/ft_button.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../models/job.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_repository.dart';
import '../chat/chat_repository.dart';
import '../reviews/review_dialog.dart';
import '../reviews/reviews_repository.dart';
import 'jobs_repository.dart';
import 'job_actions.dart';
import 'widgets/job_card_skeleton.dart';
import 'widgets/job_status_badge.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/notification_bell_button.dart';
import '../services/user_services_list_screen.dart';

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
  bool _isLoadingUser = true;
  String? _userLoadError;

  // Freelancer Sub-tab management (only for Freelancer role)
  int _freelancerSubTabIndex = 0; // 0: Services, 1: Jobs

  static const List<String> _activeJobStatuses = [
    'pending',
    'awaiting_payment',
    'accepted',
    'in_progress',
    'in_review',
    'in_revision',
    'disputed',
    'payout_processing',
    'payout_hold',
    'payout_failed',
    'completed',
    'cancelled',
    'rejected',
    'paid_out',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _primeReviews();
    // _loadJobs moved to after user load to optimize fetching
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setFreelancerSubTab(int index) {
    if (_freelancerSubTabIndex != index) {
      setState(() {
        _freelancerSubTabIndex = index;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      _isLoadingUser = true;
      _userLoadError = null;
    });

    try {
      final user = await authRepository.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _isLoadingUser = false;
      });

      // Load jobs only after we know the user role
      if (user != null) {
        _loadJobs();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingUser = false;
        _userLoadError = AppStrings.errorLoadingProfile;
      });
      showErrorSnackBar(
        context,
        'Profil gagal dimuat: $error',
      );
    }
  }

  Future<void> _loadJobs() async {
    if (_currentUser == null) return;

    final role = _currentUser!.role.toUpperCase();

    // Optimize: Only fetch relevant jobs
    final futures = <Future<void>>[];

    if (role == 'CLIENT' || role == 'ADMIN') {
      futures.add(_fetchClientJobs());
    }

    if (role == 'FREELANCER' || role == 'ADMIN') {
      futures.add(_fetchFreelancerJobs());
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _primeReviews() async {
    try {
      await reviewsRepository.getSubmittedReviews();
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
        status: _activeJobStatuses,
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
      const message = AppStrings.errorLoadingJobs;
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
        status: _activeJobStatuses,
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
      const message = AppStrings.errorLoadingJobs;
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
    String successMessage, {
    required String jobId,
    required JobAction jobAction,
  }) async {
    // Optimistic Update Logic
    final previousState = <Job>[..._freelancerJobs];
    final jobIndex = _freelancerJobs.indexWhere((j) => j.id == jobId);

    if (jobIndex == -1) return;

    final job = _freelancerJobs[jobIndex];

    // Optimistically update UI
    setState(() {
      if (jobAction == JobAction.reject) {
        // Remove strictly for rejection
        _freelancerJobs.removeAt(jobIndex);
      } else if (jobAction == JobAction.accept) {
        // For accept, move to "In Progress" or "Accepted" visually
        // We'll update the status manually for now
        // Note: The backend returns the updated job, but we want instant feedback
        _freelancerJobs[jobIndex] = job.copyWith(status: JobStatus.accepted);
      }
    });

    try {
      final result = await action();

      if (!mounted) return;

      if (result != null) {
        // If success, we might want to refresh to get exact server state,
        // but for now, the optimistic capability is enough for "speed".
        // To be safe, we can silent-refresh in background:
        _fetchFreelancerJobs().then((_) {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      } else {
        throw Exception('Action returned null');
      }
    } on JobStatusConflict catch (error) {
      if (!mounted) return;
      // Revert state
      setState(() {
        _freelancerJobs
          ..clear()
          ..addAll(previousState);
      });
      showErrorSnackBar(context, error.message);
    } on DioException catch (error) {
      if (!mounted) return;
      // Revert state
      setState(() {
        _freelancerJobs
          ..clear()
          ..addAll(previousState);
      });
      showErrorSnackBar(context, resolveDioErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      // Revert state
      setState(() {
        _freelancerJobs
          ..clear()
          ..addAll(previousState);
      });
      showErrorSnackBar(context, AppStrings.errorGeneric);
    }
  }

  Future<void> _openChat(Job job) async {
    final currentUserId = _currentUser?.id;
    if (currentUserId == null) return;

    // Use linked conversation if available
    if (job.conversationId != null && job.conversationId!.isNotEmpty) {
      context.push('/chats/${job.conversationId}/messages');
      return;
    }

    // Determine other user ID
    final otherUserId =
        currentUserId == job.clientId ? job.freelancerId : job.clientId;

    if (otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID pengguna tidak sah.')),
      );
      return;
    }

    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final chatRepo = ChatRepository();
      // This might create a DUPLICATE conversation if one exists but isn't linked in Job yet.
      // Ideally, backend should handle "get or create" safely.
      final thread =
          await chatRepo.createConversation(otherUserId: otherUserId);

      if (!mounted) return;
      context.push('/chats/${thread.id}/messages');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka chat: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
              content: Text(AppStrings.errorCannotDetermineReviewee)),
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
        const SnackBar(content: Text(AppStrings.successReviewSubmitted)),
      );
    }
  }

  JobStatusVisual _statusVisual(JobStatus status) {
    return mapJobStatusVisual(status);
  }

  String _formatJobDate(DateTime? date) {
    return AppFormatters.formatDateTime(date);
  }

  String _formatAmount(Job job) {
    return AppFormatters.formatAmount(
      job.hasAmountIssue || job.amount <= 0 ? null : job.amount,
    );
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
                    width: 46, // Reduced size slightly for icon
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusVisual.color.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      statusVisual.icon,
                      color: statusVisual.color,
                      size: 24,
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
                        JobStatusBadge(visual: statusVisual),
                      ],
                    ),
                  ),
                  // Thumbnail on the Right
                  if (job.serviceThumbnailUrl != null &&
                      job.serviceThumbnailUrl!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: Image.network(
                          UrlUtils.resolveImageUrl(job.serviceThumbnailUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined,
                                size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Chevron only if no image, or keep it? User wants clean UI.
                  // Let's keep chevron if no image? Or just rely on tapping row.
                  // User said "thumbnails on right".
                  if (job.serviceThumbnailUrl == null ||
                      job.serviceThumbnailUrl!.isEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.neutral300,
                    ),
                  ],
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openChat(job),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text(AppStrings.btnOpenChat),
                ),
              ),
              if (job.isDisputed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: AppRadius.mediumRadius,
                      border: Border.all(color: Colors.orange.shade200),
                    ),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.disputeInProgress,
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (job.disputeReason != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Sebab: ${job.disputeReason}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
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

    if (isClientView && role == 'CLIENT' && isClientOwner) {
      final List<Widget> actions = <Widget>[];
      /*
      // Removed Cancel Button as requested
      if ({JobStatus.pending, JobStatus.accepted, JobStatus.inProgress}
          .contains(job.status)) {
        actions.add(
           FTButton(
            label: AppStrings.jobActionCancel,
             // ...
           ),
        );
      }
      */

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
            label: AppStrings.jobActionReject,
            isLoading: _isProcessing,
            onPressed: () async {
              final confirmed = await showConfirmationDialog(
                context: context,
                title: AppStrings.confirmRejectJobTitle,
                message: AppStrings.confirmRejectJobMessage,
                confirmText: AppStrings.jobActionReject,
                isDangerous: true,
              );
              if (confirmed != true) return;
              await _handleAction(
                () => jobsRepository.rejectJob(job.id),
                AppStrings.successJobRejected,
                jobId: job.id,
                jobAction: JobAction.reject,
              );
            },
            expanded: false,
            size: FTButtonSize.small,
          ),
          const SizedBox(width: 8),
          FTButton(
            label: AppStrings.jobActionAccept,
            isLoading: _isProcessing,
            onPressed: () => _handleAction(
              () => jobsRepository.acceptJob(job.id),
              AppStrings.successJobAccepted,
              jobId: job.id,
              jobAction: JobAction.accept,
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
          label: AppStrings.jobActionStart,
          isLoading: _isProcessing,
          onPressed: () => _handleAction(
            () => jobsRepository.startJob(job.id),
            AppStrings.successJobStarted,
            jobId: job.id,
            jobAction: JobAction.start,
          ),
          expanded: false,
          size: FTButtonSize.small,
        ),
      );
    }

    // Removed "Selesai" button - freelancers should submit work instead
    // Jobs in progress don't need a complete button here

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
                label: Text(AppStrings.reviewSubmitted),
              )
            : FTButton(
                label: AppStrings.jobActionReview,
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
                label: AppStrings.btnRetry,
                onPressed: onRefresh,
                expanded: false,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_outlined),
                label: const Text(AppStrings.btnGoHome),
              ),
            ],
          ),
        ),
      );
    }

    if (jobs.isEmpty) {
      final title = isClientView
          ? AppStrings.emptyJobsClient
          : AppStrings.emptyJobsFreelancer;
      final subtitle = isClientView
          ? AppStrings.emptyJobsClientSubtitle
          : AppStrings.emptyJobsFreelancerSubtitle;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isClientView
                    ? Icons.shopping_bag_outlined
                    : Icons.work_outline_rounded,
                size: 56,
                color: AppColors.neutral300,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.neutral500),
              ),
              const SizedBox(height: 20),
              if (isClientView)
                FTButton(
                  label: AppStrings.emptyClientCta,
                  onPressed: () => context.go('/home'),
                  expanded: false,
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
    // Logic: If role == Freelancer, show Freelancer View (Sub-tabs: Services/Jobs).
    // Else (Client, Admin, etc), show Client Job List (Jobs they posted).

    final role = _currentUser?.role.toUpperCase();
    final isFreelancer = role == 'FREELANCER';

    if (_isLoadingUser) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If user failed to load completely
    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _userLoadError ?? 'Gagal memuatkan profil pengguna.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              FTButton(
                label: 'Cuba Semula',
                onPressed: _loadCurrentUser,
                expanded: false,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.jobs),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _JobsHeader(
              isFreelancer: isFreelancer,
              currentSubTab: _freelancerSubTabIndex,
              onSubTabChanged: _setFreelancerSubTab,
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: Container(
              margin: const EdgeInsets.only(top: 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  if (_userLoadError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: AppRadius.mediumRadius,
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade700),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userLoadError!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loadCurrentUser,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                    ),
                                    child:
                                        const Text('Cuba muat semula profil'),
                                  ),
                                  TextButton.icon(
                                    onPressed: authRepository.logout,
                                    icon: const Icon(Icons.logout, size: 16),
                                    label: const Text('Log keluar'),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!isFreelancer)
                    Expanded(
                      child: _buildJobsTab(
                        jobs: _clientJobs,
                        isClientView: true,
                        isLoading: _isLoadingClient,
                        errorMessage: _clientErrorMessage,
                        onRefresh: _refreshClientJobs,
                      ),
                    )
                  else
                    Expanded(
                      child: IndexedStack(
                        index: _freelancerSubTabIndex,
                        children: [
                          const UserServicesView(),
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
                  if (_isProcessing)
                    const LoadingOverlay(
                      message: 'Memproses tindakan...',
                      backgroundOpacity: 0.4,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsHeader extends StatelessWidget {
  const _JobsHeader({
    required this.isFreelancer,
    required this.currentSubTab,
    required this.onSubTabChanged,
  });

  final bool isFreelancer;
  final int currentSubTab;
  final ValueChanged<int> onSubTabChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          width: double.infinity,
          height: 180,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Badge & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.work_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Jobs',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const NotificationBellButton(color: Colors.white),
                        ),
                        if (isFreelancer) ...[
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () => context.push('/services/create'),
                              tooltip: 'Create Service',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                // Removed spacing here to pull things up if needed, but 24 is fine
              ],
            ),
          ),
        ),
        // Overlapping Filter Card
        if (isFreelancer)
          Container(
            margin:
                const EdgeInsets.only(top: 130, left: 16, right: 16, bottom: 0),
            constraints: const BoxConstraints(minHeight: 100),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FilterChip(
                        label: 'Servis Saya',
                        icon: Icons.design_services,
                        isSelected: currentSubTab == 0,
                        onTap: () => onSubTabChanged(0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FilterChip(
                        label: 'Urus Pesanan',
                        icon: Icons.list_alt,
                        isSelected: currentSubTab == 1,
                        onTap: () => onSubTabChanged(1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
