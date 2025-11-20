import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/async_state_view.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/service_card.dart';
import 'service_list_controller.dart';

class ServiceListScreen extends ConsumerStatefulWidget {
  const ServiceListScreen({super.key, this.initialCategory, this.initialQuery});

  final String? initialCategory;
  final String? initialQuery;

  @override
  ConsumerState<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends ConsumerState<ServiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  ProviderSubscription<ServiceListState>? _errorListener;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _errorListener = ref.listen<ServiceListState>(
      serviceListControllerProvider,
      (previous, next) {
        final previousStatus = previous?.services;
        final nextStatus = next.services;
        if (nextStatus.hasError && previousStatus != nextStatus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final message = nextStatus.message ??
                friendlyErrorMessage(nextStatus.error ?? 'Tidak dapat memuatkan servis.');
            showErrorSnackBar(context, message);
          });
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(serviceListControllerProvider.notifier).bootstrap(
            initialCategory: widget.initialCategory,
            initialQuery: widget.initialQuery,
          );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _errorListener?.close();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(serviceListControllerProvider.notifier)
          .updateSearchQuery(_searchController.text);
    });
  }

  Future<void> _openFilterSheet(
    ServiceListFilters currentFilters,
    List<String> categories,
  ) async {
    final minPriceController =
        TextEditingController(text: currentFilters.minPrice?.toString() ?? '');
    final maxPriceController =
        TextEditingController(text: currentFilters.maxPrice?.toString() ?? '');
    final maxDeliveryController =
        TextEditingController(text: currentFilters.maxDeliveryDays?.toString() ?? '');
    double? minRating = currentFilters.minRating;
    String selectedCategory = currentFilters.category;

    final ServiceListFilters? result = await showModalBottomSheet<ServiceListFilters>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Penapis lanjutan',
                      style: AppTextStyles.headlineSmall,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                DropdownButtonFormField<String>(
                  value: selectedCategory.isNotEmpty ? selectedCategory : 'Semua',
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: <String>{'Semua', ...categories}
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    if (value == null) return;
                    selectedCategory = value;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Harga minima (RM)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: TextField(
                        controller: maxPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Harga maksima (RM)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<double>(
                        value: minRating ?? 0,
                        decoration: const InputDecoration(labelText: 'Rating minimum'),
                        items: _ratingOptions
                            .map(
                              (double value) => DropdownMenuItem<double>(
                                value: value,
                                child: Text(_ratingLabel(value)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (double? value) {
                          minRating = value;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: TextField(
                        controller: maxDeliveryController,
                        decoration: const InputDecoration(
                          labelText: 'Maks. hari penghantaran',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        minPriceController.clear();
                        maxPriceController.clear();
                        maxDeliveryController.clear();
                        minRating = null;
                        selectedCategory = 'Semua';
                      },
                      child: const Text('Set semula'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          currentFilters.copyWith(
                            category: selectedCategory,
                            minPrice: double.tryParse(minPriceController.text),
                            maxPrice: double.tryParse(maxPriceController.text),
                            minRating: minRating,
                            maxDeliveryDays: int.tryParse(maxDeliveryController.text),
                          ),
                        );
                      },
                      child: const Text('Guna penapis'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    await ref.read(serviceListControllerProvider.notifier).applyFilters(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceListControllerProvider);
    final filters = state.filters;
    final servicesState = state.services;

    if (_searchController.text != filters.searchQuery) {
      _searchController.value = TextEditingValue(
        text: filters.searchQuery,
        selection: TextSelection.collapsed(offset: filters.searchQuery.length),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF3FC), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints _) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: CustomScrollView(
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: _MarketplaceHero(
                            searchController: _searchController,
                            onSearchChanged: _onSearchChanged,
                            categories: state.categories,
                            selectedCategory: filters.category,
                            onCategorySelected: (String value) {
                              ref
                                  .read(serviceListControllerProvider.notifier)
                                  .selectCategory(value);
                            },
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: _FilterBar(
                            filters: filters,
                            onOpenFilters: () => _openFilterSheet(filters, state.categories),
                          ),
                        ),
                      ),
                      AsyncStateView<List<Service>>(
                        state: servicesState,
                        onRetry: () =>
                            ref.read(serviceListControllerProvider.notifier).refresh(),
                        loading: (_) => SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (BuildContext context, int index) {
                                if (index.isOdd) {
                                  return const SizedBox(height: 12);
                                }
                                return const ServiceCardSkeleton();
                              },
                              childCount: (6 * 2) - 1,
                            ),
                          ),
                        ),
                        empty: (BuildContext context, String message) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.store_mall_directory_outlined,
                                    size: 52, color: Colors.grey),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    message,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FTButton(
                                  label: 'Cari Servis Lain',
                                  expanded: false,
                                  onPressed: () =>
                                      ref.read(serviceListControllerProvider.notifier).refresh(),
                                ),
                              ],
                            ),
                          );
                        },
                        error: (BuildContext context, String message, VoidCallback? onRetry) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    Icons.error_outline,
                                    size: 42,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    message,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FTButton(
                                    label: 'Cuba Lagi',
                                    onPressed: onRetry,
                                    expanded: false,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        data: (BuildContext context, List<Service> services) {
                          return SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  if (index.isOdd) {
                                    return const SizedBox(height: 12);
                                  }
                                  final service = services[index ~/ 2];
                                  return ServiceCard(
                                    service: service,
                                    onTap: () =>
                                        context.push('/service/${service.id}'),
                                  );
                                },
                                childCount: (services.length * 2) - 1,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  }
}

class _MarketplaceHero extends StatelessWidget {
  const _MarketplaceHero({
    required this.searchController,
    required this.onSearchChanged,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store_mall_directory_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marketplace Servis',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih servis berkualiti dengan reka bentuk marketplace moden.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: const InputDecoration(
              hintText: 'Cari servis, kategori atau freelancer...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (BuildContext context, int index) {
                final category = categories[index];
                final isSelected = category == selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) => onCategorySelected(category),
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.neutral400,
                        fontWeight: FontWeight.w600,
                      ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.neutral100,
                    ),
                  ),
                );
              },
              separatorBuilder: (BuildContext context, int _) => const SizedBox(width: 8),
              itemCount: categories.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filters, required this.onOpenFilters});

  final ServiceListFilters filters;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final activeBadges = _buildBadges(filters);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeRadius,
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onOpenFilters,
            icon: const Icon(Icons.filter_list_rounded),
            label: const Text('Penapis'),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: activeBadges.isEmpty
                ? Text(
                    'Tiada penapis tambahan',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.neutral500,
                        ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activeBadges
                        .map((label) => _FilterBadge(label: label))
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }

  List<String> _buildBadges(ServiceListFilters filters) {
    final badges = <String>[];
    if (filters.minPrice != null) {
      badges.add('Min RM${filters.minPrice!.toStringAsFixed(0)}');
    }
    if (filters.maxPrice != null) {
      badges.add('Maks RM${filters.maxPrice!.toStringAsFixed(0)}');
    }
    if (filters.minRating != null && filters.minRating! > 0) {
      badges.add(_ratingLabel(filters.minRating!));
    }
    if (filters.maxDeliveryDays != null) {
      badges.add('≤ ${filters.maxDeliveryDays} hari');
    }
    if (filters.category != 'Semua') {
      badges.add(filters.category);
    }
    return badges;
  }
}

class _FilterBadge extends StatelessWidget {
  const _FilterBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _ratingLabel(double rating) {
  if (rating <= 0) {
    return 'Semua rating';
  }
  return '≥ ${rating.toStringAsFixed(rating.truncateToDouble() == rating ? 0 : 1)} bintang';
}

const List<double> _ratingOptions = <double>[0, 3, 4, 4.5];
