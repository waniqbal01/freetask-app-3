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

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../../services/upload_service.dart';
import '../auth/auth_repository.dart';

class JobCheckoutScreen extends StatefulWidget {
  const JobCheckoutScreen({super.key, this.serviceSummary});

  final Map<String, dynamic>? serviceSummary;

  @override
  State<JobCheckoutScreen> createState() => _JobCheckoutScreenState();
}

class _JobCheckoutScreenState extends State<JobCheckoutScreen> {
  bool _isSubmitting = false;
  bool _isUploading = false;
  String? _errorMessage;
  String? _messageError;
  String? _amountError;
  late final TextEditingController _descriptionController;
  late final TextEditingController _messageController;
  late final TextEditingController _amountController;
  late final bool _allowEditing;
  final List<String> _attachments = [];

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
    _messageController = TextEditingController();
    _amountController = TextEditingController(
      text: _amount != null && _amount! > 0 ? _amount!.toStringAsFixed(2) : '',
    );
    _allowEditing = _hasPriceIssue || _amount == null || _amount! <= 0;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _messageController.dispose();
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
    // Use message input as the job description
    final messageInput = _messageController.text.trim();
    final combinedDescription = messageInput;

    final amountInput = _amountController.text.trim();
    final parsedAmount =
        amountInput.isNotEmpty ? double.tryParse(amountInput) : _amount;

    setState(() {
      _errorMessage = null;
      _messageError = null;
      _amountError = null;
    });

    if (serviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maklumat servis tidak lengkap.')),
      );
      return;
    }

    if (combinedDescription.length < jobMinDescLen ||
        parsedAmount == null ||
        parsedAmount < jobMinAmount) {
      setState(() {
        _messageError = combinedDescription.length < jobMinDescLen
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
        parsedAmount,
        combinedDescription, // Send message as description
        serviceTitle:
            _title.isEmpty ? _summary['serviceTitle']?.toString() : _title,
        attachments: _attachments.isNotEmpty ? _attachments : null,
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
        _messageError = fieldErrors['description'];
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
          _messageError = message;
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
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    maxLines: 2,
                                    enabled: false, // Read-only
                                    decoration: InputDecoration(
                                      labelText: 'Butiran Servis',
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      disabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                        borderRadius: AppRadius.mediumRadius,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s12),
                                  TextField(
                                    controller: _messageController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText:
                                          'Mesej / Arahan kepada freelancer',
                                      hintText:
                                          'Sila nyatakan keperluan job anda...',
                                      helperText: _messageError ??
                                          'Minimum $jobMinDescLen aksara.',
                                      helperStyle: TextStyle(
                                        color: _messageError != null
                                            ? AppColors.error
                                            : AppColors.neutral400,
                                      ),
                                      errorText: _messageError,
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s12),
                                  TextField(
                                    controller: _amountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
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
                            SectionCard(
                              title: 'Lampiran (Pautan)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_attachments.isNotEmpty) ...[
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _attachments
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final index = entry.key;
                                        final url = entry.value;
                                        return Chip(
                                          label: Text(
                                            url.length > 30
                                                ? '${url.substring(0, 30)}...'
                                                : url,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                          onDeleted: () {
                                            setState(() {
                                              _attachments.removeAt(index);
                                            });
                                          },
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  FTButton(
                                    label: _isUploading
                                        ? 'Uploading...'
                                        : 'Tambah Pautan Document/Image',
                                    size: FTButtonSize.small,
                                    variant: FTButtonVariant.outline,
                                    expanded: false,
                                    isLoading: _isUploading,
                                    onPressed: _isUploading
                                        ? null
                                        : () async {
                                            await showModalBottomSheet(
                                              context: context,
                                              shape:
                                                  const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                        top: Radius.circular(
                                                            16)),
                                              ),
                                              builder: (context) => SafeArea(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ListTile(
                                                      leading: const Icon(Icons
                                                          .upload_file_rounded),
                                                      title: const Text(
                                                          'Muat naik dari peranti'),
                                                      onTap: () async {
                                                        Navigator.pop(context);
                                                        try {
                                                          final result =
                                                              await FilePicker
                                                                  .platform
                                                                  .pickFiles(
                                                            withData: true,
                                                            type:
                                                                FileType.custom,
                                                            allowedExtensions: [
                                                              'jpg',
                                                              'jpeg',
                                                              'png',
                                                              'pdf',
                                                              'doc',
                                                              'docx'
                                                            ],
                                                          );

                                                          if (result != null &&
                                                              result.files
                                                                  .isNotEmpty) {
                                                            final file = result
                                                                .files.first;
                                                            final bytes =
                                                                file.bytes;
                                                            final name =
                                                                file.name;

                                                            if (bytes == null) {
                                                              throw Exception(
                                                                  'Gagal membaca fail.');
                                                            }

                                                            setState(() {
                                                              _isUploading =
                                                                  true;
                                                            });

                                                            final mimeType =
                                                                lookupMimeType(
                                                                    name);
                                                            final uploadResult =
                                                                await uploadService
                                                                    .uploadData(
                                                                        name,
                                                                        bytes,
                                                                        mimeType);

                                                            setState(() {
                                                              _attachments.add(
                                                                  uploadResult
                                                                      .url);
                                                            });
                                                          }
                                                        } catch (e) {
                                                          if (mounted) {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      'Ralat muat naik: $e')),
                                                            );
                                                          }
                                                        } finally {
                                                          if (mounted) {
                                                            setState(() {
                                                              _isUploading =
                                                                  false;
                                                            });
                                                          }
                                                        }
                                                      },
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(
                                                          Icons.link_rounded),
                                                      title: const Text(
                                                          'Tampal Pautan URL'),
                                                      onTap: () async {
                                                        Navigator.pop(context);
                                                        final controller =
                                                            TextEditingController();
                                                        final url =
                                                            await showDialog<
                                                                String>(
                                                          context: context,
                                                          builder: (context) =>
                                                              AlertDialog(
                                                            title: const Text(
                                                                'Tambah Pautan'),
                                                            content: TextField(
                                                              controller:
                                                                  controller,
                                                              decoration:
                                                                  const InputDecoration(
                                                                hintText:
                                                                    'https://example.com/file.pdf',
                                                                labelText:
                                                                    'URL Pautan',
                                                              ),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context),
                                                                child:
                                                                    const Text(
                                                                        'Batal'),
                                                              ),
                                                              FilledButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        controller
                                                                            .text),
                                                                child: const Text(
                                                                    'Tambah'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (url != null &&
                                                            url
                                                                .trim()
                                                                .isNotEmpty) {
                                                          setState(() {
                                                            _attachments.add(
                                                                url.trim());
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                  ),
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
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                            const SizedBox(height: AppSpacing.s24),
                          ],
                        ),
                      ),
                    ),
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
