import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple string-only storage that is safe across mobile, desktop, and web.
abstract class AppStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Platform-aware storage factory. Uses secure storage on mobile/desktop and
/// SharedPreferences (localStorage-backed) on web to avoid startup crashes.
class PlatformStorage implements AppStorage {
  factory PlatformStorage({AppStorage? override}) {
    if (_instance == null) {
      final delegate =
          override ?? (kIsWeb ? WebPreferencesStorage() : SecureKeyStorage());
      _instance = PlatformStorage._(delegate);
    }
    return _instance!;
  }

  PlatformStorage._(this._delegate);

  static PlatformStorage? _instance;
  final AppStorage _delegate;

  @override
  Future<String?> read(String key) => _delegate.read(key);

  @override
  Future<void> write(String key, String value) => _delegate.write(key, value);

  @override
  Future<void> delete(String key) => _delegate.delete(key);
}

class SecureKeyStorage implements AppStorage {
  SecureKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class WebPreferencesStorage implements AppStorage {
  WebPreferencesStorage({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    _preferences ??= await SharedPreferences.getInstance();
    return _preferences!;
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await _prefs();
    await prefs.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    final prefs = await _prefs();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await _prefs();
    await prefs.setString(key, value);
  }
}

final AppStorage appStorage = PlatformStorage();
