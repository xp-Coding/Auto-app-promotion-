class PublishedPostModel {
  final String id;
  final String postId;
  final String platform;
  final String? remoteId;
  final String? remoteUrl;
  final DateTime publishedAt;
  final String status; // active, processing, removed, flagged

  const PublishedPostModel({
    required this.id,
    required this.postId,
    required this.platform,
    this.remoteId,
    this.remoteUrl,
    required this.publishedAt,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'platform': platform,
      'remote_id': remoteId,
      'remote_url': remoteUrl,
      'published_at': publishedAt.toIso8601String(),
      'status': status,
    };
  }

  factory PublishedPostModel.fromMap(Map<String, dynamic> map) {
    return PublishedPostModel(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      platform: map['platform'] as String,
      remoteId: map['remote_id'] as String?,
      remoteUrl: map['remote_url'] as String?,
      publishedAt: DateTime.parse(map['published_at'] as String),
      status: map['status'] as String? ?? 'active',
    );
  }
}
