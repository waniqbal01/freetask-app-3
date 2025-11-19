import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:freetask_app/features/services/services_repository.dart';
import 'package:freetask_app/services/token_storage.dart';

class _MockDio extends Mock implements Dio {}

class _FakeRequestOptions extends Fake implements RequestOptions {
  @override
  String path = '/test';
}

class _FakeTokenStorage implements TokenStorage {
  _FakeTokenStorage(this._token);

  String? _token;

  @override
  Future<void> delete(String key) async {
    _token = null;
  }

  @override
  Future<String?> read(String key) async => _token;

  @override
  Future<void> write(String key, String value) async {
    _token = value;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
    registerFallbackValue(Options());
  });

  group('ServicesRepository', () {
    late _MockDio dio;
    late ServicesRepository repository;

    setUp(() {
      dio = _MockDio();
      repository = ServicesRepository(
        dio: dio,
        tokenStorage: _FakeTokenStorage('token'),
      );
    });

    test('getServices returns list of services', () async {
      final sample = <String, dynamic>{
        'id': 1,
        'title': 'Logo Baru',
        'category': 'Design',
        'description': 'Moden',
        'price': 120,
        'freelancer': <String, dynamic>{'id': 3, 'name': 'Aisyah'},
      };
      when(
        () => dio.get<List<dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          data: <dynamic>[sample],
          requestOptions: RequestOptions(path: '/services'),
        ),
      );

      final services = await repository.getServices(q: 'logo');

      expect(services, hasLength(1));
      expect(services.first.title, 'Logo Baru');
    });

    test('createService posts payload and returns Service', () async {
      final payload = ServiceRequestPayload(
        title: 'UX Audit',
        description: 'Audit penuh aplikasi.',
        price: 500,
        category: 'UX',
      );

      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: <String, dynamic>{
            'id': 10,
            'title': payload.title,
            'category': payload.category,
            'description': payload.description,
            'price': payload.price,
            'freelancerId': 1,
          },
          requestOptions: RequestOptions(path: '/services'),
        ),
      );

      final service = await repository.createService(payload);

      expect(service.title, payload.title);
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/services',
          data: payload.toJson(),
          options: any(named: 'options'),
        ),
      ).called(1);
    });
  });
}
