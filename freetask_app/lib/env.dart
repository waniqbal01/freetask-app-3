import 'package:flutter/foundation.dart';

class Env {
  static String get defaultApiBaseUrl {
    // Note: This default can be overridden by BaseUrlManager (user settings)
    const envOverride = String.fromEnvironment('API_BASE_URL');
    if (envOverride.isNotEmpty) return envOverride;

    if (kIsWeb) {
      return 'http://localhost:4000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000';
    }

    // iOS simulator/device: localhost works for simulator, use LAN IP for physical devices
    return 'http://localhost:4000';
  }
}
