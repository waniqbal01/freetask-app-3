import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'http_client.dart';
import 'token_storage.dart';

class UploadService {
  UploadService({Dio? dio, TokenStorage? tokenStorage})
      : _dio = dio ?? HttpClient(tokenStorage: tokenStorage).dio,
        _storage = tokenStorage ?? createTokenStorage();

  final Dio _dio;
  final TokenStorage _storage;

  Future<String> uploadFile(String filePath) async {
    final fileName = p.basename(filePath);
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final token = await _storage.read(_authTokenKey) ??
        await _storage.read(_legacyAccessTokenKey);
    final headers = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      debugPrint('UploadService: no auth token found; uploads may be rejected with 401.');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/uploads',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        headers: headers.isNotEmpty ? headers : null,
      ),
    );

    final data = response.data;
    final url = data?['url']?.toString();

    if (url == null || url.isEmpty) {
      throw StateError('URL muat naik tidak sah.');
    }

    return url;
  }

  static const String _authTokenKey = 'auth_token';
  static const String _legacyAccessTokenKey = 'access_token';
}

final uploadService = UploadService();
