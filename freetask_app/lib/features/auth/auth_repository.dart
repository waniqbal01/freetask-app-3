import 'package:dio/dio.dart';

import '../../core/utils/error_utils.dart';
import '../../models/user.dart';
import '../../services/http_client.dart';
import '../../services/token_storage.dart';

class AuthRepository {
  AuthRepository({TokenStorage? tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage ?? createTokenStorage(),
        _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio;

  static const tokenStorageKey = 'auth_token';

  final TokenStorage _tokenStorage;
  final Dio _dio;
  AppUser? _cachedUser;

  AppUser? get currentUser => _cachedUser;

  Future<bool> login(String email, String password) async {
    return _guardRequest(() async {
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
        throw const AppException('Token tidak diterima.', type: AppErrorType.server);
      }
      await _saveToken(token);
      final userJson = data?['user'];
      if (userJson is Map<String, dynamic>) {
        _cachedUser = AppUser.fromJson(userJson);
      }
      return true;
    }, clearOn401: false);
  }

  Future<bool> register(Map<String, dynamic> payload) async {
    return _guardRequest(() async {
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
    }, clearOn401: false);
  }

  Future<AppUser?> getCurrentUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }

    final token = await getSavedToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    return _guardRequest(() async {
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
    });
  }

  Future<String?> getSavedToken() {
    return _tokenStorage.read(tokenStorageKey);
  }

  Future<void> logout() async {
    final token = await _tokenStorage.read(tokenStorageKey);
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
      await _tokenStorage.delete(tokenStorageKey);
    }
  }

  Map<String, String> _bearerHeader(String token) {
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  Future<void> _saveToken(String token) {
    return _tokenStorage.write(tokenStorageKey, token);
  }

  Future<T> _guardRequest<T>(
    Future<T> Function() runner, {
    bool clearOn401 = true,
  }) async {
    try {
      return await runner();
    } on DioException catch (error) {
      final mapped = mapDioError(error);
      if (clearOn401 && mapped.isUnauthorized) {
        _cachedUser = null;
        await _tokenStorage.delete(tokenStorageKey);
      }
      throw mapped;
    }
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

    addOptional('avatar');
    addOptional('bio');
    addOptional('skills');
    addOptional('rate');

    return data;
  }
}

final authRepository = AuthRepository();
