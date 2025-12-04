import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage.dart';
import '../../theme/app_theme.dart';

const String firstClientBannerKey = 'client_first_time';

/// Banner shown to first-time clients after registration
/// UX-C-05: First-time Client onboarding banner
class FirstClientBanner extends StatelessWidget {
  const FirstClientBanner({super.key, this.onDismiss});

  final VoidCallback? onDismiss;

  Future<void> _dismiss(BuildContext context) async {
    await appStorage.write(firstClientBannerKey, 'false');
    onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.largeRadius,
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Selamat datang sebagai Client!',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _dismiss(context),
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.neutral500,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Langkah seterusnya:',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildStep('1', 'Lengkapkan profil anda'),
          const SizedBox(height: 4),
          _buildStep('2', 'Post job pertama ATAU pilih servis dari senarai'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _dismiss(context);
                    context.go('/home');
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Cari Servis'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _dismiss(context);
                    context.go('/settings');
                  },
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Lengkap Profil'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }
}
