import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freetask_app/main.dart';

void main() {
  testWidgets('Home screen shows welcome message', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FreeTaskApp()));

    expect(find.textContaining('Welcome to FreeTask!'), findsOneWidget);
    await tester.tap(find.text('Show message'));
    await tester.pump();

    expect(find.text('Get started building your app!'), findsOneWidget);
  });
}
