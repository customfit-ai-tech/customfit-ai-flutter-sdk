// lib/src/analytics/event/event_tracker.dart
//
// Event tracking implementation with batching, retry logic, and network awareness.
// Manages the collection, queuing, and transmission of analytics events to the
// CustomFit backend with automatic retry, backpressure handling, and offline support.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';

import '../../config/core/cf_config.dart';
import '../../constants/cf_constants.dart';
import '../../core/error/cf_result.dart';
import '../../core/error/error_handler.dart';
import '../../core/error/error_severity.dart';
import '../../core/error/error_category.dart';
import '../../logging/logger.dart';
import '../../core/model/cf_user.dart';
import '../../network/connection/connection_information.dart';
import '../../network/connection/connection_status.dart';
import '../../network/connection/connection_manager.dart';
import '../../network/http_client.dart';

import '../../network/models/track_request.dart';
import '../../core/util/retry_util.dart';
import '../../core/resource_registry.dart';
import '../../network/request_deduplicator.dart';
import 'persistent_event_queue.dart';
import 'event_data.dart';
import 'event_data_pool.dart';
import 'event_type.dart';
// import 'batch_processor.dart'; // Unused

import '../../core/validation/input_validator.dart';
// import '../../core/validation/batch_input_validator.dart'; // Unused
import '../summary/summary_manager.dart';

/// Callback for event tracking notifications
typedef EventCallback = void Function(EventData event);

/// Implements robust event tracking with batching, retry logic, and network awareness.
class EventTracker implements ConnectionStatusListener {
  static const String _source = 'EventTracker';

  late final PersistentEventQueue _eventQueue;
  final HttpClient _httpClient;
  final ConnectionManager _connectionManager;
  final CFUser _user;
  final String _sessionId;
  final CFConfig _config;

  // Added reference to SummaryManager to ensure summaries are flushed before events
  final SummaryManager? _summaryManager;

  // Request deduplicator to prevent duplicate concurrent flush operations
  final RequestDeduplicator _requestDeduplicator = RequestDeduplicator();

  bool _autoFlushEnabled = true;
  ManagedTimer? _flushTimer;
  EventCallback? _eventCallback;
  bool _isShutdown = false;

  // Backpressure handling
  int _consecutiveFailedFlushes = 0;
  DateTime? _lastBackpressureDelay;

  // Add proper async synchronization
  Completer<void>? _flushCompleter;

  // Enhanced backpressure metrics
  int _totalEventsDropped = 0;
  DateTime? _lastEventDropTime;
  static const int _maxConsecutiveFailures = 5;
  static const int _backpressureThreshold = 80;

  // Event drop callbacks
  void Function(int droppedCount, String reason)? _onEventsDropped;
  void Function(Map<String, dynamic> metrics)? _onBackpressureApplied;

  // Circuit breaker state
  bool _circuitBreakerOpen = false;
  DateTime? _circuitBreakerOpenTime;
  static const Duration _circuitBreakerCooldown = Duration(minutes: 2);

  /// Creates a new event tracker with the given dependencies
  EventTracker(
    this._httpClient,
    this._connectionManager,
    this._user,
    this._sessionId,
    this._config, {
    SummaryManager? summaryManager,
  }) : _summaryManager = summaryManager {
    // Initialize event queue with proper callbacks
    _eventQueue = PersistentEventQueue(
      maxQueueSize: 100,
      onEventsDropped: (droppedEvents) {
        _handleDroppedEvents(droppedEvents);
      },
    );

    _connectionManager.addConnectionStatusListener(this);
    _startFlushTimer();
    Logger.i(
      '🔔 🔔 TRACK: EventTracker initialized with autoFlush=$_autoFlushEnabled, sessionId=$_sessionId',
    );
  }

  /// Setup event tracking listeners
  /// This method centralizes the event tracking listener setup that was previously in CFClient
  void setupListeners({void Function(EventData)? onEventTracked}) {
    if (onEventTracked != null) {
      setEventCallback(onEventTracked);
    }
    Logger.d('🔔 🔔 TRACK: Event tracking listeners configured');
  }

