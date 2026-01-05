// test/unit/monitoring/network_health_monitor_test.dart
//
// Tests for NetworkHealthMonitor covering metrics collection,
// health scoring, trend analysis, and diagnostic exports.
//
// This file is part of the CustomFit SDK test suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/monitoring/network_health_monitor.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NetworkHealthMonitor Tests', () {
    late NetworkHealthMonitor monitor;
    setUp(() {
      monitor = NetworkHealthMonitor.instance;
      monitor.clearAllData(); // Start with clean slate
    });
    tearDown(() {
      monitor.clearAllData();
    });
    group('Request Recording', () {
      test('should record successful requests', () {
        monitor.recordRequest(
          endpoint: 'https://api.example.com/config',
          responseTimeMs: 150,
          success: true,
        );
        final metrics =
            monitor.getEndpointMetrics('https://api.example.com/config');
        expect(metrics.totalRequests, 1);
        expect(metrics.successfulRequests, 1);
        expect(metrics.failedRequests, 0);
        expect(metrics.successRate, 1.0);
        expect(metrics.averageResponseTimeMs, 150.0);
      });
      test('should record failed requests with error types', () {
        monitor.recordRequest(
          endpoint: 'https://api.example.com/events',
          responseTimeMs: 5000,
          success: false,
          errorType: 'timeout',
        );
        final metrics =
            monitor.getEndpointMetrics('https://api.example.com/events');
        expect(metrics.totalRequests, 1);
        expect(metrics.successfulRequests, 0);
        expect(metrics.failedRequests, 1);
        expect(metrics.successRate, 0.0);
        expect(metrics.averageResponseTimeMs, 5000.0);
      });
      test('should calculate correct success rate for mixed requests', () {
        const endpoint = 'https://api.example.com/mixed';
        // Record 7 successful and 3 failed requests
        for (int i = 0; i < 7; i++) {
          monitor.recordRequest(
            endpoint: endpoint,
            responseTimeMs: 100 + i * 10,
            success: true,
          );
        }
        for (int i = 0; i < 3; i++) {
          monitor.recordRequest(
            endpoint: endpoint,
            responseTimeMs: 2000 + i * 100,
            success: false,
            errorType: 'server_error',
          );
        }
        final metrics = monitor.getEndpointMetrics(endpoint);
        expect(metrics.totalRequests, 10);
        expect(metrics.successfulRequests, 7);
        expect(metrics.failedRequests, 3);
        expect(metrics.successRate, 0.7);
      });
      test('should calculate response time percentiles correctly', () {
        const endpoint = 'https://api.example.com/percentiles';
        final responseTimes = [
          50,
          75,
          100,
          125,
          150,
          200,
          300,
          500,
          1000,
          2000
        ];
        for (final responseTime in responseTimes) {
          monitor.recordRequest(
            endpoint: endpoint,
            responseTimeMs: responseTime,
            success: true,
          );
        }
        final metrics = monitor.getEndpointMetrics(endpoint);
        expect(metrics.averageResponseTimeMs,
            responseTimes.reduce((a, b) => a + b) / responseTimes.length);
        expect(metrics.p95ResponseTimeMs,
            greaterThanOrEqualTo(1000)); // 95th percentile
        expect(metrics.p99ResponseTimeMs,
            greaterThanOrEqualTo(2000)); // 99th percentile
      });
      test('should limit stored request history', () {
        const endpoint = 'https://api.example.com/overflow';
        // Record more than max records (1000)
        for (int i = 0; i < 1200; i++) {
          monitor.recordRequest(
            endpoint: endpoint,
            responseTimeMs: 100,
            success: true,
          );
        }
        final metrics = monitor.getEndpointMetrics(endpoint);
        expect(metrics.totalRequests, 1000); // Should be limited to max
      });
    });
    group('Circuit Breaker Monitoring', () {
      test('should record circuit breaker state changes', () {
        monitor.recordCircuitBreakerEvent(
          endpoint: 'https://api.example.com/circuit',
          fromState: 'closed',
          toState: 'open',
          reason: 'failure_threshold_reached',
        );
        final metrics =
            monitor.getEndpointMetrics('https://api.example.com/circuit');
        expect(metrics.circuitBreakerState, 'open');
        expect(metrics.circuitBreakerOpens, 1);
      });
      test('should track multiple circuit breaker events', () {
        const endpoint = 'https://api.example.com/flaky';
        // Open -> Half-open -> Closed -> Open cycle
        monitor.recordCircuitBreakerEvent(
          endpoint: endpoint,
          fromState: 'closed',
          toState: 'open',
          reason: 'failures',
        );
        monitor.recordCircuitBreakerEvent(
          endpoint: endpoint,
          fromState: 'open',
          toState: 'half-open',
          reason: 'timeout_expired',
        );
        monitor.recordCircuitBreakerEvent(
          endpoint: endpoint,
          fromState: 'half-open',
          toState: 'closed',
          reason: 'successful_request',
        );
        monitor.recordCircuitBreakerEvent(
          endpoint: endpoint,
          fromState: 'closed',
          toState: 'open',
          reason: 'failures_again',
        );
        final metrics = monitor.getEndpointMetrics(endpoint);
        expect(metrics.circuitBreakerState, 'open');
        expect(metrics.circuitBreakerOpens, 2); // Two open events
      });
      test('should provide circuit breaker activity summary', () {
        final endpoints = ['api1', 'api2', 'api3'];
        for (final endpoint in endpoints) {
          monitor.recordCircuitBreakerEvent(
            endpoint: endpoint,
            fromState: 'closed',
            toState: 'open',
            reason: 'test',
          );
        }
        final activity = monitor.getCircuitBreakerActivity();
        expect(activity['total_events'], 3);
        expect(activity['endpoints_affected'], 3);
        expect(activity['events_by_endpoint']['api1']['opens'], 1);
      });
    });
    group('Health Scoring', () {
      test('should calculate overall health score correctly', () {
        // Add healthy endpoint
        for (int i = 0; i < 10; i++) {
          monitor.recordRequest(
            endpoint: 'healthy-api',
            responseTimeMs: 100,
            success: true,
          );
        }
        // Add unhealthy endpoint
        for (int i = 0; i < 10; i++) {
          monitor.recordRequest(
            endpoint: 'unhealthy-api',
            responseTimeMs: 3000,
            success: i < 3, // 30% success rate
          );
        }
        final healthScore = monitor.getOverallHealthScore();
        expect(healthScore, greaterThan(0.0));
        expect(healthScore,
            lessThan(1.0)); // Should be affected by unhealthy endpoint
      });
      test('should return perfect health score for no data', () {
        final healthScore = monitor.getOverallHealthScore();
        expect(healthScore, 1.0);
      });
      test('should factor in circuit breaker state', () {
        monitor.recordRequest(
          endpoint: 'circuit-open-api',
          responseTimeMs: 100,
          success: true,
        );
        // Before circuit opens
        final healthBefore = monitor.getOverallHealthScore();
        // Open circuit breaker
        monitor.recordCircuitBreakerEvent(
          endpoint: 'circuit-open-api',
          fromState: 'closed',
          toState: 'open',
          reason: 'test',
        );
        // After circuit opens
        final healthAfter = monitor.getOverallHealthScore();
        expect(healthAfter, lessThan(healthBefore));
      });
    });
    group('Error Pattern Analysis', () {
      test('should track recent error patterns', () {
        final errorTypes = ['timeout', 'server_error', 'network_error'];
        final errorCounts = [5, 3, 2];
        for (int i = 0; i < errorTypes.length; i++) {
          for (int j = 0; j < errorCounts[i]; j++) {
            monitor.recordRequest(
              endpoint: 'error-api',
              responseTimeMs: 1000,
              success: false,
              errorType: errorTypes[i],
            );
          }
        }
        final patterns = monitor.getRecentErrorPatterns();
        expect(patterns['timeout'], 5);
        expect(patterns['server_error'], 3);
        expect(patterns['network_error'], 2);
      });
      test('should filter errors by time window', () {
        // This would require mocking DateTime.now() to test properly
        // For now, we'll test that the method runs without error
        monitor.recordRequest(
          endpoint: 'time-api',
          responseTimeMs: 1000,
          success: false,
          errorType: 'old_error',
        );
        final patterns = monitor.getRecentErrorPatterns(
          timeWindow: const Duration(minutes: 30),
        );
        expect(patterns.containsKey('old_error'), true);
      });
    });
    group('Network Quality Trends', () {
      test('should generate network quality trend data', () {
        // Add requests with varying performance
        final responseTimes = [100, 150, 200, 500, 1000];
        final successRates = [true, true, true, false, false];
        for (int i = 0; i < responseTimes.length; i++) {
          monitor.recordRequest(
            endpoint: 'trend-api',
            responseTimeMs: responseTimes[i],
            success: successRates[i],
          );
        }
        final trend = monitor.getNetworkQualityTrend();
        expect(trend.length, greaterThan(0));
        // Each bucket should have required fields
        for (final bucket in trend) {
          expect(bucket.containsKey('timestamp'), true);
          expect(bucket.containsKey('success_rate'), true);
          expect(bucket.containsKey('average_response_time_ms'), true);
          expect(bucket.containsKey('request_count'), true);
        }
      });
    });
    group('Diagnostics Export', () {
      test('should export comprehensive diagnostics', () {
        // Setup some test data
        monitor.recordRequest(
          endpoint: 'diag-api',
          responseTimeMs: 200,
          success: true,
        );
        monitor.recordCircuitBreakerEvent(
          endpoint: 'diag-api',
          fromState: 'closed',
          toState: 'open',
          reason: 'test',
        );
        final diagnostics = monitor.exportDiagnostics();
        // Verify top-level structure
        expect(diagnostics.containsKey('timestamp'), true);
        expect(diagnostics.containsKey('overall_health_score'), true);
        expect(diagnostics.containsKey('endpoint_metrics'), true);
        expect(diagnostics.containsKey('recent_errors'), true);
        expect(diagnostics.containsKey('network_quality_trend'), true);
        expect(diagnostics.containsKey('circuit_breaker_activity'), true);
        expect(diagnostics.containsKey('system_info'), true);
        // Verify endpoint metrics
        final endpointMetrics = diagnostics['endpoint_metrics'] as Map;
        expect(endpointMetrics.containsKey('diag-api'), true);
        // Verify system info
        final systemInfo = diagnostics['system_info'] as Map;
        expect(systemInfo['total_endpoints_monitored'], 1);
        expect(systemInfo['total_requests_tracked'], 1);
      });
    });
    group('Data Management', () {
      test('should clear all data', () {
        // Add some data
        monitor.recordRequest(
          endpoint: 'clear-test',
          responseTimeMs: 100,
          success: true,
        );
        monitor.recordCircuitBreakerEvent(
          endpoint: 'clear-test',
          fromState: 'closed',
          toState: 'open',
          reason: 'test',
        );
        // Verify data exists
        expect(monitor.getAllEndpointMetrics().isNotEmpty, true);
        // Clear all data
        monitor.clearAllData();
        // Verify data is gone
        expect(monitor.getAllEndpointMetrics().isEmpty, true);
        final activity = monitor.getCircuitBreakerActivity();
        expect(activity['total_events'], 0);
      });
      test('should provide metrics for all endpoints', () {
        final endpoints = ['api1', 'api2', 'api3'];
        for (final endpoint in endpoints) {
          monitor.recordRequest(
            endpoint: endpoint,
            responseTimeMs: 100,
            success: true,
          );
        }
        final allMetrics = monitor.getAllEndpointMetrics();
        expect(allMetrics.keys.length, 3);
        expect(allMetrics.keys.toSet(), endpoints.toSet());
      });
    });
  });
}
