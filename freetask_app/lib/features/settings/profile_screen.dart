import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../auth/auth_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await authRepository.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = user;
        _isLoadingUser = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: AppStrings.confirmLogoutTitle,
      message: AppStrings.confirmLogoutMessage,
      confirmText: AppStrings.btnLogout,
      isDangerous: true,
    );
    if (confirmed != true) return;

    await authRepository.logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final role = _user?.role.toUpperCase();
    final isAdmin = role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.profile),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                // UX-F-05: Consolidated Profile/Settings content
                if (_user != null) ...[
                  Card(
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.largeRadius,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: Text(
                              _user!.name.isNotEmpty
                                  ? _user!.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _user!.name,
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(
                              role ?? 'User',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.neutral600,
                              ),
                            ),
                            backgroundColor: AppColors.neutral100,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],
                if (isAdmin)
                  Card(
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.largeRadius,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: const Text('Admin Dashboard'),
                      subtitle: const Text('Akses terus ke paparan admin.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/admin'),
                    ),
                  ),
                if (isAdmin) const SizedBox(height: AppSpacing.s16),
                const Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.largeRadius,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pembayaran & Escrow',
                          style: AppTextStyles.titleMedium,
                        ),
                        SizedBox(height: AppSpacing.s8),
                        Text(
                          'Dana dipegang secara escrow dan hanya dilepaskan apabila job ditanda selesai atau selepas 7 hari.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                FTButton(
                  label: AppStrings.btnLogout,
                  onPressed: _logout,
                ),
              ],
            ),
    );
  }
}
