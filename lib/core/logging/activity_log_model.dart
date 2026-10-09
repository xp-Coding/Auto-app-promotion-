import 'dart:convert';

class ActivityLogModel {
  final String id;
  final String level; // info, warn, error, success
  final String category; // publishing, auth, analytics, database, system
  final String message;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  const ActivityLogModel({
    required this.id,
    required this.level,
    required this.category,
    required this.message,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level': level,
      'category': category,
      'message': message,
      'details_json': details != null ? jsonEncode(details) : null,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityLogModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? detailsMap;
    if (map['details_json'] != null) {
      try {
        final decoded = jsonDecode(map['details_json'] as String);
        if (decoded is Map<String, dynamic>) detailsMap = decoded;
      } catch (_) {}
    }

    return ActivityLogModel(
      id: map['id'] as String,
      level: map['level'] as String,
      category: map['category'] as String,
      message: map['message'] as String,
      details: detailsMap,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
