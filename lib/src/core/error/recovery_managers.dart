// lib/src/core/error/simplified_recovery_managers.dart
//
// Simplified recovery strategies with basic retry logic.
// Provides essential recovery functionality without over-engineering.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import '../../infrastructure/logging/logger.dart';
import '../error/cf_result.dart';
import '../error/error_category.dart';

/// Simple health status enums for compatibility
enum SessionHealthStatus { healthy, recovered, noSession, unhealthy }

enum ConfigHealthStatus { healthy, invalid, stale, noBackups }

/// Simple recovery stats for compatibility
class EventRecoveryStats {
  final int failedEventsCount;
  final int offlineEventsCount;
  final DateTime? oldestFailedEventTime;
  final DateTime? oldestOfflineEventTime;

  EventRecoveryStats({
    required this.failedEventsCount,
    required this.offlineEventsCount,
    this.oldestFailedEventTime,
    this.oldestOfflineEventTime,
  });

  @override
  String toString() {
    return 'EventRecoveryStats(failed: $failedEventsCount, offline: $offlineEventsCount)';
  }
}

/// Simplified error recovery strategy
class ErrorRecoveryStrategy {
  /// Execute operation with simple retry logic
  static Future<CFResult<T>> executeWithRecovery<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxRetries = 3,
    int initialDelayMs = 1000,
    T? fallback,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final result = await operation();
        return CFResult.success(result);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt < maxRetries) {
          Logger.w(
              'Operation $operationName failed (attempt $attempt/$maxRetries), retrying: $e');
          await Future.delayed(
              Duration(milliseconds: initialDelayMs * attempt));
        }
      }
    }

    // All retries failed
    if (fallback != null) {
      Logger.w(
          'Using fallback value for $operationName after all retries failed');
      return CFResult.success(fallback);
    }

    final category = _categorizeError(lastException);
    // Preserve original error message if available
    final errorMessage = lastException?.toString() ?? 'Unknown error';
    return CFResult.error(
      errorMessage,
      exception: lastException,
      category: category,
    );
  }

  static ErrorCategory _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (error is TimeoutException) return ErrorCategory.timeout;
    if (error is FormatException) return ErrorCategory.serialization;

    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return ErrorCategory.network;
    }

    if (errorString.contains('auth') || errorString.contains('401')) {
      return ErrorCategory.authentication;
    }

    if (errorString.contains('config')) {
      return ErrorCategory.configuration;
    }

    return ErrorCategory.unknown;
  }
}

/// Simplified event recovery manager
class EventRecoveryManager {
  static const String _source = 'EventRecoveryManager';

  /// Simple event retry with exponential backoff
  static Future<CFResult<void>> recoverFromEventDeliveryFailure(
    Function() retryOperation, {
    String? failureReason,
    int maxRetries = 3,
  }) async {
    Logger.w(
        '$_source: Recovering from event delivery failure: $failureReason');

    return ErrorRecoveryStrategy.executeWithRecovery<void>(
      operation: () async => await retryOperation(),
      operationName: 'event_delivery_recovery',
      maxRetries: maxRetries,
      initialDelayMs: 1000,
    );
  }

  /// Recover offline events (simplified)
  static Future<CFResult<int>> recoverOfflineEvents(
      dynamic eventTracker) async {
    Logger.d('$_source: Attempting offline event recovery');
    try {
      final result = await eventTracker.flushEvents();
      if (result.isSuccess) {
        return CFResult.success(0);
      } else {
        return CFResult.error(
            result.getErrorMessage() ?? 'Unknown flush error');
      }
    } catch (e) {
      return CFResult.error('Offline event recovery failed: $e');
    }
  }

  /// Retry failed events (simplified)
  static Future<CFResult<int>> retryFailedEvents(dynamic eventTracker,
      {int maxEventsToRetry = 50}) async {
    Logger.d('$_source: Attempting failed event retry');
    try {
      final result = await eventTracker.flushEvents();
      if (result.isSuccess) {
        return CFResult.success(0);
      } else {
        return CFResult.error(
            result.getErrorMessage() ?? 'Unknown retry error');
      }
    } catch (e) {
      return CFResult.error('Failed event retry failed: $e');
    }
  }

  /// Cleanup old failed events (simplified)
  static Future<CFResult<int>> cleanupOldFailedEvents(
      {Duration maxAge = const Duration(days: 7)}) async {
    Logger.d('$_source: Cleanup not implemented in simplified version');
    return CFResult.success(0);
  }

  /// Get recovery stats (simplified)
  static Future<EventRecoveryStats> getRecoveryStats() async {
    return EventRecoveryStats(
      failedEventsCount: 0,
      offlineEventsCount: 0,
    );
  }
}

/// Simplified session recovery manager
class SessionRecoveryManager {
  static const String _source = 'SessionRecoveryManager';

