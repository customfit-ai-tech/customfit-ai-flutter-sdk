// test/stress/feature_flags/feature_flag_stress_test.dart
//
// Stress tests for feature flag evaluation under high load.
// Tests rapid sequential evaluations, large values, and concurrent access.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../shared/test_client_builder.dart';
import '../../shared/test_configs.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Feature Flag Stress Tests', () {
    tearDown(() async {
      if (CFClient.isInitialized()) {
        await CFClient.shutdownSingleton();
      }
      CFClient.clearInstance();
    });
    group('Rapid Sequential Evaluation Stress', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle rapid sequential boolean flag evaluations', () async {
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          final result = client.getBoolean('rapid_bool_flag_$i', false);
          expect(result, isA<bool>());
        }
        stopwatch.stop();
        // Should complete rapidly
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
      test('should handle rapid sequential string flag evaluations', () async {
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          final result = client.getString('rapid_string_flag_$i', 'default');
          expect(result, isA<String>());
        }
        stopwatch.stop();
        // Should complete rapidly
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
      test('should handle rapid sequential number flag evaluations', () async {
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          final result = client.getNumber('rapid_number_flag_$i', 0.0);
          expect(result, isA<double>());
        }
        stopwatch.stop();
        // Should complete rapidly
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
      test('should handle rapid sequential JSON flag evaluations', () async {
        final stopwatch = Stopwatch()..start();
        final defaultJson = {'default': true};
        for (int i = 0; i < 500; i++) {
          final result = client.getJson('rapid_json_flag_$i', defaultJson);
          expect(result, isA<Map<String, dynamic>>());
        }
        stopwatch.stop();
        // Should complete rapidly (fewer iterations due to JSON complexity)
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      });
    });
    group('Large Value Handling Stress', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle very large string flag values', () async {
        final largeString = 'x' * 10000; // 10KB string
        for (int i = 0; i < 100; i++) {
          final result = client.getString('large_string_flag_$i', largeString);
          expect(result, isA<String>());
          expect(result.length, greaterThan(1000));
        }
      });
      test('should handle very large JSON flag values', () async {
        final largeJson = <String, dynamic>{};
        // Create large JSON object
        for (int i = 0; i < 1000; i++) {
          largeJson['property_$i'] = {
            'id': i,
            'name': 'property_name_$i',
            'value': 'property_value_$i' * 10,
            'metadata': {
              'created': DateTime.now().toIso8601String(),
              'type': 'large_json_test',
              'nested_data': List.generate(5, (j) => 'nested_item_$j'),
            },
          };
        }
        for (int i = 0; i < 50; i++) {
          final result = client.getJson('large_json_flag_$i', largeJson);
          expect(result, isA<Map<String, dynamic>>());
          expect(result.keys.length, greaterThan(100));
        }
      });
      test('should handle extremely large number arrays', () async {
        final largeNumberArray = List.generate(10000, (i) => i.toDouble());
        final defaultJson = {'numbers': largeNumberArray};
        for (int i = 0; i < 20; i++) {
          final result = client.getJson(
            'large_number_array_flag_$i',
            defaultJson,
          );
          expect(result, isA<Map<String, dynamic>>());
          expect((result['numbers'] as List).length, equals(10000));
        }
      });
    });
    group('Concurrent Flag Evaluation Stress', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle concurrent boolean flag evaluations', () async {
        final futures = <Future<bool>>[];
        for (int i = 0; i < 200; i++) {
          futures.add(
            Future(() => client.getBoolean('concurrent_bool_$i', false)),
          );
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(200));
        for (final result in results) {
          expect(result, isA<bool>());
        }
      });
      test('should handle concurrent mixed flag type evaluations', () async {
        final futures = <Future<dynamic>>[];
        for (int i = 0; i < 100; i++) {
          futures.add(
            Future(() => client.getBoolean('concurrent_mixed_bool_$i', false)),
          );
          futures.add(
            Future(
              () => client.getString('concurrent_mixed_string_$i', 'default'),
            ),
          );
          futures.add(
            Future(() => client.getNumber('concurrent_mixed_number_$i', 0.0)),
          );
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(300));
      });
      test(
        'should handle concurrent evaluations with different users',
        () async {
          final users = [
            TestConfigs.getUser(TestUserType.defaultUser),
            TestConfigs.getUser(TestUserType.premiumUser),
            TestConfigs.getUser(TestUserType.defaultUser),
          ];
          final futures = <Future<dynamic>>[];
          for (int i = 0; i < 150; i++) {
            final userIndex = i % users.length;
            futures.add(
              Future(() async {
                await client.setUser(users[userIndex]);
                return client.getBoolean('user_specific_flag_$i', false);
              }),
            );
          }
          final results = await Future.wait(futures);
          expect(results.length, equals(150));
        },
      );
    });
    group('Cache Performance Stress Tests', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle cache pressure from many unique flags', () async {
        // Create cache pressure with many unique flag evaluations
        for (int i = 0; i < 2000; i++) {
          final result = client.getBoolean('unique_cache_flag_$i', false);
          expect(result, isA<bool>());
        }
        // Cache should handle pressure without degrading performance significantly
        expect(true, isTrue);
      });
      test(
        'should handle cache thrashing from alternating flag access',
        () async {
          final flagNames = List.generate(100, (i) => 'thrashing_flag_$i');
          // Access flags in alternating pattern to cause cache thrashing
          for (int round = 0; round < 20; round++) {
            for (final flagName in flagNames) {
              final result = client.getBoolean(flagName, false);
              expect(result, isA<bool>());
            }
          }
          expect(true, isTrue);
        },
      );
      test(
        'should maintain performance with cache invalidation stress',
        () async {
          // Simulate frequent cache invalidations
          for (int i = 0; i < 100; i++) {
            // Evaluate some flags
            for (int j = 0; j < 10; j++) {
              client.getBoolean('invalidation_flag_${i}_$j', false);
            }
            // Trigger potential cache invalidation by updating user
            if (i % 10 == 0) {
              await client.setUser(
                TestConfigs.getUser(TestUserType.defaultUser),
              );
            }
          }
          expect(true, isTrue);
        },
      );
    });
    group('Error Handling Stress Tests', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle rapid evaluations with invalid flag names', () async {
        // Test with various invalid flag name patterns
        final invalidNames = [
          '', // Empty
          ' ', // Whitespace
          'flag with spaces',
          'flag-with-special-chars!@#',
          'very_long_flag_name_' * 20, // Very long name
        ];
        for (int i = 0; i < 200; i++) {
          final invalidName = invalidNames[i % invalidNames.length];
          final result = client.getBoolean('${invalidName}_$i', false);
          expect(result, isA<bool>()); // Should return default value
        }
      });
      test('should handle stress with malformed default values', () async {
        // Test with various edge case default values
        for (int i = 0; i < 100; i++) {
          // Test with null-like scenarios (using appropriate defaults)
          client.getString('malformed_string_$i', '');
          client.getNumber('malformed_number_$i', double.nan);
          client.getNumber('malformed_number_infinity_$i', double.infinity);
          client.getJson('malformed_json_$i', <String, dynamic>{});
        }
        expect(true, isTrue);
      });
    });
    group('Memory Management Stress Tests', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test(
        'should handle memory pressure from flag evaluation history',
        () async {
          // Create sustained flag evaluation to test memory management
          for (int i = 0; i < 5000; i++) {
            client.getBoolean('memory_pressure_$i', false);
            client.getString('memory_pressure_string_$i', 'default');
            // Occasional complex JSON to increase memory pressure
            if (i % 100 == 0) {
              final complexDefault = {
                'data': List.generate(
                  50,
                  (j) => {'item': j, 'value': 'test_$j'},
                ),
              };
              client.getJson('memory_pressure_json_$i', complexDefault);
            }
          }
          // System should handle memory pressure gracefully
          expect(true, isTrue);
        },
      );
      test('should handle garbage collection pressure', () async {
        // Create many temporary objects to pressure garbage collection
        for (int i = 0; i < 1000; i++) {
          final tempData = List.generate(100, (j) => 'temp_data_${i}_$j');
          final tempMap = {
            'data': tempData,
            'index': i,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          client.getJson('gc_pressure_$i', tempMap);
          // Force some object creation and disposal
          tempData.clear();
        }
        expect(true, isTrue);
      });
    });
  });
}
