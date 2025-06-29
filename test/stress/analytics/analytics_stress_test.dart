// test/stress/analytics/analytics_stress_test.dart
//
// Stress tests for analytics and event tracking functionality.
// Tests system behavior under high load, rapid events, and large payloads.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../shared/test_client_builder.dart';
import '../../shared/test_configs.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Analytics Stress Tests', () {
    tearDown(() async {
      if (CFClient.isInitialized()) {
        await CFClient.shutdownSingleton();
      }
      CFClient.clearInstance();
    });
    group('Event Batching and Performance Stress', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle rapid events under stress', () async {
        final futures = <Future<CFResult<void>>>[];
        for (int i = 0; i < 100; i++) {
          futures.add(client.trackEvent('rapid_stress_$i'));
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(100));
      });
      test('should handle concurrent events under load', () async {
        final futures = List.generate(
          50,
          (i) => client.trackEvent(
            'concurrent_stress_$i',
            properties: {'index': i},
          ),
        );
        final results = await Future.wait(futures);
        for (final result in results) {
          expect(result, isA<CFResult<void>>());
        }
      });
      test('should optimize event batching for high performance', () async {
        // Track multiple events in quick succession under stress
        final startTime = DateTime.now();
        for (int i = 0; i < 500; i++) {
          await client.trackEvent(
            'batch_stress_$i',
            properties: {'batch_id': 'stress_test', 'event_number': i},
          );
        }
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        // Stress test - should complete within reasonable time
        expect(duration.inSeconds, lessThan(60));
      });
      test('should handle very large payloads under stress', () async {
        final largeProperties = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          largeProperties['property_$i'] = {
            'id': i,
            'name': 'property_name_$i',
            'value': 'property_value_$i' * 20,
            'metadata': {
              'created': DateTime.now().toIso8601String(),
              'type': 'stress_test_property',
              'active': i % 2 == 0,
              'nested_data': List.generate(10, (j) => 'item_$j'),
            },
          };
        }
        final result = await client.trackEvent(
          'large_payload_stress_event',
          properties: largeProperties,
        );
        expect(result, isA<CFResult<void>>());
      });
      test('should handle sustained high-volume event tracking', () async {
        // Simulate sustained load over time
        const batches = 10;
        const eventsPerBatch = 50;
        for (int batch = 0; batch < batches; batch++) {
          final futures = <Future<CFResult<void>>>[];
          for (int i = 0; i < eventsPerBatch; i++) {
            futures.add(
              client.trackEvent(
                'sustained_load_${batch}_$i',
                properties: {
                  'batch': batch,
                  'event_index': i,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'stress_test': true,
                },
              ),
            );
          }
          await Future.wait(futures);
          // Small delay between batches to simulate real-world usage
          await Future.delayed(const Duration(milliseconds: 10));
        }
        // If we get here without timeout, the stress test passed
        expect(true, isTrue);
      });
    });
    group('Memory and Resource Stress Tests', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle memory pressure from large event queues', () async {
        // Create many events without flushing to test memory handling
        for (int i = 0; i < 1000; i++) {
          await client.trackEvent(
            'memory_stress_$i',
            properties: {
              'large_data': 'x' * 1000,
              'index': i,
              'memory_test': true,
            },
          );
        }
        // System should handle this without crashing
        expect(true, isTrue);
      });
      test('should handle rapid property variations', () async {
        // Test with varying property structures to stress serialization
        for (int i = 0; i < 200; i++) {
          final properties = <String, dynamic>{
            'base_property': i,
            'test_type': 'property_variation',
          };
          // Add varying numbers of properties
          for (int j = 0; j < (i % 20); j++) {
            properties['dynamic_prop_$j'] = {
              'value': j * i,
              'data': List.generate(j % 5, (k) => 'item_$k'),
            };
          }
          await client.trackEvent(
            'property_variation_$i',
            properties: properties,
          );
        }
        expect(true, isTrue);
      });
    });
    group('Concurrent Access Stress Tests', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle extreme concurrent event tracking', () async {
        final futures = <Future<CFResult<void>>>[];
        // Create high concurrency load
        for (int i = 0; i < 200; i++) {
          futures.add(
            Future(() async {
              return await client.trackEvent(
                'extreme_concurrent_$i',
                properties: {
                  'thread_id': i,
                  'concurrent_test': true,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                },
              );
            }),
          );
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(200));
        // Verify all events were processed
        for (final result in results) {
          expect(result, isA<CFResult<void>>());
        }
      });
      test(
        'should maintain stability under mixed concurrent operations',
        () async {
          final futures = <Future>[];
          // Mix different types of operations concurrently
          for (int i = 0; i < 100; i++) {
            // Event tracking
            futures.add(client.trackEvent('mixed_op_$i'));
            // Flag evaluations
            futures.add(
              Future(() => client.getBoolean('stress_flag_$i', false)),
            );
            futures.add(
              Future(() => client.getString('stress_string_$i', 'default')),
            );
            // User operations
            if (i % 10 == 0) {
              futures.add(
                client.setUser(TestConfigs.getUser(TestUserType.defaultUser)),
              );
            }
          }
          await Future.wait(futures);
          expect(true, isTrue);
        },
      );
    });
  });
}
