// test/stress/feature_flags/feature_flag_performance_stress_test.dart
// Stress tests for feature flag performance under high load.
// Tests rapid sequential evaluations, large values, and concurrent access.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../shared/test_client_builder.dart';
import '../../shared/test_configs.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Feature Flag Performance Stress Tests', () {
    group('High Volume Sequential Evaluations', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle rapid sequential flag evaluations', () {
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 10000; i++) {
          client.getBoolean('perf_bool_$i', i % 2 == 0);
          client.getString('perf_str_$i', 'default_$i');
          client.getNumber('perf_num_$i', i.toDouble());
          if (i % 100 == 0) {
            client.getJson('perf_json_$i', {'index': i});
          }
        }
        stopwatch.stop();
        // Should complete in reasonable time (< 5 seconds for 10k evaluations)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
      test('should handle large flag values efficiently', () {
        // Very large string - using default since we're in offline mode
        final largeString = 'x' * 100000;
        expect(client.getString('large_string_flag', largeString),
            equals(largeString));
        // Very large JSON - using default since we're in offline mode
        final largeJson = Map.fromEntries(
            List.generate(1000, (i) => MapEntry('key_$i', 'value_$i')));
        expect(
            client.getJson('large_json_flag', largeJson).length, equals(1000));
      });
      test('should maintain consistency under concurrent load', () async {
        final futures = <Future>[];
        // Mix of operations
        for (int i = 0; i < 100; i++) {
          futures.add(Future(() => client.getBoolean('load_test', false)));
          futures.add(Future(() => client.getString('load_test', 'default')));
          futures.add(Future(() => client.flagExists('load_test')));
          futures.add(Future(() => client.getAllFlags()));
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(400));
      });
    });
    group('Concurrent Flag Access Stress', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.standard)
            .withTestUser(TestUserType.defaultUser)
            .withInitialFlags({
          'concurrent_bool': {'enabled': true, 'value': true},
          'concurrent_string': {'enabled': true, 'value': 'test'},
          'concurrent_num': {'enabled': true, 'value': 123},
          'concurrent_json': {
            'enabled': true,
            'value': {'key': 'value'}
          },
        }).build();
      });
      test('should handle concurrent flag access', () async {
        final futures = <Future>[];
        // Concurrent reads of different flag types
        for (int i = 0; i < 50; i++) {
          futures
              .add(Future(() => client.getBoolean('concurrent_bool', false)));
          futures.add(Future(() => client.getString('concurrent_string', '')));
          futures.add(Future(() => client.getNumber('concurrent_num', 0)));
          futures.add(Future(() => client.getJson('concurrent_json', {})));
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(200));
      });
    });
  });
}
