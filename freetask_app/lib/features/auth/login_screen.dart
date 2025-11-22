import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';
import 'auth_redirect.dart';
import 'auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    try {
      final success = await authRepository.login(
        email,
        password,
      );

      if (success && mounted) {
        final user = authRepository.currentUser;
        if (user != null) {
          goToRoleHome(context, user.role);
        } else {
          context.go('/home');
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Log masuk gagal. Sila cuba lagi.';
        });
        showErrorSnackBar(context, 'Log masuk gagal. Sila cuba lagi.');
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

  @override
  Widget build(BuildContext context) {
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
              constraints: const BoxConstraints(maxWidth: 500),
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
                          context.go('/');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.neutral500,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      'Selamat kembali 👋',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Akses marketplace profesional untuk cari atau tawar khidmat terbaik.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    SectionCard(
                      title: 'Log masuk akaun',
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Sila masukkan email';
                                }
                                if (!value.contains('@')) {
                                  return 'Email tidak sah';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Kata laluan',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Sila masukkan kata laluan';
                                }
                                if (value.length < 6) {
                                  return 'Kata laluan perlu sekurang-kurangnya 6 aksara';
                                }
                                return null;
                              },
                            ),
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
                              onPressed: _isSubmitting ? null : _handleLogin,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Log Masuk'),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            TextButton(
                              onPressed: () => context.push('/register'),
                              child: const Text('Belum ada akaun? Daftar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    SectionCard(
                      title: 'Demo Accounts',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Gunakan akaun sedia ada untuk ujian cepat:'),
                          SizedBox(height: AppSpacing.s12),
                          _DemoCredentialRow(role: 'Client', email: 'client1@example.com'),
                          _DemoCredentialRow(role: 'Client', email: 'client2@example.com'),
                          _DemoCredentialRow(role: 'Freelancer', email: 'freelancer1@example.com'),
                          _DemoCredentialRow(role: 'Freelancer', email: 'freelancer2@example.com'),
                          SizedBox(height: AppSpacing.s8),
                          Text(
                            'Kata laluan untuk semua akaun demo: password123',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
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

class _DemoCredentialRow extends StatelessWidget {
  const _DemoCredentialRow({required this.role, required this.email});

  final String role;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$role · $email'),
          ),
        ],
      ),
    );
  }
}
