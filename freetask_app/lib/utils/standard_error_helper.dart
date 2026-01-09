import 'package:flutter/material.dart';

/// Standard error display helper for consistent error handling across the app
/// UX-G-10: Standardize error handling
void showStandardError(
  BuildContext context, {
  String? message,
  String? code,
  VoidCallback? onRetry,
  bool showSupportContact = false,
}) {
  final defaultMessage =
      message ?? 'Ralat semasa memproses tindakan ini. Sila cuba lagi.';

  final snackBar = SnackBar(
    content: Text(defaultMessage),
    duration: const Duration(seconds: 4),
    action: onRetry != null
        ? SnackBarAction(
            label: 'Cuba lagi',
            onPressed: onRetry,
          )
        : null,
    behavior: SnackBarBehavior.floating,
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);

  // For critical errors, show additional support message
  if (showSupportContact) {
    Future.delayed(const Duration(seconds: 4), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jika masalah berterusan, hubungi sokongan.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
}

/// Show error dialog for critical errors that need user attention
Future<void> showStandardErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
  VoidCallback? onRetry,
}) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Cuba lagi'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      );
    },
  );
}
