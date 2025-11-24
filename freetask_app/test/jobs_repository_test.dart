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

class RecordingDio extends Dio {
  int postCalls = 0;
  Map<String, dynamic>? lastRequestData;

  String _repeat(String value, int times) => List.filled(times, value).join();

  @override
  Future<Response<Map<String, dynamic>>> post<Map<String, dynamic>>(
    String path, {
    data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    postCalls++;
    lastRequestData = (data as Map?)?.cast<String, dynamic>();
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
      data: {
        'id': '123',
        'clientId': '1',
        'freelancerId': '2',
        'serviceId': lastRequestData?['serviceId'].toString() ?? '',
        'serviceTitle': lastRequestData?['title']?.toString() ?? 'Service',
        'description': lastRequestData?['description']?.toString() ?? _repeat('x', jobMinDescLen),
        'amount': lastRequestData?['amount'] ?? jobMinAmount,
        'status': 'PENDING',
      },
    );
  }
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
        () => repository.createOrder('1', jobMinAmount - 0.5, 'valid description'),
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
