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
import '../../logging/logger.dart';
import '../../core/model/cf_user.dart';
import '../../config/core/cf_config.dart';
import '../../core/util/retry_util.dart';

import 'cf_config_request_summary.dart';
import '../../network/http_client.dart';
import '../../network/models/summary_request.dart';
import '../../network/request_deduplicator.dart';
import '../../constants/cf_constants.dart';
import '../../core/util/type_conversion_strategy.dart';
import '../../utils/timestamp_util.dart';

/// Manages collection and flushing of configuration summaries, mirroring Kotlin's SummaryManager
class SummaryManager {
  static const _source = 'SummaryManager';

  final String _sessionId;
  final HttpClient _httpClient;
  final CFUser _user;
  final CFConfig _config;

  late final int _queueSize;
  late int _flushIntervalMs;
  final int _flushTimeSeconds;

  final Queue<CFConfigRequestSummary> _queue =
      ListQueue<CFConfigRequestSummary>();
  final Map<String, bool> _trackMap = {};

  Timer? _timer;

  // Request deduplicator to prevent duplicate concurrent flush operations
  final RequestDeduplicator _requestDeduplicator = RequestDeduplicator();

  // Add proper async synchronization
  Completer<void>? _pushCompleter;

  SummaryManager(
    this._sessionId,
    this._httpClient,
    this._user,
    this._config,
  ) : _flushTimeSeconds = _config.summariesFlushTimeSeconds {
    _queueSize = _config.summariesQueueSize;
    _flushIntervalMs = _config.summariesFlushIntervalMs;
    Logger.i(
        '📊 SUMMARY: SummaryManager initialized with queueSize=$_queueSize, flushIntervalMs=$_flushIntervalMs, flushTimeSeconds=$_flushTimeSeconds');
    _startPeriodicFlush();
  }

