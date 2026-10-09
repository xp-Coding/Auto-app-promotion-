import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'activity_log_model.dart';
import 'activity_log_repository.dart';

class AppLogger {
  static final ActivityLogRepository _repo = ActivityLogRepository();
  static const Uuid _uuid = Uuid();

  /// Sanitizes messages and maps to prevent secret leakage in logs
  static String _sanitize(String text) {
    var sanitized = text;
    // Redact OAuth Bearer tokens
    sanitized = sanitized.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false), 'Bearer [REDACTED]');
    // Redact Google OAuth secrets
    sanitized = sanitized.replaceAll(RegExp(r'GOCSPX-[A-Za-z0-9\-_]+'), 'GOCSPX-[REDACTED]');
    // Redact generic refresh tokens
    sanitized = sanitized.replaceAll(RegExp(r'1//[A-Za-z0-9\-_]+'), '1//[REDACTED]');
    return sanitized;
  }

  static Map<String, dynamic>? _sanitizeDetails(Map<String, dynamic>? details) {
    if (details == null) return null;
    final sanitized = <String, dynamic>{};
    for (final entry in details.entries) {
      final k = entry.key.toLowerCase();
      if (k.contains('secret') || k.contains('token') || k.contains('password') || k.contains('authorization')) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (entry.value is String) {
        sanitized[entry.key] = _sanitize(entry.value as String);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  static Future<void> log({
    required String level,
    required String category,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    final cleanMessage = _sanitize(message);
    final cleanDetails = _sanitizeDetails(details);

    if (kDebugMode) {
      debugPrint('[$level][$category] $cleanMessage');
    }

    try {
      final entry = ActivityLogModel(
        id: _uuid.v4(),
        level: level.toLowerCase(),
        category: category.toLowerCase(),
        message: cleanMessage,
        details: cleanDetails,
        timestamp: DateTime.now().toUtc(),
      );
      await _repo.addLog(entry);
    } catch (_) {
      // Never crash on logging failures
    }
  }

  static Future<void> info(String category, String message, [Map<String, dynamic>? details]) {
    return log(level: 'info', category: category, message: message, details: details);
  }

  static Future<void> success(String category, String message, [Map<String, dynamic>? details]) {
    return log(level: 'success', category: category, message: message, details: details);
  }

  static Future<void> warn(String category, String message, [Map<String, dynamic>? details]) {
    return log(level: 'warn', category: category, message: message, details: details);
  }

  static Future<void> error(String category, String message, [Map<String, dynamic>? details]) {
    return log(level: 'error', category: category, message: message, details: details);
  }
}
