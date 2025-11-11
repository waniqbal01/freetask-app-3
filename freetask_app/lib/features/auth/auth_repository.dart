import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  AuthRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage _secureStorage;

  Future<bool> login(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await _secureStorage.write(key: _tokenKey, value: 'fake-token');

    return email.isNotEmpty && password.isNotEmpty;
  }

  Future<bool> register(Map<String, dynamic> payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    await _secureStorage.write(key: _tokenKey, value: 'fake-token');

    return payload.isNotEmpty;
  }

  Future<Map<String, dynamic>?> me() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final token = await _secureStorage.read(key: _tokenKey);
    if (token == null) {
      return null;
    }

    return <String, dynamic>{
      'token': token,
      'email': 'user@example.com',
      'role': 'Client',
      'name': 'John Doe',
    };
  }

  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _secureStorage.delete(key: _tokenKey);
  }
}

final authRepository = AuthRepository();
