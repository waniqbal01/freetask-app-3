import 'package:flutter/foundation.dart';

class Env {
  static String get defaultApiBaseUrl {
    const envOverride = String.fromEnvironment('API_BASE_URL');
    if (envOverride.isNotEmpty) return envOverride;

    if (kIsWeb) {
      return 'http://localhost:4000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000';
    }

    // NOTE: Confirm the correct host for iOS simulator; typically http://localhost:4000 works.
    return 'http://localhost:4000';
  }
}
