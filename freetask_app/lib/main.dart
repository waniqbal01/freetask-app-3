import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/notifications/fcm_service_web.dart'
    if (dart.library.io) 'core/notifications/fcm_service.dart';
import 'core/storage/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  await initStorage();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');

    // Initialize FCM service
    await fcmService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue without Firebase if initialization fails
  }

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
