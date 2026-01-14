import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/confirmation_dialog.dart';

import '../../models/user.dart';
import '../../models/portfolio_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../auth/auth_repository.dart';

import 'package:file_picker/file_picker.dart';
import '../../services/upload_service.dart';
import '../../core/utils/url_utils.dart';
import 'users_repository.dart';
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

  // Inline editing state
  String? _editingField;
  late TextEditingController _editController;
  bool _isSavingField = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _loadUser();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
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

  void _startEditing(String field, String currentValue) {
    setState(() {
      _editingField = field;
      _editController.text = currentValue;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingField = null;
      _editController.clear();
    });
  }

  Future<void> _saveField(Future<void> Function(String) onSave) async {
    if (_editingField == null) return;

    setState(() => _isSavingField = true);

    try {
      await onSave(_editController.text);
      await _loadUser();
      _cancelEditing();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berjaya dikemaskini')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingField = false);
      }
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

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.single;

      // For web, use bytes; for mobile/desktop, use path
      setState(() => _isLoadingUser = true);

      late UploadResult uploadResult;

      if (platformFile.bytes != null) {
        // Web upload using bytes
        // Map extension to proper MIME type
        String mimeType = 'image/jpeg'; // default
        final ext = platformFile.extension?.toLowerCase();
        if (ext == 'png') {
          mimeType = 'image/png';
        } else if (ext == 'jpg' || ext == 'jpeg') {
          mimeType = 'image/jpeg';
        } else if (ext == 'gif') {
          mimeType = 'image/gif';
        } else if (ext == 'webp') {
          mimeType = 'image/webp';
        }

        uploadResult = await uploadService.uploadData(
          platformFile.name,
          platformFile.bytes!,
          mimeType,
        );
      } else if (platformFile.path != null) {
        // Mobile/desktop upload using file path
        uploadResult = await uploadService.uploadFile(platformFile.path!);
      } else {
        throw Exception('Unable to access file data');
      }

      // Update Profile
      await usersRepository.updateProfile(avatarUrl: uploadResult.url);

      await _loadUser();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Gambar profil berjaya dikemaskini!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat naik gambar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    try {
      setState(() => _isLoadingUser = true);

      await usersRepository.updateProfile(isAvailable: value);
      await _loadUser();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengemaskini status: $e')),
      );
      setState(() => _isLoadingUser = false);
    }
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
      builder: (_) => EditPortfolioDialog(item: item),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_user != null) _buildUserInfo(_user!, isFreelancer),
                    const SizedBox(height: 24),
                    if (isFreelancer) ...[
                      const Divider(),
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
                    const SizedBox(height: 32), // Bottom padding
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserInfo(AppUser user, bool isFreelancer) {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              // Avatar with loading overlay
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: user.avatarUrl != null &&
                            user.avatarUrl!.isNotEmpty
                        ? NetworkImage(UrlUtils.resolveImageUrl(user.avatarUrl))
                        : null,
                    child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                        ? Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 32))
                        : null,
                  ),
                  // Loading overlay
                  if (_isLoadingUser)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                ],
              ),
              // Camera button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isLoadingUser ? null : _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isLoadingUser ? Icons.hourglass_empty : Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildProfileItem(
          fieldKey: 'name',
          label: 'Nama Penuh',
          value: user.name,
          icon: Icons.person,
          onSave: (val) => usersRepository.updateProfile(name: val),
        ),
        _buildProfileItem(
          fieldKey: 'phone',
          label: 'No Telefon',
          value: user.phoneNumber ?? 'Belum ditetapkan',
          icon: Icons.phone,
          inputType: TextInputType.phone,
          onSave: (val) => usersRepository.updateProfile(phoneNumber: val),
        ),
        _buildProfileItem(
          fieldKey: 'location',
          label: 'Lokasi',
          value: user.location ?? 'Belum ditetapkan',
          icon: Icons.location_on,
          onSave: (val) => usersRepository.updateProfile(location: val),
        ),
        if (isFreelancer) ...[
          _buildProfileItem(
            fieldKey: 'bio',
            label: 'Bio / Pengenalan',
            value: user.bio ?? 'Belum ditetapkan',
            icon: Icons.info,
            maxLines: 3,
            onSave: (val) => usersRepository.updateProfile(bio: val),
          ),

          _buildProfileItem(
            fieldKey: 'skills',
            label: 'Kemahiran',
            value: user.skills?.join(', ') ?? 'Belum ditetapkan',
            icon: Icons.build,
            onSave: (val) {
              final skillsList = val
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              return usersRepository.updateProfile(skills: skillsList);
            },
          ),

          _buildProfileItem(
            fieldKey: 'rate',
            label: 'Kadar Upah (RM/jam)',
            value: user.rate != null ? 'RM ${user.rate}' : 'Belum ditetapkan',
            icon: Icons.monetization_on,
            inputType: TextInputType.number,
            onSave: (val) =>
                usersRepository.updateProfile(rate: num.tryParse(val) ?? 0),
          ),

          const SizedBox(height: 16),
          // Active Status Toggle
          SwitchListTile(
            title: const Text('Status Aktif'),
            subtitle: Text(user.isAvailable
                ? 'Anda boleh menerima tempahan baru'
                : 'Anda tidak menerima tempahan baru'),
            value: user.isAvailable,
            onChanged: _toggleAvailability,
            secondary: Icon(
              user.isAvailable ? Icons.check_circle : Icons.remove_circle,
              color: user.isAvailable ? Colors.green : Colors.grey,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }

  Widget _buildProfileItem({
    required String fieldKey,
    required String label,
    required String value,
    required IconData icon,
    required Future<void> Function(String) onSave,
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) {
    final isEditing = _editingField == fieldKey;

    return Column(
      children: [
        if (isEditing)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey.shade50,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 16),
                  child: Icon(icon, color: Theme.of(context).primaryColor),
                ),
                Expanded(
                  child: TextField(
                    controller: _editController,
                    decoration: InputDecoration(
                      labelText: label,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: inputType,
                    maxLines: maxLines,
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed:
                            _isSavingField ? null : () => _saveField(onSave)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _isSavingField ? null : _cancelEditing,
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: Colors.grey[600]),
            title: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            subtitle: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              color: Theme.of(context).primaryColor,
              onPressed: () => _startEditing(
                  fieldKey, value == 'Belum ditetapkan' ? '' : value),
            ),
          ),
        const Divider(height: 1),
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
}
