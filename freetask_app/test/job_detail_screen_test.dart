import 'package:flutter_test/flutter_test.dart';

import 'package:freetask_app/features/jobs/job_detail_screen.dart';

void main() {
  group('resolveClientViewMode', () {
    test('uses navigation flag when provided (true)', () {
      expect(resolveClientViewMode(navigationFlag: true, role: 'FREELANCER'), isTrue);
    });

    test('uses navigation flag when provided (false)', () {
      expect(resolveClientViewMode(navigationFlag: false, role: 'CLIENT'), isFalse);
    });

    test('defaults to role-based view when flag is null (client)', () {
      expect(resolveClientViewMode(role: 'client'), isTrue);
    });

    test('defaults to role-based view when flag is null (freelancer)', () {
      expect(resolveClientViewMode(role: 'freelancer'), isFalse);
    });
  });
}
