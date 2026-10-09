class MetricSnapshotModel {
  final String id;
  final String appId;
  final String platform; // youtube, tiktok, facebook, instagram
  final String metricName; // views, likes, comments, shares, clicks, installs
  final double metricValue;
  final String metricType; // views, likes, comments, shares, clicks, installs
  final DateTime measuredAt;
  final String? period; // daily, weekly, monthly, all_time
  final String? sourceRecordId; // e.g. youtube video id
  final bool isEstimated; // false = measured via API, true = statistical/benchmark model

  const MetricSnapshotModel({
    required this.id,
    required this.appId,
    required this.platform,
    required this.metricName,
    required this.metricValue,
    required this.metricType,
    required this.measuredAt,
    this.period = 'all_time',
    this.sourceRecordId,
    this.isEstimated = false,
  });

  bool get isMeasured => !isEstimated;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'app_id': appId,
      'platform': platform,
      'metric_name': metricName,
      'metric_value': metricValue,
      'metric_type': metricType,
      'measured_at': measuredAt.toIso8601String(),
      'period': period,
      'source_record_id': sourceRecordId,
      'is_estimated': isEstimated ? 1 : 0,
    };
  }

  factory MetricSnapshotModel.fromMap(Map<String, dynamic> map) {
    return MetricSnapshotModel(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      platform: map['platform'] as String,
      metricName: map['metric_name'] as String,
      metricValue: (map['metric_value'] as num).toDouble(),
      metricType: map['metric_type'] as String,
      measuredAt: DateTime.parse(map['measured_at'] as String),
      period: map['period'] as String?,
      sourceRecordId: map['source_record_id'] as String?,
      isEstimated: (map['is_estimated'] as num?) == 1,
    );
  }
}
