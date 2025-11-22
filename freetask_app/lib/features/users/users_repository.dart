import 'package:dio/dio.dart';

import '../../services/http_client.dart';

class UsersRepository {
  UsersRepository({Dio? dio}) : _dio = dio ?? HttpClient().dio;

  final Dio _dio;

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? bio,
    List<String>? skills,
    num? rate,
  }) async {
    final payload = <String, dynamic>{};

    void addIfPresent(String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is Iterable && value.isEmpty) return;
      payload[key] = value;
    }

    addIfPresent('name', name);
    addIfPresent('avatarUrl', avatarUrl);
    addIfPresent('bio', bio);
    addIfPresent('skills', skills);
    addIfPresent('rate', rate);

    if (payload.isEmpty) {
      return;
    }

    await _dio.patch<void>(
      '/users/me',
      data: payload,
    );
  }
}

final usersRepository = UsersRepository();
