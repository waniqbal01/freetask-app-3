import 'package:flutter/material.dart';

/// Web-compatible FCM service stub
/// Firebase Cloud Messaging is not available on web platform
class FCMService {
  Future<void> initialize() async {
    debugPrint('FCM: Not available on web platform');
    // No-op for web - FCM notifications not supported
  }

  String? get fcmToken => null;
}

final fcmService = FCMService();
