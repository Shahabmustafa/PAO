import '../../domain/report_type.dart';

class ReportModel {
  const ReportModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.platform,
  });

  final String id;
  final String userId;
  final ReportType type;
  final String title;
  final String description;
  final ReportStatus status;
  final String? platform;
  final DateTime createdAt;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: ReportType.fromDb(json['type'] as String?),
      title: json['title'] as String,
      description: json['description'] as String,
      status: ReportStatus.fromDb(json['status'] as String?),
      platform: json['platform'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
