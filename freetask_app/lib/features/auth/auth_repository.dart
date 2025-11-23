import 'package:dio/dio.dart';

import '../../core/storage/storage.dart';
import '../../models/user.dart';
import '../../services/http_client.dart';

class AuthRepository {
  AuthRepository({AppStorage? storage, Dio? dio})
      : _storage = storage ?? appStorage,
        _dio = dio ?? HttpClient().dio;

  static const tokenStorageKey = 'auth_token';
  static const legacyTokenStorageKey = 'access_token';

  final AppStorage _storage;
  final Dio _dio;
  AppUser? _cachedUser;

  AppUser? get currentUser => _cachedUser;

  Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: <String, dynamic>{
          'email': email,
          'password': password,
        },
      );
      final data = response.data;
      final token = data?['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        return false;
      }
      await _saveToken(token);
      final userJson = data?['user'];
      if (userJson is Map<String, dynamic>) {
        _cachedUser = AppUser.fromJson(userJson);
      }
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await logout();
      }
      rethrow;
    }
  }

  Future<bool> register(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: _buildRegisterPayload(payload),
      );
      final data = response.data;
      final token = data?['accessToken']?.toString();
      if (token != null && token.isNotEmpty) {
        await _saveToken(token);
      }
      final userJson = data?['user'];
      if (userJson is Map<String, dynamic>) {
        _cachedUser = AppUser.fromJson(userJson);
      } else {
        _cachedUser = null;
      }
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await logout();
      }
      rethrow;
    }
  }

  Future<AppUser?> getCurrentUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }

    final token = await getSavedToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/me',
        options: Options(headers: _bearerHeader(token)),
      );
      final data = response.data;
      if (data == null) {
        return null;
      }
      final user = AppUser.fromJson(data);
      _cachedUser = user;
      return user;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await logout();
        return null;
      }
      rethrow;
    }
  }

  Future<String?> getSavedToken() async {
    final token = await _storage.read(tokenStorageKey);
    if (token != null && token.isNotEmpty) {
      return token;
    }

    final legacy = await _storage.read(legacyTokenStorageKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(tokenStorageKey, legacy);
      await _storage.delete(legacyTokenStorageKey);
      return legacy;
    }

    return token;
  }

  Future<void> logout() async {
    final token = await _storage.read(tokenStorageKey);
    try {
      if (token != null && token.isNotEmpty) {
        await _dio.post<void>(
          '/auth/logout',
          options: Options(headers: _bearerHeader(token)),
        );
      }
    } on DioException {
      // Ignore logout failures and continue clearing local session.
    } finally {
      _cachedUser = null;
      await _storage.delete(tokenStorageKey);
      await _storage.delete(legacyTokenStorageKey);
    }
  }

  Map<String, String> _bearerHeader(String token) {
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  Future<void> _saveToken(String token) {
    return _storage.write(tokenStorageKey, token);
  }

  Map<String, dynamic> _buildRegisterPayload(Map<String, dynamic> payload) {
    final data = <String, dynamic>{
      'email': payload['email'],
      'password': payload['password'],
      'name': payload['name'],
      'role': payload['role'],
    };

    void addOptional(String key) {
      final value = payload[key];
      if (value == null) {
        return;
      }
      if (value is String && value.trim().isEmpty) {
        return;
      }
      if (value is Iterable && value.isEmpty) {
        return;
      }
      data[key] = value;
    }

    if (payload.containsKey('avatarUrl')) {
      data['avatarUrl'] = payload['avatarUrl'];
    }
    addOptional('avatar');
    addOptional('bio');
    addOptional('skills');
    addOptional('rate');

    return data;
  }
}

final authRepository = AuthRepository();
