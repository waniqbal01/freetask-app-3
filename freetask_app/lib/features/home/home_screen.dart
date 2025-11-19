import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/service.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/service_card.dart';
import '../auth/auth_repository.dart';
import '../services/services_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppUser? _user;
  List<String> _categories = const <String>[];
  List<Service> _featured = const <Service>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        authRepository.getCurrentUser(),
        servicesRepository.getCategories(),
        servicesRepository.getServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as AppUser?;
        _categories = (results[1] as List<String>?) ?? const <String>[];
        _featured = ((results[2] as List<Service>?) ?? const <Service>[]) 
            .take(6)
            .toList(growable: false);
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      showErrorSnackBar(context, error);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Tidak dapat memuatkan dashboard.');
      showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadContent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: _buildHero(context),
                ),
              ),
              if (_categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
                    child: _CategorySection(
                      categories: _categories,
                      onSelected: (String category) {
                        final uri = Uri(path: '/services', queryParameters: {'category': category});
                        context.push(uri.toString());
                      },
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s20, 0),
                  child: Row(
                    children: [
                      Text(
                        'Servis Pilihan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push('/services'),
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s20),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else if (_featured.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Belum ada servis popular.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s20, 0, AppSpacing.s20, AppSpacing.s20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        if (index.isOdd) {
                          return const SizedBox(height: AppSpacing.s12);
                        }
                        final service = _featured[index ~/ 2];
                        return ServiceCard(
                          service: service,
                          onTap: () => context.push('/service/${service.id}'),
                        );
                      },
                      childCount: (_featured.length * 2) - 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final name = _user?.name ?? 'FreeTasker';
    final role = _user?.role?.toUpperCase();
    final isFreelancer = role == 'FREELANCER';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeRadius,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hai, $name',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            isFreelancer
                ? 'Urus servis dan job anda di sini.'
                : 'Cari servis profesional atau cipta job baharu.',
          ),
          const SizedBox(height: AppSpacing.s20),
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s12,
            children: [
              FTButton(
                label: isFreelancer ? 'Servis Saya' : 'Browse Servis',
                onPressed: () => context.push(isFreelancer ? '/freelancer/services' : '/services'),
                expanded: false,
              ),
              FTButton.outlined(
                label: isFreelancer ? 'Jobs Saya' : 'Post a Job',
                onPressed: () => context.push('/jobs'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.categories, required this.onSelected});

  final List<String> categories;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori Popular',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: categories
              .map(
                (String category) => ChoiceChip(
                  label: Text(category),
                  selected: false,
                  onSelected: (_) => onSelected(category),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
