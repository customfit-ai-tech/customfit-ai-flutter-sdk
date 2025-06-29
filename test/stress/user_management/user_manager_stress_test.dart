// test/stress/user_management/user_manager_stress_test.dart
// Stress tests for user management under high load.
// Tests large numbers of properties and concurrent operations.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('User Manager Stress Tests', () {
    late UserManager userManager;
    setUp(() {
      userManager = UserManagerImpl(CFUser.builder('stress-test-user').build());
      userManager.updateUser(CFUser.builder('stress-test-user').build());
    });
    tearDown(() async {
      if (CFClient.isInitialized()) {
        await CFClient.shutdownSingleton();
      }
      CFClient.clearInstance();
    });
    group('Large Property Sets Stress', () {
      test('should handle large number of properties under stress', () {
        final largeProps = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          largeProps['prop_$i'] = 'value_$i';
        }
        userManager.addUserProperties(largeProps);
        final user = userManager.getUser();
        expect(user.properties.length, greaterThanOrEqualTo(1000));
        expect(user.properties['prop_500'], 'value_500');
      });
      test('should handle massive property updates efficiently', () {
        final stopwatch = Stopwatch()..start();
        // Add properties in batches
        for (int batch = 0; batch < 10; batch++) {
          final batchProps = <String, dynamic>{};
          for (int i = 0; i < 100; i++) {
            batchProps['batch_${batch}_prop_$i'] = 'value_${batch}_$i';
          }
          userManager.addUserProperties(batchProps);
        }
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds,
            lessThan(1000)); // Should be efficient
        final user = userManager.getUser();
        expect(user.properties.length, greaterThanOrEqualTo(1000));
      });
      test('should handle special characters in property keys under stress',
          () {
        final specialKeys = <String, dynamic>{};
        for (int i = 0; i < 100; i++) {
          specialKeys['key-with-dash-$i'] = 'value$i';
          specialKeys['key_with_underscore_$i'] = 'value$i';
          specialKeys['key.with.dots.$i'] = 'value$i';
          specialKeys['key@with@at@$i'] = 'value$i';
          specialKeys['key with spaces $i'] = 'value$i';
        }
        userManager.addUserProperties(specialKeys);
        final user = userManager.getUser();
        expect(user.properties['key-with-dash-50'], 'value50');
        expect(user.properties['key_with_underscore_50'], 'value50');
        expect(user.properties['key.with.dots.50'], 'value50');
        expect(user.properties['key@with@at@50'], 'value50');
        expect(user.properties['key with spaces 50'], 'value50');
      });
    });
    group('Deep Nested JSON Stress', () {
      test('should handle deep nested JSON properties under stress', () {
        for (int i = 0; i < 100; i++) {
          final deepJson = {
            'level1_$i': {
              'level2_$i': {
                'level3_$i': {
                  'level4_$i': {
                    'value': 'deep_$i',
                    'index': i,
                    'metadata': {
                      'created': DateTime.now().toIso8601String(),
                      'type': 'stress_test',
                    },
                  },
                },
              },
            },
          };
          userManager.addJsonProperty('deep_$i', deepJson);
        }
        final user = userManager.getUser();
        final retrieved = user.properties['deep_50'] as Map<String, dynamic>;
        expect(
          retrieved['level1_50']['level2_50']['level3_50']['level4_50']
              ['value'],
          'deep_50',
        );
      });
      test('should handle large JSON arrays under stress', () {
        for (int i = 0; i < 50; i++) {
          final largeArray = List.generate(
              100,
              (index) => {
                    'id': index,
                    'name': 'item_${i}_$index',
                    'data': 'x' * 100, // Large string data
                    'nested': {
                      'value': index * i,
                      'metadata': 'test_data_$index',
                    },
                  });
          userManager.addJsonProperty('large_array_$i', {'items': largeArray});
        }
        final user = userManager.getUser();
        final map = user.properties['large_array_25'] as Map;
        final array = map['items'] as List;
        expect(array.length, 100);
        expect(array[50]['name'], 'item_25_50');
      });
    });
    group('Concurrent User Operations Stress', () {
      test('should handle concurrent property additions under stress',
          () async {
        final futures = <Future>[];
        for (int i = 0; i < 100; i++) {
          futures.add(Future(() {
            userManager.addStringProperty('concurrent_string_$i', 'value_$i');
            userManager.addNumberProperty('concurrent_number_$i', i.toDouble());
            userManager.addBooleanProperty('concurrent_bool_$i', true);
          }));
        }
        await Future.wait(futures);
        final user = userManager.getUser();
        expect(user.properties['concurrent_string_50'], 'value_50');
        expect(user.properties['concurrent_number_50'], 50.0);
        expect(user.properties['concurrent_bool_50'], true);
      });
      test('should handle concurrent listener modifications under stress', () {
        final listeners = <void Function(CFUser)>[];
        // Add many listeners concurrently
        for (int i = 0; i < 50; i++) {
          listener(CFUser user) {
            // Listener that might add more listeners
            if (listeners.length < 100) {
              newListener(CFUser u) {}
              listeners.add(newListener);
              userManager.addUserChangeListener(newListener);
            }
          }

          listeners.add(listener);
          userManager.addUserChangeListener(listener);
        }
        // Trigger notifications
        userManager.addStringProperty('trigger', 'notification');
        // Should handle concurrent modifications without issues
        expect(listeners.length, greaterThan(50));
      });
    });
    group('Memory Management Stress', () {
      test('should handle memory pressure from large user data', () {
        // Create very large user properties
        for (int i = 0; i < 100; i++) {
          userManager.addStringProperty('huge_prop_$i', 'x' * 1000);
          userManager.addJsonProperty('large_json_$i', {
            'data': List.generate(100, (j) => 'item_$j'),
            'metadata': Map.fromEntries(
                List.generate(50, (k) => MapEntry('key_$k', 'value_$k'))),
          });
        }
        final user = userManager.getUser();
        expect(user.properties.length, greaterThanOrEqualTo(200));
        // Should still be able to add more properties
        userManager.addStringProperty('final_test', 'success');
        expect(userManager.getUser().properties['final_test'], 'success');
      });
      test('should handle rapid user updates under stress', () {
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          final userBuilder = CFUser.builder('user_$i');
          userBuilder.addStringProperty('rapid_prop', 'value_$i');
          userManager.updateUser(userBuilder.build());
        }
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds,
            lessThan(2000)); // Should be efficient
        final finalUser = userManager.getUser();
        expect(finalUser.userCustomerId, 'user_999');
        expect(finalUser.properties['rapid_prop'], 'value_999');
      });
    });
  });
}
