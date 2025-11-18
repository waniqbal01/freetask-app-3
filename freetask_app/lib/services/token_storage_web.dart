// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'token_storage.dart';

class WebTokenStorage implements TokenStorage {
  final html.Storage _storage = html.window.localStorage;

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return _storage[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }
}

TokenStorage getTokenStorage(bool isWeb) => WebTokenStorage();