  /// Updates the flush interval
  void updateFlushInterval(int intervalMs) {
    try {
      if (intervalMs <= 0) throw ArgumentError('Interval must be > 0');
      _flushIntervalMs = intervalMs;
      _restartPeriodicFlush();
      Logger.i(
          '📊 SUMMARY: Updated summaries flush interval to $intervalMs ms');
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
    Logger.d('📊 SUMMARY: Cleared all summaries and tracking map');
  }

  /// Pushes a config summary into the queue
  Future<CFResult<bool>> pushSummary(Map<String, dynamic> config) async {
    // Log the config being processed
    Logger.i(
        '📊 SUMMARY: Processing summary for config: ${config["key"] ?? "unknown"}');

    // Validate map keys
    if (config.keys.any((k) => k.runtimeType != String)) {
      const msg = 'Config map has non-string keys';
      Logger.w('📊 SUMMARY: $msg');
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
      Logger.w('📊 SUMMARY: $msg, summary not tracked');
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
      Logger.w('📊 SUMMARY: $msg, summary not tracked');
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
      Logger.d(
          '📊 SUMMARY: Experience-Behaviour combination already processed: $compositeKey');
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

    Logger.i(
        '📊 SUMMARY: Created summary for experience: $experienceId, config: $configId');

    if (_queue.length >= _queueSize) {
      Logger.w('📊 SUMMARY: Queue full, forcing flush for new entry');
      ErrorHandler.handleError(
        'Summary queue full, forcing flush for new entry',
        source: _source,
        category: ErrorCategory.internal,
        severity: ErrorSeverity.medium,
      );

      await flushSummaries();

      if (_queue.length >= _queueSize) {
        Logger.e('📊 SUMMARY: Failed to queue summary after flush');
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
    Logger.i(
        '📊 SUMMARY: Added to queue: experience=$experienceId, queue size=${_queue.length}');

    // Check if queue size threshold is reached
    if (_queue.length >= _queueSize) {
      Logger.i(
          '📊 SUMMARY: Queue size threshold reached (${_queue.length}/$_queueSize), triggering flush');
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
      // Silent return when queue is empty - no logging needed
      return CFResult.success(0);
    }

    Logger.i(
        '📊 SUMMARY: flushSummaries() called, queue size: ${_queue.length}');

    final batch = <CFConfigRequestSummary>[];
    while (_queue.isNotEmpty) {
      batch.add(_queue.removeFirst());
    }

    if (batch.isEmpty) {
      Logger.d('📊 SUMMARY: No summaries to flush after drain');
      return CFResult.success(0);
    }

    Logger.i('📊 SUMMARY: Flushing ${batch.length} summaries to server');

    try {
      final result = await _sendSummariesToServer(batch);
      if (result.isSuccess) {
        Logger.i(
            '📊 SUMMARY: Successfully flushed ${batch.length} summaries to server');
        return CFResult.success(batch.length);
      } else {
        Logger.w(
            '📊 SUMMARY: Failed to flush summaries: ${result.getErrorMessage()}');
        return CFResult.error(
          'Failed to flush summaries: ${result.getErrorMessage()}',
          category: ErrorCategory.network,
        );
      }
    } catch (e) {
      Logger.e(
          '📊 SUMMARY: Unexpected error during summary flush: ${e.toString()}');
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
    Logger.i('📊 SUMMARY: Sending ${summaries.length} summaries to server');

    // Create strongly typed request
    final request = SummaryRequest(
      user: _user,
      summaries: summaries,
      cfClientSdkVersion: CFConstants.general.sdkVersion,
    );

    final payload = request.toJsonString();

    // Log summary payload info (reduced verbosity)
    Logger.d(
        '📊 SUMMARY: Sending ${summaries.length} summaries, payload size: ${payload.length} bytes');

    // SECURITY FIX: Move API key to headers instead of URL parameter
    final url = '${CFConstants.api.baseApiUrl}${CFConstants.api.summariesPath}';

    // Create secure headers with API key
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_config.clientKey}',
      'X-CF-SDK-Version': CFConstants.general.sdkVersion,
    };

    try {
      var success = false;
      await RetryUtil.withRetryResult<dynamic>(
        maxAttempts: 3,
        initialDelayMs: 1000,
        maxDelayMs: 5000,
        backoffMultiplier: 2.0,
        block: () async {
          Logger.d('📊 SUMMARY: Attempting to send summaries');
          final res = await _httpClient.post(
            url,
            data: payload,
            headers: headers,
          );

          if (!res.isSuccess) {
            Logger.w('📊 SUMMARY: Server returned error, retrying...');
            throw Exception('Failed to send summaries - server returned error');
          }

          Logger.i('📊 SUMMARY: Server accepted summaries');
          success = true;
          return res;
        },
      );

      if (success) {
        Logger.i(
            '📊 SUMMARY: Successfully sent ${summaries.length} summaries to server');
        return CFResult.success(true);
      } else {
        Logger.w(
            '📊 SUMMARY: Failed to send summaries after ${_config.maxRetryAttempts} attempts');
        await _handleSendFailure(summaries);
        return CFResult.error(
          'Failed to send summaries after ${_config.maxRetryAttempts} attempts',
          category: ErrorCategory.network,
        );
      }
    } catch (e) {
      Logger.e(
          '📊 SUMMARY: Error sending summaries to server: ${e.toString()}');
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
    Logger.w(
        '📊 SUMMARY: Failed to send ${summaries.length} summaries after retries, re-queuing');
    var requeueFailCount = 0;

    for (final summary in summaries) {
      if (_queue.length >= _queueSize) {
        requeueFailCount++;
      } else {
        _queue.addLast(summary);
      }
    }

    if (requeueFailCount > 0) {
      Logger.e(
          '📊 SUMMARY: Failed to re-queue $requeueFailCount summaries after send failure');
      ErrorHandler.handleError(
        'Failed to re-queue $requeueFailCount summaries after send failure',
        source: _source,
        category: ErrorCategory.internal,
        severity: ErrorSeverity.high,
      );
    }
  }

  void _startPeriodicFlush() {
    // Cancel existing timer
    _timer?.cancel();
    _timer = null;

    // Create new timer
    _timer = Timer.periodic(
      Duration(milliseconds: _flushIntervalMs),
      (_) async {
        try {
          // Only log if there are summaries to flush
          if (_queue.isNotEmpty) {
            Logger.i(
                '📊 SUMMARY: Periodic flush triggered, queue size: ${_queue.length}');
          }
          await flushSummaries();
        } catch (e) {
          Logger.e(
              '📊 SUMMARY: Error during periodic summary flush: ${e.toString()}');
          ErrorHandler.handleException(
            e,
            'Error during periodic summary flush',
            source: _source,
            severity: ErrorSeverity.medium,
          );
        }
      },
    );

    Logger.i(
        '📊 SUMMARY: Started periodic summary flush with interval $_flushIntervalMs ms');
  }

  Future<void> _restartPeriodicFlush() async {
    // Cancel existing timer
    _timer?.cancel();
    _timer = null;

    // Create new timer with updated interval
    _timer = Timer.periodic(
      Duration(milliseconds: _flushIntervalMs),
      (_) async {
        try {
          // Only log if there are summaries to flush
          if (_queue.isNotEmpty) {
            Logger.d(
                '📊 SUMMARY: Periodic flush triggered, queue size: ${_queue.length}');
          }
          await flushSummaries();
        } catch (e) {
          Logger.e(
              '📊 SUMMARY: Error during periodic summary flush: ${e.toString()}');
          ErrorHandler.handleException(
            e,
            'Error during periodic summary flush',
            source: _source,
            severity: ErrorSeverity.medium,
          );
        }
      },
    );

    Logger.d(
        '📊 SUMMARY: Restarted periodic flush with interval $_flushIntervalMs ms');
  }

  /// Returns all tracked summaries
  Map<String, bool> getSummaries() => Map.unmodifiable(_trackMap);

  /// Get the current queue size (for testing)
  int getQueueSize() => _queue.length;

  /// Shutdown method to clean up timers
  void shutdown() {
    _timer?.cancel();
    _timer = null;

    // Cancel any in-flight requests
    _requestDeduplicator.cancelAll();

    Logger.i('📊 SUMMARY: Summary manager shutdown');
  }
}
