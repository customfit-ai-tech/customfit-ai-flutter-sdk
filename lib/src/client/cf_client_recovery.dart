// lib/src/client/cf_client_recovery.dart
//
// Recovery component for CFClient that handles system health checks and recovery operations.
// This component encapsulates all recovery logic to keep the main CFClient class focused on its core API.

import 'dart:async';
import '../core/error/cf_result.dart';
import '../core/error/error_category.dart';
import '../core/error/recovery_managers.dart';
import '../core/session/session_manager.dart';
import '../analytics/event/event_tracker.dart';
import '../client/managers/config_manager.dart';
import '../logging/logger.dart';

/// Recovery component that handles system health checks and recovery operations
class CFClientRecovery {
  static const _source = 'CFClientRecovery';

  final SessionManager? Function() _getSessionManager;
  final EventTracker Function() _getEventTracker;
  final ConfigManager Function() _getConfigManager;
  final String Function() _getCurrentSessionId;

  CFClientRecovery({
    required SessionManager? Function() getSessionManager,
    required EventTracker Function() getEventTracker,
    required ConfigManager Function() getConfigManager,
    required String Function() getCurrentSessionId,
  })  : _getSessionManager = getSessionManager,
        _getEventTracker = getEventTracker,
        _getConfigManager = getConfigManager,
        _getCurrentSessionId = getCurrentSessionId;

  /// Perform comprehensive system health check and recovery
  Future<CFResult<SystemHealthStatus>> performSystemHealthCheck() async {
    try {
      Logger.i('🔍 Performing comprehensive system health check');

      final sessionManager = _getSessionManager();
      if (sessionManager == null) {
        return CFResult.error(
          'System health check failed: SessionManager not initialized',
          category: ErrorCategory.session,
        );
      }

      // Perform all health checks in parallel
      final futures = await Future.wait([
        SessionRecoveryManager.performSessionHealthCheck(sessionManager),
        ConfigRecoveryManager.performConfigHealthCheck(_getConfigManager()),
        EventRecoveryManager.getRecoveryStats(),
      ]);

      final sessionHealth = futures[0] as CFResult<SessionHealthStatus>;
      final configHealth = futures[1] as CFResult<ConfigHealthStatus>;
      final eventStats = futures[2] as EventRecoveryStats;

      // Determine overall system health
      var overallStatus = SystemOverallStatus.healthy;
      final issues = <String>[];

      if (!sessionHealth.isSuccess ||
          sessionHealth.getOrNull() != SessionHealthStatus.healthy) {
        overallStatus = SystemOverallStatus.degraded;
        issues.add('Session issues detected');
      }

      if (!configHealth.isSuccess ||
          configHealth.getOrNull() != ConfigHealthStatus.healthy) {
        overallStatus = SystemOverallStatus.degraded;
        issues.add('Configuration issues detected');
      }

      if (eventStats.failedEventsCount > 50 ||
          eventStats.offlineEventsCount > 100) {
        overallStatus = SystemOverallStatus.degraded;
        issues.add('High number of failed/offline events');
      }

      final systemStatus = SystemHealthStatus(
        overallStatus: overallStatus,
        sessionHealth:
            sessionHealth.getOrNull() ?? SessionHealthStatus.unhealthy,
        configHealth: configHealth.getOrNull() ?? ConfigHealthStatus.invalid,
        eventRecoveryStats: eventStats,
        issues: issues,
        timestamp: DateTime.now(),
      );

      Logger.i(
          '🔍 System health check completed: ${systemStatus.overallStatus}');
      return CFResult.success(systemStatus);
    } catch (e) {
      Logger.e('🔍 System health check failed: $e');
      return CFResult.error(
        'System health check failed',
        exception: e is Exception ? e : Exception(e.toString()),
        category: ErrorCategory.internal,
      );
    }
  }