  /// Track a single event.
  ///
  /// Returns a result with event data or error.
  Future<CFResult<void>> trackEvent(
    String eventName,
    Map<String, dynamic> properties,
  ) async {
    if (_isShutdown) {
      return CFResult.error(
        'EventTracker has been shut down',
        code: 4999,
        category: ErrorCategory.internal,
      );
    }

    // SECURITY FIX: Validate event name input
    final eventNameValidation = InputValidator.validateEventName(eventName);
    if (!eventNameValidation.isSuccess) {
      Logger.w(
          '🔔 🔔 TRACK: Event name validation failed: ${eventNameValidation.getErrorMessage()}');
      return CFResult.error(
        'Invalid event name: ${eventNameValidation.getErrorMessage()}',
        category:
            eventNameValidation.error?.category ?? ErrorCategory.validation,
        errorCode: eventNameValidation.error?.errorCode,
      );
    }

    // SECURITY FIX: Validate properties input
    final propertiesValidation = InputValidator.validateProperties(properties);
    if (!propertiesValidation.isSuccess) {
      Logger.w(
          '🔔 🔔 TRACK: Event properties validation failed: ${propertiesValidation.getErrorMessage()}');
      return CFResult.error(
        'Invalid event properties: ${propertiesValidation.getErrorMessage()}',
        category:
            propertiesValidation.error?.category ?? ErrorCategory.validation,
        errorCode: propertiesValidation.error?.errorCode,
      );
    }

    // Use validated inputs
    final validatedEventName = eventNameValidation.getOrThrow();
    final validatedProperties = propertiesValidation.getOrThrow();

    final result = await _trackEvent(validatedEventName, validatedProperties);
    return result.isSuccess
        ? CFResult.success(null)
        : CFResult.error(
            result.getErrorMessage() ?? 'Failed to track event',
            exception: result.error?.exception,
            category: result.error?.category ?? ErrorCategory.internal,
          );
  }

