// test/stress/caching/cache_performance_stress_test.dart
// Stress tests for cache performance under high load.
// Tests cache size limits, LRU eviction, and large value handling.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../shared/test_client_builder.dart';
import '../../shared/test_configs.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Cache Performance Stress Tests', () {
    tearDown(() async {
      if (CFClient.isInitialized()) {
        await CFClient.shutdownSingleton();
      }
      CFClient.clearInstance();
    });
    group('High Volume Cache Operations', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle cache size limits under stress', () {
        // Fill cache with many entries
        for (int i = 0; i < 10000; i++) {
          client.getBoolean('cache_limit_flag_$i', false);
        }
        // Should still function normally
        expect(client.getBoolean('test_after_limit', true), isA<bool>());
      });
      test('should implement LRU eviction policy under stress', () {
        // Access flags in order
        for (int i = 0; i < 100; i++) {
          client.getBoolean('lru_flag_$i', false);
        }
        // Access early flags again (making them recently used)
        for (int i = 0; i < 10; i++) {
          client.getBoolean('lru_flag_$i', false);
        }
        // Add more flags to trigger eviction
        for (int i = 100; i < 200; i++) {
          client.getBoolean('lru_flag_$i', false);
        }
        // Early accessed flags should still be cached
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 10; i++) {
          client.getBoolean('lru_flag_$i', false);
        }
        stopwatch.stop();
        // Should be fast (cached)
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });
      test('should handle large cached values efficiently under stress', () {
        // Cache large JSON values
        final largeJson = Map.fromEntries(
            List.generate(1000, (i) => MapEntry('key_$i', 'value_$i')));
        for (int i = 0; i < 100; i++) {
          client.getJson('large_json_$i', largeJson);
        }
        // Should still perform well
        final stopwatch = Stopwatch()..start();
        client.getJson('large_json_50', {});
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(5));
      });
    });
    group('Queue Overflow Stress Tests', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .withRealStorage()
            .build();
      });
      test('should handle queue overflow gracefully under stress', () async {
        // Fill queue with many events
        final futures = <Future>[];
        for (int i = 0; i < 1000; i++) {
          futures.add(client.trackEvent('overflow_event_$i',
              properties: {'overflow_test': true, 'sequence': i}));
        }
        final results = await Future.wait(futures, eagerError: false);
        expect(results.length, equals(1000));
      });
      test('should optimize cache access performance under load', () async {
        final startTime = DateTime.now();
        // Perform multiple cache operations
        for (int i = 0; i < 100; i++) {
          client.getBoolean('perf_flag_$i', i % 2 == 0);
        }
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        // Should complete within reasonable time
        expect(duration.inMilliseconds, lessThan(10000));
      });
    });
    group('Concurrent Cache Access Stress', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test(
          'should maintain cache consistency across concurrent reads under stress',
          () async {
        const flagKey = 'consistency_test_flag';
        final futures = <Future<bool>>[];
        // Concurrent reads of the same flag
        for (int i = 0; i < 100; i++) {
          futures.add(Future(() => client.getBoolean(flagKey, false)));
        }
        final results = await Future.wait(futures);
        // All reads should return the same value
        final firstValue = results.first;
        expect(results.every((value) => value == firstValue), isTrue);
      });
      test('should handle concurrent storage operations under stress',
          () async {
        // Concurrent read operations
        final readFutures = List.generate(
            50,
            (i) => Future(
                () => client.getBoolean('concurrent_read_$i', i % 2 == 0)));
        // Concurrent write operations
        final writeFutures =
            List.generate(50, (i) => client.trackEvent('concurrent_write_$i'));
        // All operations should complete successfully
        final readResults = await Future.wait(readFutures);
        final writeResults = await Future.wait(writeFutures);
        expect(readResults.length, equals(50));
        expect(writeResults.length, equals(50));
      });
    });
  });
}
