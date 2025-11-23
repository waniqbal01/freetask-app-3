import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'http_client.dart';
import '../core/storage/storage.dart';

class UploadService {
  UploadService({Dio? dio, AppStorage? storage})
      : _dio = dio ?? HttpClient().dio,
        _storage = storage ?? appStorage;

  final Dio _dio;
  final AppStorage _storage;

  Future<String> uploadFile(String filePath) async {
    await _validateFile(filePath);
    final fileName = p.basename(filePath);
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final token = await _storage.read(_authTokenKey) ??
        await _storage.read(_legacyAccessTokenKey);
    if (token == null || token.isEmpty) {
      throw const UnauthenticatedUploadException('Sila login dulu untuk upload.');
    }
    final headers = <String, dynamic>{};
    headers['Authorization'] = 'Bearer $token';

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
    if (size > maxFileBytes) {
      throw const ValidationException('Saiz fail melebihi had 5MB.');
    }

    final mimeType = lookupMimeType(filePath) ?? '';
    if (!allowedMimeTypes.contains(mimeType)) {
      throw const ValidationException('Jenis fail tidak disokong untuk muat naik.');
    }
  }

  static const int maxFileBytes = 5 * 1024 * 1024;
  static const Set<String> allowedMimeTypes = <String>{
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

class UnauthenticatedUploadException implements Exception {
  const UnauthenticatedUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
