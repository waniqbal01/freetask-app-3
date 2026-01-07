import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage.dart';

const String onboardingCompletedKey = 'onboarding_completed';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isSaving = false;

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await appStorage.write(onboardingCompletedKey, 'true');
    if (!mounted) return;
    context.go('/role-selection');
  }

  Future<void> _skipToLogin() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await appStorage.write(onboardingCompletedKey, 'true');
    if (!mounted) return;
    context.go('/login');
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<String> bullets,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.indigo.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: Colors.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ...bullets.map(
                  (point) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            point,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat datang ke Freetask',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Platform untuk mengupah atau menawarkan servis dengan selamat menggunakan escrow.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'Apa itu Freetask?',
                      subtitle:
                          'Marketplace servis dan job custom dengan bayaran dilindungi.',
                      bullets: const [
                        'Pilih servis siap sedia atau minta job khusus.',
                        'Bayaran dipegang oleh sistem escrow sehingga kerja selesai.',
                        'Pantau status job secara telus.',
                      ],
                      icon: Icons.verified_user_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Untuk siapa?',
                      subtitle:
                          'Client dan Freelancer masing-masing ada laluan mudah.',
                      bullets: const [
                        'Client: Upah freelancer dengan selamat dan pantau job.',
                        'Freelancer: Terima job, jana pendapatan, bina reputasi.',
                        'Admin: Pantau escrow dan operasi.',
                      ],
                      icon: Icons.people_alt_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Apa boleh dibuat?',
                      subtitle: 'Semua aliran utama tersedia.',
                      bullets: const [
                        'Beli servis katalog atau post job custom.',
                        'Chat, terima, mulakan dan lengkapkan job.',
                        'Lihat status pembayaran escrow setiap masa.',
                      ],
                      icon: Icons.playlist_add_check_outlined,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _completeOnboarding,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                            _isSaving ? 'Memproses...' : 'Saya faham, mulakan'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _skipToLogin,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Teruskan ke Login'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              context.go('/login');
                            },
                      child: const Text('Sudah ada akaun? Log masuk'),
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
