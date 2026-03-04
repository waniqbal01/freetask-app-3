import 'dart:ui';
import 'package:flutter/material.dart';

import 'core/router.dart';
import 'core/notifications/notification_service.dart';
import 'theme/app_theme.dart';
import 'core/websocket/socket_service.dart';
import 'services/http_client.dart';
import 'features/auth/auth_repository.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return _AppLifecycleManager(
      child: MaterialApp.router(
        title: 'FreeTask',
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
        scaffoldMessengerKey: notificationService.messengerKey,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        builder: (context, child) {
          // Set context for overlay notifications
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notificationService.setContext(context);
          });
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}

/// A widget that listens to the app lifecycle and manages the global WebSocket connection.
/// It connects when the app is in the foreground and disconnects when in the background.
class _AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const _AppLifecycleManager({required this.child});

  @override
  State<_AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<_AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial connection attempt if user is already logged in
    _connectSocketIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AppLifecycleState changed to: $state');
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _connectSocketIfNeeded();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App went to background
      _disconnectSocket();
    }
  }

  Future<void> _connectSocketIfNeeded() async {
    // Only connect if we have a logged-in user
    if (authRepository.currentUser != null) {
      try {
        final baseUrl = await HttpClient().currentBaseUrl();
        await SocketService.instance.connect(baseUrl);
      } catch (e) {
        debugPrint('AppLifecycleManager failed to connect socket: $e');
      }
    }
  }

  void _disconnectSocket() {
    SocketService.instance.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
