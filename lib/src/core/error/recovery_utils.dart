import 'dart:async';
import 'dart:convert';
import '../../logging/logger.dart';
import '../util/cache_manager.dart';
import 'cf_result.dart';
import 'error_category.dart';

/// Shared utilities for recovery operations to eliminate code duplication
class RecoveryUtils {
  /// Generic cache getter with error handling
  static Future<List<Map<String, dynamic>>> getCachedList(
    String key,
    String source,
  ) async {
    try {
      final data = await CacheManager.instance.get<String>(key);
      if (data == null) return [];

      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.e('$source: Failed to get cached list for $key: $e');
      return [];
    }
  }

  /// Generic cache setter with error handling
  static Future<void> setCachedList(
    String key,
    List<Map<String, dynamic>> data,
    String source,
  ) async {
    try {
      await CacheManager.instance.put(key, jsonEncode(data));
    } catch (e) {
      Logger.e('$source: Failed to save cached list for $key: $e');
    }
  }

  /// Generic cache remover with error handling
  static Future<void> removeCached(
    String key,
    String source,
  ) async {
    try {
      await CacheManager.instance.remove(key);
    } catch (e) {
      Logger.e('$source: Failed to remove cached data for $key: $e');
    }
  }

  /// Generic cache getter for single objects
  static Future<Map<String, dynamic>?> getCachedObject(
    String key,
    String source,
  ) async {
    try {
      final data = await CacheManager.instance.get<String>(key);
      if (data == null) return null;

      final Map<String, dynamic> object = jsonDecode(data);
      return object;
    } catch (e) {
      Logger.e('$source: Failed to get cached object for $key: $e');
      return null;
    }
  }

  /// Generic cache setter for single objects
  static Future<void> setCachedObject(
    String key,
    Map<String, dynamic> data,
    String source,
  ) async {
    try {
      await CacheManager.instance.put(key, jsonEncode(data));
    } catch (e) {
      Logger.e('$source: Failed to save cached object for $key: $e');
    }
  }

  /// Standard error result creation
  static CFResult<T> createErrorResult<T>(
    String message,
    String source,
    ErrorCategory category, {
    dynamic exception,
  }) {
    Logger.e('$source: $message');
    return CFResult.error(
      message,
      exception:
          exception is Exception ? exception : Exception(exception.toString()),
      category: category,
    );
  }

  /// Get oldest timestamp from event list
  static DateTime? getOldestTimestamp(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return null;

    int? oldestTimestamp;
    for (final event in events) {
      final timestamp = event['timestamp'] as int?;
      if (timestamp != null) {
        if (oldestTimestamp == null || timestamp < oldestTimestamp) {
          oldestTimestamp = timestamp;
        }
      }
    }

    return oldestTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(oldestTimestamp)
        : null;
  }
}

/// Consolidated exception classes for all recovery operations
class RecoveryException implements Exception {
  final String message;
  final String type;

  RecoveryException(this.message, this.type);

  @override
  String toString() => '$type: $message';
}

/// Network-related recovery exceptions
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Network unavailable exception
class NetworkUnavailableException implements Exception {
  final String message;
  NetworkUnavailableException(this.message);

  @override
  String toString() => 'NetworkUnavailableException: $message';
}

/// Session recovery exceptions
class SessionRecoveryException extends RecoveryException {
  SessionRecoveryException(String message)
      : super(message, 'SessionRecoveryException');
}

/// Authentication recovery exceptions
class AuthRecoveryException extends RecoveryException {
  AuthRecoveryException(String message)
      : super(message, 'AuthRecoveryException');
}

/// Configuration recovery exceptions
class ConfigRecoveryException extends RecoveryException {
  ConfigRecoveryException(String message)
      : super(message, 'ConfigRecoveryException');
}

/// Configuration validation exceptions
class ConfigValidationException extends RecoveryException {
  ConfigValidationException(String message)
      : super(message, 'ConfigValidationException');
}

/// Configuration application exceptions
class ConfigApplicationException extends RecoveryException {
  ConfigApplicationException(String message)
      : super(message, 'ConfigApplicationException');
}
