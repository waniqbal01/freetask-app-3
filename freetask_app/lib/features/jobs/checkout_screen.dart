import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/ft_button.dart';
import '../../core/widgets/loading_overlay.dart';
import '../escrow/escrow_repository.dart';
import 'jobs_repository.dart';
import '../../core/utils/error_utils.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';
import 'job_constants.dart';

import '../auth/auth_repository.dart';

class JobCheckoutScreen extends StatefulWidget {
  const JobCheckoutScreen({super.key, this.serviceSummary});

  final Map<String, dynamic>? serviceSummary;

  @override
  State<JobCheckoutScreen> createState() => _JobCheckoutScreenState();
}

class _JobCheckoutScreenState extends State<JobCheckoutScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _descriptionError;
  String? _amountError;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final bool _allowEditing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = authRepository.currentUser;
      if (user?.role != 'CLIENT') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hanya Client boleh membuat tempahan job.'),
            backgroundColor: Colors.red,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    });

    _descriptionController = TextEditingController(
      text: _description.isNotEmpty ? _description : _serviceDescription,
    );
    _amountController = TextEditingController(
      text: _amount != null && _amount! > 0 ? _amount!.toStringAsFixed(2) : '',
    );
    _allowEditing = _hasPriceIssue || _amount == null || _amount! <= 0;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _summary =>
      widget.serviceSummary ?? <String, dynamic>{};

  String get _serviceId => (_summary['serviceId'] ?? '') as String;

  String get _description => _summary['description']?.toString() ?? '';

  String get _serviceDescription =>
      _summary['serviceDescription']?.toString() ??
      _summary['service_desc']?.toString() ??
      '';

  String get _title => _summary['title']?.toString() ?? '';

  double? get _amount {
    final value = _summary['price'];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String && value.isNotEmpty) {
      return double.tryParse(value);
    }
    return null;
  }

  bool get _hasPriceIssue => _summary['priceIssue'] == true;

  Future<void> _createOrder() async {
    final serviceId = _serviceId;
    final descriptionInput = _descriptionController.text.trim();
    final description = descriptionInput.isNotEmpty
        ? descriptionInput
        : (_description.isNotEmpty ? _description : _serviceDescription);
    final amountInput = _amountController.text.trim();
    final parsedAmount = amountInput.isNotEmpty
        ? double.tryParse(amountInput)
        : _amount;

    setState(() {
      _errorMessage = null;
      _descriptionError = null;
      _amountError = null;
    });

    if (serviceId.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maklumat servis tidak lengkap.')),
      );
      return;
    }

    final trimmedDescription = description.trim();

    if (trimmedDescription.length < jobMinDescLen ||
        parsedAmount == null ||
        parsedAmount < jobMinAmount) {
      setState(() {
        _descriptionError = trimmedDescription.length < jobMinDescLen
            ? 'Minimum $jobMinDescLen aksara diperlukan.'
            : null;
        _amountError = parsedAmount == null || parsedAmount < jobMinAmount
            ? 'Minimum RM${jobMinAmount.toStringAsFixed(2)} diperlukan.'
            : null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final job = await jobsRepository.createOrder(
        serviceId,
        parsedAmount!,
        description,
        serviceTitle:
            _title.isEmpty ? _summary['serviceTitle']?.toString() : _title,
      );
      try {
        await escrowRepository.hold(job.id);

        if (!mounted) {
          return;
        }

        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Order ${job.id} dicipta. Dana RM${job.amount.toStringAsFixed(2)} dipegang untuk status Booked.',
            ),
          ),
        );
      } on EscrowUnavailable catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      await _showSuccessDialog();
      if (mounted) {
        context.go('/jobs');
      }
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final message = resolveDioErrorMessage(error);
      final fieldErrors = _parseFieldErrors(error);
      setState(() {
        _errorMessage = fieldErrors.isEmpty ? message : null;
        _descriptionError = fieldErrors['description'];
        _amountError = fieldErrors['amount'];
      });
      final status = error.response?.statusCode;
      if (status != 400 && status != 404) {
        showErrorSnackBar(context, message);
      }
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.message.isEmpty
          ? 'Maklumat tempahan tidak sah.'
          : error.message;
      setState(() {
        _errorMessage = message;
        if (message.toLowerCase().contains('penerangan')) {
          _descriptionError = message;
        }
        if (message.toLowerCase().contains('jumlah minima')) {
          _amountError = message;
        }
      });
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = 'Ralat mencipta order: $error';
      setState(() {
        _errorMessage = message;
      });
      showErrorSnackBar(context, message);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.green,
                child: Icon(Icons.check_rounded, color: Colors.white, size: 34),
              ),
              SizedBox(height: 16),
              Text(
                'Tempahan berjaya! Freelancer akan respon.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Anda boleh semak status tempahan dalam halaman Jobs.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FTButton(
                label: 'Lihat Jobs',
                onPressed: () => Navigator.of(context).pop(),
                expanded: true,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _summary['title']?.toString();

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
            SafeArea(
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
                        const SizedBox(width: 12),
                        Text(
                          'Job Checkout',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    SectionCard(
                      title: 'Ringkasan Servis',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title ?? 'Servis ID: $_serviceId',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Penerangan job',
                              helperText:
                                  _descriptionError ?? 'Minimum $jobMinDescLen aksara.',
                              helperStyle: TextStyle(
                                color: _descriptionError != null
                                    ? AppColors.error
                                    : AppColors.neutral400,
                              ),
                              errorText: _descriptionError,
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            readOnly: !_allowEditing,
                            decoration: InputDecoration(
                              labelText: _allowEditing
                                  ? 'Anggaran harga (RM)'
                                  : 'Jumlah (RM)',
                              helperText: _amountError ??
                                  'Minimum RM${jobMinAmount.toStringAsFixed(2)}.',
                              helperStyle: TextStyle(
                                color: _amountError != null
                                    ? AppColors.error
                                    : AppColors.neutral400,
                              ),
                              errorText: _amountError,
                              suffixIcon: _allowEditing
                                  ? const Icon(Icons.edit_outlined)
                                  : const Icon(Icons.lock_outline),
                            ),
                          ),
                          if (_allowEditing) ...[
                            const SizedBox(height: AppSpacing.s8),
                            const Text(
                              'Harga servis belum tersedia. Masukkan anggaran untuk minta sebut harga.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: AppColors.neutral50,
                        borderRadius: AppRadius.mediumRadius,
                        border: Border.all(color: AppColors.neutral100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Tip checkout',
                            style: AppTextStyles.titleMedium,
                          ),
                          SizedBox(height: AppSpacing.s8),
                          Text(
                            'Perincikan skop tambahan dalam ruangan penerangan supaya freelancer jelas tentang tugasan.',
                          ),
                          SizedBox(height: AppSpacing.s8),
                          Text(
                            'Dana anda akan dipegang secara escrow dan hanya dilepaskan apabila job selesai atau selepas 7 hari.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: AppRadius.mediumRadius,
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                    ],
                    FTButton(
                      label: 'Create Order (Escrow Hold)',
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _createOrder,
                    ),
                  ],
                ),
              ),
            ),
            if (_isSubmitting)
              const LoadingOverlay(
                message: 'Memproses tempahan...',
                backgroundOpacity: 0.25,
              ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _parseFieldErrors(DioException error) {
    final errors = <String, String>{};
    final data = error.response?.data;
    final dynamic message =
        data is Map<String, dynamic> ? data['message'] : null;

    final messages = <String>[];
    if (message is String && message.isNotEmpty) {
      messages.add(message);
    }
    if (message is List) {
      messages.addAll(message.whereType<String>());
    }

    for (final item in messages) {
      final lower = item.toLowerCase();
      if (lower.contains('description')) {
        errors['description'] = item;
      }
      if (lower.contains('amount')) {
        errors['amount'] = item;
      }
    }

    return errors;
  }
}
