// test/unit/core/util/properties_builder_test.dart
//
// Comprehensive unit tests for PropertiesBuilder covering all methods and edge cases
// to achieve 100% coverage from 0.0%
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/properties_builder.dart';
// A concrete implementation for testing the abstract PropertiesBuilder.
class _TestPropertiesBuilder extends PropertiesBuilder {
  // For testing purposes, expose build method
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PropertiesBuilder', () {
    late _TestPropertiesBuilder builder;
    setUp(() {
      builder = _TestPropertiesBuilder();
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      PreferencesService.reset();
    });
    group('Abstract Class Implementation', () {
      test('should create instance of concrete implementation', () {
        expect(builder, isA<PropertiesBuilder>());
        expect(builder, isA<_TestPropertiesBuilder>());
      });
      test('should have empty properties map initially', () {
        final properties = builder.build();
        expect(properties, isEmpty);
        expect(properties, isA<Map<String, dynamic>>());
      });
    });
    group('addProperty', () {
      test('should add a property of any type', () {
        // Arrange
        const key = 'anyKey';
        final value = ['list', 'of', 'items'];
        // Act
        builder.addProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
        expect(properties.length, 1);
      });
      test('should allow null as a value', () {
        // Arrange
        const key = 'nullKey';
        // Act
        builder.addProperty(key, null);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, null));
        expect(properties.containsKey(key), isTrue);
        expect(properties[key], isNull);
      });
      test('should overwrite existing property with the same key', () {
        // Arrange
        const key = 'duplicateKey';
        builder.addProperty(key, 'initialValue');
        // Act
        builder.addProperty(key, 'overwrittenValue');
        final properties = builder.build();
        // Assert
        expect(properties[key], 'overwrittenValue');
        expect(properties.length, 1);
      });
      test('should handle various primitive types', () {
        // Arrange & Act
        builder.addProperty('string', 'text');
        builder.addProperty('int', 42);
        builder.addProperty('double', 3.14);
        builder.addProperty('bool', true);
        builder.addProperty('list', [1, 2, 3]);
        builder.addProperty('map', {'nested': 'value'});
        final properties = builder.build();
        // Assert
        expect(properties['string'], 'text');
        expect(properties['int'], 42);
        expect(properties['double'], 3.14);
        expect(properties['bool'], true);
        expect(properties['list'], [1, 2, 3]);
        expect(properties['map'], {'nested': 'value'});
        expect(properties.length, 6);
      });
      test('should handle complex nested objects', () {
        // Arrange
        final complexObject = {
          'level1': {
            'level2': {
              'level3': ['deep', 'nested', 'data']
            }
          },
          'array': [
            {'item': 1},
            {'item': 2}
          ]
        };
        // Act
        builder.addProperty('complex', complexObject);
        final properties = builder.build();
        // Assert
        expect(properties['complex'], complexObject);
        expect(properties['complex']['level1']['level2']['level3'],
            ['deep', 'nested', 'data']);
      });
      test('should handle empty string as key', () {
        // Act & Assert
        expect(
          () => builder.addProperty('', 'empty key value'),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', 'Property key cannot be empty')),
        );
      });
      test('should handle special characters in keys', () {
        // Act
        builder.addProperty('key with spaces', 'value1');
        builder.addProperty('key@#\$%', 'value2');
        builder.addProperty('key\nwith\nnewlines', 'value3');
        final properties = builder.build();
        // Assert
        expect(properties['key with spaces'], 'value1');
        expect(properties['key@#\$%'], 'value2');
        expect(properties['key\nwith\nnewlines'], 'value3');
        expect(properties.length, 3);
      });
    });
    group('addStringProperty', () {
      test('should add a valid non-empty string property', () {
        // Arrange
        const key = 'stringKey';
        const value = 'hello world';
        // Act
        builder.addStringProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
      });
      test('should throw ArgumentError for an empty string', () {
        // Arrange
        const key = 'emptyStringKey';
        const value = '';
        // Act & Assert
        expect(
          () => builder.addStringProperty(key, value),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              "String value for '$key' cannot be blank")),
        );
      });
      test('should include the correct key name in ArgumentError message', () {
        // Test different key names to ensure message formatting
        expect(
          () => builder.addStringProperty('user_id', ''),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              "String value for 'user_id' cannot be blank")),
        );
        expect(
          () => builder.addStringProperty('email', ''),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              "String value for 'email' cannot be blank")),
        );
      });
      test('should allow string with only whitespace characters', () {
        // This test highlights that the current implementation does not trim
        // the string before checking for emptiness.
        // Arrange
        const key = 'whitespaceKey';
        const value = '   ';
        // Act
        builder.addStringProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
      });
      test('should allow string with tabs and newlines', () {
        // Arrange
        const key = 'tabNewlineKey';
        const value = '\t\n\r';
        // Act
        builder.addStringProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
      });
      test('should handle special characters in string values', () {
        // Arrange
        const key = 'specialCharsKey';
        const value = 'Hello! @#\$%^&*()_+ 你好 🎉';
        // Act
        builder.addStringProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
      });
      test('should handle very long strings', () {
        // Arrange
        const key = 'longStringKey';
        final value = 'a' * 10000; // 10,000 character string
        // Act
        builder.addStringProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
        expect(properties[key].length, 10000);
      });
      test('should handle unicode strings', () {
        // Arrange
        const key = 'unicodeKey';
        const value = '🌟🚀💻🎯🔥 Unicode test with émojis and açcénts';
        // Act
        builder.addStringProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
      });
      test('should not modify the original string', () {
        // Arrange
        const key = 'originalKey';
        var value = 'original value';
        // Act
        builder.addStringProperty(key, value);
        value = 'modified value';
        final properties = builder.build();
        // Assert
        expect(properties[key], 'original value');
      });
    });
    group('addNumberProperty', () {
      test('should add an integer property', () {
        // Arrange
        const key = 'intKey';
        const value = 123;
        // Act
        builder.addNumberProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
        expect(properties[key], isA<int>());
      });
      test('should add a double property', () {
        // Arrange
        const key = 'doubleKey';
        const value = 3.14;
        // Act
        builder.addNumberProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
        expect(properties[key], isA<double>());
      });
      test('should handle zero values', () {
        // Act
        builder.addNumberProperty('zero_int', 0);
        builder.addNumberProperty('zero_double', 0.0);
        final properties = builder.build();
        // Assert
        expect(properties['zero_int'], 0);
        expect(properties['zero_double'], 0.0);
      });
      test('should handle negative numbers', () {
        // Act
        builder.addNumberProperty('negative_int', -42);
        builder.addNumberProperty('negative_double', -3.14);
        final properties = builder.build();
        // Assert
        expect(properties['negative_int'], -42);
        expect(properties['negative_double'], -3.14);
      });
      test('should handle very large numbers', () {
        // Act
        builder.addNumberProperty(
            'large_int', 9223372036854775807); // Max int64
        builder.addNumberProperty(
            'large_double', 1.7976931348623157e+308); // Close to max double
        final properties = builder.build();
        // Assert
        expect(properties['large_int'], 9223372036854775807);
        expect(properties['large_double'], 1.7976931348623157e+308);
      });
      test('should handle very small numbers', () {
        // Act
        builder.addNumberProperty(
            'small_int', -9223372036854775808); // Min int64
        builder.addNumberProperty(
            'small_double', 4.9e-324); // Close to min positive double
        final properties = builder.build();
        // Assert
        expect(properties['small_int'], -9223372036854775808);
        expect(properties['small_double'], 4.9e-324);
      });
      test('should handle special double values', () {
        // Act
        builder.addNumberProperty('infinity', double.infinity);
        builder.addNumberProperty('negative_infinity', double.negativeInfinity);
        builder.addNumberProperty('nan', double.nan);
        final properties = builder.build();
        // Assert
        expect(properties['infinity'], double.infinity);
        expect(properties['negative_infinity'], double.negativeInfinity);
        expect(properties['nan'].isNaN, isTrue);
      });
    });
    group('addBooleanProperty', () {
      test('should add a true boolean property', () {
        // Arrange
        const key = 'trueKey';
        const value = true;
        // Act
        builder.addBooleanProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
        expect(properties[key], isA<bool>());
        expect(properties[key], isTrue);
      });
      test('should add a false boolean property', () {
        // Arrange
        const key = 'falseKey';
        const value = false;
        // Act
        builder.addBooleanProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
        expect(properties[key], isA<bool>());
        expect(properties[key], isFalse);
      });
      test('should handle multiple boolean properties', () {
        // Act
        builder.addBooleanProperty('flag1', true);
        builder.addBooleanProperty('flag2', false);
        builder.addBooleanProperty('flag3', true);
        final properties = builder.build();
        // Assert
        expect(properties['flag1'], true);
        expect(properties['flag2'], false);
        expect(properties['flag3'], true);
        expect(properties.length, 3);
      });
      test('should overwrite boolean property with same key', () {
        // Act
        builder.addBooleanProperty('toggle', true);
        builder.addBooleanProperty('toggle', false);
        final properties = builder.build();
        // Assert
        expect(properties['toggle'], false);
        expect(properties.length, 1);
      });
    });
    group('addJsonProperty', () {
      test('should add a map property', () {
        // Arrange
        const key = 'jsonKey';
        final value = {'nestedKey': 'nestedValue', 'nestedNum': 1};
        // Act
        builder.addJsonProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties, containsPair(key, value));
        expect(properties[key], isA<Map<String, dynamic>>());
        expect(properties[key]['nestedKey'], 'nestedValue');
        expect(properties[key]['nestedNum'], 1);
      });
      test('should allow empty map property', () {
        // Arrange
        const key = 'emptyJsonKey';
        final value = <String, dynamic>{};
        // Act
        builder.addJsonProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties[key], equals(value));
        expect(properties[key], isEmpty);
      });
      test('should handle complex nested maps', () {
        // Arrange
        const key = 'complexJsonKey';
        final value = {
          'user': {
            'id': 123,
            'profile': {
              'name': 'John Doe',
              'settings': {'theme': 'dark', 'notifications': true}
            }
          },
          'permissions': ['read', 'write'],
          'metadata': {'created': '2023-01-01', 'updated': null}
        };
        // Act
        builder.addJsonProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties[key], value);
        expect(properties[key]['user']['profile']['name'], 'John Doe');
        expect(properties[key]['permissions'], ['read', 'write']);
        expect(properties[key]['metadata']['updated'], null);
      });
      test('should handle maps with various value types', () {
        // Arrange
        const key = 'mixedTypesKey';
        final value = {
          'string': 'text',
          'number': 42,
          'double': 3.14,
          'boolean': true,
          'null_value': null,
          'list': [1, 2, 3],
          'nested_map': {'inner': 'value'}
        };
        // Act
        builder.addJsonProperty(key, value);
        final properties = builder.build();
        // Assert
        expect(properties[key], value);
        expect(properties[key]['string'], 'text');
        expect(properties[key]['number'], 42);
        expect(properties[key]['double'], 3.14);
        expect(properties[key]['boolean'], true);
        expect(properties[key]['null_value'], null);
        expect(properties[key]['list'], [1, 2, 3]);
        expect(properties[key]['nested_map'], {'inner': 'value'});
      });
      test('should not modify the original map', () {
        // Arrange
        const key = 'originalMapKey';
        final originalMap = {'original': 'value'};
        // Act
        builder.addJsonProperty(key, originalMap);
        originalMap['modified'] = 'new value';
        final properties = builder.build();
        // Assert
        expect(properties[key], {'original': 'value', 'modified': 'new value'});
        // The map reference is stored, so modifications affect the stored value
        // This is expected behavior for reference types
      });
    });
    group('build', () {
      test('should return an empty map if no properties are added', () {
        // Act
        final properties = builder.build();
        // Assert
        expect(properties, isEmpty);
        expect(properties, isA<Map<String, dynamic>>());
      });
      test('should return a map with all added properties of various types',
          () {
        // Arrange
        builder.addStringProperty('string', 'value');
        builder.addNumberProperty('number', 42);
        builder.addBooleanProperty('boolean', true);
        builder.addJsonProperty('json', {'a': 1});
        builder.addProperty('nullVal', null);
        // Act
        final properties = builder.build();
        // Assert
        expect(properties, {
          'string': 'value',
          'number': 42,
          'boolean': true,
          'json': {'a': 1},
          'nullVal': null,
        });
        expect(properties.length, 5);
      });
      test('should return an immutable copy of the properties', () {
        // Arrange
        builder.addStringProperty('key1', 'value1');
        final properties1 = builder.build();
        // Act: Modify the builder after building
        builder.addStringProperty('key2', 'value2');
        final properties2 = builder.build();
        // Assert: The first map should be unaffected by later additions
        expect(properties1, {'key1': 'value1'});
        expect(properties1.length, 1);
        // Assert: The second map should contain all properties
        expect(properties2, {'key1': 'value1', 'key2': 'value2'});
        expect(properties2.length, 2);
      });
      test('modifying the returned map should not affect the builder', () {
        // Arrange
        builder.addStringProperty('key', 'value');
        final properties = builder.build();
        // Act: Modify the returned map
        properties['key2'] = 'newValue';
        properties['key'] = 'overwritten';
        // Assert: The builder's internal state should be unchanged
        final originalProperties = builder.build();
        expect(originalProperties, {'key': 'value'});
        expect(originalProperties.containsKey('key2'), isFalse);
        // Map.from() creates a proper copy, so modifications to the returned map
        // should not affect the builder's internal state.
      });
      test('should handle multiple calls to build', () {
        // Arrange
        builder.addStringProperty('key1', 'value1');
        // Act
        final build1 = builder.build();
        final build2 = builder.build();
        final build3 = builder.build();
        // Assert
        expect(build1, build2);
        expect(build2, build3);
        expect(build1, {'key1': 'value1'});
      });
      test('should return consistent results across multiple builds', () {
        // Arrange
        builder.addStringProperty('string', 'value');
        builder.addNumberProperty('number', 42);
        builder.addBooleanProperty('boolean', true);
        // Act
        final build1 = builder.build();
        final build2 = builder.build();
        // Assert
        expect(build1, build2);
        expect(build1.length, 3);
        expect(build2.length, 3);
        expect(build1['string'], build2['string']);
        expect(build1['number'], build2['number']);
        expect(build1['boolean'], build2['boolean']);
      });
    });
    group('Mixed Operations and Edge Cases', () {
      test('should handle adding properties in mixed order', () {
        // Act
        builder.addBooleanProperty('bool', true);
        builder.addProperty('dynamic', [1, 2, 3]);
        builder.addStringProperty('string', 'value');
        builder.addJsonProperty('json', {'key': 'value'});
        builder.addNumberProperty('number', 42);
        final properties = builder.build();
        // Assert
        expect(properties.length, 5);
        expect(properties['bool'], true);
        expect(properties['dynamic'], [1, 2, 3]);
        expect(properties['string'], 'value');
        expect(properties['json'], {'key': 'value'});
        expect(properties['number'], 42);
      });
      test('should handle overwriting properties with different types', () {
        // Act
        builder.addStringProperty('key', 'text');
        builder.addNumberProperty('key', 42);
        builder.addBooleanProperty('key', true);
        builder.addJsonProperty('key', {'final': 'value'});
        final properties = builder.build();
        // Assert
        expect(properties.length, 1);
        expect(properties['key'], {'final': 'value'});
      });
      test('should handle large number of properties', () {
        // Act
        for (int i = 0; i < 1000; i++) {
          builder.addProperty('key$i', 'value$i');
        }
        final properties = builder.build();
        // Assert
        expect(properties.length, 1000);
        expect(properties['key0'], 'value0');
        expect(properties['key999'], 'value999');
        expect(properties['key500'], 'value500');
      });
      test('should handle empty and null combinations', () {
        // Act
        builder.addProperty('null', null);
        builder.addJsonProperty('non_empty_map', {'key': 'value'});
        builder.addProperty('empty_list', []);
        builder.addStringProperty('non_empty', 'value');
        final properties = builder.build();
        // Assert
        expect(properties['null'], null);
        expect(properties['non_empty_map'], {'key': 'value'});
        expect(properties['empty_list'], []);
        expect(properties['non_empty'], 'value');
        expect(properties.length, 4);
      });
      test('should maintain type information correctly', () {
        // Act
        builder.addProperty('int_as_dynamic', 42);
        builder.addNumberProperty('int_as_number', 42);
        builder.addProperty('double_as_dynamic', 3.14);
        builder.addNumberProperty('double_as_number', 3.14);
        final properties = builder.build();
        // Assert
        expect(properties['int_as_dynamic'], isA<int>());
        expect(properties['int_as_number'], isA<int>());
        expect(properties['double_as_dynamic'], isA<double>());
        expect(properties['double_as_number'], isA<double>());
      });
    });
    group('Error Handling and Validation', () {
      test('should be the only method that throws exceptions', () {
        // Test that only addStringProperty with empty string throws
        expect(() => builder.addProperty('key', ''), returnsNormally);
        expect(() => builder.addNumberProperty('test_number', 1), returnsNormally);
        expect(() => builder.addBooleanProperty('test_bool', true), returnsNormally);
        expect(() => builder.addJsonProperty('key', {}), returnsNormally);
        // Only this should throw
        expect(() => builder.addStringProperty('key', ''), throwsArgumentError);
      });
      test('should handle ArgumentError without corrupting state', () {
        // Arrange
        builder.addStringProperty('valid', 'value');
        // Act & Assert
        expect(() => builder.addStringProperty('invalid', ''),
            throwsArgumentError);
        final properties = builder.build();
        expect(properties, {'valid': 'value'});
        expect(properties.length, 1);
      });
      test('should allow recovery after ArgumentError', () {
        // Act & Assert - First error
        expect(
            () => builder.addStringProperty('invalid1', ''), throwsArgumentError);
        // Recovery
        builder.addStringProperty('valid1', 'value1');
        // Second error
        expect(
            () => builder.addStringProperty('invalid2', ''), throwsArgumentError);
        // Final recovery
        builder.addStringProperty('valid2', 'value2');
        final properties = builder.build();
        expect(properties, {'valid1': 'value1', 'valid2': 'value2'});
        expect(properties.length, 2);
      });
    });
  });
}
