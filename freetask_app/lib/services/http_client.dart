import 'package:dio/dio.dart';

import '../core/env.dart';

class HttpClient {
  HttpClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );

  final Dio dio;
}
