import 'package:flutter_test/flutter_test.dart';

import 'package:freetask_app/models/job.dart';

void main() {
  group('Job model', () {
    test('fromJson maps nested relations', () {
      final json = <String, dynamic>{
        'id': 5,
        'title': 'Translate',
        'description': 'Terjemah dokumen.',
        'amount': '450',
        'status': 'IN_PROGRESS',
        'service': <String, dynamic>{'id': 3, 'title': 'Terjemahan'},
        'client': <String, dynamic>{'id': 10, 'name': 'Client'},
        'freelancer': <String, dynamic>{'id': 2, 'name': 'Freelancer'},
      };

      final job = Job.fromJson(json);

      expect(job.id, '5');
      expect(job.serviceTitle, 'Terjemahan');
      expect(job.status, JobStatus.inProgress);
      expect(job.clientName, 'Client');
    });

    test('toJson exports snake_case friendly keys', () {
      final job = Job(
        id: '9',
        title: 'Design Poster',
        description: 'Poster digital',
        clientId: '1',
        freelancerId: '2',
        serviceId: '3',
        serviceTitle: 'Poster',
        clientName: 'Client',
        freelancerName: 'Freelancer',
        amount: 120,
        status: JobStatus.accepted,
        disputeReason: null,
        createdAt: DateTime.utc(2024, 7, 1),
      );

      final json = job.toJson();

      expect(json['id'], '9');
      expect(json['status'], 'ACCEPTED');
      expect(json['amount'], 120);
      expect(json['createdAt'], isNotNull);
    });
  });
}
