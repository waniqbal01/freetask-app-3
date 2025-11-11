import 'dart:async';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'http_client.dart';

class UploadService {
  UploadService({Dio? dio}) : _dio = dio ?? HttpClient().dio;

  final Dio _dio;

  Future<String> uploadFile(String filePath) async {
    final fileName = p.basename(filePath);
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/uploads',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final data = response.data;
    final url = data?['url']?.toString();

    if (url == null || url.isEmpty) {
      throw StateError('URL muat naik tidak sah.');
    }

    return url;
  }
}

final uploadService = UploadService();
