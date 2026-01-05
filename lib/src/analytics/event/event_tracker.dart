// lib/src/analytics/event/simplified_event_tracker.dart
//
// Simplified event tracking implementation with time-based flushing.
// Manages the collection, queuing, and transmission of analytics events to the
// CustomFit backend with simple retry logic and offline support.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';

import '../../config/core/cf_config.dart';
import '../../constants/cf_constants.dart';
import '../../core/error/cf_result.dart';
import '../../core/error/error_category.dart';
import '../../infrastructure/logging/logger.dart';
import '../../core/model/cf_user.dart';
import '../../infrastructure/types.dart';
import '../../infrastructure/network/models/track_request.dart';
import 'event_data.dart';
import 'event_type.dart';
import '../summary/summary_manager.dart';

// Type aliases imported from infrastructure/types.dart

/// Callback for event tracking notifications
typedef EventCallback = void Function(EventData event);

/// Simplified event tracking with time-based flushing
class EventTracker implements ConnectionStatusListener {
  // Simplified configuration
  static const int _maxQueueSize = 1000;
  static const int _batchSize = 50;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  final List<EventData> _eventQueue = [];
  final HttpClient _httpClient;
  final ConnectionManager _connectionManager;
  final CFUser _user;
  final String _sessionId;
  final CFConfig _config;
  final SummaryManager? _summaryManager;

  Timer? _flushTimer;
  EventCallback? _eventCallback;
  bool _isShutdown = false;
  bool _isFlushInProgress = false;
  int _totalEventsDropped = 0;

  /// Creates a new simplified event tracker
  EventTracker(
    this._httpClient,
    this._connectionManager,
    this._user,
    this._sessionId,
    this._config, {
    SummaryManager? summaryManager,
  }) : _summaryManager = summaryManager {
    _connectionManager.addConnectionStatusListener(this);
    _startFlushTimer();
    Logger.i(
      '🔔 🔔 TRACK: EventTracker initialized with simple time-based flushing, sessionId=$_sessionId',
    );
  }

  /// Setup event tracking listeners
  void setupListeners({void Function(EventData)? onEventTracked}) {
    if (onEventTracked != null) {
      setEventCallback(onEventTracked);
    }
    Logger.d('🔔 🔔 TRACK: Event tracking listeners configured');
  }