  /// Internal method that returns EventData
  Future<CFResult<EventData>> _trackEvent(
    String eventName, [
    Map<String, dynamic> properties = const {},
  ]) async {
    if (_isShutdown) {
      return CFResult.error(
        'EventTracker has been shut down',
        code: 4999,
        category: ErrorCategory.internal,
      );
    }

    try {
      // Enhanced logging similar to Kotlin improvements
      Logger.i(
        '🔔 🔔 TRACK: Tracking event: $eventName with properties: $properties',
      );
      Logger.d(
        '🔔 🔔 TRACK DEBUG: Properties type: ${properties.runtimeType}, keys: ${properties.keys.toList()}, values: ${properties.values.toList()}',
      );

      // Flush summaries before tracking a new event if SummaryManager is provided
      if (_summaryManager != null) {
        Logger.i(
          '🔔 🔔 TRACK: Flushing summaries before tracking event: $eventName',
        );
        await _summaryManager.flushSummaries().then((result) {
          if (!result.isSuccess) {
            Logger.w(
              '🔔 🔔 TRACK: Failed to flush summaries before tracking event: ${result.getErrorMessage()}',
            );
          }
        });
      }

      // Validate event name (consistent with other SDKs)
      if (eventName.trim().isEmpty) {
        const message = 'Event name cannot be blank';
        Logger.w('🔔 🔔 TRACK: Invalid event - $message');
        ErrorHandler.handleError(
          message,
          source: _source,
          category: ErrorCategory.validation,
          severity: ErrorSeverity.medium,
        );
        return CFResult.error(message, category: ErrorCategory.validation);
      }

      // Create event data - use event name as eventCustomerId to match Kotlin SDK
      final eventData = EventData.create(
        eventCustomerId:
            eventName, // Changed to use eventName instead of userCustomerId
        eventType: EventType.track,
        properties: properties,
        sessionId: _sessionId,
      );

      // Backpressure handling: apply delay if needed
      await _applyBackpressureDelay();

      // Enhanced backpressure handling
      final maxQueueSize = _getMaxQueueSize();
      final queueUtilization = (_eventQueue.size / maxQueueSize * 100).round();

      if (queueUtilization >= _backpressureThreshold) {
        Logger.w(
          '🔔 🔔 TRACK: Queue utilization at $queueUtilization%, applying backpressure',
        );

        // Try to flush events immediately to make space
        await _forceFlushEvents();

        // Recalculate after flush attempt
        final newUtilization = (_eventQueue.size / maxQueueSize * 100).round();

        // If still above threshold after flush attempt
        if (newUtilization >= _backpressureThreshold) {
          _consecutiveFailedFlushes++;
          Logger.w(
            '🔔 🔔 TRACK: Event queue still at $newUtilization% after flush, applying backpressure (failed flushes: $_consecutiveFailedFlushes)',
          );
          ErrorHandler.handleError(
            'Event queue is at $newUtilization% capacity, applying backpressure',
            source: _source,
            category: ErrorCategory.internal,
            severity: ErrorSeverity.high,
          );

          // Notify about backpressure being applied
          if (_onBackpressureApplied != null) {
            try {
              _onBackpressureApplied!({
                'queueUtilization': newUtilization,
                'consecutiveFailures': _consecutiveFailedFlushes,
                'queueSize': _eventQueue.size,
                'maxQueueSize': maxQueueSize,
                'timestamp': DateTime.now().toIso8601String(),
              });
            } catch (e) {
              Logger.w('Error in backpressure callback: $e');
            }
          }

          // Apply exponential backoff delay
          final delayMs = _calculateBackpressureDelay();
          if (delayMs > 0) {
            await Future.delayed(Duration(milliseconds: delayMs));
          }

          // If we've hit max consecutive failures, start dropping oldest events
          if (_consecutiveFailedFlushes >= _maxConsecutiveFailures &&
              _eventQueue.size >= maxQueueSize) {
            final droppedCount = _eventQueue.size ~/ 4; // Drop 25% of queue
            final droppedEvents = _eventQueue.popEventBatch(droppedCount);
            _totalEventsDropped += droppedEvents.length;
            _lastEventDropTime = DateTime.now();

            Logger.e(
              '🔔 🔔 TRACK: Dropped ${droppedEvents.length} oldest events due to sustained backpressure (total dropped: $_totalEventsDropped)',
            );
            ErrorHandler.handleError(
              'Dropped ${droppedEvents.length} events due to sustained backpressure',
              source: _source,
              category: ErrorCategory.internal,
              severity: ErrorSeverity.critical,
            );

            // Notify about dropped events
            if (_onEventsDropped != null && droppedEvents.isNotEmpty) {
              try {
                _onEventsDropped!(
                    droppedEvents.length, 'sustained_backpressure');
              } catch (e) {
                Logger.w('Error in event drop callback: $e');
              }
            }
          }
        }
      }

      _eventQueue.addEvent(eventData);
      Logger.i(
        '🔔 🔔 TRACK: Event added to queue: ${eventData.eventCustomerId}, queue size=${_eventQueue.size}',
      );

      // Notify callback if set
      if (_eventCallback != null) {
        try {
          _eventCallback!(eventData);
          Logger.d('🔔 🔔 TRACK: Event callback executed successfully');
        } catch (e) {
          ErrorHandler.handleException(
            e,
            'Error in event callback',
            source: _source,
            severity: ErrorSeverity.low,
          );
        }
      }

      // Flush if auto flush is enabled and connection is available
      if (_autoFlushEnabled &&
          _connectionManager.getConnectionStatus() ==
              ConnectionStatus.connected) {
        final threshold = (_getMaxQueueSize() * 0.75).round();
        if (_eventQueue.size >= threshold) {
          Logger.i(
            '🔔 🔔 TRACK: Queue size threshold reached (${_eventQueue.size}/$threshold), triggering flush',
          );
          _maybeFlushEvents();
        }
      }

      return CFResult.success(eventData);
    } catch (e) {
      final errorMsg = 'Failed to track event: ${e.toString()}';
      Logger.e('🔔 🔔 TRACK: $errorMsg');
      ErrorHandler.handleException(
        e,
        'Failed to track event',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(
        errorMsg,
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Track multiple events.
  ///
  /// Returns a result with the tracked events or error.
  Future<CFResult<void>> trackBatch(List<EventData> events) async {
    final result = await trackEvents(events);
    return result.isSuccess
        ? CFResult.success(null)
        : CFResult.error(
            result.getErrorMessage() ?? 'Failed to track batch',
            exception: result.error?.exception,
            category: result.error?.category ?? ErrorCategory.internal,
          );
  }

  /// Track multiple events.
  ///
  /// Returns a result with the tracked events or error.
  Future<CFResult<List<EventData>>> trackEvents(List<EventData> events) async {
    try {
      Logger.i('🔔 🔔 TRACK: Tracking ${events.length} events');

      // Flush summaries before tracking new events if SummaryManager is provided
      if (_summaryManager != null) {
        Logger.d(
          '🔔 🔔 TRACK: Flushing summaries before tracking ${events.length} events',
        );
        await _summaryManager.flushSummaries().then((result) {
          if (!result.isSuccess) {
            Logger.w(
              '🔔 🔔 TRACK: Failed to flush summaries: ${result.getErrorMessage()}',
            );
          }
        });
      }

      // Add to queue
      _eventQueue.addEvents(events);
      Logger.i(
        '🔔 🔔 TRACK: ${events.length} events added to queue, queue size=${_eventQueue.size}',
      );

      // Notify callback for each event if set
      if (_eventCallback != null) {
        for (final event in events) {
          try {
            _eventCallback!(event);
          } catch (e) {
            ErrorHandler.handleException(
              e,
              'Error in event callback',
              source: _source,
              severity: ErrorSeverity.low,
            );
          }
        }
      }

      // Flush if auto flush is enabled and connection is available
      if (_autoFlushEnabled &&
          _connectionManager.getConnectionStatus() ==
              ConnectionStatus.connected) {
        final threshold = (_getMaxQueueSize() * 0.75).round();
        if (_eventQueue.size >= threshold) {
          Logger.i(
            '🔔 🔔 TRACK: Queue size threshold reached (${_eventQueue.size}/$threshold), triggering flush',
          );
          _maybeFlushEvents();
        }
      }

      return CFResult.success(events);
    } catch (e) {
      final errorMsg = 'Failed to track events: ${e.toString()}';
      Logger.e('🔔 🔔 TRACK: $errorMsg');
      ErrorHandler.handleException(
        e,
        'Failed to track events',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(
        errorMsg,
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// This will attempt to send all events in the queue immediately.
  /// Returns a result indicating success or failure.
  Future<CFResult<bool>> flush() async {
    Logger.i('🔔 🔔 TRACK: Beginning event flush process');

    if (_eventQueue.isEmpty) {
      Logger.d('🔔 🔔 TRACK: No events to flush');
      return CFResult.success(true);
    }

    // Use request deduplication to prevent concurrent flush operations
    return await _requestDeduplicator.execute<bool>(
      'event_flush_${_user.userCustomerId}_$_sessionId',
      () => _performEventFlush(),
    );
  }

  /// Performs the actual event flush operation (extracted for deduplication)
  Future<CFResult<bool>> _performEventFlush() async {
    if (_connectionManager.getConnectionStatus() !=
        ConnectionStatus.connected) {
      Logger.w('🔔 🔔 TRACK: Cannot flush events: network not connected');
      return CFResult.error(
        'Cannot flush events: network not connected',
        category: ErrorCategory.network,
      );
    }

    // Check circuit breaker status
    if (_circuitBreakerOpen) {
      if (_circuitBreakerOpenTime != null) {
        final timeSinceOpen = DateTime.now().difference(
          _circuitBreakerOpenTime!,
        );
        if (timeSinceOpen < _circuitBreakerCooldown) {
          Logger.w(
            '🔔 🔔 TRACK: Circuit breaker is open, skipping flush for ${_circuitBreakerCooldown.inSeconds - timeSinceOpen.inSeconds}s',
          );
          return CFResult.error(
            'Circuit breaker is open, flush temporarily disabled',
            category: ErrorCategory.network,
          );
        } else {
          // Try to close circuit breaker
          Logger.i(
            '🔔 🔔 TRACK: Circuit breaker cooldown expired, attempting to close',
          );
          _circuitBreakerOpen = false;
          _circuitBreakerOpenTime = null;
        }
      }
    }

    try {
      // Flush summaries first
      if (_summaryManager != null) {
        Logger.d('🔔 🔔 TRACK: Flushing summaries before flushing events');
        await _summaryManager.flushSummaries().then((result) {
          if (!result.isSuccess) {
            Logger.w(
              '🔔 🔔 TRACK: Failed to flush summaries: ${result.getErrorMessage()}',
            );
          } else {
            Logger.d(
              '🔔 🔔 TRACK: Successfully flushed summaries before events',
            );
          }
        });
      }

      // Get batch of events to send with optimal batch size
      final batchSize = _getOptimalBatchSize();
      Logger.d(
        '🔔 🔔 TRACK: Using batch size: $batchSize based on current conditions',
      );
      final events = _eventQueue.popEventBatch(batchSize);
      if (events.isEmpty) {
        Logger.d('🔔 🔔 TRACK: No events to flush after drain');
        return CFResult.success(true);
      }

      Logger.i('🔔 🔔 TRACK HTTP: Preparing to send ${events.length} events');

      // Log summary instead of individual events
      Logger.d('🔔 🔔 TRACK HTTP: Processing batch of ${events.length} events');

      // Create strongly typed request
      final request = TrackRequest(
        user: _user,
        events: events,
        cfClientSdkVersion: CFConstants.general.sdkVersion,
      );

      final payload = request.toJsonString();

      Logger.d('🔔 🔔 TRACK HTTP: Event payload size: ${payload.length} bytes');

      // Send events to server - SECURITY FIX: Move API key to headers
      final url = '${CFConstants.api.baseApiUrl}${CFConstants.api.eventsPath}';

      // Create secure headers with API key
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config.clientKey}',
        'X-CF-SDK-Version': CFConstants.general.sdkVersion,
      };

      Logger.d('🔔 🔔 TRACK HTTP: POST request to: $url');
      Logger.d('🔔 🔔 TRACK HTTP: Request headers: ${headers.keys.join(', ')}');
      Logger.d(
        '🔔 🔔 TRACK HTTP: Request body preview: ${payload.length > 200 ? "${payload.substring(0, 200)}..." : payload}',
      );

      // Use retry logic for network calls
      final result = await RetryUtil.withRetryResult(
        maxAttempts: 3,
        initialDelayMs: 1000,
        maxDelayMs: 10000,
        backoffMultiplier: 2.0,
        retryOn: (exception) {
          // Retry on network-related errors
          final message = exception.toString().toLowerCase();
          return message.contains('network') ||
              message.contains('timeout') ||
              message.contains('connection') ||
              message.contains('socket');
        },
        block: () async {
          return await _httpClient.post(
            url,
            data: payload,
            headers: headers,
          );
        },
      );

      if (result.isSuccess) {
        Logger.i('🔔 🔔 TRACK: Successfully flushed ${events.length} events');
        Logger.d('🔔 🔔 TRACK HTTP: Response received successfully');
        _connectionManager.recordConnectionSuccess();

        // Release pooled events back to the pool after successful send
        _releasePooledEvents(events);

        // Reset consecutive failures on success
        _consecutiveFailedFlushes = 0;

        // If we have more events, trigger another flush
        if (!_eventQueue.isEmpty) {
          Logger.d(
            '🔔 🔔 TRACK: Queue still has events, triggering another flush',
          );
          _maybeFlushEvents();
        }

        return CFResult.success(true);
      } else {
        final errorMessage =
            'Failed to send events to server: ${result.getErrorMessage()}';
        Logger.e('🔔 🔔 TRACK HTTP: $errorMessage');

        // Increment failure count
        _consecutiveFailedFlushes++;

        // Open circuit breaker if too many consecutive failures
        if (_consecutiveFailedFlushes >= _maxConsecutiveFailures &&
            !_circuitBreakerOpen) {
          _circuitBreakerOpen = true;
          _circuitBreakerOpenTime = DateTime.now();
          Logger.e(
            '🔔 🔔 TRACK: Circuit breaker opened due to $_consecutiveFailedFlushes consecutive failures',
          );
        }

        // Put events back in queue
        Logger.w(
          '🔔 🔔 TRACK HTTP: Failed to send ${events.length} events after retries, attempting to re-queue',
        );

        var requeueFailCount = 0;
        for (final event in events) {
          if (_eventQueue.size >= _getMaxQueueSize()) {
            requeueFailCount++;
            Logger.w(
              '🔔 🔔 TRACK: Failed to re-queue event ${event.eventCustomerId} after send failure',
            );
          } else {
            _eventQueue.addEvent(event);
            Logger.d(
              '🔔 🔔 TRACK: Successfully re-queued event ${event.eventCustomerId}',
            );
          }
        }

        final resultMessage = requeueFailCount > 0
            ? 'Failed to send events and $requeueFailCount event(s) could not be requeued'
            : 'Failed to send events but all ${events.length} were requeued';

        Logger.e('🔔 🔔 TRACK: $resultMessage');

        // Record connection failure
        _connectionManager.recordConnectionFailure(errorMessage);

        return CFResult.error(resultMessage, category: ErrorCategory.network);
      }
    } catch (e) {
      final errorMsg = 'Error during flush: ${e.toString()}';
      Logger.e('🔔 🔔 TRACK HTTP: $errorMsg');

      // Increment failure count
      _consecutiveFailedFlushes++;

      // Cannot re-queue events here as they are not in scope
      Logger.w('🔔 🔔 TRACK: Exception during flush, events may be lost');

      ErrorHandler.handleException(
        e,
        'Failed to flush events',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error(
        'Failed to flush events: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Implement ConnectionStatusListener
  @override
  void onConnectionStatusChanged(
    ConnectionStatus status,
    ConnectionInformation info,
  ) {
    Logger.i('🔔 🔔 TRACK: Connection status changed to $status');
    if (status == ConnectionStatus.connected && _autoFlushEnabled) {
      Logger.d('🔔 🔔 TRACK: Connection restored, attempting to flush events');
      _maybeFlushEvents();
    }
  }

  /// Set a callback to be notified when events are tracked.
  void setEventCallback(EventCallback? callback) {
    _eventCallback = callback;
    Logger.d(
      '🔔 🔔 TRACK: Event callback ${callback == null ? 'removed' : 'set'}',
    );
  }

  /// Set a callback to be notified when events are dropped due to backpressure.
  void setOnEventsDroppedCallback(
    void Function(int droppedCount, String reason)? callback,
  ) {
    _onEventsDropped = callback;
    Logger.d(
      '🔔 🔔 TRACK: Event drop callback ${callback == null ? 'removed' : 'set'}',
    );
  }

  /// Set a callback to be notified when backpressure is applied.
  void setOnBackpressureAppliedCallback(
    void Function(Map<String, dynamic> metrics)? callback,
  ) {
    _onBackpressureApplied = callback;
    Logger.d(
      '🔔 🔔 TRACK: Backpressure callback ${callback == null ? 'removed' : 'set'}',
    );
  }

  /// Enable or disable automatic event flushing.
  void setAutoFlushEnabled(bool enabled) {
    _autoFlushEnabled = enabled;
    Logger.i('🔔 🔔 TRACK: Auto flush ${enabled ? 'enabled' : 'disabled'}');
    if (enabled) {
      _startFlushTimer();
    } else {
      _stopFlushTimer();
    }
  }

  /// Force flush all pending events immediately.
  /// Returns a result indicating success or failure.
  Future<CFResult<bool>> flushEvents() async {
    Logger.i('🔔 🔔 TRACK: flushEvents() called - delegating to flush()');
    return await flush();
  }

  /// Get the number of events currently pending in the queue.
  /// Returns the count of events waiting to be sent.
  int getPendingEventsCount() {
    final count = _eventQueue.size;
    Logger.d('🔔 🔔 TRACK: getPendingEventCount() returning $count');
    return count;
  }

  /// Get dropped events count
  int getDroppedEventsCount() {
    return _totalEventsDropped;
  }

  /// Clear all events
  void clearEvents() {
    _eventQueue.clear();
    Logger.i('🔔 🔔 TRACK: Cleared all events from queue');
  }

  /// Shutdown the event tracker and release resources.
  Future<void> shutdown() async {
    if (_isShutdown) return;

    _isShutdown = true;
    Logger.i('🔔 🔔 TRACK: Shutting down event tracker');
    _stopFlushTimer();
    _connectionManager.removeConnectionStatusListener(this);

    // Cancel any in-flight requests
    _requestDeduplicator.cancelAll();

    // Try to flush events one last time
    await flush();

    // Persist any remaining events
    await _eventQueue.shutdown();

    // Clear the event data pool
    EventDataPool.instance.clear();
    Logger.d('🔔 🔔 TRACK: Cleared EventData object pool');

    Logger.i('🔔 🔔 TRACK: Event tracker shutdown complete');
  }

  /// Start the timer for flushing events periodically.
  void _startFlushTimer() {
    if (_isShutdown) return;

    _stopFlushTimer();
    if (_autoFlushEnabled) {
      Logger.d(
        '🔔 🔔 TRACK: Starting flush timer with interval ${_config.eventsFlushIntervalMs}ms',
      );
      _flushTimer = ManagedTimer.periodic(
        owner: 'EventTracker',
        duration: Duration(milliseconds: _config.eventsFlushIntervalMs),
        callback: (_) {
          if (_isShutdown) return;

          // Only log if there are events to flush
          if (!_eventQueue.isEmpty) {
            Logger.d(
                '🔔 🔔 TRACK: Flush timer triggered, queue size: ${_eventQueue.size}');
          }
          _maybeFlushEvents();
        },
      );
    }
  }

  /// Stop the flush timer.
  void _stopFlushTimer() {
    if (_flushTimer != null) {
      Logger.d('🔔 🔔 TRACK: Stopping flush timer');
      _flushTimer!.dispose();
      _flushTimer = null;
    }
  }

  /// Flush events if conditions are met.
  void _maybeFlushEvents() {
    if (_connectionManager.getConnectionStatus() ==
        ConnectionStatus.connected) {
      if (!_eventQueue.isEmpty) {
        Logger.d('🔔 🔔 TRACK: Conditions met for flushing events');
        flush();
      }
    } else {
      Logger.d('🔔 🔔 TRACK: Skipping flush: network not connected');
    }
  }

  /// Release pooled events back to the object pool
  void _releasePooledEvents(List<EventData> events) {
    // Use batch release for better performance
    EventDataPoolExtension.releaseBatch(events);

    // Log pool statistics periodically
    final stats = EventDataPool.instance.getStatistics();
    if ((stats['totalAllocations'] as int) % 100 == 0) {
      Logger.d(
          '🔔 🔔 TRACK: EventData pool stats - ${stats['hitRate']} hit rate, ${stats['poolSize']} in pool, String cache hit rate: ${stats['stringCacheHitRate']}');
    }
  }

  /// Helper method to get the maximum queue size
  int _getMaxQueueSize() {
    // Get this from the EventQueue instance
    return 100; // Using the default value from the constructor
  }

  /// Get optimal batch size based on current conditions
  int _getOptimalBatchSize() {
    final currentQueueSize = _eventQueue.size;
    final maxQueueSize = _getMaxQueueSize();
    final queueUtilization = (currentQueueSize / maxQueueSize * 100).round();

    // Adjust batch size based on queue utilization and recent failures
    if (_consecutiveFailedFlushes > 3) {
      // Reduce batch size when experiencing failures
      return 25;
    } else if (queueUtilization > 80) {
      // Larger batches when queue is getting full
      return 150;
    } else if (queueUtilization < 20) {
      // Smaller batches for low utilization
      return 50;
    } else {
      // Default batch size
      return 100;
    }
  }

  /// Apply backpressure delay if needed
  Future<void> _applyBackpressureDelay() async {
    if (_lastBackpressureDelay != null) {
      final timeSinceLastDelay =
          DateTime.now().difference(_lastBackpressureDelay!).inMilliseconds;
      const minDelayBetweenBackpressure = 1000; // 1 second

      if (timeSinceLastDelay < minDelayBetweenBackpressure) {
        final remainingDelay = minDelayBetweenBackpressure - timeSinceLastDelay;
        await Future.delayed(Duration(milliseconds: remainingDelay));
      }
    }
  }

  /// Calculate backpressure delay based on consecutive failures
  int _calculateBackpressureDelay() {
    if (_consecutiveFailedFlushes <= 0) return 0;

    // Exponential backoff with jitter
    const baseDelay = 100;
    const maxDelay = 5000;
    final exponentialDelay =
        (baseDelay * (1 << (_consecutiveFailedFlushes - 1))).clamp(0, maxDelay);

    // Add 20% jitter to prevent thundering herd
    final jitter = (exponentialDelay *
            0.2 *
            (DateTime.now().millisecondsSinceEpoch % 100) /
            100)
        .round();
    final delayMs = exponentialDelay + jitter;

    _lastBackpressureDelay = DateTime.now();

    Logger.d(
      '🔔 🔔 TRACK: Applying backpressure delay: ${delayMs}ms (failures: $_consecutiveFailedFlushes, jitter: ${jitter}ms)',
    );
    return delayMs;
  }

  /// Get current backpressure metrics
  Map<String, dynamic> getBackpressureMetrics() {
    return {
      'consecutiveFailedFlushes': _consecutiveFailedFlushes,
      'totalEventsDropped': _totalEventsDropped,
      'lastEventDropTime': _lastEventDropTime?.toIso8601String(),
      'isFlushInProgress':
          _flushCompleter != null && !_flushCompleter!.isCompleted,
      'queueSize': _eventQueue.size,
      'queueUtilization': (_eventQueue.size / _getMaxQueueSize() * 100).round(),
    };
  }

  /// Get comprehensive health metrics for the analytics system
  Map<String, dynamic> getHealthMetrics() {
    final metrics = getBackpressureMetrics();

    // Add additional health indicators
    metrics.addAll({
      'systemHealth': _getSystemHealthStatus(),
      'optimalBatchSize': _getOptimalBatchSize(),
      'autoFlushEnabled': _autoFlushEnabled,
      'flushIntervalMs': _config.eventsFlushIntervalMs,
      'connectionStatus': _connectionManager.getConnectionStatus().toString(),
      'sessionId': _sessionId,
      'userId': _user.userCustomerId,
      'timestamp': DateTime.now().toIso8601String(),
      'circuitBreakerOpen': _circuitBreakerOpen,
      'circuitBreakerOpenTime': _circuitBreakerOpenTime?.toIso8601String(),
    });

    return metrics;
  }

  /// Handle events that were dropped from the queue
  void _handleDroppedEvents(List<EventData> droppedEvents) {
    if (droppedEvents.isEmpty) return;

    _totalEventsDropped += droppedEvents.length;
    _lastEventDropTime = DateTime.now();

    Logger.e(
      '🔔 🔔 TRACK: Dropped ${droppedEvents.length} events due to queue overflow (total dropped: $_totalEventsDropped)',
    );

    ErrorHandler.handleError(
      'Dropped ${droppedEvents.length} events due to queue overflow (total: $_totalEventsDropped, queue size: ${_eventQueue.size})',
      source: _source,
      category: ErrorCategory.internal,
      severity: ErrorSeverity.critical,
    );

    // Notify external callback if set
    if (_onEventsDropped != null) {
      try {
        _onEventsDropped!(droppedEvents.length, 'queue_overflow');
      } catch (e) {
        Logger.w('Error in event drop callback: $e');
      }
    }
  }

  /// Assess overall system health status
  String _getSystemHealthStatus() {
    final queueUtilization =
        (_eventQueue.size / _getMaxQueueSize() * 100).round();

    if (_circuitBreakerOpen ||
        _consecutiveFailedFlushes >= _maxConsecutiveFailures) {
      return 'CRITICAL';
    } else if (_consecutiveFailedFlushes > 2 || queueUtilization > 90) {
      return 'WARNING';
    } else if (_totalEventsDropped > 0 && _lastEventDropTime != null) {
      final timeSinceLastDrop = DateTime.now().difference(_lastEventDropTime!);
      if (timeSinceLastDrop.inMinutes < 5) {
        return 'WARNING';
      }
    }

    return 'HEALTHY';
  }

  /// Force flush events immediately (used for backpressure handling)
  Future<void> _forceFlushEvents() async {
    // Use proper async synchronization to prevent race conditions
    if (_flushCompleter != null && !_flushCompleter!.isCompleted) {
      return _flushCompleter!.future;
    }

    _flushCompleter = Completer<void>();

    try {
      Logger.d('🔔 🔔 TRACK: Force flushing events due to backpressure');
      final result = await flush();

      if (result.isSuccess) {
        _consecutiveFailedFlushes = 0; // Reset on successful flush
        Logger.d('🔔 🔔 TRACK: Force flush successful, reset failure count');
      } else {
        _consecutiveFailedFlushes++;
        Logger.w(
          '🔔 🔔 TRACK: Force flush failed, incremented failure count to $_consecutiveFailedFlushes',
        );
      }
    } catch (e) {
      _consecutiveFailedFlushes++;
      Logger.e('🔔 🔔 TRACK: Force flush exception: $e');
    } finally {
      _flushCompleter?.complete();
      _flushCompleter = null;
    }
  }
}
