import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router.dart';
import '../../services/notifications_repository.dart';
import 'notification_service.dart';
import 'notification_overlay.dart';
import 'package:permission_handler/permission_handler.dart';

// Top-level background handler — MUST be outside class
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');

  // MUST initialize local notifications in the background isolate
  await fcmService._initLocalNotifications();

  // If data-only message in background, show local notification manually
  if (message.notification == null && message.data.isNotEmpty) {
    fcmService._showLocalNotification(message);
  }
}

// Top-level background notification tap handler — MUST be outside class
@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  // Navigation not possible from background — handled on app resume
  debugPrint('[FCM] Background notification tapped: ${response.payload}');
}

class FCMService {
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  static const _channelId = 'freetask_chat_channel';
  static const _channelName = 'FreeTask Chat';

  Future<void> initialize() async {
    // FCM not supported on web
    if (kIsWeb) {
      debugPrint('[FCM] Skipping FCM init on web platform');
      return;
    }
    try {
      _messaging = FirebaseMessaging.instance;

      // Request permission
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permission denied');
        return;
      }

      // Setup local notifications (for when app is in foreground)
      await _initLocalNotifications();

      // Explicitly request notification permissions (Android 13+)
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // Request ignoring battery optimizations for reliable background delivery
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Foreground messages — FCM won't show heads-up, so we show locally
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          // Show elegant in-app overlay for 10/10 UX instead of system tray when open
          notificationService.pushLocal(
            message.notification!.title ?? 'FreeTask',
            message.notification!.body ?? 'Mesej baru',
            type: NotificationType.info,
            duration: const Duration(seconds: 4),
          );
        } else if (message.data.isNotEmpty) {
          // Fallback if no notification object but data exists
          final title = message.data['title'] ?? 'FreeTask';
          final body = message.data['body'] ?? 'Mesej baru';
          notificationService.pushLocal(
            title.toString(),
            body.toString(),
            type: NotificationType.info,
            duration: const Duration(seconds: 4),
          );
        }
      });

      // App was in BACKGROUND — user tapped notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // App was KILLED — user tapped notification to open app
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationTap(initialMessage);
        });
      }

      // Get and register token
      await refreshToken();

      // Listen for token refreshes
      _messaging!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerTokenWithBackend(newToken);
      });
    } catch (e) {
      debugPrint('[FCM] Init error: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) {
          _navigateToChat(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
            playSound: true,
          ),
        );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'FreeTask';
    String body = message.notification?.body ??
        message.data['body']?.toString() ??
        'Mesej baru';

    if (body.startsWith('__REPLY:')) {
      final endIdx = body.indexOf('__\n');
      if (endIdx != -1) {
        body = body.substring(endIdx + 3);
      }
    }

    await _localNotifications.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['route']?.toString() ??
          message.data['conversationId']?.toString(),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // 1. If payload explicitly defines a route:
    final route = message.data['route'];
    if (route != null && route.toString().isNotEmpty) {
      _navigateToRoute(route.toString());
      return;
    }

    // 2. Fallback to conversationId
    final conversationId = message.data['conversationId'];
    if (conversationId != null) {
      _navigateToChat(conversationId.toString());
    }
  }

  void _navigateToRoute(String route) {
    if (!route.startsWith('/')) {
      appRouter.push('/$route');
    } else {
      appRouter.push(route);
    }
  }

  void _navigateToChat(String conversationId) {
    appRouter.push('/chats/$conversationId/messages');
  }

  /// Call after user logs in to register this device for push notifications.
  Future<void> refreshToken() async {
    // FCM token not available on web
    if (kIsWeb) return;
    try {
      _messaging ??= FirebaseMessaging.instance;
      final token = await _messaging!.getToken();
      if (token != null && token != _fcmToken) {
        _fcmToken = token;
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await NotificationsRepository().registerToken(token, platform: 'android');
      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Error registering token: $e');
    }
  }

  /// Call on logout to stop push notifications for this device.
  Future<void> unregisterToken() async {
    if (kIsWeb) return;
    try {
      if (_fcmToken != null) {
        await NotificationsRepository().deleteToken(_fcmToken!);
        _fcmToken = null;
        debugPrint('[FCM] Token unregistered');
      }
    } catch (e) {
      debugPrint('[FCM] Error unregistering token: $e');
    }
  }
}

final fcmService = FCMService();
