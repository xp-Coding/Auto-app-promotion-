import 'dart:convert';

class CampaignModel {
  final String id;
  final String appId;
  final String name;
  final String objective;
  final String? targetAudience;
  final String? targetCountry;
  final String? language;
  final String? startDate;
  final String? endDate;
  final String status; // draft, active, paused, completed, cancelled
  final String? postingFrequency;
  final List<String> platforms;
  final List<String> contentThemes;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CampaignModel({
    required this.id,
    required this.appId,
    required this.name,
    required this.objective,
    this.targetAudience,
    this.targetCountry,
    this.language,
    this.startDate,
    this.endDate,
    this.status = 'draft',
    this.postingFrequency,
    this.platforms = const ['YouTube', 'TikTok', 'Instagram'],
    this.contentThemes = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  CampaignModel copyWith({
    String? id,
    String? appId,
    String? name,
    String? objective,
    String? targetAudience,
    String? targetCountry,
    String? language,
    String? startDate,
    String? endDate,
    String? status,
    String? postingFrequency,
    List<String>? platforms,
    List<String>? contentThemes,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CampaignModel(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      name: name ?? this.name,
      objective: objective ?? this.objective,
      targetAudience: targetAudience ?? this.targetAudience,
      targetCountry: targetCountry ?? this.targetCountry,
      language: language ?? this.language,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      postingFrequency: postingFrequency ?? this.postingFrequency,
      platforms: platforms ?? this.platforms,
      contentThemes: contentThemes ?? this.contentThemes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'app_id': appId,
      'name': name,
      'objective': objective,
      'target_audience': targetAudience,
      'target_country': targetCountry,
      'language': language,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'posting_frequency': postingFrequency,
      'content_themes': jsonEncode(contentThemes),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CampaignModel.fromMap(Map<String, dynamic> map, {List<String> platforms = const []}) {
    List<String> parseThemes(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(val.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      return [];
    }

    return CampaignModel(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      name: map['name'] as String,
      objective: map['objective'] as String,
      targetAudience: map['target_audience'] as String?,
      targetCountry: map['target_country'] as String?,
      language: map['language'] as String?,
      startDate: map['start_date'] as String?,
      endDate: map['end_date'] as String?,
      status: map['status'] as String? ?? 'draft',
      postingFrequency: map['posting_frequency'] as String?,
      platforms: platforms,
      contentThemes: parseThemes(map['content_themes']),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
