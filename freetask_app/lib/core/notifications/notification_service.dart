import 'package:flutter/material.dart';
import 'notification_overlay.dart';

class NotificationService {
  NotificationService();

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  BuildContext? _context;

  GlobalKey<ScaffoldMessengerState> get messengerKey => _messengerKey;

  // Set the context for overlay notifications
  void setContext(BuildContext context) {
    _context = context;
  }

  // Main notification method using overlay
  void pushLocal(
    String title,
    String body, {
    NotificationType type = NotificationType.info,
    Duration? duration,
  }) {
    if (_context != null) {
      NotificationOverlay.show(
        _context!,
        title: title,
        message: body,
        type: type,
        duration: duration ?? const Duration(seconds: 4),
      );
    } else {
      // Fallback to SnackBar if context is not available
      final messengerState = _messengerKey.currentState;
      if (messengerState != null) {
        messengerState.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        debugPrint('[Notification] $title: $body');
      }
    }
  }

  // Convenience methods for different notification types
  void showSuccess(String title, String message, {Duration? duration}) {
    pushLocal(title, message,
        type: NotificationType.success, duration: duration);
  }

  void showError(String title, String message, {Duration? duration}) {
    pushLocal(title, message, type: NotificationType.error, duration: duration);
  }

  void showWarning(String title, String message, {Duration? duration}) {
    pushLocal(title, message,
        type: NotificationType.warning, duration: duration);
  }

  void showInfo(String title, String message, {Duration? duration}) {
    pushLocal(title, message, type: NotificationType.info, duration: duration);
  }
}

final notificationService = NotificationService();
