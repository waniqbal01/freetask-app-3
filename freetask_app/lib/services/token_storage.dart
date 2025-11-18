import 'package:flutter/foundation.dart';

import 'token_storage_io.dart' if (dart.library.html) 'token_storage_web.dart';

abstract class TokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

TokenStorage createTokenStorage() => getTokenStorage(kIsWeb);
