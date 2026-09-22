import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/reports/data/model/report_model.dart';
import 'package:pao/features/reports/domain/report_type.dart';
import 'package:pao/features/reports/presentation/provider/report_provider.dart';
import 'package:pao/features/reports/presentation/screens/report_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

/// The page's own list (text fields are scrollables too).
final _page = find.byType(Scrollable).first;

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Submit'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Submit'));
}

void main() {
  late FakeReportRepository reports;
  late ReportProvider provider;

  setUpAll(initFakeSupabase);

  setUp(() {
    reports = FakeReportRepository();
    provider = ReportProvider(
      repository: reports,
      authRepository: FakeAuthRepository(
        user: const UserModel(id: 'u1', email: 'me@example.com'),
      ),
    );
  });

  testWidgets('shows both types and the empty history', (tester) async {
    await tester.pumpWidget(testApp(ReportScreen(provider: provider)));
    await tester.pumpAndSettle();
    expect(find.text('Report a bug'), findsOneWidget);
    expect(find.text('Suggest a feature'), findsOneWidget);
    expect(find.text('What went wrong?'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Nothing sent yet'),
      200,
      scrollable: _page,
    );
    expect(find.textContaining('Nothing sent yet'), findsOneWidget);
  });

  testWidgets('switching to feature changes the form', (tester) async {
    await tester.pumpWidget(testApp(ReportScreen(provider: provider)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggest a feature'));
    await tester.pump();
    expect(find.text("What's your idea?"), findsOneWidget);
  });

  testWidgets('validates, then submits and lists the report', (tester) async {
    await tester.pumpWidget(testApp(ReportScreen(provider: provider)));
    await tester.pumpAndSettle();

    await _tapSubmit(tester);
    await tester.pump();
    expect(find.text('Please add a short title'), findsOneWidget);
    expect(reports.submitCalls, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), 'Crash on send');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'The app closes when I send a photo.',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(reports.submitCalls.single.title, 'Crash on send');
    await tester.scrollUntilVisible(
      find.text('Received'),
      200,
      scrollable: _page,
    );
    expect(find.text('Received'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('renders existing reports in Urdu and dark mode', (tester) async {
    reports.existing = [
      ReportModel(
        id: 'r1',
        userId: 'u1',
        type: ReportType.feature,
        title: 'Dark map',
        description: 'Please add a dark map',
        status: ReportStatus.done,
        createdAt: DateTime(2026, 9, 1),
      ),
    ];
    await tester.pumpWidget(
      testApp(
        ReportScreen(provider: provider),
        themeMode: ThemeMode.dark,
        locale: const Locale('ur'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dark map'),
      200,
      scrollable: _page,
    );
    expect(find.text('مکمل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
