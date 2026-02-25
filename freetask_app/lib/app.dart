import 'dart:ui';
import 'package:flutter/material.dart';

import 'core/router.dart';
import 'core/notifications/notification_service.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
    );
  }
}
