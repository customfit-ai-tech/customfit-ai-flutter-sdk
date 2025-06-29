// test/stress/core/cf_user_stress_test.dart
// Stress tests for CF user performance under high load.
// Tests large numbers of properties and serialization performance.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CF User Stress Tests', () {
    group('Large Property Sets Stress', () {
      test('should handle large number of properties efficiently under stress',
          () {
        final stopwatch = Stopwatch()..start();
        final user = CFUser.builder('stress_user');
        for (int i = 0; i < 1000; i++) {
          user.addStringProperty('prop_string_$i', 'value_$i');
          user.addNumberProperty('prop_number_$i', i);
          user.addBooleanProperty('prop_bool_$i', i % 2 == 0);
        }
        final builtUser = user.build();
        stopwatch.stop();
        expect(builtUser.properties.length, equals(3000));
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
      test('should serialize large users efficiently under stress', () {
        final user = CFUser.builder('large_stress_user');
        // Add many properties
        for (int i = 0; i < 500; i++) {
          user.addMapProperty('map_$i', {
            'index': i,
            'data': List.generate(10, (j) => 'item_$j'),
          });
        }
        final builtUser = user.build();
        final stopwatch = Stopwatch()..start();
        final json = builtUser.toJson();
        stopwatch.stop();
        expect(json, isNotEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
      });
    });
  });
}
