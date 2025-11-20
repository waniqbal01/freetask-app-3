import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/service.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../core/widgets/async_state_view.dart';
import '../../widgets/service_card.dart';
import 'home_controller.dart';
import '../notifications/notifications_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<HomeState>(homeControllerProvider, (previous, next) {
      if (next.featured.hasError && previous?.featured != next.featured) {
        final message = next.featured.message ??
            friendlyErrorMessage(next.featured.error ?? 'Tidak dapat memuatkan dashboard.');
        showErrorSnackBar(context, message);
      }
    });

    final state = ref.watch(homeControllerProvider);
    final categories = state.categories;
    final featuredState = state.featured;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FreeTask'),
        actions: const [
          _NotificationBell(),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: _HomeHero(user: state.user),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s20,
                    0,
                    AppSpacing.s20,
                    AppSpacing.s12,
                  ),
                  child: const _EnvironmentInfo(),
                ),
              ),
              if (categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
                    child: _CategorySection(
                      categories: categories,
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
              AsyncStateView<List<Service>>(
                state: featuredState,
                onRetry: () => ref.read(homeControllerProvider.notifier).refresh(),
                loading: (_) => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                empty: (BuildContext context, String message) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s20),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
                error: (BuildContext context, String message, VoidCallback? onRetry) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            FTButton(
                              label: 'Cuba Lagi',
                              expanded: false,
                              onPressed: onRetry,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                data: (BuildContext context, List<Service> services) {
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s20, 0, AppSpacing.s20, AppSpacing.s20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          if (index.isOdd) {
                            return const SizedBox(height: AppSpacing.s12);
                          }
                          final service = services[index ~/ 2];
                          return ServiceCard(
                            service: service,
                            onTap: () => context.push('/service/${service.id}'),
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
      ),
    );
  }
}

class _EnvironmentInfo extends StatelessWidget {
  const _EnvironmentInfo();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maklumat persekitaran',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text('Environment: ${AppInfo.environmentLabel}'),
            Text('API Base URL: ${AppInfo.apiBaseUrl}'),
            Text('App Version: ${AppInfo.version}'),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);
    final bool showBadge = unread > 0;
    final icon = IconButton(
      tooltip: 'Notifikasi',
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () => context.push('/notifications'),
    );

    if (!showBadge) {
      return icon;
    }

    final badgeLabel = unread > 9 ? '9+' : unread.toString();
    return IconButton(
      tooltip: 'Notifikasi',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        label: Text(badgeLabel),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'FreeTasker';
    final role = user?.role?.toUpperCase();
    final isFreelancer = role == 'FREELANCER';
    final isAdmin = role == 'ADMIN';

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
              if (isAdmin)
                FTButton(
                  label: 'Admin Dashboard',
                  onPressed: () => context.push('/admin'),
                  expanded: false,
                ),
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
