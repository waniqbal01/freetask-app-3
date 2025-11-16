import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/utils/error_utils.dart';
import '../../services/upload_service.dart';
import 'auth_redirect.dart';
import 'auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.role});

  final String? role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _avatarController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillsController = TextEditingController();
  final _rateController = TextEditingController();

  bool _isSubmitting = false;
  bool _isUploadingAvatar = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final avatar = _avatarController.text.trim();

    final apiRole = role.toUpperCase();
    final isFreelancerRole = apiRole == 'FREELANCER';

    final payload = <String, dynamic>{
      'role': apiRole,
      'name': _nameController.text.trim(),
      'email': email,
      'password': password,
    };

    if (avatar.isNotEmpty) {
      payload['avatar'] = avatar;
    }

    if (isFreelancerRole) {
      final bio = _bioController.text.trim();
      final skillsRaw = _skillsController.text.trim();
      final rateText = _rateController.text.trim();

      if (bio.isNotEmpty) {
        payload['bio'] = bio;
      }

      if (skillsRaw.isNotEmpty) {
        final skills = skillsRaw
            .split(',')
            .map((skill) => skill.trim())
            .where((skill) => skill.isNotEmpty)
            .toList();
        if (skills.isNotEmpty) {
          payload['skills'] = skills;
        }
      }

      if (rateText.isNotEmpty) {
        final parsedRate = double.tryParse(rateText);
        if (parsedRate != null) {
          payload['rate'] = parsedRate;
        }
      }
    }

    try {
      final success = await authRepository.register(payload);
      if (success && mounted) {
        final user = authRepository.currentUser;
        if (user != null) {
          goToRoleHome(context, user.role);
        } else {
          notificationService.pushLocal(
            'Berjaya',
            'Pendaftaran berjaya, sila log masuk.',
          );
          context.go('/login');
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Pendaftaran gagal. Sila cuba lagi.';
        });
      }
    } catch (error) {
      if (error is DioException) {
        final message = resolveDioErrorMessage(error);
        if (mounted) {
          setState(() {
            _errorMessage = message;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Ralat: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handlePickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final url = await uploadService.uploadFile(path);
      _avatarController.text = url;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar berjaya dimuat naik.')),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resolveDioErrorMessage(error))),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError ? error.message : error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialRole = widget.role ?? 'Client';
    final normalizedRole =
        initialRole.toLowerCase() == 'freelancer' ? 'Freelancer' : 'Client';
    final isFreelancer = normalizedRole == 'Freelancer';

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
                'Daftar sebagai $normalizedRole',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email diperlukan';
                  }
                  if (!value.contains('@')) {
                    return 'Email tidak sah';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata laluan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kata laluan diperlukan';
                  }
                  if (value.length < 6) {
                    return 'Kata laluan perlu sekurang-kurangnya 6 aksara';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Sahkan kata laluan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Sila sahkan kata laluan';
                  }
                  if (value != _passwordController.text) {
                    return 'Kata laluan tidak sepadan';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _avatarController,
                readOnly: true,
                onTap: () {
                  if (_isUploadingAvatar) {
                    return;
                  }
                  FocusScope.of(context).requestFocus(FocusNode());
                  _handlePickAvatar();
                },
                decoration: InputDecoration(
                  labelText: 'Avatar (URL)',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isUploadingAvatar
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.upload_file),
                          onPressed: _isUploadingAvatar ? null : _handlePickAvatar,
                        ),
                ),
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
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skillsController,
                  decoration: const InputDecoration(
                    labelText: 'Kemahiran (dipisah dengan koma)',
                    border: OutlineInputBorder(),
                  ),
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
                      return null;
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
                onPressed: _isSubmitting
                    ? null
                    : () => _handleRegister(normalizedRole),
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
