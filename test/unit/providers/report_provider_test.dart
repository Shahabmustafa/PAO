import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/reports/data/model/report_model.dart';
import 'package:pao/features/reports/domain/report_type.dart';
import 'package:pao/features/reports/presentation/provider/report_provider.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeReportRepository reports;
  late FakeAuthRepository auth;
  late ReportProvider provider;

  setUp(() {
    reports = FakeReportRepository();
    auth = FakeAuthRepository(
      user: const UserModel(id: 'u1', email: 'me@example.com'),
    );
    provider = ReportProvider(repository: reports, authRepository: auth);
  });

  test('starts on bug reports and can switch type', () {
    expect(provider.type, ReportType.bug);
    provider.selectType(ReportType.feature);
    expect(provider.type, ReportType.feature);
  });

  test('loadReports fills the list', () async {
    reports.existing = [
      ReportModel(
        id: 'r1',
        userId: 'u1',
        type: ReportType.feature,
        title: 'Dark map',
        description: 'Please add a dark map',
        status: ReportStatus.inProgress,
        createdAt: DateTime(2026, 9, 1),
      ),
    ];
    await provider.loadReports();
    expect(provider.isLoadingReports, isFalse);
    expect(provider.reports.single.title, 'Dark map');
    expect(provider.loadError, isNull);
  });

  test('loadReports records an error instead of throwing', () async {
    reports.fetchError = Exception('offline');
    await provider.loadReports();
    expect(provider.isLoadingReports, isFalse);
    expect(provider.loadError, isNotNull);
  });

  test('submit sends the selected type, trimmed, and adds it on top', () async {
    provider.selectType(ReportType.feature);
    final ok = await provider.submit(
      title: '  Filter by distance ',
      description: ' Show nearby items first ',
    );
    expect(ok, isTrue);
    final call = reports.submitCalls.single;
    expect(call.userId, 'u1');
    expect(call.type, ReportType.feature);
    expect(call.title, 'Filter by distance');
    expect(call.description, 'Show nearby items first');
    expect(provider.reports.first.title, 'Filter by distance');
    expect(provider.isSubmitting, isFalse);
  });

  test('submit fails with a message when signed out', () async {
    auth.user = null;
    final ok = await provider.submit(title: 'x', description: 'long enough');
    expect(ok, isFalse);
    expect(provider.errorMessage, isNotNull);
    expect(reports.submitCalls, isEmpty);
  });

  test('submit reports a failure from the server', () async {
    reports.submitError = Exception('rls');
    final ok = await provider.submit(title: 'x', description: 'long enough');
    expect(ok, isFalse);
    expect(provider.errorMessage, isNotNull);
    expect(provider.reports, isEmpty);
  });

  test('unknown database values fall back safely', () {
    expect(ReportType.fromDb('something-new'), ReportType.bug);
    expect(ReportStatus.fromDb(null), ReportStatus.open);
    expect(ReportStatus.fromDb('in_progress'), ReportStatus.inProgress);
  });
}
