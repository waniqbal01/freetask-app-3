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
import '../reviews/review_dialog.dart';
import '../reviews/reviews_repository.dart';
import 'jobs_repository.dart';
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
  String? _userLoadError;

  // Freelancer Sub-tab management (only for Freelancer role)
  int _freelancerSubTabIndex = 0; // 0: Services, 1: Jobs

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _primeReviews();
    _loadJobs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await authRepository.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _userLoadError = AppStrings.errorLoadingProfile;
      });
      showErrorSnackBar(
        context,
        'Profil gagal dimuat: $error',
      );
    }
  }

  Future<void> _loadJobs() async {
    // We can optimize this to only load relevant jobs based on role later,
    // but for now, we'll keep the logic simple and safe.
    // If we only load client jobs for clients, we save bandwidth.
    await Future.wait([_fetchClientJobs(), _fetchFreelancerJobs()]);
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
            content: Text(AppStrings.errorActionFailed),
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
      showErrorSnackBar(context, AppStrings.errorGeneric);
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
              Text(
                '${AppStrings.serviceIdLabel}: ${job.serviceId}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/chats/${job.id}/messages'),
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
      if ({JobStatus.pending, JobStatus.accepted, JobStatus.inProgress}
          .contains(job.status)) {
        actions.add(
          FTButton(
            label: AppStrings.jobActionCancel,
            isLoading: _isProcessing,
            onPressed: () async {
              final confirmed = await showConfirmationDialog(
                context: context,
                title: AppStrings.confirmCancelJobTitle,
                message: AppStrings.confirmCancelJobMessage,
                confirmText: AppStrings.jobActionCancel,
                isDangerous: true,
              );
              if (confirmed != true) return;
              await _handleAction(
                () => jobsRepository.cancelJob(job.id),
                AppStrings.successJobCancelled,
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

    // Show create button ONLY if Freelancer Tab is active AND SubTab is 0 (Services)
    final showCreateServiceButton = isFreelancer && _freelancerSubTabIndex == 0;

    return Scaffold(
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
                    const Spacer(),
                    const NotificationBellButton(),
                    if (showCreateServiceButton) ...[
                      const SizedBox(width: 4),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () async {
                            await context.push('/services/create');
                            setState(() {});
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          tooltip: 'Create Service',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
                                child: const Text('Cuba muat semula profil'),
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
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('Servis Saya'),
                              icon: Icon(Icons.design_services),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('Urus Pesanan'),
                              icon: Icon(Icons.list_alt),
                            ),
                          ],
                          selected: {_freelancerSubTabIndex},
                          onSelectionChanged: (Set<int> newSelection) {
                            setState(() {
                              _freelancerSubTabIndex = newSelection.first;
                            });
                          },
                          showSelectedIcon: false,
                        ),
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _freelancerSubTabIndex,
                          children: [
                            const UserServicesView(), // Sub-tab 0: My Services
                            _buildJobsTab(
                              // Sub-tab 1: Jobs
                              jobs: _freelancerJobs,
                              isClientView: false,
                              isLoading: _isLoadingFreelancer,
                              errorMessage: _freelancerErrorMessage,
                              onRefresh: _refreshFreelancerJobs,
                            ),
                          ],
                        ),
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
    );
  }
}
