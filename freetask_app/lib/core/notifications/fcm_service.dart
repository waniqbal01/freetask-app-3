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
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _fcmToken;

  Future<void> initialize() async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM: User granted permission');

        // Get FCM token
        _fcmToken = await _messaging.getToken();
        debugPrint('FCM Token: $_fcmToken');

        // Initialize local notifications
        await _initializeLocalNotifications();

        // Listen to token refresh
        _messaging.onTokenRefresh.listen(_onTokenRefresh);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);

        // Handle notification taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Register token with backend
        await registerTokenWithBackend();
      } else {
        debugPrint('FCM: User declined permission');
      }
    } catch (e) {
      debugPrint('FCM initialization error: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.messageId}');
    _navigateBasedOnData(message.data);
  }

  void _navigateBasedOnData(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final type = data['type'] as String?;
    final id = data['id'] as String?;

    if (type == null || id == null) return;

    // Import router at top of file to use appRouter
    // For now, just log the navigation intent
    debugPrint('Should navigate to: $type with id: $id');
    // To implement: use go_router navigation
    // Example: context.go('/jobs/$id'); or appRouter.push('/jobs/$id');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Parse payload and navigate
    // Payload format assumption: "type:id" (e.g., "job:123")
    if (response.payload != null && response.payload!.isNotEmpty) {
      final parts = response.payload!.split(':');
      if (parts.length == 2) {
        _navigateBasedOnData({'type': parts[0], 'id': parts[1]});
      }
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    _fcmToken = token;
    debugPrint('FCM token refreshed: $token');
    await registerTokenWithBackend();
  }

  Future<void> registerTokenWithBackend() async {
    if (_fcmToken == null) return;

    try {
      final token = await appStorage.read(AuthRepository.tokenStorageKey);
      if (token == null) return;

      final dio = Dio();
      final apiUrl = await HttpClient().currentBaseUrl();

      await dio.post(
        '$apiUrl/notifications/register-token',
        data: {
          'token': _fcmToken,
          'platform': 'flutter',
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      debugPrint('FCM token registered with backend');
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  String? get fcmToken => _fcmToken;
}

final fcmService = FCMService();
