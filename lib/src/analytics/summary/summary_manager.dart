// lib/src/analytics/summary/summary_manager.dart
//
// Manages collection and flushing of configuration request summaries.
// Tracks feature flag evaluations and API requests for analytics purposes,
// batching and transmitting summary data to the CustomFit backend.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:collection';
import '../../core/error/cf_result.dart';
import '../../core/error/error_category.dart';
import '../../core/error/error_handler.dart';
import '../../core/error/error_severity.dart';
import '../../infrastructure/logging/logger.dart';
import '../../core/model/cf_user.dart';
import '../../config/core/cf_config.dart';
import '../../infrastructure/utils/exponential_backoff.dart';

import 'cf_config_request_summary.dart';
import '../../infrastructure/types.dart';
import '../../infrastructure/network/models/summary_request.dart';
import '../../infrastructure/network/internal/request_deduplicator.dart';
import '../../constants/cf_constants.dart';
import '../../infrastructure/utils/type_conversion_strategy.dart';
import '../../utils/timestamp_util.dart';

// HttpClient imported from infrastructure/types.dart

/// Manages collection and flushing of configuration summaries, mirroring Kotlin's SummaryManager
class SummaryManager {
  static const _source = 'SummaryManager';

  final String _sessionId;
  final HttpClient _httpClient;
  final CFUser _user;
  final CFConfig _config;

  late final int _queueSize;
  late int _flushIntervalMs;

  final Queue<CFConfigRequestSummary> _queue =
      ListQueue<CFConfigRequestSummary>();
  final Map<String, bool> _trackMap = {};

  Timer? _timer;

  // Request deduplicator to prevent duplicate concurrent flush operations
  final RequestDeduplicator _requestDeduplicator = RequestDeduplicator();

  SummaryManager(
    this._sessionId,
    this._httpClient,
    this._user,
    this._config,
  ) {
    _queueSize = _config.summariesQueueSize;
    _flushIntervalMs = _config.summariesFlushIntervalMs;
    Logger.d('SummaryManager initialized (queueSize=$_queueSize)');
    _startPeriodicFlush();
  }

