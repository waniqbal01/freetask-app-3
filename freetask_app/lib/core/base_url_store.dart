import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'env.dart';

class BaseUrlStore {
  BaseUrlStore({FlutterSecureStorage? secureStorage})
      : _storage = secureStorage ?? const FlutterSecureStorage();

  static const _key = 'api_base_url_override';
  final FlutterSecureStorage _storage;

  Future<String> readBaseUrl() async {
    final stored = (await _storage.read(key: _key))?.trim();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return Env.defaultApiBaseUrl;
  }

  Future<void> saveBaseUrl(String? value) async {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      await _storage.delete(key: _key);
      return;
    }
    await _storage.write(key: _key, value: normalized);
  }
}
