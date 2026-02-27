import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../core/constants/malaysia_locations.dart';

import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/freelancer_card.dart';
import '../../widgets/app_bottom_nav.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/notification_bell_button.dart';
import '../auth/auth_repository.dart';
import 'services_repository.dart';
import '../users/users_repository.dart';
import '../chat/chat_repository.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  // Static cache to preserve data across route transitions
  static List<AppUser>? _cachedFreelancers;
  static List<String>? _cachedCategories;

  final TextEditingController _searchController = TextEditingController();
  final List<AppUser> _freelancers = <AppUser>[];
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _categories = const <String>['Semua'];
  String _selectedCategory = 'Semua';
  String? _selectedSortOption;
  String? _selectedState;
  String? _selectedDistrict;
  bool _isNearMeEnabled = false;
  double? _userLat;
  double? _userLng;
  Timer? _debounce;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    // Use cached data to enable instant UI load
    if (_cachedFreelancers != null) {
      _freelancers.addAll(_cachedFreelancers!);
      // Still fetch in background, but don't show full loading
      _isLoading = false;
    }
    if (_cachedCategories != null) {
      _categories = _cachedCategories!;
    }

    _fetchFreelancers(silent: _cachedFreelancers != null);
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
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _fetchFreelancers());
  }

  Future<void> _fetchFreelancers({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final t0 = DateTime.now();
    try {
      // If "Near Me" is enabled, we need GPS location
      if (_isNearMeEnabled && (_userLat == null || _userLng == null)) {
        await _fetchGPSForNearMe();
      }

      final freelancersList = await usersRepository.getFreelancers(
        q: _searchController.text,
        category: _selectedCategory == 'Semua' ? null : _selectedCategory,
        state: _selectedState,
        district: _selectedDistrict,
      );
      debugPrint(
          '[PERF] LoadFreelancers: ${DateTime.now().difference(t0).inMilliseconds}ms');

      if (!mounted) return;

      setState(() {
        _freelancers
          ..clear()
          ..addAll(freelancersList);
        _cachedFreelancers = List.from(_freelancers);
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final message = resolveDioErrorMessage(error);
      setState(() {
        _errorMessage = silent ? null : message;
      });
      if (!silent) showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      const message = AppStrings.errorLoadingServices;
      setState(() {
        _errorMessage = silent ? null : message;
      });
      if (!silent) showErrorSnackBar(context, '$message\n$error');
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
      if (!mounted) return;

      setState(() {
        _categories = <String>['Semua', ...categories];
        _cachedCategories = _categories;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'Semua';
        }
      });
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Gagal memuat kategori: $error');
    }
  }

  Future<void> _fetchGPSForNearMe() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Keizinan lokasi diperlukan untuk ciri ini.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Keizinan lokasi ditolak kekal. Sila ubah di tetapan.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (!mounted) return;
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Gagal mendapatkan GPS: $e');
        setState(() {
          _isNearMeEnabled = false; // Turn off if it fails
        });
      }
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
        color: Colors.white,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints _) {
              return Center(
                child: RefreshIndicator(
                  onRefresh: _fetchFreelancers,
                  color: AppColors.primary,
                  child: CustomScrollView(
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: Stack(
                          children: [
                            // 1. Background Gradient Container
                            Container(
                              width: double.infinity,
                              height: 260,
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2196F3),
                                    Color(0xFF1565C0),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(32),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                bottom: false,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top Bar: Logo/Brand & Notification
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child:
                                                  const NotificationBellButton(
                                                      color: Colors.white),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                icon: const Icon(
                                                    Icons.account_circle,
                                                    color: Colors.white),
                                                onPressed: () =>
                                                    context.push('/profile'),
                                                tooltip: 'Profile',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    // Personalized Greeting
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Hello, ',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          TextSpan(
                                            text: _currentUser?.name
                                                    .split(' ')
                                                    .first ??
                                                'Tetamu',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Cari pekerja yang sesuai di sini.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 2. Overlapping Search Card
                            Container(
                              margin: const EdgeInsets.only(
                                  top: 220, left: 20, right: 20, bottom: 20),
                              child: _SearchAndFilterCard(
                                searchController: _searchController,
                                onSearchChanged: _onSearchChanged,
                                categories: _categories,
                                selectedCategory: _selectedCategory,
                                onCategorySelected: (String value) {
                                  setState(() => _selectedCategory = value);
                                  _fetchFreelancers();
                                },
                                selectedSortOption: _selectedSortOption,
                                onSortOptionSelected: (String? value) {
                                  setState(() => _selectedSortOption = value);
                                  _fetchFreelancers();
                                },
                                selectedState: _selectedState,
                                onStateSelected: (String? value) {
                                  setState(() {
                                    _selectedState = value;
                                    _selectedDistrict = null;
                                  });
                                  _fetchFreelancers();
                                },
                                selectedDistrict: _selectedDistrict,
                                onDistrictSelected: (String? value) {
                                  setState(() => _selectedDistrict = value);
                                  _fetchFreelancers();
                                },
                                isNearMeEnabled: _isNearMeEnabled,
                                onNearMeToggled: (bool value) {
                                  setState(() => _isNearMeEnabled = value);
                                  _fetchFreelancers();
                                },
                              ),
                            ),
                          ],
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
                                return const FreelancerCardSkeleton();
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
                                  onPressed: _fetchFreelancers,
                                  expanded: false,
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_freelancers.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.people_outline,
                                    size: 52, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tiada freelancer ditemui',
                                  style: AppTextStyles.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tiada freelancer ditemui untuk carian ini.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall,
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
                                final freelancer = _freelancers[index ~/ 2];
                                return FreelancerCard(
                                  user: freelancer,
                                  onTap: () async {
                                    try {
                                      final chatRepo = ChatRepository();
                                      final thread =
                                          await chatRepo.createConversation(
                                              otherUserId: freelancer.id);
                                      if (context.mounted) {
                                        context.push(
                                            '/chats/${thread.id}/messages');
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        showErrorSnackBar(
                                            context, 'Gagal membuka chat: $e');
                                      }
                                    }
                                  },
                                );
                              },
                              childCount: (_freelancers.length * 2) - 1,
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

class _SearchAndFilterCard extends StatelessWidget {
  const _SearchAndFilterCard({
    required this.searchController,
    required this.onSearchChanged,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.selectedSortOption,
    required this.onSortOptionSelected,
    required this.selectedState,
    required this.onStateSelected,
    required this.selectedDistrict,
    required this.onDistrictSelected,
    required this.isNearMeEnabled,
    required this.onNearMeToggled,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final String? selectedSortOption;
  final ValueChanged<String?> onSortOptionSelected;
  final String? selectedState;
  final ValueChanged<String?> onStateSelected;
  final String? selectedDistrict;
  final ValueChanged<String?> onDistrictSelected;
  final bool isNearMeEnabled;
  final ValueChanged<bool> onNearMeToggled;

  String get _sortLabel {
    if (isNearMeEnabled) return 'Berdekatan';
    switch (selectedSortOption) {
      case 'popular':
        return 'Popular';
      case 'newest':
        return 'Baru';
      case 'cheapest':
        return 'Murah';
      case 'expensive':
        return 'Mahal';
      default:
        return 'Tapis';
    }
  }

  void _showCategorySelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _SelectionBottomSheet(
          title: 'Kemahiran',
          items: categories,
          selectedValue: selectedCategory,
          onSelected: (value) {
            if (value != null) {
              onCategorySelected(value);
            }
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showSortSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _SortBottomSheet(
          selectedSortOption: selectedSortOption,
          isNearMeEnabled: isNearMeEnabled,
          onSortOptionSelected: (val) {
            onSortOptionSelected(val);
            if (isNearMeEnabled) onNearMeToggled(false);
            Navigator.pop(context);
          },
          onNearMeToggled: (val) {
            onNearMeToggled(val);
            if (val) onSortOptionSelected(null);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showStateSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _SelectionBottomSheet(
          title: 'Negeri',
          items: malaysiaStatesAndDistricts.keys.toList(),
          selectedValue: selectedState,
          showAllOption: true,
          allOptionLabel: 'Semua Negeri',
          onSelected: (value) {
            onStateSelected(value);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showDistrictSelector(BuildContext context) {
    if (selectedState == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _SelectionBottomSheet(
          title: 'Daerah ($selectedState)',
          items: malaysiaStatesAndDistricts[selectedState] ?? [],
          selectedValue: selectedDistrict,
          showAllOption: true,
          allOptionLabel: 'Semua Daerah',
          onSelected: (value) {
            onDistrictSelected(value);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle Buttons
          Row(
            children: [
              // Chat Button (Inactive)
              Expanded(
                child: InkWell(
                  onTap: () => context.go('/chats'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Chat',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Marketplace Button (Active)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2196F3).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.store_mall_directory_outlined,
                        color: Color(0xFF2196F3),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Marketplace',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF2196F3),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: InputDecoration(
              hintText: 'Cari freelancer...',
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.neutral500),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.neutral200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.neutral200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              filled: true,
              fillColor: AppColors.neutral50,
            ),
          ),
          const SizedBox(height: 16),
          // Horizontal Action Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionChip(
                  icon: Icons.work_outline_rounded,
                  label: selectedCategory == 'Semua'
                      ? 'Kemahiran'
                      : selectedCategory,
                  isActive: selectedCategory != 'Semua',
                  onTap: () => _showCategorySelector(context),
                  showDropdownIcon: true,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.map_outlined,
                  label: selectedState ?? 'Negeri',
                  isActive: selectedState != null,
                  onTap: () => _showStateSelector(context),
                  showDropdownIcon: true,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.location_city_outlined,
                  label: selectedDistrict ?? 'Daerah',
                  isActive: selectedDistrict != null,
                  isDisabled: selectedState == null,
                  onTap: () => _showDistrictSelector(context),
                  showDropdownIcon: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.isActive = false,
    this.isDisabled = false,
    this.showDropdownIcon = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isActive;
  final bool isDisabled;
  final bool showDropdownIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.neutral200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isDisabled
                      ? AppColors.neutral300
                      : (isActive ? AppColors.primary : AppColors.neutral600),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isDisabled
                      ? AppColors.neutral300
                      : (isActive ? AppColors.primary : AppColors.neutral600),
                ),
              ),
              if (showDropdownIcon) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDisabled
                      ? AppColors.neutral300
                      : (isActive ? AppColors.primary : AppColors.neutral500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBottomSheet extends StatelessWidget {
  const _SelectionBottomSheet({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.showAllOption = false,
    this.allOptionLabel = 'Semua',
  });

  final String title;
  final List<String> items;
  final String? selectedValue;
  final ValueChanged<String?> onSelected;
  final bool showAllOption;
  final String allOptionLabel;

  @override
  Widget build(BuildContext context) {
    final double maxSheetHeight = MediaQuery.of(context).size.height * 0.7;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (showAllOption)
                  ListTile(
                    title: Text(allOptionLabel,
                        style: TextStyle(
                            fontWeight: selectedValue == null
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selectedValue == null
                                ? AppColors.primary
                                : AppColors.neutral900)),
                    trailing: selectedValue == null
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => onSelected(null),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ...items.map((item) {
                  final isSelected = item == selectedValue;
                  return ListTile(
                    title: Text(item,
                        style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.neutral900)),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => onSelected(item),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SortBottomSheet extends StatelessWidget {
  const _SortBottomSheet({
    required this.selectedSortOption,
    required this.isNearMeEnabled,
    required this.onSortOptionSelected,
    required this.onNearMeToggled,
  });

  final String? selectedSortOption;
  final bool isNearMeEnabled;
  final ValueChanged<String?> onSortOptionSelected;
  final ValueChanged<bool> onNearMeToggled;

  Widget _buildListTile(BuildContext context, String title, IconData icon,
      bool isSelected, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? AppColors.primary : AppColors.neutral500),
      title: Text(title,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.primary : AppColors.neutral900)),
      trailing:
          isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tapis & Susunan', style: AppTextStyles.titleMedium),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          _buildListTile(
            context,
            'Terdekat',
            Icons.my_location,
            isNearMeEnabled,
            () => onNearMeToggled(true),
          ),
          _buildListTile(
            context,
            'Popular',
            Icons.local_fire_department_outlined,
            selectedSortOption == 'popular' && !isNearMeEnabled,
            () => onSortOptionSelected('popular'),
          ),
          _buildListTile(
            context,
            'Paling Baru',
            Icons.auto_awesome_outlined,
            selectedSortOption == 'newest' && !isNearMeEnabled,
            () => onSortOptionSelected('newest'),
          ),
          _buildListTile(
            context,
            'Harga (Murah ke Mahal)',
            Icons.arrow_upward_rounded,
            selectedSortOption == 'cheapest' && !isNearMeEnabled,
            () => onSortOptionSelected('cheapest'),
          ),
          _buildListTile(
            context,
            'Harga (Mahal ke Murah)',
            Icons.arrow_downward_rounded,
            selectedSortOption == 'expensive' && !isNearMeEnabled,
            () => onSortOptionSelected('expensive'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
