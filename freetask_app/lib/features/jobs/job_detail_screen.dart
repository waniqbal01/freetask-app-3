import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/job.dart';

import '../auth/auth_repository.dart';

import '../escrow/escrow_repository.dart';
import '../chat/chat_repository.dart';

import 'jobs_repository.dart';
import 'job_transition_rules.dart';
import 'widgets/job_status_badge.dart';
import 'widgets/submit_work_dialog.dart';
import 'widgets/attachment_viewer.dart';
import '../reviews/reviews_repository.dart';
import '../../services/payment_service.dart';
import '../../models/payment.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/http_client.dart';

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
  bool _isEscrowLoading = false;
  bool _isPaymentProcessing = false;
  String? _errorMessage;
  String? _escrowError;
  EscrowRecord? _escrow;
  String? _userRole;
  String? _userId;
  bool _isUserLoading = true;
  late bool _isClientView;
  late PaymentService _paymentService;
  Payment? _payment;
  bool _isPaymentLoading = false;

  @override
  void initState() {
    super.initState();
    final httpClient = HttpClient();
    _paymentService = PaymentService(httpClient.dio);
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

  Future<void> _fetchPayment() async {
    setState(() {
      _isPaymentLoading = true;
    });

    try {
      final jobIdInt = int.tryParse(widget.jobId);
      if (jobIdInt != null) {
        final payment = await _paymentService.getPaymentInfo(jobIdInt);
        if (!mounted) return;
        setState(() {
          _payment = payment;
        });
      }
    } catch (error) {
      // Payment might not exist, which is okay
    } finally {
      if (mounted) {
        setState(() {
          _isPaymentLoading = false;
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
      await _fetchPayment();
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

  JobStatusVisual _statusVisual(JobStatus status) {
    return mapJobStatusVisual(status);
  }

  Future<void> _showRevisionRequestDialog(Job job) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Minta Semakan Semula'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nyatakan apa yang perlu diperbaiki oleh freelancer:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Sebab (Wajib)',
                hintText: 'Contoh: Sila tambah logo di sebelah kanan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sebab wajib diisi')),
                );
                return;
              }
              if (reasonController.text.trim().length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sebab perlu sekurang-kurangnya 10 aksara'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Hantar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _guardedJobAction(
        allowed: true,
        action: () => jobsRepository.requestRevision(
            job.id, reasonController.text.trim()),
        successMessage: 'Permintaan semakan dihantar kepada freelancer.',
      );
    }
  }

  Future<void> _showDisputeDialog(Job job) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buka Dispute?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adakah anda pasti mahu membuka dispute untuk job ini? Tindakan ini akan menghantar kes kepada admin untuk review.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Sebab Dispute',
                hintText: 'Terangkan mengapa anda membuka dispute...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 8),
            Text(
              'Minimum 10 aksara diperlukan',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Sebab dispute perlu sekurang-kurangnya 10 aksara'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Buka Dispute'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim();
      await _guardedJobAction(
        allowed: true,
        action: () => jobsRepository.disputeJob(job.id, reason),
        successMessage: 'Dispute telah dibuka. Admin akan review kes ini.',
      );
    }
  }

  Future<void> _showReviewDialog(Job job) async {
    int selectedRating = 5;
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Beri Penilaian'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Berikan penilaian anda untuk freelancer:'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    icon: Icon(
                      star <= selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade600,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedRating = star;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Komen (Optional)',
                  hintText: 'Kongsi pengalaman anda...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hantar Penilaian'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final jobIdInt = int.tryParse(job.id);
        final freelancerIdInt = int.tryParse(job.freelancerId);

        if (jobIdInt == null || freelancerIdInt == null) {
          throw StateError('ID tidak sah');
        }

        await reviewsRepository.createReview(
          jobId: jobIdInt,
          revieweeId: freelancerIdInt,
          rating: selectedRating,
          comment: commentController.text.trim().isEmpty
              ? null
              : commentController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terima kasih atas penilaian anda!')),
        );
        setState(() {});
      } catch (error) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Gagal menghantar penilaian: $error');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  Future<void> _handlePayNow(Job job) async {
    setState(() {
      _isPaymentProcessing = true;
    });

    try {
      final jobIdInt = int.tryParse(job.id);
      if (jobIdInt == null) {
        throw Exception('Invalid job ID');
      }

      final paymentUrl =
          await _paymentService.createPayment(jobIdInt, 'billplz');

      if (!mounted) return;

      // Launch Billplz payment page
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diarahkan ke halaman pembayaran...'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Could not launch payment URL');
      }
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Gagal memproses bayaran: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isPaymentProcessing = false;
        });
      }
    }
  }

  Future<void> _handleRetryPayment(Job job) async {
    setState(() {
      _isPaymentProcessing = true;
    });

    try {
      final jobIdInt = int.tryParse(job.id);
      if (jobIdInt == null) {
        throw Exception('Invalid job ID');
      }

      final paymentUrl = await _paymentService.retryPayment(jobIdInt);

      if (!mounted) return;

      // Launch Billplz payment page
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redirecting to payment page...'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Could not launch payment URL');
      }
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to retry payment: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isPaymentProcessing = false;
        });
        // Refresh payment info
        await _fetchPayment();
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Tarikh tidak tersedia';
    }

    return DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());
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
          label: 'Hantar Kerja',
          isLoading: _isProcessing,
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => SubmitWorkDialog(jobId: job.id),
            );

            if (result == true && mounted) {
              // Refresh job after successful submission
              await _fetchJob();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Kerja dihantar untuk semakan!')),
                );
              }
            }
          },
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
      // Add "Pay Now" button for AWAITING_PAYMENT jobs
      if (job.status == JobStatus.awaitingPayment) {
        return _ActionBarButton(
          label: 'Bayar Sekarang',
          isLoading: _isPaymentProcessing,
          onPressed: () => _handlePayNow(job),
          variant: FTButtonVariant.filled,
        );
      }
      /*
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
      */
      if (job.status == JobStatus.inReview) {
        return _ActionBarDualButton(
          primaryLabel: 'Terima & Selesai',
          primaryOnPressed: () => _guardedJobAction(
            allowed: true,
            action: () => jobsRepository.confirmJob(job.id),
            successMessage: 'Job diterima dan selesai!',
          ),
          secondaryLabel: 'Minta Semakan',
          secondaryOnPressed: () {
            // Show revision dialog
            _showRevisionRequestDialog(job);
          },
          isLoading: _isProcessing,
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

  Future<void> _openChat() async {
    final job = _job;
    if (job == null || _userId == null) return;

    // Determine other user ID
    final otherUserId =
        _userId == job.clientId ? job.freelancerId : job.clientId;

    if (otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID pengguna tidak sah.')),
      );
      return;
    }

    // Use linked conversation if available
    if (job.conversationId != null && job.conversationId!.isNotEmpty) {
      if (!mounted) return;
      context.push('/chats/${job.conversationId}/messages');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Fallback for legacy jobs
      final chatRepo = ChatRepository();
      // Note: check if createConversation returns a model with 'id'
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final job = _job;

    // Loading state
    if (_isLoading && job == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Job Detail'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Error state
    if (_errorMessage != null && job == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Job Detail'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchJob,
                  child: const Text('Cuba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // No job
    if (job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Detail')),
        body: const Center(child: Text('Tiada data job')),
      );
    }

    // Main content with job loaded
    final statusVisual = _statusVisual(job.status);
    final viewLabel = _isClientView ? 'Client' : 'Freelancer';

    return Scaffold(
      appBar: AppBar(
        title: Text(job.serviceTitle),
        backgroundColor: statusVisual.color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: _openChat,
            tooltip: 'Chat',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Badge
            _buildInfoCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusVisual.color.withValues(alpha: 0.15),
                    ),
                    child: Icon(statusVisual.icon,
                        color: statusVisual.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.serviceTitle,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusVisual.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusVisual.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Role Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Anda melihat sebagai: $viewLabel',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Job Details Card
            _buildInfoCard(
              title: 'Maklumat Job',
              child: Column(
                children: [
                  _buildDetailRow(Icons.confirmation_number, 'Job ID', job.id),
                  _buildDetailRow(
                      Icons.receipt_long, 'Service ID', job.serviceId),
                  _buildDetailRow(Icons.calendar_today, 'Tarikh',
                      _formatDate(job.createdAt)),
                  _buildDetailRow(Icons.payments, 'Jumlah',
                      'RM${job.amount.toStringAsFixed(2)}'),
                  _buildDetailRow(
                    Icons.person,
                    _isClientView ? 'Freelancer ID' : 'Client ID',
                    _isClientView ? job.freelancerId : job.clientId,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Message Card - Quick access to chat
            _buildInfoCard(
              title: 'Mesej',
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: theme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bincang job ini dengan ${_isClientView ? 'freelancer' : 'client'}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Klik untuk buka chat',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Chat'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Description
            if (job.description?.isNotEmpty ?? false)
              _buildInfoCard(
                title: 'Arahan / Mesej',
                child: Text(job.description!, style: textTheme.bodyMedium),
              ),
            if (job.description?.isNotEmpty ?? false)
              const SizedBox(height: 12),

            // Order Attachments
            if (job.orderAttachments?.isNotEmpty ?? false)
              _buildInfoCard(
                title: 'Lampiran Order',
                child: AttachmentViewer(
                  attachments: job.orderAttachments!,
                  label: 'Fail dilampirkan oleh pelanggan:',
                ),
              ),
            if (job.orderAttachments?.isNotEmpty ?? false)
              const SizedBox(height: 12),

            // Submission Section (for completed/in-review jobs)
            if (job.submissionMessage != null ||
                (job.submissionAttachments?.isNotEmpty ?? false))
              _buildInfoCard(
                title: 'Hasil Kerja / Submission',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (job.submittedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Dihantar: ${_formatDate(job.submittedAt)}',
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (job.submissionMessage?.isNotEmpty ?? false) ...[
                      Text('Nota:', style: textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(job.submissionMessage!, style: textTheme.bodyMedium),
                    ],
                    if (job.submissionAttachments?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 12),
                      AttachmentViewer(
                        attachments: job.submissionAttachments!,
                        label: 'Fail dihantar oleh freelancer:',
                      ),
                    ],
                  ],
                ),
              ),
            if (job.submissionMessage != null ||
                (job.submissionAttachments?.isNotEmpty ?? false))
              const SizedBox(height: 12),

            // Payment Information Section
            if (_payment != null || _isPaymentLoading)
              _buildInfoCard(
                title: 'Payment Information',
                child: _isPaymentLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.payment,
                            'Status',
                            _payment!.status,
                          ),
                          if (_payment!.paymentMethod != null)
                            _buildDetailRow(
                              Icons.credit_card,
                              'Payment Method',
                              _payment!.paymentMethod!,
                            ),
                          if (_payment!.transactionId != null)
                            _buildDetailRow(
                              Icons.receipt_long,
                              'Transaction ID',
                              _payment!.transactionId!,
                            ),
                          if (_payment!.isFailed) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isPaymentProcessing
                                    ? null
                                    : () => _handleRetryPayment(job),
                                icon: _isPaymentProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                                label: Text(_isPaymentProcessing
                                    ? 'Processing...'
                                    : 'Retry Payment'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            if (_payment != null || _isPaymentLoading)
              const SizedBox(height: 12),

            // Escrow Section
            _buildInfoCard(
              title: 'Escrow / Pembayaran',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEscrowLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_escrowError != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_escrowError!)),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _escrowStatusColor(_escrow?.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _escrowStatusLabel(_escrow?.status),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_escrow?.amount != null)
                              Text(
                                'RM${_escrow!.amount!.toStringAsFixed(2)}',
                                style: textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Dispute Info
            if (job.isDisputed)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Dispute',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (job.disputeReason != null) ...[
                      const SizedBox(height: 8),
                      Text(job.disputeReason!),
                    ],
                  ],
                ),
              ),
            if (job.isDisputed) const SizedBox(height: 12),

            // Chat Button
            ElevatedButton.icon(
              onPressed: () {
                GoRouter.of(context).go('/chats/${job.id}/messages');
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Buka Chat'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),

            // Dispute Button (IN_PROGRESS only)
            if (job.status == JobStatus.inProgress && !job.isDisputed)
              ElevatedButton.icon(
                onPressed: () => _showDisputeDialog(job),
                icon: const Icon(Icons.gavel),
                label: const Text('Buka Dispute'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            if (job.status == JobStatus.inProgress && !job.isDisputed)
              const SizedBox(height: 12),

            // Review Button (COMPLETED, CLIENT only)
            if (job.status == JobStatus.completed &&
                _userRole?.toUpperCase() == 'CLIENT' &&
                job.clientId == _userId &&
                !reviewsRepository.hasSubmittedReview(job.id))
              ElevatedButton.icon(
                onPressed: () => _showReviewDialog(job),
                icon: const Icon(Icons.star_rate),
                label: const Text('Beri Penilaian'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            if (job.status == JobStatus.completed &&
                _userRole?.toUpperCase() == 'CLIENT' &&
                job.clientId == _userId &&
                !reviewsRepository.hasSubmittedReview(job.id))
              const SizedBox(height: 12),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: () {
        final bar = _buildBottomActionBar(job);
        debugPrint('JobDetailScreen: Bottom bar widget: $bar');
        return bar;
      }(),
    );
  }

  Widget _buildInfoCard({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widgets for bottom action bar

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
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
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

class _ActionBarDualButton extends StatelessWidget {
  const _ActionBarDualButton({
    required this.primaryLabel,
    required this.primaryOnPressed,
    required this.secondaryLabel,
    required this.secondaryOnPressed,
    this.isLoading = false,
  });

  final String primaryLabel;
  final VoidCallback primaryOnPressed;
  final String secondaryLabel;
  final VoidCallback secondaryOnPressed;
  final bool isLoading;

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
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: FTButton(
                label: primaryLabel,
                onPressed: isLoading ? () {} : primaryOnPressed,
                isLoading: isLoading,
                variant: FTButtonVariant.filled,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FTButton(
                label: secondaryLabel,
                onPressed: isLoading ? () {} : secondaryOnPressed,
                variant: FTButtonVariant.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
