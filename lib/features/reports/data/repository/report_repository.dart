import '../../domain/report_type.dart';
import '../datasource/report_remote_datasource.dart';
import '../model/report_model.dart';

/// Bridges the report data source and the presentation layer.
class ReportRepository {
  ReportRepository({ReportRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? ReportRemoteDataSource();

  final ReportRemoteDataSource _dataSource;

  Future<List<ReportModel>> fetchForUser(String userId) async {
    final rows = await _dataSource.fetchForUser(userId);
    return rows.map(ReportModel.fromJson).toList();
  }

  Future<ReportModel> submit({
    required String userId,
    required ReportType type,
    required String title,
    required String description,
    String? platform,
  }) async {
    final row = await _dataSource.submit(
      userId: userId,
      type: type.dbValue,
      title: title,
      description: description,
      platform: platform,
    );
    return ReportModel.fromJson(row);
  }
}
