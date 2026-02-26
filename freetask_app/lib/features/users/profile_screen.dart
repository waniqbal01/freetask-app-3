import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/confirmation_dialog.dart';

import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_bell_button.dart';
import '../auth/auth_repository.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../services/upload_service.dart';
import '../../core/utils/url_utils.dart';
import '../../core/constants/malaysia_locations.dart';
import 'users_repository.dart';
import 'package:geolocator/geolocator.dart';

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

  // Visibility state for sensitive fields
  final Set<String> _visibleFields = {};
  bool _isObscureText = true; // For editing mode

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
      final user = await authRepository.getCurrentUser(forceRefresh: true);
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
      _isObscureText = true; // Reset obscure state when starting edit
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
        File fileToUpload = File(platformFile.path!);

        try {
          // Compress image
          final targetPath = platformFile.path!
              .replaceFirst(RegExp(r'\.[^.]+$'), '_compressed.jpg');

          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            platformFile.path!,
            targetPath,
            quality: 75,
            minWidth: 1024,
            minHeight: 1024,
          );

          if (compressedFile != null) {
            fileToUpload = File(compressedFile.path);
          }
        } catch (e) {
          debugPrint('Compression failed, using original file: $e');
        }

        uploadResult = await uploadService.uploadFile(fileToUpload.path);
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

  @override
  Widget build(BuildContext context) {
    final isFreelancer = _user?.roleEnum.isFreelancer ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya'), actions: [
        const NotificationBellButton(),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {}, // Settings placeholder
        ),
      ]),
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

                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text(AppStrings.btnLogout),
                    ),
                    const SizedBox(height: 32), // Bottom padding

                    const SizedBox(height: 24),
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
                          Theme.of(context).primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
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
        const SizedBox(height: 16),
        if (isFreelancer) ...[
          _buildLevelBadge(user.level),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildLevelProgress(user),
          ),
          const SizedBox(height: 24),
        ] else ...[
          const SizedBox(height: 24),
        ],
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
        _buildLocationSection(user),
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

          const SizedBox(height: 16),
          // Active Status Toggle
          SwitchListTile(
            title: const Text('Status Aktif'),
            subtitle: Text(user.isAvailable
                ? 'Profil anda kelihatan kepada pelanggan'
                : 'Profil anda disembunyikan'),
            value: user.isAvailable,
            onChanged: (val) => _toggleAvailability(val),
            secondary: Icon(
              user.isAvailable ? Icons.check_circle : Icons.remove_circle,
              color: user.isAvailable ? Colors.green : Colors.grey,
            ),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Maklumat Bank (Untuk Bayaran)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
          ),
          const SizedBox(height: 16),

          _buildBankDropdown(user),
          _buildProfileItem(
            fieldKey: 'bankAccount',
            label: 'Nombor Akaun',
            value: user.bankAccount ?? 'Belum ditetapkan',
            icon: Icons.account_balance_wallet,
            inputType: TextInputType.number,
            isSensitive: true,
            onSave: (val) => usersRepository.updateProfile(bankAccount: val),
          ),
          _buildProfileItem(
            fieldKey: 'bankHolderName',
            label: 'Nama Pemegang Akaun',
            value: user.bankHolderName ?? 'Belum ditetapkan',
            icon: Icons.person_outline,
            isSensitive: true,
            onSave: (val) => usersRepository.updateProfile(bankHolderName: val),
          ),
          if (user.bankVerified)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Akaun Bank Disahkan',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else if (user.bankAccount != null && user.bankAccount!.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.pending, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('Menunggu Pengesahan Admin',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildLocationSection(AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Lokasi & Liputan Perkhidmatan',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
        ),
        const SizedBox(height: 16),
        _buildStateDropdown(user),
        _buildDistrictDropdown(user),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gps_fixed, color: Colors.grey),
          title: const Text('Koordinat GPS',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          subtitle: Text(
            user.latitude != null && user.longitude != null
                ? '${user.latitude!.toStringAsFixed(4)}, ${user.longitude!.toStringAsFixed(4)}'
                : 'Belum ditetapkan',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          trailing: TextButton.icon(
            icon: const Icon(Icons.my_location, size: 16),
            label: const Text('Kemaskini'),
            onPressed: () => _fetchAndUpdateGPS(user),
          ),
        ),
        if (user.roleEnum.isFreelancer) ...[
          _buildProfileItem(
              fieldKey: 'coverageRadius',
              label: 'Jejari Liputan (km)',
              value: user.coverageRadius?.toString() ?? 'Belum ditetapkan',
              icon: Icons.radar,
              inputType: TextInputType.number,
              onSave: (val) async {
                final radius = int.tryParse(val);
                if (radius != null) {
                  await usersRepository.updateProfile(coverageRadius: radius);
                } else if (val.isEmpty) {
                  // handle clearing
                } else {
                  throw Exception('Sila masukkan nombor yang sah.');
                }
              }),
          SwitchListTile(
            title: const Text('Terima Job Luar Kawasan'),
            subtitle: Text(user.acceptsOutstation
                ? 'Boleh ditempah oleh client dari luar kawasan (cas tambahan mungkin dikenakan)'
                : 'Hanya terima tempahan dalam radius liputan sahaja'),
            value: user.acceptsOutstation,
            onChanged: (val) async {
              try {
                setState(() => _isLoadingUser = true);
                await usersRepository.updateProfile(acceptsOutstation: val);
                await _loadUser();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal: $e')),
                );
                setState(() => _isLoadingUser = false);
              }
            },
            secondary: Icon(
              user.acceptsOutstation ? Icons.directions_car : Icons.block,
              color: user.acceptsOutstation ? Colors.green : Colors.grey,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
        const Divider(height: 32),
      ],
    );
  }

  Future<void> _fetchAndUpdateGPS(AppUser user) async {
    setState(() => _isLoadingUser = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Keizinan lokasi ditolak.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Keizinan lokasi ditolak kekal. Sila ubah di tetapan.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await usersRepository.updateProfile(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await _loadUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS berjaya dikemaskini')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapatkan GPS: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Widget _buildStateDropdown(AppUser user) {
    final states = malaysiaStatesAndDistricts.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_editingField != 'state')
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.map, color: Colors.grey),
            title: const Text('Negeri',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            subtitle: Text(
              user.state ?? 'Belum ditetapkan',
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              color: Theme.of(context).primaryColor,
              onPressed: () => _startEditing('state', user.state ?? ''),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Negeri',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: states.contains(_editController.text)
                            ? _editController.text
                            : null,
                        hint: const Text('Sila pilih negeri'),
                        items: states
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _editController.text = val);
                          }
                        },
                      ),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _isSavingField
                          ? null
                          : () => _saveField((val) async {
                                // Reset district when state changes
                                await usersRepository.updateProfile(
                                    state: val, district: '');
                              })),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _isSavingField ? null : _cancelEditing,
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDistrictDropdown(AppUser user) {
    if (user.state == null || user.state!.isEmpty)
      return const SizedBox.shrink();

    final districts = malaysiaStatesAndDistricts[user.state] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_editingField != 'district')
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_city, color: Colors.grey),
            title: const Text('Daerah',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            subtitle: Text(
              user.district ?? 'Belum ditetapkan',
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              color: Theme.of(context).primaryColor,
              onPressed: () => _startEditing('district', user.district ?? ''),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Daerah',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: districts.contains(_editController.text)
                            ? _editController.text
                            : null,
                        hint: const Text('Sila pilih daerah'),
                        items: districts
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _editController.text = val);
                          }
                        },
                      ),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _isSavingField
                          ? null
                          : () => _saveField((val) async {
                                await usersRepository.updateProfile(
                                    district: val);
                              })),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _isSavingField ? null : _cancelEditing,
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBankDropdown(AppUser user) {
    if (!user.role.toUpperCase().contains('FREELANCER')) {
      return const SizedBox.shrink();
    }

    final banks = {
      'MBBEMYKL': 'Maybank',
      'BCBBMYKL': 'CIMB Bank',
      'PBBEMYKL': 'Public Bank',
      'RHBBMYKL': 'RHB Bank',
      'HLBBMYKL': 'Hong Leong Bank',
      'AMBBMYKL': 'AmBank',
      'BIMBMYKL': 'Bank Islam',
      'BKRM': 'Bank Rakyat',
      'BMMB': 'Bank Muamalat',
      'BSN': 'BSN',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_editingField != 'bankCode')
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance, color: Colors.grey),
            title: const Text('Bank',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            subtitle: Text(
              banks[user.bankCode] ?? user.bankCode ?? 'Belum ditetapkan',
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              color: Theme.of(context).primaryColor,
              onPressed: () => _startEditing('bankCode', user.bankCode ?? ''),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Bank',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: banks.containsKey(_editController.text)
                            ? _editController.text
                            : null,
                        hint: const Text('Sila pilih bank'),
                        items: banks.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _editController.text = val);
                          }
                        },
                      ),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _isSavingField
                          ? null
                          : () => _saveField((val) async {
                                await usersRepository.updateProfile(
                                    bankCode: val);
                              })),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _isSavingField ? null : _cancelEditing,
                  ),
                ],
              ),
            ],
          ),
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
    bool isSensitive = false,
  }) {
    final isEditing = _editingField == fieldKey;
    final isVisible = _visibleFields.contains(fieldKey);

    String displayValue = value;
    if (isSensitive && !isVisible && value != 'Belum ditetapkan') {
      // Simple masking logic: show last 4 digits if it's a number, or just show asterisks
      if (value.length > 4) {
        displayValue =
            '${"*" * (value.length - 4)}${value.substring(value.length - 4)}';
      } else {
        displayValue = "*" * value.length;
      }
    }

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
                    obscureText: isSensitive ? _isObscureText : false,
                    decoration: InputDecoration(
                      labelText: label,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: isSensitive
                          ? IconButton(
                              icon: Icon(
                                _isObscureText
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isObscureText = !_isObscureText;
                                });
                              },
                            )
                          : null,
                    ),
                    keyboardType: inputType,
                    maxLines: isSensitive ? 1 : maxLines,
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
              displayValue,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSensitive && value != 'Belum ditetapkan')
                  IconButton(
                    icon: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        if (isVisible) {
                          _visibleFields.remove(fieldKey);
                        } else {
                          _visibleFields.add(fieldKey);
                        }
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  color: Theme.of(context).primaryColor,
                  onPressed: () => _startEditing(
                      fieldKey, value == 'Belum ditetapkan' ? '' : value),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildLevelBadge(String level) {
    Color color;
    String label;
    IconData icon;
    switch (level) {
      case 'PRO':
        color = Colors.purple;
        label = 'Pro';
        icon = Icons.star;
        break;
      case 'STANDARD':
        color = Colors.blue;
        label = 'Standard';
        icon = Icons.verified;
        break;
      default:
        color = Colors.green;
        label = 'Newbie';
        icon = Icons.circle;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgress(AppUser user) {
    if (user.level == 'PRO') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Text(
            '🌟 Tahniah! Anda adalah Freelancer tahap Pro.',
            style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final isNewbie = user.level == 'NEWBIE';
    final nextLevelName = isNewbie ? 'Standard' : 'Pro';
    final targetJobs = isNewbie ? 10 : 30;

    final currentJobs = user.totalCompletedJobs;
    final progress = (currentJobs / targetJobs).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress ke $nextLevelName',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('$currentJobs / $targetJobs Job'),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            color: Theme.of(context).primaryColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            'Tingkatkan siapan job & skor rating untuk naik level!',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
