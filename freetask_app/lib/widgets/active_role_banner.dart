import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';

class ActiveRoleBanner extends StatelessWidget {
  const ActiveRoleBanner({
    super.key,
    required this.user,
    this.actionLabel,
    this.onAction,
    this.subtitle,
    this.switchLabel,
    this.onSwitch,
  });

  final AppUser? user;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? subtitle;
  final String? switchLabel;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const SizedBox.shrink();
    }

    final role = user!.role.toUpperCase();
    final isAdmin = role == 'ADMIN';
    final isClient = role == 'CLIENT';
    final Color accentColor = isAdmin
        ? AppColors.secondary
        : isClient
            ? AppColors.primary
            : Colors.deepPurple.shade600;
    final label = isClient
        ? 'Client'
        : role == 'FREELANCER'
            ? 'Freelancer'
            : 'Admin';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.largeRadius,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accentColor.withValues(alpha: 0.12),
            child: Icon(
              isAdmin
                  ? Icons.shield_moon_outlined
                  : isClient
                      ? Icons.person_outline
                      : Icons.work_outline,
              color: accentColor,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are logged in as $label',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                ],
                if (switchLabel != null && onSwitch != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onSwitch,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: Text(switchLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
