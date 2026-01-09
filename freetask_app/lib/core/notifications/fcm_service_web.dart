import 'package:flutter/foundation.dart';

// Web-specific FCM service that does nothing
// Firebase Messaging has compatibility issues on web
class FCMService {
  Future<void> initialize() async {
    debugPrint('FCM: Web platform - notifications not supported');
  }

  String? get fcmToken => null;

  Future<void> registerTokenWithBackend() async {
    debugPrint('FCM: Skipping token registration on web');
  }
}

final fcmService = FCMService();
