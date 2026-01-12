import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/confirmation_dialog.dart';

import '../../models/user.dart';
import '../../models/portfolio_item.dart'; // Added import for type safety
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../auth/auth_repository.dart';
import 'edit_profile_screen.dart';

import 'widgets/portfolio_list_widget.dart';
import 'widgets/edit_portfolio_dialog.dart';

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

  Future<void> _editProfile() async {
    if (_user == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)),
    );
    _loadUser(); // Reload after edit
  }

  Future<void> _addPortfolio() async {
    final result = await showDialog(
      context: context,
      builder: (_) => const EditPortfolioDialog(),
    );
    if (result == true) {
      setState(() {}); // Rebuild to refresh portfolio list
    }
  }

  void _editPortfolio(PortfolioItem item) async {
    final result = await showDialog(
      context: context,
      builder: (_) =>
          EditPortfolioDialog(item: item), // Needs proper item passing
    );
    if (result == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _user?.role.toUpperCase();
    final isFreelancer = role == 'FREELANCER';
    final isAdmin = role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya'), actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {}, // Settings placeholder
        ),
      ]),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.profile),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUser,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.s16),
                children: [
                  if (_user != null) _buildUserInfo(_user!),
                  const SizedBox(height: 24),
                  if (isFreelancer) ...[
                    _buildSectionTitle('Servis Saya',
                        trailing: TextButton(
                          onPressed: () => context.push('/services/create'),
                          child: const Text('Tambah'),
                        )),
                    // Placeholder for Service List - for now just a link or summary
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.list_alt),
                        title: const Text('Urus Servis'),
                        subtitle: const Text('Lihat dan kemaskini servis anda'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/services/mine'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Portfolio',
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _addPortfolio,
                        )),
                    PortfolioListWidget(
                      userId: int.tryParse(_user!.id) ?? 0,
                      isEditable: true,
                      onEdit: _addPortfolio,
                      onItemTap: _editPortfolio,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Tempahan Masuk'),
                    _buildOrderTile(
                        'Job Requests',
                        '0 Baru',
                        () => context.push(
                            '/jobs/filtered?title=Job Requests&role=freelancer&statuses=PENDING')),
                    _buildOrderTile(
                        'In Progress',
                        '0 Aktif',
                        () => context.push(
                            '/jobs/filtered?title=Active Jobs&role=freelancer&statuses=IN_PROGRESS')),
                  ] else ...[
                    // Client View
                    _buildSectionTitle('Tempahan Saya'),
                    _buildOrderTile(
                        'Pending Acceptance',
                        'Lihat status',
                        () => context.push(
                            '/jobs/filtered?title=Pending Acceptance&role=client&statuses=PENDING')),
                    _buildOrderTile(
                        'In Progress',
                        'Lihat job berjalan',
                        () => context.push(
                            '/jobs/filtered?title=In Progress&role=client&statuses=IN_PROGRESS')),
                    _buildOrderTile(
                        'Completed',
                        'Sejarah tempahan',
                        () => context.push(
                            '/jobs/filtered?title=Completed History&role=client&statuses=COMPLETED,CANCELLED,REJECTED,DISPUTED')),
                  ],
                  if (isAdmin) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings,
                            color: Colors.red),
                        title: const Text('Admin Dashboard'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/admin'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text(AppStrings.btnLogout),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUserInfo(AppUser user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage:
              user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null
              ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 24))
              : null,
        ),
        const SizedBox(height: 12),
        Text(user.name, style: AppTextStyles.titleMedium),
        if (user.rating != null && user.reviewCount != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${user.rating!.toStringAsFixed(1)} (${user.reviewCount} ulasan)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        if (user.role == 'FREELANCER') ...[
          if (user.bio != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(user.bio!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.grey[600])),
            ),
          if (user.location != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('📍 ${user.location}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _editProfile,
          child: const Text('Edit Profil'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleMedium),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildOrderTile(String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
