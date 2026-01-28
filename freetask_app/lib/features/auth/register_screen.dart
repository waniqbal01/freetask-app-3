import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/utils/error_utils.dart';
import '../../services/upload_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';
import '../../widgets/authorized_image.dart';
import 'auth_redirect.dart';
import 'auth_repository.dart';
import '../users/users_repository.dart';
import '../../core/storage/storage.dart';

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
  String? _selectedAvatarPath;
  String? _uploadedAvatarUrl;

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
    final apiRole = _selectedRole.toUpperCase();
    final isFreelancerRole = apiRole == 'FREELANCER';

    final payload = <String, dynamic>{
      'role': apiRole,
      'name': _nameController.text.trim(),
      'email': email,
      'password': password,
    };

    if (isFreelancerRole) {
      final bio = _bioController.text.trim();

      if (bio.isNotEmpty) {
        payload['bio'] = bio;
      }
    }

    try {
      final success = await authRepository.register(payload);
      if (success && mounted) {
        await _uploadAvatarAfterAuth();

        // UX-C-05: Set first-time client flag
        if (apiRole == 'CLIENT') {
          await appStorage.write('client_first_time', 'true');
        }

        final user = authRepository.currentUser;
        if (user != null && mounted) {
          goToRoleHome(context, user.role);
        } else if (mounted) {
          notificationService.pushLocal(
            'Berjaya',
            'Pendaftaran berjaya, sila log masuk.',
          );
          if (mounted) {
            showErrorSnackBar(
              context,
              'Pendaftaran berjaya, sila log masuk.',
            );
          }
          if (mounted) {
            context.go('/login');
          }
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Pendaftaran gagal. Sila cuba lagi.';
        });
        showErrorSnackBar(context, 'Pendaftaran gagal. Sila cuba lagi.');
      }
    } catch (error) {
      if (error is DioException) {
        final message = resolveDioErrorMessage(error);
        if (mounted) {
          setState(() {
            _errorMessage = message;
          });
          showErrorSnackBar(context, message);
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Ralat: $error';
          });
          showErrorSnackBar(context, 'Ralat: $error');
        }
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) {
      return;
    }

    final mimeType = lookupMimeType(file.name, headerBytes: file.bytes) ?? '';
    if (!UploadService.allowedMimeTypes.contains(mimeType)) {
      if (mounted) {
        showErrorSnackBar(
            context, 'Hanya imej JPEG/PNG/GIF atau dokumen diterima.');
      }
      return;
    }

    if (file.size > UploadService.maxFileBytes) {
      if (mounted) {
        showErrorSnackBar(
            context, 'Fail melebihi had 5MB. Pilih fail yang lebih kecil.');
      }
      return;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Platform ini tidak menyokong muat naik fail terus. Cuba dari peranti mudah alih.',
        );
      }
      return;
    }

    setState(() {
      _selectedAvatarPath = path;
      _avatarController.text = path.split(RegExp(r'[\\/]')).last;
      _uploadedAvatarUrl = null;
    });

    if (mounted) {
      showErrorSnackBar(
        context,
        'Avatar akan dimuat naik selepas pendaftaran.',
      );
    }
  }

  Future<void> _uploadAvatarAfterAuth() async {
    final path = _selectedAvatarPath;
    if (path == null) {
      return;
    }

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final uploadResult = await uploadService.uploadFile(path);
      await usersRepository.updateProfile(avatarUrl: uploadResult.url);
      setState(() {
        _uploadedAvatarUrl = uploadResult.url;
      });
      if (mounted) {
        showErrorSnackBar(
          context,
          'Avatar berjaya dimuat naik dan dikemaskini.',
        );
      }
    } on UnauthenticatedUploadException catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error.message);
        context.go('/login');
      }
    } on ValidationException catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error.message);
      }
    } on DioException catch (error) {
      if (mounted) {
        showErrorSnackBar(
          context,
          '${resolveDioErrorMessage(error)}. Avatar upload failed, you can upload later.',
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message
            : 'Avatar upload failed, you can upload later.';
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
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                                DropdownMenuItem(
                                    value: 'Client', child: Text('Client')),
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
                                FocusScope.of(context)
                                    .requestFocus(FocusNode());
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
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.upload_file),
                                        onPressed: _isUploadingAvatar
                                            ? null
                                            : _handlePickAvatar,
                                      ),
                              ),
                            ),
                            if (_uploadedAvatarUrl != null) ...[
                              const SizedBox(height: AppSpacing.s8),
                              Text(
                                'Pratonton avatar:',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: AppColors.neutral500),
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              Row(
                                children: [
                                  AuthorizedImage(
                                    url: _uploadedAvatarUrl!,
                                    width: 72,
                                    height: 72,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ],
                              ),
                            ],
                            if (isFreelancer) ...[
                              const SizedBox(height: AppSpacing.s16),
                              TextFormField(
                                controller: _bioController,
                                decoration: const InputDecoration(
                                  labelText: 'Bio',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                  helperText:
                                      'Bio membantu client memahami pengalaman anda. Disarankan minimum 30 aksara.',
                                  helperMaxLines: 2,
                                ),
                                maxLines: 3,
                              ),
                            ],
                            if (_errorMessage != null) ...[
                              const SizedBox(height: AppSpacing.s16),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: AppRadius.mediumRadius,
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style:
                                      const TextStyle(color: AppColors.error),
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
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
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
