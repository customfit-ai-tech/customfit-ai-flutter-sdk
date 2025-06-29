// lib/src/monitoring/network_health_monitor.dart
//
// Network health monitoring and diagnostics system for the CustomFit SDK.
// Tracks request success/failure rates, response times, circuit breaker states,
// and provides comprehensive network health metrics.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:collection';

import '../logging/logger.dart';

/// Network health metrics data structure
class NetworkHealthMetrics {
  final String endpoint;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final double successRate;
  final double averageResponseTimeMs;
  final double p95ResponseTimeMs;
  final double p99ResponseTimeMs;
  final int circuitBreakerOpens;
  final String circuitBreakerState;
  final DateTime lastUpdated;

  NetworkHealthMetrics({
    required this.endpoint,
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.successRate,
    required this.averageResponseTimeMs,
    required this.p95ResponseTimeMs,
    required this.p99ResponseTimeMs,
    required this.circuitBreakerOpens,
    required this.circuitBreakerState,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'endpoint': endpoint,
      'total_requests': totalRequests,
      'successful_requests': successfulRequests,
      'failed_requests': failedRequests,
      'success_rate': successRate,
      'average_response_time_ms': averageResponseTimeMs,
      'p95_response_time_ms': p95ResponseTimeMs,
      'p99_response_time_ms': p99ResponseTimeMs,
      'circuit_breaker_opens': circuitBreakerOpens,
      'circuit_breaker_state': circuitBreakerState,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

/// Individual request record for tracking
class RequestRecord {
  final String endpoint;
  final DateTime timestamp;
  final int responseTimeMs;
  final bool success;
  final String? errorType;

  RequestRecord({
    required this.endpoint,
    required this.timestamp,
    required this.responseTimeMs,
    required this.success,
    this.errorType,
  });
}

/// Circuit breaker state change record
class CircuitBreakerEvent {
  final String endpoint;
  final DateTime timestamp;
  final String fromState;
  final String toState;
  final String reason;

  CircuitBreakerEvent({
    required this.endpoint,
    required this.timestamp,
    required this.fromState,
    required this.toState,
    required this.reason,
  });
}

/// Comprehensive network health monitoring system
class NetworkHealthMonitor {
  static const String _source = 'NetworkHealthMonitor';
  static const int _maxRecords = 1000; // Keep last 1000 requests per endpoint
  static const int _maxCircuitEvents = 100; // Keep last 100 circuit events

  // Request history per endpoint
  final Map<String, Queue<RequestRecord>> _requestHistory = {};

  // Circuit breaker event history
  final Queue<CircuitBreakerEvent> _circuitBreakerEvents = Queue();

  // Active circuit breaker references
  final Map<String, String> _circuitBreakerStates = {};

  // Singleton instance
  static final NetworkHealthMonitor _instance =
      NetworkHealthMonitor._internal();
  static NetworkHealthMonitor get instance => _instance;

  NetworkHealthMonitor._internal();

  /// Record a network request completion
  void recordRequest({
    required String endpoint,
    required int responseTimeMs,
    required bool success,
    String? errorType,
  }) {
    final record = RequestRecord(
      endpoint: endpoint,
      timestamp: DateTime.now(),
      responseTimeMs: responseTimeMs,
      success: success,
      errorType: errorType,
    );

    _requestHistory.putIfAbsent(endpoint, () => Queue<RequestRecord>());
    final endpointHistory = _requestHistory[endpoint]!;

    endpointHistory.addLast(record);

    // Keep only the most recent records
    while (endpointHistory.length > _maxRecords) {
      endpointHistory.removeFirst();
    }

    Logger.d('$_source: Recorded request to $endpoint: '
        '${success ? 'SUCCESS' : 'FAILURE'} in ${responseTimeMs}ms');
  }

  /// Record a circuit breaker state change
  void recordCircuitBreakerEvent({
    required String endpoint,
    required String fromState,
    required String toState,
    required String reason,
  }) {
    final event = CircuitBreakerEvent(
      endpoint: endpoint,
      timestamp: DateTime.now(),
      fromState: fromState,
      toState: toState,
      reason: reason,
    );

    _circuitBreakerEvents.addLast(event);
    _circuitBreakerStates[endpoint] = toState;

    // Keep only recent events
    while (_circuitBreakerEvents.length > _maxCircuitEvents) {
      _circuitBreakerEvents.removeFirst();
    }

    Logger.i(
        '$_source: Circuit breaker for $endpoint: $fromState -> $toState ($reason)');
  }

  /// Get comprehensive health metrics for an endpoint
  NetworkHealthMetrics getEndpointMetrics(String endpoint) {
    final history = _requestHistory[endpoint] ?? Queue<RequestRecord>();

    if (history.isEmpty) {
      // Count circuit breaker opens for this endpoint even if no requests
      final circuitBreakerOpens = _circuitBreakerEvents
          .where((e) => e.endpoint == endpoint && e.toState == 'open')
          .length;

      return NetworkHealthMetrics(
        endpoint: endpoint,
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        successRate: 0.0,
        averageResponseTimeMs: 0.0,
        p95ResponseTimeMs: 0.0,
        p99ResponseTimeMs: 0.0,
        circuitBreakerOpens: circuitBreakerOpens,
        circuitBreakerState: _circuitBreakerStates[endpoint] ?? 'unknown',
        lastUpdated: DateTime.now(),
      );
    }

    final totalRequests = history.length;
    final successfulRequests = history.where((r) => r.success).length;
    final failedRequests = totalRequests - successfulRequests;
    final successRate =
        totalRequests > 0 ? successfulRequests / totalRequests : 0.0;

    // Calculate response time statistics
    final responseTimes = history.map((r) => r.responseTimeMs).toList()..sort();
    final averageResponseTime = responseTimes.isEmpty
        ? 0.0
        : responseTimes.reduce((a, b) => a + b) / responseTimes.length;

    final p95ResponseTime = _percentile(responseTimes, 95);
    final p99ResponseTime = _percentile(responseTimes, 99);

    // Count circuit breaker opens for this endpoint
    final circuitBreakerOpens = _circuitBreakerEvents
        .where((e) => e.endpoint == endpoint && e.toState == 'open')
        .length;

    final circuitBreakerState = _circuitBreakerStates[endpoint] ?? 'unknown';

    return NetworkHealthMetrics(
      endpoint: endpoint,
      totalRequests: totalRequests,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      successRate: successRate,
      averageResponseTimeMs: averageResponseTime,
      p95ResponseTimeMs: p95ResponseTime,
      p99ResponseTimeMs: p99ResponseTime,
      circuitBreakerOpens: circuitBreakerOpens,
      circuitBreakerState: circuitBreakerState,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get metrics for all monitored endpoints
  Map<String, NetworkHealthMetrics> getAllEndpointMetrics() {
    final metrics = <String, NetworkHealthMetrics>{};

    for (final endpoint in _requestHistory.keys) {
      metrics[endpoint] = getEndpointMetrics(endpoint);
    }

    return metrics;
  }

  /// Get overall system health score (0.0 to 1.0)
  double getOverallHealthScore() {
    final allMetrics = getAllEndpointMetrics().values;

    if (allMetrics.isEmpty) return 1.0;

    double totalScore = 0.0;
    int scoreCount = 0;

    for (final metrics in allMetrics) {
      if (metrics.totalRequests > 0) {
        // Weight success rate more heavily than response time
        final successScore = metrics.successRate;
        final responseTimeScore =
            _calculateResponseTimeScore(metrics.averageResponseTimeMs);
        final circuitBreakerScore =
            metrics.circuitBreakerState == 'open' ? 0.0 : 1.0;

        final endpointScore = (successScore * 0.6) +
            (responseTimeScore * 0.3) +
            (circuitBreakerScore * 0.1);

        totalScore += endpointScore;
        scoreCount++;
      }
    }

    return scoreCount > 0 ? totalScore / scoreCount : 1.0;
  }

  /// Get recent error patterns
  Map<String, int> getRecentErrorPatterns({Duration? timeWindow}) {
    timeWindow ??= const Duration(hours: 1);
    final cutoff = DateTime.now().subtract(timeWindow);
    final errorCounts = <String, int>{};

    for (final history in _requestHistory.values) {
      for (final record in history) {
        if (record.timestamp.isAfter(cutoff) &&
            !record.success &&
            record.errorType != null) {
          errorCounts[record.errorType!] =
              (errorCounts[record.errorType!] ?? 0) + 1;
        }
      }
    }

    return errorCounts;
  }

  /// Get network quality trends
  List<Map<String, dynamic>> getNetworkQualityTrend({
    Duration? timeWindow,
    Duration? bucketSize,
  }) {
    timeWindow ??= const Duration(hours: 6);
    bucketSize ??= const Duration(minutes: 30);

    final now = DateTime.now();
    final startTime = now.subtract(timeWindow);
    final buckets = <DateTime, List<RequestRecord>>{};

    // Initialize time buckets
    DateTime bucketTime = startTime;
    while (bucketTime.isBefore(now)) {
      buckets[bucketTime] = [];
      bucketTime = bucketTime.add(bucketSize);
    }

    // Distribute records into buckets
    for (final history in _requestHistory.values) {
      for (final record in history) {
        if (record.timestamp.isAfter(startTime)) {
          final bucketKey =
              _findBucket(record.timestamp, buckets.keys.toList(), bucketSize);
          if (bucketKey != null) {
            buckets[bucketKey]!.add(record);
          }
        }
      }
    }

    // Calculate metrics for each bucket
    final trend = <Map<String, dynamic>>[];
    for (final entry in buckets.entries) {
      final records = entry.value;
      final successRate = records.isEmpty
          ? 1.0
          : records.where((r) => r.success).length / records.length;

      final avgResponseTime = records.isEmpty
          ? 0.0
          : records.map((r) => r.responseTimeMs).reduce((a, b) => a + b) /
              records.length;

      trend.add({
        'timestamp': entry.key.toIso8601String(),
        'success_rate': successRate,
        'average_response_time_ms': avgResponseTime,
        'request_count': records.length,
      });
    }

    return trend;
  }

  /// Get circuit breaker activity summary
  Map<String, dynamic> getCircuitBreakerActivity({Duration? timeWindow}) {
    timeWindow ??= const Duration(hours: 24);
    final cutoff = DateTime.now().subtract(timeWindow);

    final recentEvents = _circuitBreakerEvents
        .where((e) => e.timestamp.isAfter(cutoff))
        .toList();

    final eventsByEndpoint = <String, List<CircuitBreakerEvent>>{};
    for (final event in recentEvents) {
      eventsByEndpoint.putIfAbsent(event.endpoint, () => []);
      eventsByEndpoint[event.endpoint]!.add(event);
    }

    final summary = <String, dynamic>{
      'total_events': recentEvents.length,
      'endpoints_affected': eventsByEndpoint.keys.length,
      'events_by_endpoint': {},
    };

    for (final entry in eventsByEndpoint.entries) {
      final endpoint = entry.key;
      final events = entry.value;

      summary['events_by_endpoint'][endpoint] = {
        'total_events': events.length,
        'opens': events.where((e) => e.toState == 'open').length,
        'closes': events.where((e) => e.toState == 'closed').length,
        'half_opens': events.where((e) => e.toState == 'half-open').length,
        'current_state': _circuitBreakerStates[endpoint] ?? 'unknown',
      };
    }

    return summary;
  }

  /// Export detailed diagnostics data
  Map<String, dynamic> exportDiagnostics() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'overall_health_score': getOverallHealthScore(),
      'endpoint_metrics': getAllEndpointMetrics()
          .map((endpoint, metrics) => MapEntry(endpoint, metrics.toMap())),
      'recent_errors': getRecentErrorPatterns(),
      'network_quality_trend': getNetworkQualityTrend(),
      'circuit_breaker_activity': getCircuitBreakerActivity(),
      'system_info': {
        'total_endpoints_monitored': _requestHistory.keys.length,
        'total_requests_tracked': _requestHistory.values
            .map((q) => q.length)
            .fold(0, (a, b) => a + b),
        'circuit_breaker_events_tracked': _circuitBreakerEvents.length,
      },
    };
  }

  /// Clear all monitoring data
  void clearAllData() {
    _requestHistory.clear();
    _circuitBreakerEvents.clear();
    _circuitBreakerStates.clear();
    Logger.i('$_source: All monitoring data cleared');
  }

  /// Clear data older than specified duration
  void clearOldData({Duration? maxAge}) {
    maxAge ??= const Duration(days: 7);
    final cutoff = DateTime.now().subtract(maxAge);

    // Clear old request records
    for (final history in _requestHistory.values) {
      history.removeWhere((record) => record.timestamp.isBefore(cutoff));
    }

    // Clear old circuit breaker events
    _circuitBreakerEvents
        .removeWhere((event) => event.timestamp.isBefore(cutoff));

    Logger.i('$_source: Cleared data older than ${maxAge.inDays} days');
  }

  // Helper methods

  double _percentile(List<int> sortedValues, int percentile) {
    if (sortedValues.isEmpty) return 0.0;

    final index = (sortedValues.length * percentile / 100).floor();
    return sortedValues[index.clamp(0, sortedValues.length - 1)].toDouble();
  }

  double _calculateResponseTimeScore(double avgResponseTimeMs) {
    // Score decreases as response time increases
    // 0-100ms = 1.0, 100-500ms = 0.8, 500-1000ms = 0.5, >1000ms = 0.2
    if (avgResponseTimeMs <= 100) {
      return 1.0; // CFConstants.networkHealth.excellentResponseTimeMs & excellentHealthScore
    }
    if (avgResponseTimeMs <= 500) {
      return 0.8; // CFConstants.networkHealth.goodResponseTimeMs & goodHealthScore
    }
    if (avgResponseTimeMs <= 1000) {
      return 0.5; // CFConstants.networkHealth.poorResponseTimeMs & poorHealthScore
    }
    return 0.2; // CFConstants.networkHealth.veryPoorHealthScore
  }

  DateTime? _findBucket(
      DateTime timestamp, List<DateTime> bucketKeys, Duration bucketSize) {
    for (final bucketKey in bucketKeys) {
      if (timestamp.isAfter(bucketKey) &&
          timestamp.isBefore(bucketKey.add(bucketSize))) {
        return bucketKey;
      }
    }
    return null;
  }
}