  /// Track a single event
  Future<CFResult<void>> trackEvent(
    String eventName,
    Map<String, dynamic> properties,
  ) async {
    if (_isShutdown) {
      return CFResult.error(
        'EventTracker has been shut down',
        category: ErrorCategory.internal,
      );
    }

    final result = await _trackEvent(eventName, properties);
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
        category: ErrorCategory.internal,
      );
    }

    try {
      // Basic validation
      if (eventName.isEmpty) {
        return CFResult.error(
          'Event name cannot be empty',
          category: ErrorCategory.validation,
        );
      }

      // Create event data
      final eventData = EventData.create(
        eventCustomerId: eventName,
        eventType: EventType.track,
        properties: properties,
        sessionId: _sessionId,
      );

      // Add event to queue with simple overflow handling
      if (_eventQueue.length >= _maxQueueSize) {
        // Remove oldest event to make space
        _eventQueue.removeAt(0);
        _totalEventsDropped++;
        Logger.w(
            '🔔 🔔 TRACK: Event queue full, dropped oldest event (total dropped: $_totalEventsDropped)');
      }

      _eventQueue.add(eventData);
      Logger.i(
          '🔔 🔔 TRACK: Event added to queue: $eventName, queue size: ${_eventQueue.length}');

      // Notify callback if set
      _eventCallback?.call(eventData);

      return CFResult.success(eventData);
    } catch (e) {
      final errorMsg = 'Failed to track event: ${e.toString()}';
      Logger.e('🔔 🔔 TRACK: $errorMsg');
      return CFResult.error(
        errorMsg,
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Track multiple events in batch
  Future<CFResult<void>> trackBatch(List<EventData> events) async {
    if (_isShutdown) {
      return CFResult.error(
        'EventTracker has been shut down',
        category: ErrorCategory.internal,
      );
    }

    try {
      for (final event in events) {
        if (_eventQueue.length >= _maxQueueSize) {
          _eventQueue.removeAt(0);
          _totalEventsDropped++;
        }
        _eventQueue.add(event);
      }

      Logger.i(
          '🔔 🔔 TRACK: Batch of ${events.length} events added to queue, queue size: ${_eventQueue.length}');
      return CFResult.success(null);
    } catch (e) {
      return CFResult.error(
        'Failed to track batch: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Flush events to server
  Future<CFResult<bool>> flush() async {
    Logger.i('🔔 🔔 TRACK: Beginning event flush process');

    if (_eventQueue.isEmpty) {
      Logger.d('🔔 🔔 TRACK: No events to flush');
      return CFResult.success(true);
    }

    if (_isFlushInProgress) {
      Logger.d('🔔 🔔 TRACK: Flush already in progress, skipping');
      return CFResult.success(true);
    }

    if (_connectionManager.getConnectionStatus() !=
        ConnectionStatus.connected) {
      Logger.w('🔔 🔔 TRACK: Cannot flush events: network not connected');
      return CFResult.error(
        'Cannot flush events: network not connected',
        category: ErrorCategory.network,
      );
    }

    return await _performEventFlush();
  }

  /// Performs the actual event flush operation
  Future<CFResult<bool>> _performEventFlush() async {
    _isFlushInProgress = true;

    try {
      // Flush summaries first if available
      if (_summaryManager != null) {
        Logger.d('🔔 🔔 TRACK: Flushing summaries before flushing events');
        final summaryResult = await _summaryManager.flushSummaries();
        if (!summaryResult.isSuccess) {
          Logger.w(
              '🔔 🔔 TRACK: Failed to flush summaries: ${summaryResult.getErrorMessage()}');
        }
      }

      // Get batch of events to send
      final eventsToSend = _eventQueue.take(_batchSize).toList();
      if (eventsToSend.isEmpty) {
        Logger.d('🔔 🔔 TRACK: No events to flush after batch selection');
        return CFResult.success(true);
      }

      Logger.i(
          '🔔 🔔 TRACK HTTP: Preparing to send ${eventsToSend.length} events');

      // Create request
      final request = TrackRequest(
        user: _user,
        events: eventsToSend,
        cfClientSdkVersion: CFConstants.general.sdkVersion,
      );

      final payload = request.toJsonString();
      Logger.d('🔔 🔔 TRACK HTTP: Event payload size: ${payload.length} bytes');

      // Send events to server
      final url = '${CFConstants.api.baseApiUrl}${CFConstants.api.eventsPath}';
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config.clientKey}',
        'X-CF-SDK-Version': CFConstants.general.sdkVersion,
      };

      // Simple retry logic
      CFResult<dynamic>? result;
      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          result = await _httpClient.post(url, data: payload, headers: headers);
          if (result.isSuccess) {
            break;
          }

          if (attempt < _maxRetries) {
            Logger.d(
                '🔔 🔔 TRACK: Retry $attempt failed, waiting ${_retryDelay.inSeconds}s before next attempt');
            await Future.delayed(_retryDelay);
          }
        } catch (e) {
          if (attempt < _maxRetries) {
            Logger.d(
                '🔔 🔔 TRACK: Network error on attempt $attempt, retrying: $e');
            await Future.delayed(_retryDelay);
          } else {
            rethrow;
          }
        }
      }

      if (result?.isSuccess == true) {
        // Remove sent events from queue
        _eventQueue.removeRange(0, eventsToSend.length);
        Logger.i(
            '🔔 🔔 TRACK: Successfully flushed ${eventsToSend.length} events');

        _connectionManager.recordConnectionSuccess();

        // If we have more events, we'll let the timer handle the next flush
        if (_eventQueue.isNotEmpty) {
          Logger.d(
              '🔔 🔔 TRACK: Queue still has ${_eventQueue.length} events, will flush on next timer');
        }

        return CFResult.success(true);
      } else {
        Logger.e(
            '🔔 🔔 TRACK: Failed to flush events after $_maxRetries attempts: ${result?.getErrorMessage()}');
        _connectionManager.recordConnectionFailure('Failed to flush events');
        return CFResult.error(
          result?.getErrorMessage() ?? 'Failed to flush events',
          category: ErrorCategory.network,
        );
      }
    } catch (e) {
      Logger.e('🔔 🔔 TRACK: Error during event flush: $e');
      return CFResult.error(
        'Error during event flush: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
      );
    } finally {
      _isFlushInProgress = false;
    }
  }

  /// Start the flush timer
  void _startFlushTimer() {
    if (_isShutdown) return;

    _stopFlushTimer();
    final interval = Duration(milliseconds: _config.eventsFlushIntervalMs);

    Logger.d(
        '🔔 🔔 TRACK: Starting flush timer with interval ${interval.inSeconds}s');
    _flushTimer = Timer.periodic(interval, (_) {
      if (_isShutdown) return;

      if (_eventQueue.isNotEmpty &&
          _connectionManager.getConnectionStatus() ==
              ConnectionStatus.connected &&
          !_isFlushInProgress) {
        Logger.d(
            '🔔 🔔 TRACK: Timer triggered flush, queue size: ${_eventQueue.length}');
        flush();
      }
    });
  }

  /// Stop the flush timer
  void _stopFlushTimer() {
    if (_flushTimer != null) {
      Logger.d('🔔 🔔 TRACK: Stopping flush timer');
      _flushTimer!.cancel();
      _flushTimer = null;
    }
  }

  /// Set event callback
  void setEventCallback(EventCallback callback) {
    _eventCallback = callback;
  }

  /// Remove event callback
  void removeEventCallback() {
    _eventCallback = null;
  }

  /// Get current queue size
  int get queueSize => _eventQueue.length;

  /// Get total events dropped
  int get totalEventsDropped => _totalEventsDropped;

  /// Check if queue is empty
  bool get isEmpty => _eventQueue.isEmpty;

  /// Get pending events count
  int getPendingEventsCount() => _eventQueue.length;

  /// Flush events (alias for flush)
  Future<CFResult<bool>> flushEvents() async {
    Logger.i('🔔 🔔 TRACK: flushEvents() called - delegating to flush()');
    return await flush();
  }

  /// Shutdown the event tracker
  Future<void> shutdown() async {
    if (_isShutdown) return;

    Logger.i('🔔 🔔 TRACK: Shutting down EventTracker');
    _isShutdown = true;

    _stopFlushTimer();
    _connectionManager.removeConnectionStatusListener(this);

    // Try to flush remaining events
    if (_eventQueue.isNotEmpty) {
      Logger.i(
          '🔔 🔔 TRACK: Flushing ${_eventQueue.length} remaining events before shutdown');
      await flush();
    }

    _eventQueue.clear();
    Logger.i('🔔 🔔 TRACK: EventTracker shutdown complete');
  }

  /// Connection status listener implementation
  @override
  void onConnectionStatusChanged(
      ConnectionStatus status, ConnectionInformation info) {
    Logger.d('🔔 🔔 TRACK: Connection status changed to: $status');

    if (status == ConnectionStatus.connected &&
        _eventQueue.isNotEmpty &&
        !_isFlushInProgress) {
      Logger.d('🔔 🔔 TRACK: Connection restored, triggering flush');
      flush();
    }
  }

  /// Get simple health metrics
  Map<String, dynamic> getHealthMetrics() {
    return {
      'queueSize': _eventQueue.length,
      'totalEventsDropped': _totalEventsDropped,
      'isFlushInProgress': _isFlushInProgress,
      'connectionStatus': _connectionManager.getConnectionStatus().toString(),
      'sessionId': _sessionId,
      'userId': _user.userCustomerId,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Set auto flush enabled (simplified for compatibility)
  void setAutoFlushEnabled(bool enabled) {
    Logger.d(
        '🔔 🔔 TRACK: Auto flush ${enabled ? 'enabled' : 'disabled'} (simplified)');
  }

  /// Get backpressure metrics (simplified for compatibility)
  Map<String, dynamic> getBackpressureMetrics() {
    return {
      'totalEventsDropped': _totalEventsDropped,
      'queueSize': _eventQueue.length,
      'queueUtilization': (_eventQueue.length / _maxQueueSize * 100).round(),
      'isFlushInProgress': _isFlushInProgress,
    };
  }
}
