import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/service_card.dart';
import 'services_repository.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Service> _services = <Service>[];
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _categories = const <String>['Semua'];
  String _selectedCategory = 'Semua';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchServices();
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _fetchServices);
  }

  Future<void> _fetchServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final services = await servicesRepository.getServices(
        q: _searchController.text,
        category: _selectedCategory,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _services
          ..clear()
          ..addAll(services);
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
      const message = 'Tidak dapat memuatkan servis. Sila cuba lagi.';
      setState(() {
        _errorMessage = message;
      });
      showErrorSnackBar(context, '$message\n$error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await servicesRepository.getCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = <String>['Semua', ...categories];
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'Semua';
        }
      });
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Gagal memuat kategori: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            categories: _categories,
                            selectedCategory: _selectedCategory,
                            onCategorySelected: (String value) {
                              setState(() => _selectedCategory = value);
                              _fetchServices();
                            },
                          ),
                        ),
                      ),
                    if (_isLoading)
                      SliverPadding(
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
                      )
                    else if (_errorMessage != null)
                      SliverFillRemaining(
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
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FTButton(
                                label: 'Cuba Lagi',
                                onPressed: _fetchServices,
                                expanded: false,
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_services.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.store_mall_directory_outlined,
                                  size: 52, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Tiada servis buat masa ini'),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              if (index.isOdd) {
                                return const SizedBox(height: 12);
                              }
                              final service = _services[index ~/ 2];
                              return ServiceCard(
                                service: service,
                                onTap: () =>
                                    context.push('/service/${service.id}'),
                              );
                            },
                            childCount: (_services.length * 2) - 1,
                          ),
                        ),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/settings/api'),
              icon: const Icon(Icons.settings_ethernet_outlined),
              label: const Text('API Server'),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
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
