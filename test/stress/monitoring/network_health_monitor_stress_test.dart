// test/stress/monitoring/network_health_monitor_stress_test.dart
// Stress tests for network health monitoring under high load.
// Tests high volume request tracking and performance calculations.
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/monitoring/network_health_monitor.dart';
import 'package:customfit_ai_flutter_sdk/src/logging/logger.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Network Health Monitor Stress Tests', () {
    late NetworkHealthMonitor monitor;
    setUp(() {
      monitor = NetworkHealthMonitor.instance;
    });
    tearDown(() {
      monitor.clearAllData();
    });
    group('High Volume Request Tracking', () {
      test('should handle high volume of requests efficiently', () {
        final startTime = DateTime.now();
        // Record 10,000 requests
        for (int i = 0; i < 10000; i++) {
          monitor.recordRequest(
            endpoint: 'load-test-${i % 10}', // 10 different endpoints
            responseTimeMs: Random().nextInt(1000),
            success: Random().nextBool(),
          );
        }
        final duration = DateTime.now().difference(startTime);
        Logger.d('Recorded 10,000 requests in ${duration.inMilliseconds}ms');
        // Should complete in reasonable time
        expect(duration.inSeconds, lessThan(5));
        // Verify data integrity
        final allMetrics = monitor.getAllEndpointMetrics();
        expect(allMetrics.keys.length, 10);
        final totalRequests = allMetrics.values
            .map((m) => m.totalRequests)
            .reduce((a, b) => a + b);
        expect(totalRequests, 10000);
      });
      test('should calculate health score efficiently for many endpoints', () {
        // Create 100 endpoints with various health patterns
        for (int i = 0; i < 100; i++) {
          final successRate = i / 100; // Varying success rates
          const requestCount = 10;
          for (int j = 0; j < requestCount; j++) {
            monitor.recordRequest(
              endpoint: 'perf-test-$i',
              responseTimeMs: 100 + (i * 10), // Varying response times
              success: j < (requestCount * successRate),
            );
          }
        }
        final startTime = DateTime.now();
        final healthScore = monitor.getOverallHealthScore();
        final duration = DateTime.now().difference(startTime);
        Logger.d(
            'Calculated health score for 100 endpoints in ${duration.inMilliseconds}ms');
        expect(duration.inMilliseconds, lessThan(100)); // Should be very fast
        expect(healthScore, greaterThanOrEqualTo(0.0));
        expect(healthScore, lessThanOrEqualTo(1.0));
      });
      test('should handle massive circuit breaker event logging', () {
        final startTime = DateTime.now();
        // Record 1000 circuit breaker events
        for (int i = 0; i < 1000; i++) {
          monitor.recordCircuitBreakerEvent(
            endpoint: 'cb-test-${i % 20}', // 20 different endpoints
            fromState: i % 2 == 0 ? 'closed' : 'open',
            toState: i % 2 == 0 ? 'open' : 'closed',
            reason: 'stress_test_$i',
          );
        }
        final duration = DateTime.now().difference(startTime);
        Logger.d(
            'Recorded 1000 circuit breaker events in ${duration.inMilliseconds}ms');
        // Should complete in reasonable time
        expect(duration.inSeconds, lessThan(2));
        // Verify data integrity
        final activity = monitor.getCircuitBreakerActivity();
        expect(activity['total_events'], 1000);
      });
    });
    group('Memory Management Under Load', () {
      test('should maintain memory efficiency with large data sets', () {
        // Simulate a long-running application with many requests
        for (int batch = 0; batch < 10; batch++) {
          for (int i = 0; i < 1200; i++) {
            monitor.recordRequest(
              endpoint: 'memory-test-${i % 50}', // 50 different endpoints
              responseTimeMs: Random().nextInt(2000),
              success: Random().nextBool(),
            );
          }
          // Periodically check that we're not accumulating too much data
          final allMetrics = monitor.getAllEndpointMetrics();
          expect(allMetrics.keys.length, lessThanOrEqualTo(50));
        }
        // Should have processed 12,000 requests total
        final allMetrics = monitor.getAllEndpointMetrics();
        final totalRequests = allMetrics.values
            .map((m) => m.totalRequests)
            .reduce((a, b) => a + b);
        expect(totalRequests, 12000);
      });
      test('should handle concurrent data access under stress', () async {
        // Setup initial data
        for (int i = 0; i < 100; i++) {
          monitor.recordRequest(
            endpoint: 'concurrent-test-$i',
            responseTimeMs: Random().nextInt(1000),
            success: Random().nextBool(),
          );
        }
        // Concurrent operations
        final futures = <Future>[];
        for (int i = 0; i < 50; i++) {
          futures.add(Future(() => monitor.getOverallHealthScore()));
          futures.add(Future(() => monitor.getAllEndpointMetrics()));
          futures.add(Future(() => monitor.getRecentErrorPatterns()));
          futures.add(Future(() => monitor.getNetworkQualityTrend()));
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(200));
      });
    });
  });
}
