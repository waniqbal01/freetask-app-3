import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/service.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/service_card.dart';
import '../../widgets/app_bottom_nav.dart';
import '../auth/auth_repository.dart';
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
  String? _selectedSortOption;
  Timer? _debounce;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _fetchServices();
    _loadCategories();
    _loadCurrentUser();
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
        category: _selectedCategory == 'Semua' ? null : _selectedCategory,
        sortBy: _selectedSortOption,
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
      const message = AppStrings.errorLoadingServices;
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

  Future<void> _loadCurrentUser() async {
    try {
      final user = await authRepository.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
      });
    } catch (_) {
      // keep browsing experience even if profile fails to load
    }
  }

  @override
  Widget build(BuildContext context) {
    // Role is no longer needed for FAB since it was removed
    // final role = context.read<RequestsRepository>().userRole;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.home),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_currentUser != null) ...[
                                const SizedBox(height: AppSpacing.s12),
                              ],
                              _MarketplaceHero(
                                searchController: _searchController,
                                onSearchChanged: _onSearchChanged,
                                categories: _categories,
                                selectedCategory: _selectedCategory,
                                onCategorySelected: (String value) {
                                  setState(() => _selectedCategory = value);
                                  _fetchServices();
                                },
                                selectedSortOption: _selectedSortOption,
                                onSortOptionSelected: (String? value) {
                                  setState(() => _selectedSortOption = value);
                                  _fetchServices();
                                },
                              ),
                            ],
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
                                    color: Theme.of(context).colorScheme.error,
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
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.store_mall_directory_outlined,
                                    size: 52, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tiada servis ditemui',
                                  style: AppTextStyles.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tiada servis ditemui untuk carian ini. Anda boleh terus post job baru atau minta quote khusus.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall,
                                ),
                                const SizedBox(height: 16),
                                FTButton(
                                  label: 'Post job sekarang',
                                  onPressed: () => context.push('/checkout'),
                                  expanded: true,
                                ),
                                const SizedBox(height: 8),
                                FTButton(
                                  label: 'Minta quote',
                                  onPressed: () => context.push('/jobs'),
                                  expanded: true,
                                  variant: FTButtonVariant.outline,
                                ),
                                const SizedBox(height: 12),
                                FTButton(
                                  label: 'Segar semula',
                                  onPressed: _fetchServices,
                                  expanded: false,
                                  variant: FTButtonVariant.ghost,
                                ),
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
    required this.selectedSortOption,
    required this.onSortOptionSelected,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final String? selectedSortOption;
  final ValueChanged<String?> onSortOptionSelected;

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
                child: const Icon(Icons.store_mall_directory_outlined,
                    color: AppColors.primary),
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
          const SizedBox(height: AppSpacing.s16),
          // Category Chips
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
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.neutral400,
                        fontWeight: FontWeight.w600,
                      ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color:
                          isSelected ? AppColors.primary : AppColors.neutral100,
                    ),
                  ),
                );
              },
              separatorBuilder: (BuildContext context, int _) =>
                  const SizedBox(width: 8),
              itemCount: categories.length,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          // Sort Filter Buttons
          Row(
            children: [
              _FilterButton(
                label: 'Popular',
                isSelected: selectedSortOption == 'popular',
                onTap: () => onSortOptionSelected(
                  selectedSortOption == 'popular' ? null : 'popular',
                ),
                icon: Icons.local_fire_department_rounded,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: 'Baru',
                isSelected: selectedSortOption == 'newest',
                onTap: () => onSortOptionSelected(
                  selectedSortOption == 'newest' ? null : 'newest',
                ),
                icon: Icons.auto_awesome_rounded,
                color: Colors.purple,
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: 'Murah',
                isSelected: selectedSortOption == 'cheapest',
                onTap: () => onSortOptionSelected(
                  selectedSortOption == 'cheapest' ? null : 'cheapest',
                ),
                icon: Icons.savings_rounded,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: 'Mahal',
                isSelected: selectedSortOption == 'expensive',
                onTap: () => onSortOptionSelected(
                  selectedSortOption == 'expensive' ? null : 'expensive',
                ),
                icon: Icons.diamond_rounded,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatefulWidget {
  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;

    return Expanded(
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
            decoration: BoxDecoration(
              gradient: widget.isSelected
                  ? LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: widget.isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isSelected ? color : AppColors.neutral200,
                width: widget.isSelected ? 1.5 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 15,
                    color: widget.isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: widget.isSelected
                              ? Colors.white
                              : AppColors.neutral600,
                          fontWeight: widget.isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 12,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
