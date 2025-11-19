import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freetask_app/models/service.dart';
import 'package:freetask_app/widgets/service_card.dart';

void main() {
  testWidgets('ServiceCard shows title, price and category', (WidgetTester tester) async {
    final service = Service(
      id: '1',
      title: 'UX Audit',
      category: 'UX',
      description: 'Audit lengkap.',
      price: 350,
      freelancerId: '2',
      freelancerName: 'Aisyah',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ServiceCard(
            service: service,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('UX Audit'), findsOneWidget);
    expect(find.textContaining('RM350'), findsWidgets);
    expect(find.text('UX'), findsWidgets);
    expect(find.textContaining('Lihat servis'), findsOneWidget);
  });
}
