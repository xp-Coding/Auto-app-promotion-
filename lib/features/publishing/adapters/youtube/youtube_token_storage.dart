import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../core/database/app_database.dart';

class YouTubeCredentials {
  final String clientId;
  final String clientSecret;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  const YouTubeCredentials({
    required this.clientId,
    required this.clientSecret,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  bool get hasValidToken {
    if (accessToken == null || accessToken!.isEmpty) return false;
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(DateTime.now().toUtc());
  }

  bool get needsRefresh {
    if (accessToken == null || accessToken!.isEmpty) return true;
    if (expiresAt == null) return false;
    // Refresh 5 minutes before actual expiration
    return DateTime.now().toUtc().isAfter(expiresAt!.subtract(const Duration(minutes: 5)));
  }

  YouTubeCredentials copyWith({
    String? clientId,
    String? clientSecret,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return YouTubeCredentials(
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

/// Secure storage for YouTube OAuth credentials using application_settings with local obfuscation
class YouTubeTokenStorage {
  final Database? _db;
  static const String _settingKey = 'auth_youtube_credentials';
  static const int _xorMask = 0x5A; // Obfuscation mask for local storage

  YouTubeTokenStorage([this._db]);

  Future<Database> get _database async => _db ?? await AppDatabase.instance.database;

  /// Simple reversible obfuscation preventing plaintext token exposure in raw database dumps
  String _obfuscate(String plaintext) {
    final bytes = utf8.encode(plaintext);
    final obfuscated = bytes.map((b) => b ^ _xorMask).toList();
    return base64Encode(obfuscated);
  }

  String _deobfuscate(String encoded) {
    try {
      final bytes = base64Decode(encoded);
      final deobfuscated = bytes.map((b) => b ^ _xorMask).toList();
      return utf8.decode(deobfuscated);
    } catch (_) {
      return '';
    }
  }

  Future<void> saveCredentials(YouTubeCredentials credentials) async {
    final db = await _database;
    final map = {
      'client_id': credentials.clientId,
      'client_secret': credentials.clientSecret,
      'access_token': credentials.accessToken,
      'refresh_token': credentials.refreshToken,
      'expires_at': credentials.expiresAt?.toIso8601String(),
    };

    final rawJson = jsonEncode(map);
    final obfuscated = _obfuscate(rawJson);

    await db.insert(
      'application_settings',
      {
        'key': _settingKey,
        'value': obfuscated,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<YouTubeCredentials?> getCredentials() async {
    final db = await _database;
    final maps = await db.query(
      'application_settings',
      where: 'key = ?',
      whereArgs: [_settingKey],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    final obfuscated = maps.first['value'] as String?;
    if (obfuscated == null || obfuscated.isEmpty) return null;

    final decodedJson = _deobfuscate(obfuscated);
    if (decodedJson.isEmpty) return null;

    try {
      final map = jsonDecode(decodedJson) as Map<String, dynamic>;
      return YouTubeCredentials(
        clientId: map['client_id'] as String? ?? '',
        clientSecret: map['client_secret'] as String? ?? '',
        accessToken: map['access_token'] as String?,
        refreshToken: map['refresh_token'] as String?,
        expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at'] as String) : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
    required DateTime expiresAt,
  }) async {
    final existing = await getCredentials();
    if (existing == null) return;

    final updated = existing.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken ?? existing.refreshToken,
      expiresAt: expiresAt,
    );

    await saveCredentials(updated);
  }

  Future<void> clearCredentials() async {
    final db = await _database;
    await db.delete(
      'application_settings',
      where: 'key = ?',
      whereArgs: [_settingKey],
    );
  }
}
