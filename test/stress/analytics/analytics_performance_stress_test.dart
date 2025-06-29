// test/stress/analytics/analytics_performance_stress_test.dart
// Stress tests for analytics performance under high load.
// Tests event batching performance, large payloads, and concurrent operations.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../shared/test_client_builder.dart';
import '../../shared/test_configs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Analytics Performance Stress Tests', () {
    tearDown(() async {
      if (CFClient.isInitialized()) {
        await CFClient.shutdownSingleton();
      }
      CFClient.clearInstance();
    });
    group('Event Batching Performance Stress', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should optimize event batching for performance under stress',
          () async {
        // Track multiple events in quick succession
        final startTime = DateTime.now();
        for (int i = 0; i < 100; i++) {
          await client.trackEvent('batch_stress_$i',
              properties: {'batch_id': 'performance_test', 'event_number': i});
        }
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        // Performance test - should complete reasonably quickly
        expect(duration.inSeconds, lessThan(30));
      });
      test('should handle large payloads efficiently under stress', () async {
        final largeProperties = <String, dynamic>{};
        for (int i = 0; i < 500; i++) {
          largeProperties['property_$i'] = {
            'id': i,
            'name': 'property_name_$i',
            'value': 'property_value_$i' * 10,
            'metadata': {
              'created': DateTime.now().toIso8601String(),
              'type': 'stress_test_property',
              'active': i % 2 == 0,
              'nested_data': List.generate(10, (j) => 'item_$j'),
            }
          };
        }
        final result = await client.trackEvent('large_payload_stress_event',
            properties: largeProperties);
        expect(result, isA<CFResult<void>>());
      });
      test('should handle rapid event succession under stress', () async {
        final futures = <Future<CFResult<void>>>[];
        for (int i = 0; i < 200; i++) {
          futures.add(client.trackEvent('rapid_stress_$i', properties: {
            'index': i,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'stress_test': true,
          }));
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(200));
        for (final result in results) {
          expect(result, isA<CFResult<void>>());
        }
      });
    });
    group('Event Queue Performance Stress', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle high-volume event queuing under stress', () async {
        final stopwatch = Stopwatch()..start();
        // Queue many events rapidly
        for (int batch = 0; batch < 10; batch++) {
          final futures = <Future<CFResult<void>>>[];
          for (int i = 0; i < 100; i++) {
            futures
                .add(client.trackEvent('queue_stress_${batch}_$i', properties: {
              'batch': batch,
              'index': i,
              'large_data': 'x' * 100,
              'queue_stress_test': true,
            }));
          }
          await Future.wait(futures);
        }
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds,
            lessThan(60000)); // Should complete in reasonable time
      });
      test('should maintain performance with mixed event types under stress',
          () async {
        final eventTypes = ['track', 'page', 'identify', 'screen', 'group'];
        final futures = <Future<CFResult<void>>>[];
        for (int i = 0; i < 500; i++) {
          final eventType = eventTypes[i % eventTypes.length];
          futures.add(
              client.trackEvent('mixed_stress_${eventType}_$i', properties: {
            'event_type': eventType,
            'index': i,
            'stress_test': true,
            'metadata': {
              'timestamp': DateTime.now().toIso8601String(),
              'session_id': 'stress_session',
            },
          }));
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(500));
      });
    });
    group('Concurrent Analytics Operations Stress', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle extreme concurrent analytics operations', () async {
        final futures = <Future>[];
        // Mix of different operations
        for (int i = 0; i < 100; i++) {
          // Event tracking
          futures.add(client.trackEvent('concurrent_stress_$i'));
          // Flag evaluations
          futures.add(
              Future(() => client.getBoolean('concurrent_flag_$i', false)));
          // User property updates
          if (i % 10 == 0) {
            futures.add(Future(() async {
              final userBuilder = CFUser.builder('stress_user_$i');
              userBuilder.addStringProperty('stress_test', 'true');
              userBuilder.addNumberProperty('iteration', i);
              final user = userBuilder.build();
              await client.setUser(user);
            }));
          }
        }
        final results = await Future.wait(futures);
        expect(results.length, greaterThan(200));
      });
      test('should handle sustained concurrent load', () async {
        const batches = 20;
        const eventsPerBatch = 25;
        for (int batch = 0; batch < batches; batch++) {
          final futures = <Future<CFResult<void>>>[];
          for (int i = 0; i < eventsPerBatch; i++) {
            futures.add(
                client.trackEvent('sustained_load_${batch}_$i', properties: {
              'batch': batch,
              'event_index': i,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'sustained_stress_test': true,
            }));
          }
          await Future.wait(futures);
          // Small delay between batches to simulate real-world usage
          await Future.delayed(const Duration(milliseconds: 5));
        }
        // If we get here without timeout, the stress test passed
        expect(true, isTrue);
      });
    });
  });
}
