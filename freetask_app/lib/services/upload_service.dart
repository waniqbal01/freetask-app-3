import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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

  Future<UploadResult> uploadFile(String filePath) async {
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
    final key = data?['key']?.toString();

    if (url == null || url.isEmpty) {
      throw StateError('URL muat naik tidak sah.');
    }

    return UploadResult(
      key: key ?? fileName,
      url: _normalizePath(url),
    );
  }

  Future<String> resolveAuthorizedUrl(String url) async {
    final normalizedPath = _normalizePath(url);
    if (normalizedPath.startsWith('http')) {
      return normalizedPath;
    }

    final base = await HttpClient().currentBaseUrl();
    return _joinBaseAndPath(base, normalizedPath);
  }

  Future<Response<Uint8List>> downloadWithAuth(String url) async {
    final targetUrl = await resolveAuthorizedUrl(url);
    final headers = await authorizationHeader();
    return _dio.get<Uint8List>(
      targetUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers.isEmpty ? null : headers,
      ),
    );
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

  Future<Map<String, String>> authorizationHeader() async {
    final token = await _storage.read(_authTokenKey) ?? await _storage.read(_legacyAccessTokenKey);
    if (token == null || token.isEmpty) {
      return <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  String _normalizePath(String url) {
    if (url.startsWith('http')) {
      return url;
    }
    return url.startsWith('/') ? url : '/$url';
  }

  String _joinBaseAndPath(String base, String path) {
    final sanitizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$sanitizedBase$path';
  }
}

final uploadService = UploadService();

class UploadResult {
  UploadResult({required this.key, required this.url});

  final String key;
  final String url;
}

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
