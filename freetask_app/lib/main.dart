import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // TODO: Startup -> check token -> navigate to Login or Home
  runApp(const ProviderScope(child: App()));
}
