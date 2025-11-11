import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.role});

  final String? role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _avatarController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillsController = TextEditingController();
  final _rateController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    _bioController.dispose();
    _skillsController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister(String role) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final payload = <String, dynamic>{
      'role': role,
      'name': _nameController.text.trim(),
      'avatar': _avatarController.text.trim(),
    };

    if (role == 'Freelancer') {
      payload.addAll(<String, dynamic>{
        'bio': _bioController.text.trim(),
        'skills': _skillsController.text
            .split(',')
            .map((skill) => skill.trim())
            .where((skill) => skill.isNotEmpty)
            .toList(),
        'rate': double.tryParse(_rateController.text.trim()) ?? 0,
      });
    }

    try {
      final success = await authRepository.register(payload);
      if (success && mounted) {
        context.pushReplacement('/home');
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Pendaftaran gagal. Sila cuba lagi.';
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Ralat: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRole = widget.role ?? 'Client';
    final isFreelancer = effectiveRole == 'Freelancer';

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akaun')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Daftar sebagai $effectiveRole',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama penuh',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama diperlukan';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _avatarController,
                decoration: const InputDecoration(
                  labelText: 'Pautan avatar (URL)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Pautan avatar diperlukan';
                  }
                  return null;
                },
              ),
              if (isFreelancer) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Bio diperlukan untuk freelancer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skillsController,
                  decoration: const InputDecoration(
                    labelText: 'Kemahiran (dipisah dengan koma)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sila senaraikan kemahiran anda';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kadar (contoh: 50.0)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kadar diperlukan';
                    }
                    final parsed = double.tryParse(value);
                    if (parsed == null) {
                      return 'Sila masukkan nombor yang sah';
                    }
                    return null;
                  },
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : () => _handleRegister(effectiveRole),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Daftar'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sudah ada akaun? Log masuk'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
