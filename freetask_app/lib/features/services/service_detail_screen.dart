import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/ft_button.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../models/service.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import 'services_repository.dart';
import '../../core/utils/error_utils.dart';
import '../auth/auth_repository.dart';
import '../jobs/jobs_repository.dart';
import 'package:geolocator/geolocator.dart';

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
  AppUser? _currentUser;
  double? _clientLat;
  double? _clientLng;

  @override
  void initState() {
    super.initState();
    _loadService();
    _loadCurrentUser();
  }

  double? get _calculatedDistance {
    if (_clientLat != null &&
        _clientLng != null &&
        _service?.freelancerLatitude != null &&
        _service?.freelancerLongitude != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _clientLat!,
        _clientLng!,
        _service!.freelancerLatitude!,
        _service!.freelancerLongitude!,
      );
      return distanceInMeters / 1000;
    }
    return null;
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await authRepository.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _clientLat = user?.latitude;
        _clientLng = user?.longitude;
      });

      if (_clientLat == null || _clientLng == null) {
        try {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            final position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.low);
            if (mounted) {
              setState(() {
                _clientLat = position.latitude;
                _clientLng = position.longitude;
              });
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      // User might not be logged in, that's okay
    }
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
    } on DioException catch (error) {
      if (!mounted) return;
      final message = resolveDioErrorMessage(error);
      setState(() {
        _errorMessage = message;
      });
      showErrorSnackBar(context, message);
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
    if (service.isPriceUnavailable) {
      // Skip confirmation — direct to checkout for price-issue flow
      setState(() => _isHireLoading = true);
      try {
        await context.push('/job-checkout', extra: <String, dynamic>{
          'serviceId': service.id,
          'title': service.title,
          'description': service.description,
          'serviceDescription': service.description,
          'price': service.price,
          'priceIssue': true,
        });
      } finally {
        if (mounted) setState(() => _isHireLoading = false);
      }
      return;
    }

    // Hire Confirmation Bottom Sheet
    final platformFeeRate = 0.02;
    final platformFee = service.price * platformFeeRate;
    final total = service.price + platformFee;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.hireConfirmTitle,
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              service.title,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.neutral500),
            ),
            const SizedBox(height: 20),
            _PriceRow(
              label: AppStrings.hireConfirmServiceFee,
              value: 'RM${service.price.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 10),
            _PriceRow(
              label:
                  '${AppStrings.hireConfirmPlatformFee} (${(platformFeeRate * 100).toStringAsFixed(0)}%)',
              value: 'RM${platformFee.toStringAsFixed(2)}',
              isLight: true,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            _PriceRow(
              label: AppStrings.hireConfirmTotal,
              value: 'RM${total.toStringAsFixed(2)}',
              isBold: true,
            ),
            const SizedBox(height: 24),
            FTButton(
              label: AppStrings.hireConfirmBtn,
              onPressed: () => Navigator.pop(sheetCtx, true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetCtx, false),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isHireLoading = true);
    final jobDraft = <String, dynamic>{
      'serviceId': service.id,
      'title': service.title,
      'description': service.description,
      'serviceDescription': service.description,
      'price': service.price,
      'priceIssue': false,
    };
    try {
      await context.push('/job-checkout', extra: jobDraft);
    } finally {
      if (mounted) setState(() => _isHireLoading = false);
    }
  }

  Future<void> _handleMessage() async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mesej Penyedia'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Apa yang anda ingin tanya?',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Hantar'),
          ),
        ],
      ),
    );

    if (message == null || message.trim().isEmpty || !mounted) return;

    setState(() => _isHireLoading = true);
    try {
      final job = await jobsRepository.createInquiry(
        serviceId: widget.serviceId,
        message: message,
      );
      if (mounted) {
        context.push('/chats/${job.id}/messages');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Gagal menghantar mesej: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isHireLoading = false);
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
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.error),
                  ),
                  AppSpacing.vertical16,
                  FTButton(
                    label: 'Cuba Lagi',
                    onPressed: _loadService,
                    expanded: false,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  TextButton.icon(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Pergi ke Home'),
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
              Icon(Icons.store_mall_directory_outlined,
                  size: 52, color: Colors.grey),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text(service.category),
                        backgroundColor: theme.colorScheme.surface,
                        shape: const StadiumBorder(),
                      ),
                      if (_calculatedDistance != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.blue.shade200, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on,
                                  size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                '${_calculatedDistance!.toStringAsFixed(1)} km',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
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
                              if (service.isPriceUnavailable)
                                Text(
                                  'Harga belum tersedia / invalid, sila refresh',
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(color: Colors.orange.shade700),
                                )
                              else
                                Text(
                                  'RM${service.price.toStringAsFixed(2)}',
                                  style: AppTextStyles.headlineSmall,
                                ),
                              AppSpacing.vertical8,
                              Text(
                                service.freelancerName?.isNotEmpty == true
                                    ? 'Disediakan oleh ${service.freelancerName}'
                                    : 'Disediakan oleh freelancer',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.payments_rounded,
                            color: AppColors.primary, size: 36),
                      ],
                    ),
                  ),
                  if (service.isPriceUnavailable) ...[
                    AppSpacing.vertical16,
                    _PriceIssueBlock(onRefresh: _loadService),
                  ],
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
                    name: service.freelancerName,
                    avatarUrl: service.freelancerAvatarUrl,
                    state: service.freelancerState,
                    district: service.freelancerDistrict,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    final isOwner = _currentUser != null &&
        _service != null &&
        _currentUser!.id == _service!.freelancerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maklumat Servis'),
        actions: [
          if (isOwner && _service != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await context.push(
                  '/services/${_service!.id}/edit',
                  extra: _service,
                );
                // Refresh if service was edited or deleted
                if (result == true && mounted) {
                  _loadService();
                }
              },
              tooltip: 'Edit Servis',
            ),
        ],
      ),
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

          bool isOutOfRange = false;
          String? coverageMessage;

          final dist = _calculatedDistance;
          final radius = service.freelancerCoverageRadius;

          if (dist != null && radius != null && dist > radius) {
            if (service.freelancerAcceptsOutstation) {
              coverageMessage =
                  'Nota: Anda berada ${dist.toStringAsFixed(1)}km dari lokasi freelancer (luar radius $radius km). Cas tambahan mungkin dikenakan.';
            } else {
              isOutOfRange = true;
              coverageMessage =
                  'Maaf, lokasi anda (${dist.toStringAsFixed(1)}km) berada di luar radius liputan freelancer ini ($radius km).';
            }
          }

          final priceIssue = service.isPriceUnavailable;
          final disableHire = priceIssue || isOutOfRange;

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s8,
                AppSpacing.s24,
                AppSpacing.s24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (priceIssue) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: AppRadius.mediumRadius,
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              'Harga servis belum sah. Mohon refresh atau hubungi sokongan untuk bantuan sebelum hire.',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: Colors.orange.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => GoRouter.of(context).go('/chats'),
                        icon: const Icon(Icons.support_agent_outlined),
                        label: const Text('Chat sokongan'),
                      ),
                    ),
                  ],
                  if (coverageMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: isOutOfRange
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                        borderRadius: AppRadius.mediumRadius,
                        border: Border.all(
                            color: isOutOfRange
                                ? Colors.red.shade200
                                : Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              isOutOfRange
                                  ? Icons.block
                                  : Icons.warning_amber_rounded,
                              color: isOutOfRange
                                  ? Colors.red.shade700
                                  : Colors.orange.shade700,
                              size: 20),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              coverageMessage,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: isOutOfRange
                                      ? Colors.red.shade800
                                      : Colors.orange.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                  ],
                  if (disableHire) ...[
                    FTButton(
                      label:
                          priceIssue ? 'Minta sebut harga' : 'Di Luar Kawasan',
                      isLoading: _isHireLoading,
                      onPressed:
                          priceIssue ? () => _handleHire(service) : () {},
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    OutlinedButton.icon(
                      onPressed: _handleMessage,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Mesej Penyedia'),
                    ),
                  ] else
                    FTButton(
                      label: 'Hire Sekarang',
                      isLoading: _isHireLoading,
                      onPressed: () => _handleHire(service),
                    ),
                ],
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
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      side: BorderSide.none,
                    ),
                    AppSpacing.vertical16,
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineSmall
                          .copyWith(color: Colors.white),
                    ),
                    AppSpacing.vertical8,
                    Row(
                      children: [
                        if (service.isPriceUnavailable)
                          Text(
                            'Harga belum tersedia',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: Colors.white),
                          )
                        else
                          Text(
                            'RM${service.price.toStringAsFixed(2)}',
                            style: AppTextStyles.headlineSmall
                                .copyWith(color: Colors.white),
                          ),
                      ],
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

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isLight = false,
  });

  final String label;
  final String value;
  final bool isBold;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final color = isLight ? AppColors.neutral400 : AppColors.neutral500;
    final weight = isBold ? FontWeight.w700 : FontWeight.w500;
    final style =
        AppTextStyles.bodyMedium.copyWith(color: color, fontWeight: weight);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _FreelancerProfile extends StatelessWidget {
  const _FreelancerProfile({
    required this.freelancerId,
    this.name,
    this.avatarUrl,
    this.state,
    this.district,
  });

  final String freelancerId;
  final String? name;
  final String? avatarUrl;
  final String? state;
  final String? district;

  @override
  Widget build(BuildContext context) {
    final displayName =
        (name != null && name!.isNotEmpty) ? name! : 'Freelancer';
    final initials = displayName
        .trim()
        .split(' ')
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return GestureDetector(
      onTap: () {
        if (freelancerId.isNotEmpty) {
          GoRouter.of(context).push('/users/$freelancerId');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.largeRadius,
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            if (avatarUrl != null && avatarUrl!.isNotEmpty)
              ClipOval(
                child: Image.network(
                  avatarUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(initials,
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: AppColors.primary)),
                  ),
                ),
              )
            else
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  initials,
                  style: AppTextStyles.headlineSmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kepakaran Oleh',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.neutral400),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (state != null && state!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_city,
                            color: Colors.grey.shade500, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            district != null && district!.isNotEmpty
                                ? '$district, $state'
                                : state!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          color: AppColors.secondary, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Lihat profil →',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.neutral300),
          ],
        ),
      ),
    );
  }
}

class _PriceIssueBlock extends StatelessWidget {
  const _PriceIssueBlock({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: AppRadius.largeRadius,
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.orange.shade700),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Harga servis belum tersedia atau tidak sah.',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.orange.shade800, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'Sila refresh untuk cuba semula atau hubungi sokongan sebelum meneruskan tempahan.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              FTButton(
                label: 'Refresh',
                onPressed: onRefresh,
                expanded: false,
                size: FTButtonSize.small,
              ),
              const SizedBox(width: AppSpacing.s12),
              FTButton(
                label: 'Minta sebut harga',
                expanded: false,
                size: FTButtonSize.small,
                onPressed: () => GoRouter.of(context)
                    .push('/job-checkout', extra: {'priceIssue': true}),
              ),
              const SizedBox(width: AppSpacing.s12),
              TextButton.icon(
                onPressed: () => GoRouter.of(context).go('/chats'),
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text('Hubungi sokongan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
