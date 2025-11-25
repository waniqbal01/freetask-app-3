import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freetask_app/core/storage/storage.dart';
import 'package:freetask_app/features/auth/auth_repository.dart';
import 'package:freetask_app/features/jobs/job_constants.dart';
import 'package:freetask_app/features/jobs/jobs_repository.dart';
import 'package:freetask_app/models/job.dart';

class FakeStorage implements AppStorage {
  FakeStorage({String? token}) : _token = token ?? 'token';

  String _token;

  @override
  Future<void> delete(String key) async {
    if (key == AuthRepository.tokenStorageKey) {
      _token = '';
    }
  }

  @override
  Future<String?> read(String key) async {
    if (key == AuthRepository.tokenStorageKey) {
      return _token;
    }
    return null;
  }

  @override
  Future<void> write(String key, String value) async {
    if (key == AuthRepository.tokenStorageKey) {
      _token = value;
    }
  }
}

class RecordingDio implements Dio {
  int postCalls = 0;
  Map<String, dynamic>? lastRequestData;

  String _repeat(String value, int times) => List.filled(times, value).join();

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    postCalls++;
    lastRequestData = (data as Map<String, dynamic>?);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
      data: {
        'id': '123',
        'clientId': '1',
        'freelancerId': '2',
        'serviceId': lastRequestData?['serviceId'].toString() ?? '',
        'serviceTitle': lastRequestData?['title']?.toString() ?? 'Service',
        'description': lastRequestData?['description']?.toString() ??
            _repeat('x', jobMinDescLen),
        'amount': lastRequestData?['amount'] ?? jobMinAmount,
        'status': 'PENDING',
      } as T,
    );
  }

  // Implement minimal Dio interface members (these won't be called in tests)
  @override
  BaseOptions get options => BaseOptions();

  @override
  set options(BaseOptions value) {}

  @override
  Dio clone(
          {HttpClientAdapter? httpClientAdapter,
          Interceptors? interceptors,
          BaseOptions? options,
          Transformer? transformer}) =>
      throw UnimplementedError();

  @override
  Interceptors get interceptors => Interceptors();

  @override
  HttpClientAdapter get httpClientAdapter => throw UnimplementedError();

  @override
  set httpClientAdapter(HttpClientAdapter adapter) =>
      throw UnimplementedError();

  @override
  Transformer get transformer => throw UnimplementedError();

  @override
  set transformer(Transformer transformer) => throw UnimplementedError();

  @override
  void close({bool force = false}) {}

  @override
  Future<Response<T>> delete<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> deleteUri<T>(Uri uri,
          {Object? data, Options? options, CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response> download(String urlPath, dynamic savePath,
          {ProgressCallback? onReceiveProgress,
          Map<String, dynamic>? queryParameters,
          CancelToken? cancelToken,
          bool deleteOnError = true,
          dynamic fileAccessMode,
          String lengthHeader = Headers.contentLengthHeader,
          Object? data,
          Options? options}) =>
      throw UnimplementedError();

  @override
  Future<Response> downloadUri(Uri uri, dynamic savePath,
          {ProgressCallback? onReceiveProgress,
          CancelToken? cancelToken,
          bool deleteOnError = true,
          dynamic fileAccessMode,
          String lengthHeader = Headers.contentLengthHeader,
          Object? data,
          Options? options}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> get<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> getUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> head<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> headUri<T>(Uri uri,
          {Object? data, Options? options, CancelToken? cancelToken}) =>
      throw UnimplementedError();

  void lock() {}

  @override
  Future<Response<T>> patch<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> patchUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> postUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> put<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> putUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> request<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          CancelToken? cancelToken,
          Options? options,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> requestUri<T>(Uri uri,
          {Object? data,
          CancelToken? cancelToken,
          Options? options,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  void unlock() {}
}

void main() {
  group('JobsRepository.createOrder validation', () {
    test('blocks description shorter than minimum', () async {
      final dio = RecordingDio();
      final repository = JobsRepository(storage: FakeStorage(), dio: dio);

      expect(
        () => repository.createOrder('1', jobMinAmount, 'short'),
        throwsA(isA<StateError>()),
      );
      expect(dio.postCalls, 0);
    });

    test('blocks amount below minimum', () async {
      final dio = RecordingDio();
      final repository = JobsRepository(storage: FakeStorage(), dio: dio);

      expect(
        () => repository.createOrder(
            '1', jobMinAmount - 0.5, 'valid description'),
        throwsA(isA<StateError>()),
      );
      expect(dio.postCalls, 0);
    });

    test('sends request when payload meets thresholds', () async {
      final dio = RecordingDio();
      final repository = JobsRepository(storage: FakeStorage(), dio: dio);

      final description = List.filled(jobMinDescLen, 'x').join();
      final job = await repository.createOrder('10', jobMinAmount, description);

      expect(job, isA<Job>());
      expect(dio.postCalls, 1);
      expect(dio.lastRequestData?['description'], description);
      expect(dio.lastRequestData?['amount'], jobMinAmount);
    });
  });
}