  /// Updates the flush interval
  void updateFlushInterval(int intervalMs) {
    try {
      if (intervalMs <= 0) throw ArgumentError('Interval must be > 0');
      _flushIntervalMs = intervalMs;
      _restartPeriodicFlush();
      Logger.d('Summary flush interval updated: ${intervalMs}ms');
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to update flush interval to $intervalMs',
        source: _source,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Get pending summaries count
  int getPendingSummariesCount() {
    return _queue.length;
  }

  /// Clear all summaries
  void clearSummaries() {
    _queue.clear();
    _trackMap.clear();
    Logger.d('Summaries cleared');
  }

  /// Pushes a config summary into the queue
  Future<CFResult<bool>> pushSummary(Map<String, dynamic> config) async {
    // Validate map keys
    if (config.keys.any((k) => k.runtimeType != String)) {
      const msg = 'Config map has non-string keys';
      Logger.w(msg);
      ErrorHandler.handleError(
        msg,
        source: _source,
        category: ErrorCategory.validation,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(msg, category: ErrorCategory.validation);
    }

    // Mandatory fields - use safe type conversion
    final experienceIdResult = SafeTypeConverter.extractFromMap<String>(
      config,
      'experience_id',
      isRequired: true,
    );
    if (!experienceIdResult.isSuccess) {
      final msg =
          'Missing mandatory experience_id in config: ${experienceIdResult.getErrorMessage()}';
      Logger.w(msg);
      ErrorHandler.handleError(
        msg,
        source: _source,
        category: ErrorCategory.validation,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(msg, category: ErrorCategory.validation);
    }
    final experienceId = experienceIdResult.data!;

    final configIdResult = SafeTypeConverter.extractFromMap<String>(
      config,
      'config_id',
      isRequired: false,
    );
    final configId = configIdResult.isSuccess ? configIdResult.data : null;

    final variationIdResult = SafeTypeConverter.extractFromMap<String>(
      config,
      'variation_id',
      isRequired: false,
    );
    final variationId =
        variationIdResult.isSuccess ? variationIdResult.data : null;

    final version = config['version']?.toString();

    final missingFields = <String>[];
    if (configId == null) missingFields.add('config_id');
    if (variationId == null) missingFields.add('variation_id');
    if (version == null) missingFields.add('version');

    if (missingFields.isNotEmpty) {
      final msg =
          'Missing mandatory fields for summary: ${missingFields.join(', ')}';
      Logger.w(msg);
      ErrorHandler.handleError(
        msg,
        source: _source,
        category: ErrorCategory.validation,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(msg, category: ErrorCategory.validation);
    }

    // Extract behaviourId safely
    final behaviourIdResult = SafeTypeConverter.extractFromMap<String>(
      config,
      'behaviour_id',
      isRequired: false,
    );
    final behaviourId =
        behaviourIdResult.isSuccess ? behaviourIdResult.data : null;

    // Create composite key from experienceId and behaviourId
    final compositeKey =
        behaviourId != null ? '${experienceId}_$behaviourId' : experienceId;

    // Prevent duplicate processing with proper async handling
    if (_trackMap.containsKey(compositeKey)) {
      return CFResult.success(true);
    }

    _trackMap[compositeKey] = true;

    final ruleIdResult = SafeTypeConverter.extractFromMap<String>(
      config,
      'rule_id',
      isRequired: false,
    );
    final ruleId = ruleIdResult.isSuccess ? ruleIdResult.data : null;

    final summary = CFConfigRequestSummary(
      configId: configId,
      version: version,
      requestedTime: TimestampUtil.formatForAPI(DateTime.now().toUtc()),
      variationId: variationId,
      userCustomerId: _user.userCustomerId ?? '',
      sessionId: _sessionId,
      behaviourId: behaviourId,
      experienceId: experienceId,
      ruleId: ruleId,
    );

    if (_queue.length >= _queueSize) {
      Logger.d('Summary queue full, flushing');
      ErrorHandler.handleError(
        'Summary queue full, forcing flush for new entry',
        source: _source,
        category: ErrorCategory.internal,
        severity: ErrorSeverity.medium,
      );

      await flushSummaries();

      if (_queue.length >= _queueSize) {
        Logger.e('Failed to queue summary after flush');
        ErrorHandler.handleError(
          'Failed to queue summary after flush',
          source: _source,
          category: ErrorCategory.internal,
          severity: ErrorSeverity.high,
        );
        return CFResult.error(
          'Queue still full after flush',
          category: ErrorCategory.internal,
        );
      }
    }

    _queue.addLast(summary);

    // Check if queue size threshold is reached
    if (_queue.length >= _queueSize) {
      await flushSummaries();
    }

    return CFResult.success(true);
  }

  /// Flushes summaries and returns count flushed
  Future<CFResult<int>> flushSummaries() async {
    // Use request deduplication to prevent concurrent flush operations
    return await _requestDeduplicator.execute<int>(
      'summary_flush_${_user.userCustomerId}_$_sessionId',
      () => _performSummaryFlush(),
    );
  }

  /// Performs the actual summary flush operation (extracted for deduplication)
  Future<CFResult<int>> _performSummaryFlush() async {
    if (_queue.isEmpty) {
      return CFResult.success(0);
    }

    final batch = <CFConfigRequestSummary>[];
    while (_queue.isNotEmpty) {
      batch.add(_queue.removeFirst());
    }

    if (batch.isEmpty) {
      return CFResult.success(0);
    }

    Logger.d('Flushing ${batch.length} summaries');

    try {
      final result = await _sendSummariesToServer(batch);
      if (result.isSuccess) {
        return CFResult.success(batch.length);
      } else {
        Logger.w('Summary flush failed: ${result.getErrorMessage()}');
        return CFResult.error(
          'Failed to flush summaries: ${result.getErrorMessage()}',
          category: ErrorCategory.network,
        );
      }
    } catch (e) {
      Logger.e('Summary flush error: $e');
      ErrorHandler.handleException(
        e,
        'Unexpected error during summary flush',
        source: _source,
        severity: ErrorSeverity.high,
      );
      return CFResult.error(
        'Failed to flush summaries',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  Future<CFResult<bool>> _sendSummariesToServer(
      List<CFConfigRequestSummary> summaries) async {
    // Create strongly typed request
    final request = SummaryRequest(
      user: _user,
      summaries: summaries,
      cfClientSdkVersion: CFConstants.general.sdkVersion,
    );

    final payload = request.toJsonString();

    // SECURITY FIX: Move API key to headers instead of URL parameter
    final url = '${CFConstants.api.baseApiUrl}${CFConstants.api.summariesPath}';

    // Create secure headers with API key
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_config.clientKey}',
      'X-CF-SDK-Version': CFConstants.general.sdkVersion,
    };

    try {
      final result = await ExponentialBackoff.retry<bool>(
        operationName: 'SummaryManager.sendSummaries',
        config: RetryConfig(
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 1000),
          maxDelay: const Duration(milliseconds: 5000),
          backoffMultiplier: 2.0,
        ),
        operation: () async {
          final res = await _httpClient.post(
            url,
            data: payload,
            headers: headers,
          );

          if (!res.isSuccess) {
            return CFResult.error(
              'Failed to send summaries - server returned error',
              category: ErrorCategory.network,
            );
          }

          return CFResult.success(true);
        },
      );

      if (result.isSuccess) {
        return CFResult.success(true);
      } else {
        Logger.w('Failed to send summaries after retries');
        await _handleSendFailure(summaries);
        return CFResult.error(
          'Failed to send summaries after ${_config.maxRetryAttempts} attempts',
          category: ErrorCategory.network,
        );
      }
    } catch (e) {
      Logger.e('Error sending summaries: $e');
      ErrorHandler.handleException(
        e,
        'Error sending summaries to server',
        source: _source,
        severity: ErrorSeverity.high,
      );
      await _handleSendFailure(summaries);
      return CFResult.error(
        'Error sending summaries to server: ${e.toString()}',
        exception: e,
        category: ErrorCategory.network,
      );
    }
  }

  /// Helper method to handle send failures by re-queueing summaries
  Future<void> _handleSendFailure(
      List<CFConfigRequestSummary> summaries) async {
    var requeueFailCount = 0;

    for (final summary in summaries) {
      if (_queue.length >= _queueSize) {
        requeueFailCount++;
      } else {
        _queue.addLast(summary);
      }
    }

    if (requeueFailCount > 0) {
      Logger.e('Failed to re-queue $requeueFailCount summaries');
      ErrorHandler.handleError(
        'Failed to re-queue $requeueFailCount summaries after send failure',
        source: _source,
        category: ErrorCategory.internal,
        severity: ErrorSeverity.high,
      );
    }
  }

  void _startPeriodicFlush() {
    _timer?.cancel();
    _timer = null;

    _timer = Timer.periodic(
      Duration(milliseconds: _flushIntervalMs),
      (_) async {
        try {
          await flushSummaries();
        } catch (e) {
          Logger.e('Periodic summary flush error: $e');
          ErrorHandler.handleException(
            e,
            'Error during periodic summary flush',
            source: _source,
            severity: ErrorSeverity.medium,
          );
        }
      },
    );
  }

  Future<void> _restartPeriodicFlush() async {
    _timer?.cancel();
    _timer = null;

    _timer = Timer.periodic(
      Duration(milliseconds: _flushIntervalMs),
      (_) async {
        try {
          await flushSummaries();
        } catch (e) {
          Logger.e('Periodic summary flush error: $e');
          ErrorHandler.handleException(
            e,
            'Error during periodic summary flush',
            source: _source,
            severity: ErrorSeverity.medium,
          );
        }
      },
    );
  }

  /// Returns all tracked summaries
  Map<String, bool> getSummaries() => Map.unmodifiable(_trackMap);

  /// Get the current queue size (for testing)
  int getQueueSize() => _queue.length;

  /// Shutdown method to clean up timers
  void shutdown() {
    _timer?.cancel();
    _timer = null;
    _requestDeduplicator.cancelAll();
    Logger.d('SummaryManager shutdown');
  }
}
