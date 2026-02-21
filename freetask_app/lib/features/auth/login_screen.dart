import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/utils/error_utils.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';
import 'auth_redirect.dart';
import '../../services/http_client.dart';
import '../../env.dart';
import 'auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.returnTo});

  final String? returnTo;

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
      // Attempt initial login
      await _performLogin(email, password);
    } catch (error) {
      bool isConnectionError = false;
      if (error is DioException) {
        final type = error.type;
        isConnectionError = type == DioExceptionType.connectionTimeout ||
            type == DioExceptionType.sendTimeout ||
            type == DioExceptionType.receiveTimeout ||
            type == DioExceptionType.connectionError ||
            type == DioExceptionType.unknown;
      }

      if (isConnectionError && mounted) {
        // SMART WAKE-UP LOGIC (3-zone timing)
        final wakeUpStart = DateTime.now();
        setState(() {
          _errorMessage = AppStrings.serverConnecting;
        });

        // Retry loop (Max 12 attempts, 6s each = ~72s max)
        bool wokeUp = false;
        debugPrint('[LoginWakeUp] Starting retry loop (max 12 attempts)...');

        for (int i = 0; i < 12; i++) {
          if (!mounted) return;

          await Future.delayed(const Duration(seconds: 6));

          // 3-zone messaging based on elapsed time (not attempt count)
          if (mounted) {
            final elapsed = DateTime.now().difference(wakeUpStart).inSeconds;
            String progressMsg;
            if (elapsed < 15) {
              progressMsg = AppStrings.serverConnecting;
            } else if (elapsed < 30) {
              progressMsg = AppStrings.serverWarmingUp;
            } else {
              // Beyond 30s — shift to muted warning tone
              progressMsg = AppStrings.serverAlmostReady;
            }
            setState(() {
              _errorMessage = progressMsg;
            });
          }

          debugPrint('[LoginWakeUp] Attempt ${i + 1}/12 - checking server...');

          final isUp = await HttpClient().wakeUpServer();
          if (isUp) {
            debugPrint('[LoginWakeUp] ✓ Server online after ${i + 1} attempts');
            wokeUp = true;
            break;
          }
        }

        if (wokeUp && mounted) {
          setState(() {
            _errorMessage = AppStrings.serverOnline;
          });
          try {
            await _performLogin(email, password);
            return;
          } catch (retryError) {
            if (mounted) _handleLoginError(retryError);
            return;
          }
        } else if (mounted) {
          // Server truly unreachable — show clear error
          setState(() {
            _errorMessage = AppStrings.serverUnreachable;
          });
          showErrorSnackBar(context, AppStrings.serverUnreachable);
          return;
        }
      }

      if (mounted) {
        _handleLoginError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _performLogin(String email, String password) async {
    final t0 = DateTime.now();
    final success = await authRepository.login(email, password);
    debugPrint(
        '[PERF] Login: ${DateTime.now().difference(t0).inMilliseconds}ms');

    if (success && mounted) {
      final user = authRepository.currentUser;
      if (user != null) {
        if (widget.returnTo != null && widget.returnTo!.isNotEmpty) {
          context.go(widget.returnTo!);
          return;
        }
        if (user.role.toUpperCase() == 'ADMIN') {
          context.go('/admin');
        } else {
          goToRoleHome(context, user.role);
        }
      } else {
        context.go('/chats');
      }
    } else if (mounted) {
      throw DioException(
          requestOptions: RequestOptions(path: '/login'),
          response: Response(
              requestOptions: RequestOptions(path: '/login'), statusCode: 401));
    }
  }

  void _handleLoginError(Object error) {
    if (error is DioException) {
      final message = resolveDioErrorMessage(error);
      setState(() {
        if (error.response?.statusCode == 429 ||
            message.toLowerCase().contains('too many requests')) {
          _errorMessage =
              'Had percubaan log masuk dicapai. Sila tunggu 5 minit sebelum cuba lagi.';
        } else {
          _errorMessage = error.response?.statusCode == 401 ||
                  message.toLowerCase().contains('unauthorized')
              ? 'Email atau kata laluan tidak sah. Sila cuba lagi.'
              : message;
        }
      });
      if (_errorMessage != null) showErrorSnackBar(context, _errorMessage!);
    } else {
      setState(() {
        _errorMessage = 'Ralat: $error';
      });
      showErrorSnackBar(context, 'Ralat: $error');
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
                    const SizedBox(height: AppSpacing.s8),
                    GestureDetector(
                      onLongPress: () async {
                        if (!mounted) return;
                        // Backup/Debug feature: Reset to default URL
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Menetapkan semula server...'),
                            duration: Duration(seconds: 1)));

                        await HttpClient().updateBaseUrl(Env.defaultApiBaseUrl);

                        if (mounted) {
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(const SnackBar(
                              content:
                                  Text('Server telah ditetapkan ke URL rasmi.'),
                              backgroundColor: Colors.green));
                        }
                      },
                      child: Text(
                        'Selamat kembali 👋',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral900,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Akses marketplace profesional untuk cari atau tawar khidmat terbaik.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.s8),
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
                              onPressed: _isSubmitting ? null : _handleLogin,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
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
