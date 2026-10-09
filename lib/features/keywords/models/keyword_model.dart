class KeywordModel {
  final String id;
  final String appId;
  final String keyword;
  final String? topicCluster;
  final String intent; // informational, commercial, navigational, transactional
  final double relevanceScore; // 0.0 to 100.0 qualitative score
  final String source; // manual, local_generator, imported_csv, youtube_public
  final String retrievalDate;
  final String? notes;
  final DateTime createdAt;

  const KeywordModel({
    required this.id,
    required this.appId,
    required this.keyword,
    this.topicCluster,
    this.intent = 'informational',
    this.relevanceScore = 50.0,
    required this.source,
    required this.retrievalDate,
    this.notes,
    required this.createdAt,
  });

  KeywordModel copyWith({
    String? id,
    String? appId,
    String? keyword,
    String? topicCluster,
    String? intent,
    double? relevanceScore,
    String? source,
    String? retrievalDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return KeywordModel(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      keyword: keyword ?? this.keyword,
      topicCluster: topicCluster ?? this.topicCluster,
      intent: intent ?? this.intent,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      source: source ?? this.source,
      retrievalDate: retrievalDate ?? this.retrievalDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'app_id': appId,
      'keyword': keyword,
      'topic_cluster': topicCluster,
      'intent': intent,
      'relevance_score': relevanceScore,
      'source': source,
      'retrieval_date': retrievalDate,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory KeywordModel.fromMap(Map<String, dynamic> map) {
    return KeywordModel(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      keyword: map['keyword'] as String,
      topicCluster: map['topic_cluster'] as String?,
      intent: map['intent'] as String? ?? 'informational',
      relevanceScore: (map['relevance_score'] as num? ?? 50.0).toDouble(),
      source: map['source'] as String? ?? 'manual',
      retrievalDate: map['retrieval_date'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
