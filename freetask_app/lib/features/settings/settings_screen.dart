import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/active_role_banner.dart';
import '../../widgets/app_bottom_nav.dart';
import '../auth/auth_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
      appBar: AppBar(title: const Text('Settings')),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.settings),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                ActiveRoleBanner(
                  user: _user,
                  actionLabel: isAdmin ? 'Admin Dashboard' : null,
                  onAction: isAdmin ? () => context.push('/admin') : null,
                  subtitle: isAdmin
                      ? 'Pantau transaksi dan status job dengan cepat.'
                      : 'Gunakan tab di bawah untuk bertukar skrin utama.',
                  switchLabel: 'Tukar role/akun',
                  onSwitch: () => context.go('/settings'),
                ),
                const SizedBox(height: AppSpacing.s16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.largeRadius,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings_ethernet_outlined),
                        title: const Text('API Server'),
                        subtitle:
                            const Text('Kemaskini URL backend demo/beta.'),
                        onTap: () => context.push('/settings/api'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                      if (isAdmin) ...[
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.shield_outlined),
                          title: const Text('Admin Dashboard'),
                          subtitle: const Text('Akses terus ke paparan admin.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/admin'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.largeRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
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
