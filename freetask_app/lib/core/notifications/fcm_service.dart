/*
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import '../storage/storage.dart';
import '../../services/http_client.dart';
import '../../features/auth/auth_repository.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

class FCMService {
  // Commented out due to build issues
  // final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  // final FlutterLocalNotificationsPlugin _localNotifications =
  //     FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;

  Future<void> initialize() async {
    debugPrint('FCM disabled for release build');
    return;
  }
}

final fcmService = FCMService();
*/

class FCMService {
  Future<void> initialize() async {
    // FCM Disabled
  }
}

final fcmService = FCMService();
