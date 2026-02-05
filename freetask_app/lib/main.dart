import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/notifications/fcm_service.dart';
import 'services/http_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    if (const bool.fromEnvironment('dart.library.js_util')) {
      debugPrint('Skipping Firebase initialization on Web (Config missing)');
    } else {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');

      // Initialize FCM service
      await fcmService.initialize();
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue without Firebase if initialization fails
  }

  // PROACTIVE WAKE-UP: Ping server in background during app startup
  // This ensures server is awake BEFORE user tries to login
  _wakeUpServerInBackground();

  // Global error boundary for unhandled errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red[50],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Oops! Sesuatu tidak kena',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: App()));
}

/// Proactively wake up the backend server in background
/// This runs asynchronously without blocking app startup
void _wakeUpServerInBackground() {
  // Fire and forget - don't await
  Future.microtask(() async {
    try {
      debugPrint('[ProactiveWakeUp] Starting background server wake-up...');
      final success = await HttpClient().wakeUpServer();
      if (success) {
        debugPrint('[ProactiveWakeUp] ✓ Server is online and ready');
      } else {
        debugPrint(
            '[ProactiveWakeUp] ⚠ Server did not respond (may still be cold)');
      }
    } catch (e) {
      debugPrint('[ProactiveWakeUp] ✗ Error during wake-up: $e');
      // Silent failure - user will see retry logic on login if needed
    }
  });
}
