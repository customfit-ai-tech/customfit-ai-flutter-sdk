import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/feature_flag_value.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FeatureFlagValue', () {
    group('Factory Constructors', () {
      test('should create boolean feature flag value', () {
        const value = FeatureFlagValue.boolean(true);
        expect(value, isA<BooleanFeatureFlagValue>());
        expect(value.rawValue, equals(true));
        expect(value.typeName, equals('boolean'));
        expect(value.toString(), equals('true'));
      });
      test('should create string feature flag value', () {
        const value = FeatureFlagValue.string('test_string');
        expect(value, isA<StringFeatureFlagValue>());
        expect(value.rawValue, equals('test_string'));
        expect(value.typeName, equals('string'));
        expect(value.toString(), equals('test_string'));
      });
      test('should create number feature flag value', () {
        const value = FeatureFlagValue.number(42);
        expect(value, isA<NumberFeatureFlagValue>());
        expect(value.rawValue, equals(42));
        expect(value.typeName, equals('number'));
        expect(value.toString(), equals('42'));
      });
      test('should create json feature flag value', () {
        final jsonMap = {'key': 'value', 'number': 123};
        final value = FeatureFlagValue.json(jsonMap);
        expect(value, isA<JsonFeatureFlagValue>());
        expect(value.rawValue, equals(jsonMap));
        expect(value.typeName, equals('json'));
        expect(value.toString(), equals(jsonMap.toString()));
      });
    });
    group('fromDynamic Factory', () {
      test('should create boolean from bool', () {
        final value = FeatureFlagValue.fromDynamic(true);
        expect(value, isA<BooleanFeatureFlagValue>());
        expect(value.rawValue, equals(true));
      });
      test('should create string from string', () {
        final value = FeatureFlagValue.fromDynamic('hello');
        expect(value, isA<StringFeatureFlagValue>());
        expect(value.rawValue, equals('hello'));
      });
      test('should create number from int', () {
        final value = FeatureFlagValue.fromDynamic(42);
        expect(value, isA<NumberFeatureFlagValue>());
        expect(value.rawValue, equals(42));
      });
      test('should create number from double', () {
        final value = FeatureFlagValue.fromDynamic(3.14);
        expect(value, isA<NumberFeatureFlagValue>());
        expect(value.rawValue, equals(3.14));
      });
      test('should create json from map', () {
        final map = {'test': 'value'};
        final value = FeatureFlagValue.fromDynamic(map);
        expect(value, isA<JsonFeatureFlagValue>());
        expect(value.rawValue, equals(map));
      });
      test('should create string from null', () {
        final value = FeatureFlagValue.fromDynamic(null);
        expect(value, isA<StringFeatureFlagValue>());
        expect(value.rawValue, equals('null'));
      });
      test('should create string from list', () {
        final value = FeatureFlagValue.fromDynamic([1, 2, 3]);
        expect(value, isA<StringFeatureFlagValue>());
        expect(value.rawValue, equals('[1, 2, 3]'));
      });
      test('should create string from unknown types', () {
        final customObject = DateTime(2023, 1, 1);
        final value = FeatureFlagValue.fromDynamic(customObject);
        expect(value, isA<StringFeatureFlagValue>());
        expect(value.rawValue, equals(customObject.toString()));
      });
    });
    group('Type Checking', () {
      test('should correctly identify boolean type', () {
        const value = FeatureFlagValue.boolean(false);
        expect(value.isType<bool>(), isTrue);
        expect(value.isType<String>(), isFalse);
        expect(value.isType<num>(), isFalse);
        expect(value.isType<Map<String, dynamic>>(), isFalse);
      });
      test('should correctly identify string type', () {
        const value = FeatureFlagValue.string('test');
        expect(value.isType<String>(), isTrue);
        expect(value.isType<bool>(), isFalse);
        expect(value.isType<num>(), isFalse);
        expect(value.isType<Map<String, dynamic>>(), isFalse);
      });
      test('should correctly identify number type', () {
        const value = FeatureFlagValue.number(42);
        expect(value.isType<num>(), isTrue);
        expect(value.isType<int>(), isTrue);
        expect(value.isType<double>(), isTrue);
        expect(value.isType<bool>(), isFalse);
        expect(value.isType<String>(), isFalse);
      });
      test('should correctly identify json type', () {
        const value = FeatureFlagValue.json({'key': 'value'});
        expect(value.isType<Map<String, dynamic>>(), isTrue);
        expect(value.isType<bool>(), isFalse);
        expect(value.isType<String>(), isFalse);
        expect(value.isType<num>(), isFalse);
      });
    });
    group('Type Conversion', () {
      test('should convert to correct type', () {
        const boolValue = FeatureFlagValue.boolean(true);
        const stringValue = FeatureFlagValue.string('hello');
        const numberValue = FeatureFlagValue.number(42.5);
        const jsonValue = FeatureFlagValue.json({'key': 'value'});
        expect(boolValue.asType<bool>(), equals(true));
        expect(stringValue.asType<String>(), equals('hello'));
        expect(numberValue.asType<num>(), equals(42.5));
        expect(
            jsonValue.asType<Map<String, dynamic>>(), equals({'key': 'value'}));
      });
      test('should return null for incorrect type conversion', () {
        const boolValue = FeatureFlagValue.boolean(true);
        expect(boolValue.asType<String>(), isNull);
        expect(boolValue.asType<num>(), isNull);
        expect(boolValue.asType<Map<String, dynamic>>(), isNull);
      });
      test('should convert number to int and double', () {
        const numberValue = FeatureFlagValue.number(42.7);
        expect(numberValue.asType<int>(), equals(42));
        expect(numberValue.asType<double>(), equals(42.7));
        expect(numberValue.asType<num>(), equals(42.7));
      });
      test('should handle int number conversion', () {
        const intValue = FeatureFlagValue.number(42);
        expect(intValue.asType<int>(), equals(42));
        expect(intValue.asType<double>(), equals(42.0));
        expect(intValue.asType<num>(), equals(42));
      });
    });
    group('BooleanFeatureFlagValue', () {
      test('should have correct properties', () {
        const value = BooleanFeatureFlagValue(true);
        expect(value.value, equals(true));
        expect(value.rawValue, equals(true));
        expect(value.typeName, equals('boolean'));
        expect(value.toString(), equals('true'));
      });
      test('should handle false value', () {
        const value = BooleanFeatureFlagValue(false);
        expect(value.value, equals(false));
        expect(value.toString(), equals('false'));
      });
      test('should implement equality correctly', () {
        const value1 = BooleanFeatureFlagValue(true);
        const value2 = BooleanFeatureFlagValue(true);
        const value3 = BooleanFeatureFlagValue(false);
        expect(value1, equals(value2));
        expect(value1, isNot(equals(value3)));
        expect(value1.hashCode, equals(value2.hashCode));
        expect(value1.hashCode, isNot(equals(value3.hashCode)));
      });
    });
    group('StringFeatureFlagValue', () {
      test('should have correct properties', () {
        const value = StringFeatureFlagValue('test_string');
        expect(value.value, equals('test_string'));
        expect(value.rawValue, equals('test_string'));
        expect(value.typeName, equals('string'));
        expect(value.toString(), equals('test_string'));
      });
      test('should handle empty string', () {
        const value = StringFeatureFlagValue('');
        expect(value.value, equals(''));
        expect(value.toString(), equals(''));
      });
      test('should handle special characters', () {
        const value = StringFeatureFlagValue('Hello 🌟 World!');
        expect(value.value, equals('Hello 🌟 World!'));
        expect(value.toString(), equals('Hello 🌟 World!'));
      });
      test('should implement equality correctly', () {
        const value1 = StringFeatureFlagValue('test');
        const value2 = StringFeatureFlagValue('test');
        const value3 = StringFeatureFlagValue('different');
        expect(value1, equals(value2));
        expect(value1, isNot(equals(value3)));
        expect(value1.hashCode, equals(value2.hashCode));
        expect(value1.hashCode, isNot(equals(value3.hashCode)));
      });
    });
    group('NumberFeatureFlagValue', () {
      test('should have correct properties for int', () {
        const value = NumberFeatureFlagValue(42);
        expect(value.value, equals(42));
        expect(value.rawValue, equals(42));
        expect(value.typeName, equals('number'));
        expect(value.toString(), equals('42'));
        expect(value.asInt, equals(42));
        expect(value.asDouble, equals(42.0));
      });
      test('should have correct properties for double', () {
        const value = NumberFeatureFlagValue(3.14);
        expect(value.value, equals(3.14));
        expect(value.rawValue, equals(3.14));
        expect(value.toString(), equals('3.14'));
        expect(value.asInt, equals(3));
        expect(value.asDouble, equals(3.14));
      });
      test('should handle negative numbers', () {
        const value = NumberFeatureFlagValue(-42.5);
        expect(value.value, equals(-42.5));
        expect(value.asInt, equals(-42));
        expect(value.asDouble, equals(-42.5));
      });
      test('should handle zero', () {
        const value = NumberFeatureFlagValue(0);
        expect(value.value, equals(0));
        expect(value.asInt, equals(0));
        expect(value.asDouble, equals(0.0));
      });
      test('should implement equality correctly', () {
        const value1 = NumberFeatureFlagValue(42);
        const value2 = NumberFeatureFlagValue(42);
        const value3 = NumberFeatureFlagValue(43);
        const value4 = NumberFeatureFlagValue(42.0);
        expect(value1, equals(value2));
        expect(value1, equals(value4)); // 42 == 42.0
        expect(value1, isNot(equals(value3)));
        expect(value1.hashCode, equals(value2.hashCode));
      });
    });
    group('JsonFeatureFlagValue', () {
      test('should have correct properties', () {
        final jsonMap = {'key': 'value', 'number': 123};
        final value = JsonFeatureFlagValue(jsonMap);
        expect(value.value, equals(jsonMap));
        expect(value.rawValue, equals(jsonMap));
        expect(value.typeName, equals('json'));
        expect(value.toString(), equals(jsonMap.toString()));
      });
      test('should handle empty map', () {
        const value = JsonFeatureFlagValue({});
        expect(value.value, equals({}));
        expect(value.toString(), equals('{}'));
      });
      test('should handle nested objects', () {
        final nestedMap = {
          'level1': {
            'level2': {'value': 'deep_value'}
          },
          'array': [1, 2, 3],
          'boolean': true,
          'null_value': null,
        };
        final value = JsonFeatureFlagValue(nestedMap);
        expect(value.value, equals(nestedMap));
      });
      test('should implement equality correctly', () {
        final map1 = {'key': 'value', 'number': 123};
        final map2 = {'key': 'value', 'number': 123};
        final map3 = {'key': 'different', 'number': 123};
        final map4 = {'key': 'value'}; // Different length
        final value1 = JsonFeatureFlagValue(map1);
        final value2 = JsonFeatureFlagValue(map2);
        final value3 = JsonFeatureFlagValue(map3);
        final value4 = JsonFeatureFlagValue(map4);
        expect(value1, equals(value2));
        expect(value1, isNot(equals(value3)));
        expect(value1, isNot(equals(value4)));
        expect(value1.hashCode, equals(value2.hashCode));
      });
      test('should handle map equality edge cases', () {
        final map1 = {'a': 1, 'b': 2};
        final map2 = {'b': 2, 'a': 1}; // Different order, same content
        final map3 = {'a': 1, 'b': 2, 'c': null};
        final value1 = JsonFeatureFlagValue(map1);
        final value2 = JsonFeatureFlagValue(map2);
        final value3 = JsonFeatureFlagValue(map3);
        expect(value1, equals(value2)); // Order shouldn't matter
        expect(value1, isNot(equals(value3))); // Different keys
      });
    });
    group('toString Implementation', () {
      test('should return correct string for all types', () {
        const boolValue = FeatureFlagValue.boolean(true);
        const stringValue = FeatureFlagValue.string('hello');
        const numberValue = FeatureFlagValue.number(42.5);
        const jsonValue = FeatureFlagValue.json({'key': 'value'});
        expect(boolValue.toString(), equals('true'));
        expect(stringValue.toString(), equals('hello'));
        expect(numberValue.toString(), equals('42.5'));
        expect(jsonValue.toString(), equals({'key': 'value'}.toString()));
      });
    });
    group('Edge Cases', () {
      test('should handle very large numbers', () {
        const largeNumber = 9223372036854775807; // Max int64
        const value = FeatureFlagValue.number(largeNumber);
        expect(value.rawValue, equals(largeNumber));
        expect(value.asType<num>(), equals(largeNumber));
      });
      test('should handle very small numbers', () {
        const smallNumber = -9223372036854775808; // Min int64
        const value = FeatureFlagValue.number(smallNumber);
        expect(value.rawValue, equals(smallNumber));
      });
      test('should handle special double values', () {
        const infValue = FeatureFlagValue.number(double.infinity);
        const nanValue = FeatureFlagValue.number(double.nan);
        expect(infValue.rawValue, equals(double.infinity));
        expect(nanValue.rawValue.isNaN, isTrue);
      });
      test('should handle very long strings', () {
        final longString = 'a' * 10000;
        final value = FeatureFlagValue.string(longString);
        expect(value.rawValue, equals(longString));
        expect(value.toString(), equals(longString));
      });
      test('should handle complex JSON structures', () {
        final complexJson = {
          'users': [
            {'id': 1, 'name': 'John', 'active': true},
            {'id': 2, 'name': 'Jane', 'active': false},
          ],
          'metadata': {
            'version': '1.0.0',
            'timestamp': '2023-01-01T00:00:00Z',
            'config': {
              'debug': true,
              'timeout': 30000,
            }
          },
          'features': ['feature1', 'feature2', 'feature3'],
        };
        final value = FeatureFlagValue.json(complexJson);
        expect(value.rawValue, equals(complexJson));
        expect(value.isType<Map<String, dynamic>>(), isTrue);
      });
    });
    group('Type Safety', () {
      test('should maintain type safety across operations', () {
        const values = [
          FeatureFlagValue.boolean(true),
          FeatureFlagValue.string('test'),
          FeatureFlagValue.number(42),
          FeatureFlagValue.json({'key': 'value'}),
        ];
        for (final value in values) {
          // Each value should know its own type
          expect(value.typeName, isNotEmpty);
          expect(value.rawValue, isNotNull);
          expect(value.toString(), isNotEmpty);
          // Type checking should work consistently
          switch (value.typeName) {
            case 'boolean':
              expect(value.isType<bool>(), isTrue);
              expect(value.asType<bool>(), isNotNull);
              break;
            case 'string':
              expect(value.isType<String>(), isTrue);
              expect(value.asType<String>(), isNotNull);
              break;
            case 'number':
              expect(value.isType<num>(), isTrue);
              expect(value.asType<num>(), isNotNull);
              break;
            case 'json':
              expect(value.isType<Map<String, dynamic>>(), isTrue);
              expect(value.asType<Map<String, dynamic>>(), isNotNull);
              break;
          }
        }
      });
    });
  });
}
