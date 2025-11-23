import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'http_client.dart';

class UploadService {
  UploadService({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio ?? HttpClient().dio,
        _storage = secureStorage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<String> uploadFile(String filePath) async {
    await _validateFile(filePath);
    final fileName = p.basename(filePath);
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final token = await _storage.read(key: _authTokenKey) ??
        await _storage.read(key: _legacyAccessTokenKey);
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

  Future<void> _validateFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const ValidationException('Fail tidak ditemui.');
    }

    final size = await file.length();
    if (size > _maxFileBytes) {
      throw const ValidationException('Saiz fail melebihi had 5MB.');
    }

    final mimeType = lookupMimeType(filePath) ?? '';
    if (!_allowedMimeTypes.contains(mimeType)) {
      throw const ValidationException('Jenis fail tidak disokong untuk muat naik.');
    }
  }

  static const int _maxFileBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/gif',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  static const String _authTokenKey = 'auth_token';
  static const String _legacyAccessTokenKey = 'access_token';
}

final uploadService = UploadService();

class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}
