import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/ft_button.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../models/service.dart';
import '../../theme/app_theme.dart';
import 'services_repository.dart';
import '../../core/utils/error_utils.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({required this.serviceId, super.key});

  final String serviceId;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  Service? _service;
  bool _isLoading = false;
  bool _isHireLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = await servicesRepository.getServiceById(widget.serviceId);
      if (!mounted) return;
      setState(() {
        _service = service;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
      showErrorSnackBar(context, error);
    } catch (error) {
      if (!mounted) return;
      const message = 'Ralat memuat servis.';
      setState(() {
        _errorMessage = message;
      });
      showErrorSnackBar(context, '$message $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleHire(Service service) async {
    setState(() {
      _isHireLoading = true;
    });

    final jobDraft = <String, dynamic>{
      'serviceId': service.id,
      'title': service.title,
      'description': service.description,
      'price': service.price,
      'freelancerName': service.freelancerName,
    };

    try {
      await context.push('/jobs/checkout', extra: jobDraft);
    } finally {
      if (mounted) {
        setState(() {
          _isHireLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget bodyContent = Builder(
      builder: (BuildContext context) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 44,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  AppSpacing.vertical16,
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                  ),
                  AppSpacing.vertical16,
                  FTButton(
                    label: 'Cuba Lagi',
                    onPressed: _loadService,
                    expanded: false,
                  ),
                ],
              ),
            ),
          );
        }

        final service = _service;
        if (service == null) {
          return const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_mall_directory_outlined, size: 52, color: Colors.grey),
              SizedBox(height: AppSpacing.s12),
              Text('Tiada servis buat masa ini'),
            ],
          );
        }

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s24,
                AppSpacing.s24,
                AppSpacing.s24 + 96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ServiceBanner(service: service),
                  AppSpacing.vertical24,
                  Text(
                    service.title,
                    style: AppTextStyles.headlineMedium,
                  ),
                  AppSpacing.vertical8,
                  Chip(
                    label: Text(service.category),
                    backgroundColor: theme.colorScheme.surface,
                    shape: const StadiumBorder(),
                  ),
                  AppSpacing.vertical16,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.largeRadius,
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text(
                            'Harga Pakej',
                            style: AppTextStyles.labelSmall,
                          ),
                          AppSpacing.vertical8,
                          Text(
                            'RM${service.price.toStringAsFixed(2)}',
                            style: AppTextStyles.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.payments_rounded, color: AppColors.primary, size: 36),
                  ],
                    ),
                  ),
                  AppSpacing.vertical24,
                  const Text(
                    'Butiran Servis',
                    style: AppTextStyles.headlineSmall,
                  ),
                  AppSpacing.vertical8,
                  Text(
                    service.description,
                    style: AppTextStyles.bodyMedium,
                  ),
                  AppSpacing.vertical24,
                  _FreelancerProfile(
                    freelancerId: service.freelancerId,
                    freelancerName: service.freelancerName,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Maklumat Servis')),
      body: Stack(
        children: [
          bodyContent,
          if (_isHireLoading)
            const LoadingOverlay(
              message: 'Memproses tempahan...',
              backgroundOpacity: 0.25,
            ),
        ],
      ),
      bottomNavigationBar: Builder(
        builder: (BuildContext context) {
          final service = _service;
          if (service == null || _isLoading) return const SizedBox.shrink();

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s8,
                AppSpacing.s24,
                AppSpacing.s24,
              ),
              child: FTButton(
                label: 'Hire Sekarang',
                isLoading: _isHireLoading,
                onPressed: () => _handleHire(service),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceBanner extends StatelessWidget {
  const _ServiceBanner({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.largeRadius,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -32,
              top: -32,
              child: Container(
                height: 160,
                width: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      label: Text(
                        service.category,
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      side: BorderSide.none,
                    ),
                    AppSpacing.vertical16,
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
                    ),
                    AppSpacing.vertical8,
                    Text(
                      service.freelancerName?.isNotEmpty == true
                          ? 'Oleh ${service.freelancerName}'
                          : 'Freelancer ID: ${service.freelancerId}',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                    ),
                    AppSpacing.vertical8,
                    Text(
                      'RM${service.price.toStringAsFixed(2)}',
                      style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreelancerProfile extends StatelessWidget {
  const _FreelancerProfile({required this.freelancerId, this.freelancerName});

  final String freelancerId;
  final String? freelancerName;

  @override
  Widget build(BuildContext context) {
    final displayName =
        freelancerName?.isNotEmpty == true ? freelancerName! : 'Freelancer $freelancerId';
    final initials = displayName.isNotEmpty
        ? displayName.substring(0, min(2, displayName.length)).toUpperCase()
        : 'FR';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeRadius,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              initials,
              style: AppTextStyles.headlineSmall.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil Freelancer',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.neutral400),
                ),
                AppSpacing.vertical8,
                Text(
                  displayName,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.neutral500),
                ),
                AppSpacing.vertical8,
                const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.secondary, size: 18),
                    SizedBox(width: AppSpacing.s8),
                    Text(
                      'Ready to collaborate',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.neutral300),
        ],
      ),
    );
  }
}
