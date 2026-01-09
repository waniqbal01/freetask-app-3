import 'package:flutter/material.dart';

class NotificationService {
  NotificationService();

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  GlobalKey<ScaffoldMessengerState> get messengerKey => _messengerKey;

  void pushLocal(String title, String body) {
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

final notificationService = NotificationService();