  /// Recover from session-related errors
  Future<CFResult<String>> recoverSession({
    String? reason,
    Future<String?> Function()? authTokenRefreshCallback,
  }) async {
    try {
      Logger.i(
          '🔄 Initiating session recovery${reason != null ? ': $reason' : ''}');

      final sessionManager = _getSessionManager();
      if (sessionManager == null) {
        return CFResult.error(
          'Session recovery failed: SessionManager not initialized',
          category: ErrorCategory.session,
        );
      }

      // Determine recovery strategy based on reason
      CFResult<String> result;

      switch (reason) {
        case 'session_timeout':
        case 'inactivity_timeout':
          result = await SessionRecoveryManager.recoverFromSessionTimeout(
              sessionManager,
              reason: reason ?? 'session_timeout');
          break;
        case 'session_invalidated':
          result = await SessionRecoveryManager.recoverFromSessionInvalidation(
              sessionManager);
          break;
        case 'session_corrupted':
          result = await SessionRecoveryManager.recoverFromSessionCorruption(
              sessionManager);
          break;
        case 'auth_failure':
          if (authTokenRefreshCallback != null) {
            final authResult =
                await SessionRecoveryManager.recoverFromAuthFailure(
              tokenRefreshCallback: authTokenRefreshCallback,
            );
            if (authResult.isSuccess) {
              // After auth recovery, get the current session
              result = CFResult.success(_getCurrentSessionId());
            } else {
              result = CFResult.error(
                  authResult.getErrorMessage() ??
                      'Authentication recovery failed',
                  category: ErrorCategory.authentication);
            }
          } else {
            result = CFResult.error(
              'Authentication recovery failed: no token refresh callback provided',
              category: ErrorCategory.authentication,
            );
          }
          break;
        default:
          // Generic session recovery
          result = await SessionRecoveryManager.recoverFromSessionTimeout(
              sessionManager,
              reason: reason ?? 'generic_recovery');
      }

      if (result.isSuccess) {
        Logger.i('🔄 Session recovery completed successfully');
      } else {
        Logger.e('🔄 Session recovery failed: ${result.getErrorMessage()}');
      }

      return result;
    } catch (e) {
      Logger.e('🔄 Session recovery error: $e');
      return CFResult.error(
        'Session recovery failed',
        exception: e is Exception ? e : Exception(e.toString()),
        category: ErrorCategory.session,
      );
    }
  }

  /// Recover failed events and retry offline events
  Future<CFResult<EventRecoveryResult>> recoverEvents({
    int maxEventsToRetry = 50,
  }) async {
    try {
      Logger.i('📧 Starting event recovery process');

      final eventTracker = _getEventTracker();

      // Recover offline events first
      final offlineRecoveryResult =
          await EventRecoveryManager.recoverOfflineEvents(eventTracker);
      final offlineRecovered = offlineRecoveryResult.getOrNull() ?? 0;

      // Then retry failed events
      final failedRetryResult = await EventRecoveryManager.retryFailedEvents(
        eventTracker,
        maxEventsToRetry: maxEventsToRetry,
      );
      final failedRetried = failedRetryResult.getOrNull() ?? 0;

      // Clean up old failed events
      final cleanupResult = await EventRecoveryManager.cleanupOldFailedEvents();
      final cleanedUp = cleanupResult.getOrNull() ?? 0;

      final result = EventRecoveryResult(
        offlineEventsRecovered: offlineRecovered,
        failedEventsRetried: failedRetried,
        oldEventsCleanedUp: cleanedUp,
        timestamp: DateTime.now(),
      );

      Logger.i('📧 Event recovery completed: $result');
      return CFResult.success(result);
    } catch (e) {
      Logger.e('📧 Event recovery failed: $e');
      return CFResult.error(
        'Event recovery failed',
        exception: e is Exception ? e : Exception(e.toString()),
        category: ErrorCategory.analytics,
      );
    }
  }

  /// Perform safe configuration update with automatic rollback on failure
  Future<CFResult<bool>> safeConfigUpdate(
    Map<String, dynamic> newConfig, {
    Duration validationTimeout = const Duration(seconds: 30),
  }) async {
    try {
      Logger.i('⚙️ Starting safe configuration update');

      final result = await ConfigRecoveryManager.safeConfigUpdate(
        _getConfigManager(),
        newConfig,
        validationTimeout: validationTimeout,
      );

      if (result.isSuccess) {
        Logger.i('⚙️ Safe configuration update completed successfully');
      } else {
        Logger.e(
            '⚙️ Safe configuration update failed: ${result.getErrorMessage()}');
      }

      return result;
    } catch (e) {
      Logger.e('⚙️ Safe configuration update error: $e');
      return CFResult.error(
        'Safe configuration update failed',
        exception: e is Exception ? e : Exception(e.toString()),
        category: ErrorCategory.configuration,
      );
    }
  }

