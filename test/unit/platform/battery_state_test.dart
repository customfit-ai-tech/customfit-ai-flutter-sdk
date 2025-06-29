import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/battery_state.dart';
import 'package:battery_plus/battery_plus.dart' as battery_plus;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('BatteryState Tests', () {
    group('Enum Values', () {
      test('should have all expected battery states', () {
        expect(BatteryState.values, hasLength(5));
        expect(BatteryState.values, contains(BatteryState.full));
        expect(BatteryState.values, contains(BatteryState.normal));
        expect(BatteryState.values, contains(BatteryState.low));
        expect(BatteryState.values, contains(BatteryState.unknown));
        expect(BatteryState.values, contains(BatteryState.charging));
      });
    });
    group('fromBatteryPlusState Extension Method', () {
      test('should return charging state when device is charging', () {
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.charging,
            50,
          ),
          equals(BatteryState.charging),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.charging,
            10,
          ),
          equals(BatteryState.charging),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.charging,
            100,
          ),
          equals(BatteryState.charging),
        );
      });
      test('should return full state for battery level >= 90%', () {
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.full,
            90,
          ),
          equals(BatteryState.full),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.full,
            95,
          ),
          equals(BatteryState.full),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.full,
            100,
          ),
          equals(BatteryState.full),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            92,
          ),
          equals(BatteryState.full),
        );
      });
      test('should return normal state for battery level between 20% and 89%',
          () {
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.full,
            20,
          ),
          equals(BatteryState.normal),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            50,
          ),
          equals(BatteryState.normal),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.full,
            89,
          ),
          equals(BatteryState.normal),
        );
      });
      test('should return low state for battery level below 20%', () {
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            19,
          ),
          equals(BatteryState.low),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.full,
            10,
          ),
          equals(BatteryState.low),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            1,
          ),
          equals(BatteryState.low),
        );
      });
      test('should return unknown state for battery level 0 or below', () {
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.unknown,
            0,
          ),
          equals(BatteryState.unknown),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            0,
          ),
          equals(BatteryState.unknown),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.full,
            -1,
          ),
          equals(BatteryState.unknown),
        );
      });
      test('should handle all battery_plus states', () {
        // Test with various battery levels
        final levels = [0, 1, 10, 19, 20, 50, 89, 90, 95, 100];
        for (final level in levels) {
          for (final plusState in battery_plus.BatteryState.values) {
            final batteryState =
                BatteryStateExtension.fromBatteryPlusState(plusState, level);
            expect(batteryState, isA<BatteryState>());
            expect(BatteryState.values.contains(batteryState), isTrue);
          }
        }
      });
    });
    group('stringValue Extension Method', () {
      test('should convert full state to string', () {
        expect(BatteryState.full.stringValue, equals('full'));
      });
      test('should convert normal state to string', () {
        expect(BatteryState.normal.stringValue, equals('normal'));
      });
      test('should convert low state to string', () {
        expect(BatteryState.low.stringValue, equals('low'));
      });
      test('should convert unknown state to string', () {
        expect(BatteryState.unknown.stringValue, equals('unknown'));
      });
      test('should convert charging state to string', () {
        expect(BatteryState.charging.stringValue, equals('charging'));
      });
      test('should handle all enum values in stringValue', () {
        for (final state in BatteryState.values) {
          final stringValue = state.stringValue;
          expect(stringValue, isNotEmpty);
          expect(stringValue, isA<String>());
          expect(stringValue, matches(RegExp(r'^[a-z]+$'))); // All lowercase
        }
      });
    });
    group('isLowBattery Extension Method', () {
      test('should return true only for low battery state', () {
        expect(BatteryState.low.isLowBattery, isTrue);
      });
      test('should return false for non-low battery states', () {
        expect(BatteryState.full.isLowBattery, isFalse);
        expect(BatteryState.normal.isLowBattery, isFalse);
        expect(BatteryState.unknown.isLowBattery, isFalse);
        expect(BatteryState.charging.isLowBattery, isFalse);
      });
      test('should work correctly for all states', () {
        for (final state in BatteryState.values) {
          if (state == BatteryState.low) {
            expect(state.isLowBattery, isTrue);
          } else {
            expect(state.isLowBattery, isFalse);
          }
        }
      });
    });
    group('isCharging Extension Method', () {
      test('should return true only for charging state', () {
        expect(BatteryState.charging.isCharging, isTrue);
      });
      test('should return false for non-charging states', () {
        expect(BatteryState.full.isCharging, isFalse);
        expect(BatteryState.normal.isCharging, isFalse);
        expect(BatteryState.low.isCharging, isFalse);
        expect(BatteryState.unknown.isCharging, isFalse);
      });
      test('should work correctly for all states', () {
        for (final state in BatteryState.values) {
          if (state == BatteryState.charging) {
            expect(state.isCharging, isTrue);
          } else {
            expect(state.isCharging, isFalse);
          }
        }
      });
    });
    group('Use Cases', () {
      test('should be usable in switch statements', () {
        String getBatteryMessage(BatteryState state) {
          switch (state) {
            case BatteryState.full:
              return 'Battery is full';
            case BatteryState.normal:
              return 'Battery level is normal';
            case BatteryState.low:
              return 'Battery is low';
            case BatteryState.unknown:
              return 'Battery state unknown';
            case BatteryState.charging:
              return 'Battery is charging';
          }
        }
        expect(getBatteryMessage(BatteryState.full), contains('full'));
        expect(getBatteryMessage(BatteryState.normal), contains('normal'));
        expect(getBatteryMessage(BatteryState.low), contains('low'));
        expect(getBatteryMessage(BatteryState.unknown), contains('unknown'));
        expect(getBatteryMessage(BatteryState.charging), contains('charging'));
      });
      test('should handle battery monitoring workflow', () {
        // Simulate battery level changes
        final batteryChanges = [
          (battery_plus.BatteryState.full, 100),
          (battery_plus.BatteryState.discharging, 85),
          (battery_plus.BatteryState.discharging, 50),
          (battery_plus.BatteryState.discharging, 15),
          (battery_plus.BatteryState.charging, 15),
          (battery_plus.BatteryState.charging, 50),
          (battery_plus.BatteryState.full, 100),
        ];
        final states = batteryChanges.map((change) {
          return BatteryStateExtension.fromBatteryPlusState(
              change.$1, change.$2);
        }).toList();
        expect(states[0], equals(BatteryState.full));
        expect(states[1], equals(BatteryState.normal));
        expect(states[2], equals(BatteryState.normal));
        expect(states[3], equals(BatteryState.low));
        expect(states[4], equals(BatteryState.charging));
        expect(states[5], equals(BatteryState.charging));
        expect(states[6], equals(BatteryState.full));
      });
      test('should support battery-based feature decisions', () {
        bool shouldReduceBackgroundActivity(BatteryState state) {
          return state.isLowBattery || state == BatteryState.unknown;
        }
        bool shouldShowChargingIndicator(BatteryState state) {
          return state.isCharging;
        }
        expect(shouldReduceBackgroundActivity(BatteryState.low), isTrue);
        expect(shouldReduceBackgroundActivity(BatteryState.unknown), isTrue);
        expect(shouldReduceBackgroundActivity(BatteryState.normal), isFalse);
        expect(shouldReduceBackgroundActivity(BatteryState.charging), isFalse);
        expect(shouldShowChargingIndicator(BatteryState.charging), isTrue);
        expect(shouldShowChargingIndicator(BatteryState.full), isFalse);
      });
    });
    group('Edge Cases', () {
      test('should handle extreme battery levels', () {
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            999,
          ),
          equals(BatteryState.full),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            -100,
          ),
          equals(BatteryState.unknown),
        );
      });
      test('should handle boundary values correctly', () {
        // Test boundary at 20%
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            20,
          ),
          equals(BatteryState.normal),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            19,
          ),
          equals(BatteryState.low),
        );
        // Test boundary at 90%
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            90,
          ),
          equals(BatteryState.full),
        );
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.discharging,
            89,
          ),
          equals(BatteryState.normal),
        );
      });
      test('should prioritize charging state over battery level', () {
        // Even with low battery, should return charging if charging
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.charging,
            5,
          ),
          equals(BatteryState.charging),
        );
        // Even with full battery, should return charging if charging
        expect(
          BatteryStateExtension.fromBatteryPlusState(
            battery_plus.BatteryState.charging,
            100,
          ),
          equals(BatteryState.charging),
        );
      });
    });
    group('Collections and Comparisons', () {
      test('should work in collections', () {
        final states = <BatteryState>{
          BatteryState.full,
          BatteryState.normal,
          BatteryState.low,
          BatteryState.unknown,
          BatteryState.charging,
        };
        expect(states.length, equals(5));
        expect(states.contains(BatteryState.full), isTrue);
        expect(states.contains(BatteryState.charging), isTrue);
      });
      test('should be comparable', () {
        const state1 = BatteryState.low;
        const state2 = BatteryState.low;
        const state3 = BatteryState.normal;
        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
      test('should maintain unique string values', () {
        final stringValues =
            BatteryState.values.map((state) => state.stringValue).toSet();
        expect(stringValues.length, equals(BatteryState.values.length));
      });
    });
  });
}
