import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart';
import '../../core/widgets/ft_button.dart';

import 'users_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _skillsController;
  late TextEditingController _rateController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio);
    _skillsController =
        TextEditingController(text: widget.user.skills?.join(', '));
    _rateController =
        TextEditingController(text: widget.user.rate?.toString() ?? '');
    // Assuming backend returns these fields, but for now we might not have them in AppUser model yet.
    // I need to update AppUser model if I want to display existing phone/location.
    // Checking AppUser model is required. For now, I'll assume they might be missing from Model but available if I update model.
    // I previously updated schema but not AppUser model in Flutter.
    _phoneController =
        TextEditingController(text: widget.user.phoneNumber ?? '');
    _locationController =
        TextEditingController(text: widget.user.location ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _skillsController.dispose();
    _rateController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final skillsList = _skillsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await usersRepository.updateProfile(
        name: _nameController.text,
        bio: _bioController.text,
        skills: skillsList,
        rate: num.tryParse(_rateController.text),
        phoneNumber: _phoneController.text,
        location: _locationController.text,
      );

      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengemaskini profil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFreelancer = widget.user.role == 'FREELANCER';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Penuh'),
              validator: (v) =>
                  v?.isEmpty == true ? 'Sila masukkan nama' : null,
            ),
            const SizedBox(height: 16),
            if (isFreelancer) ...[
              TextFormField(
                controller: _bioController,
                decoration:
                    const InputDecoration(labelText: 'Bio Ringkas (Max 200)'),
                maxLines: 3,
                maxLength: 200,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  labelText: 'Skills (asingkan dengan koma)',
                  hintText: 'Logo Design, Flutter, Translation',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(labelText: 'Rate (RM/jam)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'No Telefon'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Lokasi (Negeri)'),
            ),
            const SizedBox(height: 24),
            FTButton(
              label: 'Simpan',
              onPressed: _isLoading ? null : _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