  /// Recover from configuration corruption or update failures
  Future<CFResult<Map<String, dynamic>>> recoverConfiguration() async {
    try {
      Logger.i('⚙️ Starting configuration recovery');

      final result = await ConfigRecoveryManager.recoverFromConfigCorruption(
          _getConfigManager());

      if (result.isSuccess) {
        Logger.i('⚙️ Configuration recovery completed successfully');
      } else {
        Logger.e(
            '⚙️ Configuration recovery failed: ${result.getErrorMessage()}');
      }

      return result;
    } catch (e) {
      Logger.e('⚙️ Configuration recovery error: $e');
      return CFResult.error(
        'Configuration recovery failed',
        exception: e is Exception ? e : Exception(e.toString()),
        category: ErrorCategory.configuration,
      );
    }
  }

  /// Perform automatic recovery based on current system state
  Future<CFResult<List<String>>> performAutoRecovery() async {
    try {
      Logger.i('🤖 Starting automatic recovery process');

      final healthCheck = await performSystemHealthCheck();
      if (!healthCheck.isSuccess) {
        return CFResult.error(
          'Auto recovery failed: health check failed',
          category: ErrorCategory.internal,
        );
      }

      final systemHealth = healthCheck.getOrNull()!;
      final recoveryActions = <String>[];

      // Perform recovery actions based on health status
      if (systemHealth.sessionHealth != SessionHealthStatus.healthy) {
        Logger.i('🤖 Performing session recovery');
        final sessionRecovery = await recoverSession(reason: 'auto_recovery');
        if (sessionRecovery.isSuccess) {
          recoveryActions.add('session_recovery');
        }
      }

      if (systemHealth.configHealth != ConfigHealthStatus.healthy) {
        Logger.i('🤖 Performing configuration recovery');
        final configRecovery = await recoverConfiguration();
        if (configRecovery.isSuccess) {
          recoveryActions.add('config_recovery');
        }
      }

      if (systemHealth.eventRecoveryStats.failedEventsCount > 0 ||
          systemHealth.eventRecoveryStats.offlineEventsCount > 0) {
        Logger.i('🤖 Performing event recovery');
        final eventRecovery = await recoverEvents();
        if (eventRecovery.isSuccess) {
          recoveryActions.add('event_recovery');
        }
      }

      Logger.i(
          '🤖 Automatic recovery completed: ${recoveryActions.length} actions performed');
      return CFResult.success(recoveryActions);
    } catch (e) {
      Logger.e('🤖 Automatic recovery failed: $e');
      return CFResult.error(
        'Automatic recovery failed',
        exception: e is Exception ? e : Exception(e.toString()),
        category: ErrorCategory.internal,
      );
    }
  }
}

// MARK: - Error Recovery Data Structures

/// Overall system health status
enum SystemOverallStatus {
  healthy,
  degraded,
  critical,
}

/// Comprehensive system health status
class SystemHealthStatus {
  final SystemOverallStatus overallStatus;
  final SessionHealthStatus sessionHealth;
  final ConfigHealthStatus configHealth;
  final EventRecoveryStats eventRecoveryStats;
  final List<String> issues;
  final DateTime timestamp;

  SystemHealthStatus({
    required this.overallStatus,
    required this.sessionHealth,
    required this.configHealth,
    required this.eventRecoveryStats,
    required this.issues,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'SystemHealthStatus(overall: $overallStatus, session: $sessionHealth, '
        'config: $configHealth, issues: ${issues.length}, timestamp: $timestamp)';
  }
}

/// Result of event recovery operations
class EventRecoveryResult {
  final int offlineEventsRecovered;
  final int failedEventsRetried;
  final int oldEventsCleanedUp;
  final DateTime timestamp;

  EventRecoveryResult({
    required this.offlineEventsRecovered,
    required this.failedEventsRetried,
    required this.oldEventsCleanedUp,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'EventRecoveryResult(offline: $offlineEventsRecovered, '
        'retried: $failedEventsRetried, cleaned: $oldEventsCleanedUp)';
  }
}