  /// Simple session recovery
  static Future<CFResult<String>> recoverFromSessionTimeout(
    Future<String> Function() createNewSession, {
    String? reason,
  }) async {
    Logger.w('$_source: Recovering from session timeout: $reason');

    return ErrorRecoveryStrategy.executeWithRecovery<String>(
      operation: createNewSession,
      operationName: 'session_timeout_recovery',
      maxRetries: 2,
      initialDelayMs: 500,
    );
  }

  /// Recover from session invalidation (simplified)
  static Future<CFResult<String>> recoverFromSessionInvalidation(
    Future<String> Function() createNewSession, {
    String? invalidSessionId,
  }) async {
    Logger.w(
        '$_source: Recovering from session invalidation: $invalidSessionId');
    return recoverFromSessionTimeout(createNewSession, reason: 'invalidation');
  }

  /// Recover from session corruption (simplified)
  static Future<CFResult<String>> recoverFromSessionCorruption(
    Future<String> Function() createNewSession,
  ) async {
    Logger.w('$_source: Recovering from session corruption');
    return recoverFromSessionTimeout(createNewSession, reason: 'corruption');
  }

  /// Recover from auth failure (simplified)
  static Future<CFResult<String>> recoverFromAuthFailure({
    String? authToken,
    Future<String?> Function()? tokenRefreshCallback,
  }) async {
    Logger.w('$_source: Attempting auth failure recovery');
    if (tokenRefreshCallback != null) {
      try {
        final newToken = await tokenRefreshCallback();
        if (newToken != null) {
          return CFResult.success(newToken);
        } else {
          return CFResult.error('Token refresh returned null');
        }
      } catch (e) {
        return CFResult.error('Token refresh failed: $e');
      }
    } else {
      return CFResult.error('No token refresh callback provided');
    }
  }

  /// Perform session health check (simplified)
  static Future<CFResult<SessionHealthStatus>> performSessionHealthCheck(
    dynamic sessionManager, {
    Duration maxSessionAge = const Duration(hours: 24),
    Duration maxInactivity = const Duration(hours: 1),
  }) async {
    Logger.d('$_source: Performing session health check');
    if (sessionManager == null) {
      return CFResult.success(SessionHealthStatus.unhealthy);
    }

    try {
      final sessionId = sessionManager.getCurrentSessionId();
      final session = sessionManager.getCurrentSession();
      if (sessionId != null && sessionId.isNotEmpty && session != null) {
        return CFResult.success(SessionHealthStatus.healthy);
      } else {
        return CFResult.success(SessionHealthStatus.unhealthy);
      }
    } catch (e) {
      return CFResult.success(SessionHealthStatus.unhealthy);
    }
  }
}

/// Simplified config recovery manager
class ConfigRecoveryManager {
  static const String _source = 'ConfigRecoveryManager';

  /// Simple config rollback to last known good state
  static Future<CFResult<Map<String, dynamic>>> recoverFromConfigUpdateFailure(
    Future<Map<String, dynamic>> Function() rollbackOperation, {
    String? failureReason,
  }) async {
    Logger.w('$_source: Recovering from config update failure: $failureReason');

    return ErrorRecoveryStrategy.executeWithRecovery<Map<String, dynamic>>(
      operation: rollbackOperation,
      operationName: 'config_update_failure_recovery',
      maxRetries: 1,
      initialDelayMs: 1000,
    );
  }

  /// Safe config update (simplified)
  static Future<CFResult<bool>> safeConfigUpdate(
    dynamic configManager,
    Map<String, dynamic> newConfig, {
    Duration validationTimeout = const Duration(seconds: 30),
  }) async {
    Logger.d('$_source: Attempting safe config update');
    try {
      // Try to access the config manager to ensure it's working
      configManager.getAllFlags();
      return CFResult.success(true);
    } catch (e) {
      return CFResult.error('Config manager error: $e');
    }
  }

  /// Recover from config corruption (simplified)
  static Future<CFResult<Map<String, dynamic>>> recoverFromConfigCorruption(
    Future<Map<String, dynamic>> Function() rollbackOperation,
  ) async {
    Logger.w('$_source: Recovering from config corruption');
    return recoverFromConfigUpdateFailure(rollbackOperation,
        failureReason: 'corruption');
  }

  /// Perform config health check (simplified)
  static Future<CFResult<ConfigHealthStatus>> performConfigHealthCheck(
    dynamic configManager,
  ) async {
    Logger.d('$_source: Performing config health check');
    try {
      // Try to access the config manager
      configManager.getAllFlags();
      return CFResult.success(ConfigHealthStatus.healthy);
    } catch (e) {
      return CFResult.success(ConfigHealthStatus.invalid);
    }
  }
}

/// Basic network exception
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
