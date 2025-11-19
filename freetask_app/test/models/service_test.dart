import 'package:flutter_test/flutter_test.dart';

import 'package:freetask_app/models/service.dart';

void main() {
  group('Service model', () {
    test('fromJson parses nested freelancer data', () {
      final json = <String, dynamic>{
        'id': 7,
        'title': 'UX Review',
        'category': 'Design',
        'description': 'Audit aplikasi anda.',
        'price': 350,
        'freelancer': <String, dynamic>{'id': 9, 'name': 'Aisyah'},
        'createdAt': '2024-06-01T10:00:00Z',
      };

      final service = Service.fromJson(json);

      expect(service.id, '7');
      expect(service.freelancerId, '9');
      expect(service.freelancerName, 'Aisyah');
      expect(service.createdAt, isNotNull);
    });

    test('toJson returns serializable map', () {
      final now = DateTime.utc(2024, 05, 01);
      final service = Service(
        id: '12',
        title: 'Logo Baru',
        category: 'Design',
        description: 'Reka bentuk logo moden.',
        price: 220,
        freelancerId: '99',
        freelancerName: 'Rahman',
        createdAt: now,
      );

      final json = service.toJson();

      expect(json['id'], '12');
      expect(json['title'], 'Logo Baru');
      expect(json['price'], 220);
      expect(json['freelancerName'], 'Rahman');
      expect(json['createdAt'], now.toIso8601String());
    });
  });
}
