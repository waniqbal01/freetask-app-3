import 'package:flutter/foundation.dart';

class Env {
  // Use localhost for web builds and Android emulator loopback for mobile/desktop.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:4000' : 'http://10.0.2.2:4000',
  );
}
