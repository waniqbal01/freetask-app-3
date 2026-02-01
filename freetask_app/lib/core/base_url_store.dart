import 'dart:async';

import 'package:flutter/foundation.dart';

import 'env.dart';
import 'storage/storage.dart';

class BaseUrlStore {
  BaseUrlStore({AppStorage? storage}) : _storage = storage ?? appStorage;

  static const _key = 'api_base_url_override';
  final AppStorage _storage;

  Future<String> readBaseUrl() async {
    // strict-enforcement: Always use production Env URL in release mode
    if (kReleaseMode) {
      return Env.defaultApiBaseUrl;
    }

    final stored = (await _storage.read(_key))?.trim();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return Env.defaultApiBaseUrl;
  }

  Future<void> saveBaseUrl(String? value) async {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      await _storage.delete(_key);
      return;
    }
    await _storage.write(_key, normalized);
  }
}

class BaseUrlManager {
  BaseUrlManager({AppStorage? storage})
      : _store = BaseUrlStore(storage: storage);

  final BaseUrlStore _store;
  String? _cached;
  Completer<String>? _loading;

  Future<String> getBaseUrl() async {
    if (_cached != null) return _cached!;
    if (_loading != null) return _loading!.future;

    _loading = Completer<String>();
    try {
      _cached = await _store.readBaseUrl();
      _loading!.complete(_cached);
    } catch (error, stack) {
      _loading!.completeError(error, stack);
      rethrow;
    } finally {
      _loading = null;
    }
    return _cached!;
  }

  Future<String> setBaseUrl(String? value) async {
    await _store.saveBaseUrl(value);
    _cached = await _store.readBaseUrl();
    return _cached!;
  }
}
