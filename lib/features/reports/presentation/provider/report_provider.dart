import 'package:flutter/foundation.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../data/model/report_model.dart';
import '../../data/repository/report_repository.dart';
import '../../domain/report_type.dart';
import '../../../../core/l10n/l10n.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider({ReportRepository? repository, AuthRepository? authRepository})
    : _repository = repository ?? ReportRepository(),
      _authRepository = authRepository ?? AuthRepository();

  final ReportRepository _repository;
  final AuthRepository _authRepository;

  ReportType type = ReportType.bug;
  List<ReportModel> reports = [];
  bool isLoadingReports = true;
  bool isSubmitting = false;
  String? loadError;
  String? errorMessage;

  void selectType(ReportType value) {
    if (value == type) return;
    type = value;
    notifyListeners();
  }

  Future<void> loadReports() async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      isLoadingReports = false;
      notifyListeners();
      return;
    }
    try {
      reports = await _repository.fetchForUser(userId);
      loadError = null;
    } catch (_) {
      loadError = l10nNow.failedToLoadReports;
    }
    isLoadingReports = false;
    notifyListeners();
  }

  /// Sends the current [type] of report. On success the new report goes to
  /// the top of [reports] and true is returned; otherwise [errorMessage]
  /// says why.
  Future<bool> submit({
    required String title,
    required String description,
  }) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      errorMessage = l10nNow.mustBeLoggedInReport;
      notifyListeners();
      return false;
    }

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final report = await _repository.submit(
        userId: userId,
        type: type,
        title: title.trim(),
        description: description.trim(),
        platform: defaultTargetPlatform.name,
      );
      reports = [report, ...reports];
      return true;
    } catch (_) {
      errorMessage = l10nNow.failedToSubmitReport;
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
