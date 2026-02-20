import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'package:http_parser/http_parser.dart';
import 'http_client.dart';
import '../core/env.dart';
import '../core/storage/storage.dart';
import '../core/notifications/notification_service.dart';

class UploadService {
  UploadService({Dio? dio, AppStorage? storage})
      : _dio = dio ?? _createDio(),
        _storage = storage ?? appStorage;

  static Dio _createDio() {
    return Dio(BaseOptions(
      baseUrl: Env.defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  final Dio _dio;
  final AppStorage _storage;

  Future<UploadResult> uploadFile(String filePath) async {
    await _validateFile(filePath);
    final fileName = p.basename(filePath);
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return _performUpload(formData);
  }

  Future<UploadResult> uploadData(
      String fileName, Uint8List bytes, String? mimeType) async {
    if (bytes.lengthInBytes > maxFileBytes) {
      throw const ValidationException('Saiz fail melebihi had 5MB.');
    }
    // Basic mime check if provided, otherwise assume valid for now or check header bytes (complex).
    if (mimeType != null && !allowedMimeTypes.contains(mimeType)) {
      throw const ValidationException(
          'Jenis fail tidak disokong untuk muat naik.');
    }

    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ),
    });
    return _performUpload(formData);
  }

  Future<UploadResult> _performUpload(FormData formData) async {
    final token = await _storage.read(_authTokenKey) ??
        await _storage.read(_legacyAccessTokenKey);
    if (token == null || token.isEmpty) {
      throw const UnauthenticatedUploadException(
          'Sila login dulu untuk upload.');
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
      key: key ?? 'unknown',
      url: _normalizePath(url),
    );
  }

  Future<String> resolveAuthorizedUrl(String url) async {
    // If it's already an absolute URL (e.g. Supabase or external), return it directly
    if (url.startsWith('http')) {
      return url;
    }

    final normalizedPath = _normalizePath(url);
    final base = await HttpClient().currentBaseUrl();
    return _joinBaseAndPath(base, normalizedPath);
  }

  Future<Response<Uint8List>> downloadWithAuth(String url) async {
    final targetUrl = await resolveAuthorizedUrl(url);
    final headers = await authorizationHeader();
    if (headers.isEmpty) {
      _notifyUnauthorized();
      throw const UnauthenticatedUploadException(
          'Sila log masuk untuk memuat turun fail.');
    }

    try {
      return await _dio.get<Uint8List>(
        targetUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        _notifyUnauthorized(
          message:
              'Akses fail memerlukan log masuk aktif. Sila log masuk semula.',
        );
      }
      rethrow;
    }
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
      throw const ValidationException(
          'Jenis fail tidak disokong untuk muat naik.');
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
    final token = await _storage.read(_authTokenKey) ??
        await _storage.read(_legacyAccessTokenKey);
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
    final sanitizedBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$sanitizedBase$path';
  }

  void _notifyUnauthorized(
      {String message =
          'Sesi tamat. Sila log masuk semula untuk akses fail.'}) {
    notificationService.messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
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
