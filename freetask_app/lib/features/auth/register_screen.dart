import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/utils/error_utils.dart';
import '../../services/upload_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';
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

  late String _selectedRole;

  bool _isSubmitting = false;
  bool _isUploadingAvatar = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRole =
        widget.role?.toLowerCase() == 'freelancer' ? 'Freelancer' : 'Client';
  }

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

  Future<void> _handleRegister() async {
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

    final apiRole = _selectedRole.toUpperCase();
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
          showErrorSnackBar(
            context,
            'Pendaftaran berjaya, sila log masuk.',
          );
          context.go('/login');
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Pendaftaran gagal. Sila cuba lagi.';
        });
        showErrorSnackBar(context, 'Pendaftaran gagal. Sila cuba lagi.');
      }
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
      showErrorSnackBar(context, error);
    } catch (error) {
      if (!mounted) return;
      final message = 'Ralat: $error';
      setState(() {
        _errorMessage = message;
      });
      showErrorSnackBar(context, message);
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
        showErrorSnackBar(context, 'Avatar berjaya dimuat naik.');
      }
    } on DioException catch (error) {
      if (mounted) {
        showErrorSnackBar(context, mapDioError(error));
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError ? error.message : error.toString();
        showErrorSnackBar(context, message);
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
    final normalizedRole = _selectedRole;
    final isFreelancer = normalizedRole == 'Freelancer';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF3FC), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.neutral500,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      'Daftar akaun baharu',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih peranan dan siapkan profil anda untuk pengalaman marketplace yang lancar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    SectionCard(
                      title: 'Maklumat Akaun',
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _selectedRole,
                              items: const [
                                DropdownMenuItem(value: 'Client', child: Text('Client')),
                                DropdownMenuItem(
                                  value: 'Freelancer',
                                  child: Text('Freelancer'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedRole = value;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Jenis Akaun',
                                prefixIcon: Icon(Icons.work_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
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
                            const SizedBox(height: AppSpacing.s16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nama penuh',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Nama diperlukan';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Kata laluan',
                                prefixIcon: Icon(Icons.lock_outline),
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
                            const SizedBox(height: AppSpacing.s16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Sahkan kata laluan',
                                prefixIcon: Icon(Icons.lock_person_outlined),
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
                            const SizedBox(height: AppSpacing.s16),
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
                                prefixIcon: const Icon(Icons.image_outlined),
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
                              const SizedBox(height: AppSpacing.s16),
                              TextFormField(
                                controller: _bioController,
                                decoration: const InputDecoration(
                                  labelText: 'Bio',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                maxLines: 3,
                              ),
                              const SizedBox(height: AppSpacing.s16),
                              TextFormField(
                                controller: _skillsController,
                                decoration: const InputDecoration(
                                  labelText: 'Kemahiran (dipisah dengan koma)',
                                  prefixIcon: Icon(Icons.handyman_outlined),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s16),
                              TextFormField(
                                controller: _rateController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Kadar (contoh: 50.0)',
                                  prefixIcon: Icon(Icons.payments_outlined),
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
                              const SizedBox(height: AppSpacing.s16),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: AppRadius.mediumRadius,
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.s24),
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _handleRegister,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text('Daftar sebagai $normalizedRole'),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Sudah ada akaun? Log masuk'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
