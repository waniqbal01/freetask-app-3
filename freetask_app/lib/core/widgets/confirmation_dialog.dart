import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable confirmation dialog for destructive or important actions.
///
/// Usage:
/// ```dart
/// final confirmed = await showConfirmationDialog(
///   context: context,
///   title: 'Delete Item?',
///   message: 'Are you sure you want to delete this item?',
///   confirmText: 'Delete',
///   isDangerous: true,
/// );
/// if (confirmed == true) {
///   // Perform action
/// }
/// ```
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
  bool isDangerous = false,
  IconData? icon,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => ConfirmationDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDangerous: isDangerous,
      icon: icon,
    ),
  );
}

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.isDangerous = false,
    this.icon,
    super.key,
  });

  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final bool isDangerous;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirmColor = isDangerous ? Colors.red : AppColors.primary;
    final iconData = icon ??
        (isDangerous ? Icons.warning_amber_rounded : Icons.help_outline);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius,
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: confirmColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: confirmColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.neutral900,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.neutral600,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.neutral600,
          ),
          child: Text(cancelText ?? 'Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText ?? 'Sahkan'),
        ),
      ],
    );
  }
}
