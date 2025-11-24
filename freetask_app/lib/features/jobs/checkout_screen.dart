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

class JobCheckoutScreen extends StatefulWidget {
  const JobCheckoutScreen({super.key, this.serviceSummary});

  final Map<String, dynamic>? serviceSummary;

  @override
  State<JobCheckoutScreen> createState() => _JobCheckoutScreenState();
}

class _JobCheckoutScreenState extends State<JobCheckoutScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Map<String, dynamic> get _summary => widget.serviceSummary ?? <String, dynamic>{};

  String get _serviceId => (_summary['serviceId'] ?? '') as String;

  String get _description => _summary['description']?.toString() ?? '';

  String get _serviceDescription =>
      _summary['serviceDescription']?.toString() ?? _summary['service_desc']?.toString() ?? '';

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
    final amount = _amount;
    final description = _description.isNotEmpty ? _description : _serviceDescription;

    if (serviceId.isEmpty || amount == null || description.isEmpty || _hasPriceIssue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hasPriceIssue
              ? 'Harga servis belum tersedia. Sila cuba lagi selepas refresh.'
              : 'Maklumat servis tidak lengkap.'),
        ),
      );
      return;
    }

    if (description.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Penerangan perlu sekurang-kurangnya 10 aksara.'),
        ),
      );
      return;
    }

    if (amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah minima ialah RM1.00.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final job = await jobsRepository.createOrder(
        serviceId,
        amount,
        description,
        serviceTitle: _title.isEmpty ? _summary['serviceTitle']?.toString() : _title,
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
      setState(() {
        _errorMessage = message;
      });
      final status = error.response?.statusCode;
      if (status != 400 && status != 404) {
        showErrorSnackBar(context, message);
      }
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.message.isEmpty ? 'Maklumat tempahan tidak sah.' : error.message;
      setState(() {
        _errorMessage = message;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    final amount = _amount;
    final amountText =
        amount == null || amount <= 0 || _hasPriceIssue ? 'Harga belum tersedia' : 'RM${amount.toStringAsFixed(2)}';

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
                              const SizedBox(height: 8),
                              Text('Jumlah: $amountText'),
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
}
