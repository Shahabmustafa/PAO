import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pao/main.dart';

void main() {
  testWidgets('App starts on splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('PAO'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the splash screen's navigation timer fire before the test ends.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
