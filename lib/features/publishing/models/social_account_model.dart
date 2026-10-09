import 'dart:convert';

class SocialAccountModel {
  final String id;
  final String platform; // youtube, facebook, instagram, tiktok
  final String accountName;
  final String accountId;
  final String? profilePictureUrl;
  final String status; // connected, disconnected, expired, restricted
  final DateTime connectedAt;
  final DateTime? lastSyncedAt;
  final List<String> capabilities;
  final Map<String, dynamic> metadata;

  const SocialAccountModel({
    required this.id,
    required this.platform,
    required this.accountName,
    required this.accountId,
    this.profilePictureUrl,
    required this.status,
    required this.connectedAt,
    this.lastSyncedAt,
    this.capabilities = const [],
    this.metadata = const {},
  });

  bool get isConnected => status == 'connected';
  bool get isExpired => status == 'expired';

  SocialAccountModel copyWith({
    String? id,
    String? platform,
    String? accountName,
    String? accountId,
    String? profilePictureUrl,
    String? status,
    DateTime? connectedAt,
    DateTime? lastSyncedAt,
    List<String>? capabilities,
    Map<String, dynamic>? metadata,
  }) {
    return SocialAccountModel(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      accountName: accountName ?? this.accountName,
      accountId: accountId ?? this.accountId,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      status: status ?? this.status,
      connectedAt: connectedAt ?? this.connectedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      capabilities: capabilities ?? this.capabilities,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'platform': platform,
      'account_name': accountName,
      'account_id': accountId,
      'profile_picture_url': profilePictureUrl,
      'status': status,
      'connected_at': connectedAt.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'capabilities': jsonEncode(capabilities),
      'metadata_json': jsonEncode(metadata),
    };
  }

  factory SocialAccountModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedCapabilities = [];
    if (map['capabilities'] != null) {
      try {
        final decoded = jsonDecode(map['capabilities'] as String);
        if (decoded is List) {
          parsedCapabilities = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    Map<String, dynamic> parsedMetadata = {};
    if (map['metadata_json'] != null) {
      try {
        final decoded = jsonDecode(map['metadata_json'] as String);
        if (decoded is Map<String, dynamic>) {
          parsedMetadata = decoded;
        }
      } catch (_) {}
    }

    return SocialAccountModel(
      id: map['id'] as String,
      platform: map['platform'] as String,
      accountName: map['account_name'] as String,
      accountId: map['account_id'] as String,
      profilePictureUrl: map['profile_picture_url'] as String?,
      status: map['status'] as String? ?? 'connected',
      connectedAt: DateTime.parse(map['connected_at'] as String),
      lastSyncedAt: map['last_synced_at'] != null ? DateTime.parse(map['last_synced_at'] as String) : null,
      capabilities: parsedCapabilities,
      metadata: parsedMetadata,
    );
  }
}
