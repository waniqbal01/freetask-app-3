import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/service.dart';
import '../../theme/app_theme.dart';
import 'services_repository.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  final List<Service> _services = <Service>[];
  bool _isLoading = true;
  String? _errorMessage;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await servicesRepository.fetchMyServices();
      if (!mounted) return;
      setState(() {
        _services
          ..clear()
          ..addAll(data);
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      showErrorSnackBar(context, error);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Tidak dapat memuatkan servis anda.');
      showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openForm({Service? service}) async {
    final route = service == null
        ? '/freelancer/services/new'
        : '/freelancer/services/${service.id}/edit';
    final result = await context.push<bool>(route, extra: service);
    if (result == true) {
      await _loadServices();
    }
  }

  Future<void> _deleteService(Service service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Padam Servis?'),
          content: Text('Anda pasti mahu memadam "${service.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Padam'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() => _deletingId = service.id);

    try {
      await servicesRepository.deleteService(service.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis dipadam.')),
      );
      await _loadServices();
    } on AppException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _deletingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servis Saya'),
        actions: [
          TextButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Tambah'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Servis Baharu'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadServices,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        children: const [
          SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: AppSpacing.s12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  FTButton(
                    label: 'Cuba Lagi',
                    onPressed: _loadServices,
                    expanded: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_services.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.design_services_outlined,
                      size: 48, color: AppColors.neutral300),
                  const SizedBox(height: AppSpacing.s12),
                  const Text('Belum ada servis. Jom tambah yang pertama!'),
                  const SizedBox(height: AppSpacing.s16),
                  FTButton(
                    label: 'Tambah Servis',
                    onPressed: () => _openForm(),
                    expanded: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _services.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
      itemBuilder: (BuildContext context, int index) {
        final service = _services[index];
        final isDeleting = _deletingId == service.id;
        return _ServiceManagementCard(
          service: service,
          isDeleting: isDeleting,
          onEdit: () => _openForm(service: service),
          onDelete: () => _deleteService(service),
          onView: () => context.push('/service/${service.id}'),
        );
      },
    );
  }
}

class _ServiceManagementCard extends StatelessWidget {
  const _ServiceManagementCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
    this.isDeleting = false,
  });

  final Service service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onView;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'RM${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              service.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s4,
              children: [
                Chip(
                  label: Text(service.category),
                  backgroundColor: AppColors.neutral50,
                ),
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text(service.freelancerName ?? 'Anda'),
                ),
              ],
            ),
            const Divider(height: AppSpacing.s24),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Lihat'),
                ),
                const SizedBox(width: AppSpacing.s8),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: isDeleting ? null : onDelete,
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(isDeleting ? 'Memadam...' : 'Padam'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
