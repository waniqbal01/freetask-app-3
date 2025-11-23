import 'env.dart';
import 'storage/storage.dart';

class BaseUrlStore {
  BaseUrlStore({AppStorage? storage})
      : _storage = storage ?? appStorage;

  static const _key = 'api_base_url_override';
  final AppStorage _storage;

  Future<String> readBaseUrl() async {
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
