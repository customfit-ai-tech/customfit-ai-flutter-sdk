// test/unit/analytics/event/typed_event_properties_test.dart
//
// Tests for TypedEventProperties and related classes
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/typed_event_properties.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EventPropertyValue', () {
    group('StringEventProperty', () {
      test('should create string property with valid value', () {
        const property = EventPropertyValue.string('test value');
        expect(property.value, equals('test value'));
        expect(property.isValid(), isTrue);
        expect(property, isA<StringEventProperty>());
      });
      test('should handle empty string as invalid', () {
        const property = EventPropertyValue.string('');
        expect(property.value, equals(''));
        expect(property.isValid(), isFalse);
      });
      test('should handle very long string as invalid', () {
        final longString = 'a' * 1001;
        final property = EventPropertyValue.string(longString);
        expect(property.value, equals(longString));
        expect(property.isValid(), isFalse);
      });
      test('should calculate estimated size correctly', () {
        const property = StringEventProperty('hello');
        expect(property.estimatedSizeBytes, equals(10)); // 5 chars * 2 bytes
      });
      test('StringEventProperty should support equality comparison', () {
        const property1 = EventPropertyValue.string('test');
        const property2 = EventPropertyValue.string('test');
        const property3 = EventPropertyValue.string('different');
        expect(property1, equals(property2));
        expect(property1, isNot(equals(property3)));
        expect(property1.hashCode, equals(property2.hashCode));
      });
      test('should handle unicode characters', () {
        const property = EventPropertyValue.string('Hello 🌍 World');
        expect(property.value, equals('Hello 🌍 World'));
        expect(property.isValid(), isTrue);
      });
    });
    group('NumberEventProperty', () {
      test('should create number property with integer', () {
        const property = EventPropertyValue.number(42);
        expect(property.value, equals(42));
        expect(property.isValid(), isTrue);
        expect(property, isA<NumberEventProperty>());
      });
      test('should create number property with double', () {
        const property = EventPropertyValue.number(3.14159);
        expect(property.value, equals(3.14159));
        expect(property.isValid(), isTrue);
      });
      test('should handle infinite values as invalid', () {
        const property = EventPropertyValue.number(double.infinity);
        expect(property.value, equals(double.infinity));
        expect(property.isValid(), isFalse);
      });
      test('should handle NaN as invalid', () {
        const property = EventPropertyValue.number(double.nan);
        expect(property.value.isNaN, isTrue);
        expect(property.isValid(), isFalse);
      });
      test('NumberEventProperty should support equality comparison', () {
        const property1 = EventPropertyValue.number(42);
        const property2 = EventPropertyValue.number(42);
        const property3 = EventPropertyValue.number(43);
        expect(property1, equals(property2));
        expect(property1, isNot(equals(property3)));
        expect(property1.hashCode, equals(property2.hashCode));
      });
      test('should handle negative numbers', () {
        const property = EventPropertyValue.number(-123.45);
        expect(property.value, equals(-123.45));
        expect(property.isValid(), isTrue);
      });
      test('should handle zero', () {
        const property = EventPropertyValue.number(0);
        expect(property.value, equals(0));
        expect(property.isValid(), isTrue);
      });
    });
    group('BooleanEventProperty', () {
      test('should create boolean property with true', () {
        const property = EventPropertyValue.boolean(true);
        expect(property.value, isTrue);
        expect(property.isValid(), isTrue);
        expect(property, isA<BooleanEventProperty>());
      });
      test('should create boolean property with false', () {
        const property = EventPropertyValue.boolean(false);
        expect(property.value, isFalse);
        expect(property.isValid(), isTrue);
      });
      test('BooleanEventProperty should support equality comparison', () {
        const property1 = EventPropertyValue.boolean(true);
        const property2 = EventPropertyValue.boolean(true);
        const property3 = EventPropertyValue.boolean(false);
        expect(property1, equals(property2));
        expect(property1, isNot(equals(property3)));
        expect(property1.hashCode, equals(property2.hashCode));
      });
    });
  });
  group('TypedEventPropertiesBuilder', () {
    late TypedEventPropertiesBuilder builder;
    setUp(() {
      builder = TypedEventPropertiesBuilder();
    });
    test('should add string property', () {
      builder.addString('name', 'John Doe');
      final properties = builder.build();
      expect(properties.toMap()['name'], equals('John Doe'));
      expect(builder.count, equals(1));
      expect(builder.hasProperty('name'), isTrue);
    });
    test('should add number property', () {
      builder.addNumber('age', 25);
      final properties = builder.build();
      expect(properties.toMap()['age'], equals(25));
    });
    test('should add boolean property', () {
      builder.addBoolean('active', true);
      final properties = builder.build();
      expect(properties.toMap()['active'], isTrue);
    });
    test('should chain builder methods', () {
      final properties = builder
          .addString('name', 'John')
          .addNumber('age', 25)
          .addBoolean('active', true)
          .build();
      final map = properties.toMap();
      expect(map['name'], equals('John'));
      expect(map['age'], equals(25));
      expect(map['active'], isTrue);
      expect(properties.count, equals(3));
    });
    test('should add all properties from map', () {
      final inputMap = {
        'name': 'John',
        'age': 25,
        'active': true,
        'unknown_type': {'nested': 'object'},
      };
      builder.addAll(inputMap);
      final properties = builder.build();
      final map = properties.toMap();
      expect(map['name'], equals('John'));
      expect(map['age'], equals(25));
      expect(map['active'], isTrue);
      expect(map['unknown_type'], equals('{nested: object}'));
    });
    test('should clear all properties', () {
      builder.addString('name', 'John').addNumber('age', 25).clear();
      expect(builder.count, equals(0));
      expect(builder.hasProperty('name'), isFalse);
      final properties = builder.build();
      expect(properties.isEmpty, isTrue);
    });
    test('should track property count correctly', () {
      expect(builder.count, equals(0));
      builder.addString('prop1', 'value1');
      expect(builder.count, equals(1));
      builder.addNumber('prop2', 42);
      expect(builder.count, equals(2));
      builder.clear();
      expect(builder.count, equals(0));
    });
    test('should check property existence', () {
      builder.addString('existing', 'value');
      expect(builder.hasProperty('existing'), isTrue);
      expect(builder.hasProperty('non_existing'), isFalse);
    });
    test('should overwrite existing property', () {
      builder.addString('key', 'original').addNumber('key', 42);
      final properties = builder.build();
      expect(properties.toMap()['key'], equals(42));
      expect(properties.count, equals(1));
    });
  });
  group('TypedEventPropertiesImpl', () {
    test('should convert to map correctly', () {
      final properties = TypedEventPropertiesBuilder()
          .addString('name', 'John')
          .addNumber('age', 25)
          .addBoolean('active', true)
          .build();
      final map = properties.toMap();
      expect(
          map,
          equals({
            'name': 'John',
            'age': 25,
            'active': true,
          }));
    });
    test('should validate valid properties', () {
      final properties = TypedEventPropertiesBuilder()
          .addString('valid_key', 'valid value')
          .addNumber('count', 42)
          .build();
      expect(properties.isValid(), isTrue);
      expect(properties.getValidationErrors(), isEmpty);
    });
    test('should detect too many properties', () {
      final builder = TypedEventPropertiesBuilder();
      for (int i = 0; i < 51; i++) {
        builder.addString('prop$i', 'value$i');
      }
      final properties = builder.build();
      expect(properties.isValid(), isFalse);
      final errors = properties.getValidationErrors();
      expect(errors, contains(contains('Too many properties')));
    });
    test('should detect invalid property keys', () {
      final invalidProperties = {
        '': const EventPropertyValue.string('empty key'),
        '123invalid': const EventPropertyValue.string('starts with number'),
        'invalid-key': const EventPropertyValue.string('contains dash'),
        'a' * 101: const EventPropertyValue.string('too long key'),
      };
      final properties = TypedEventPropertiesImpl(invalidProperties);
      expect(properties.isValid(), isFalse);
      final errors = properties.getValidationErrors();
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('empty')), isTrue);
      expect(
          errors.any((e) => e.contains('Invalid property key format')), isTrue);
      expect(errors.any((e) => e.contains('too long')), isTrue);
    });
    test('should detect invalid property values', () {
      final invalidProperties = {
        'empty_string': const EventPropertyValue.string(''),
        'long_string': EventPropertyValue.string('a' * 1001),
        'infinite_number': const EventPropertyValue.number(double.infinity),
      };
      final properties = TypedEventPropertiesImpl(invalidProperties);
      expect(properties.isValid(), isFalse);
      final errors = properties.getValidationErrors();
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('cannot be empty')), isTrue);
      expect(errors.any((e) => e.contains('too long')), isTrue);
      expect(errors.any((e) => e.contains('must be finite')), isTrue);
    });
    test('should calculate memory usage', () {
      final properties = TypedEventPropertiesBuilder()
          .addString('name', 'John') // 4 + 8 = 12 bytes
          .addNumber('age', 25) // 3 + 8 = 11 bytes
          .addBoolean('active', true) // 6 + 1 = 7 bytes
          .build();
      final memoryUsage = properties.getEstimatedMemoryUsage();
      expect(memoryUsage, greaterThan(0));
      expect(memoryUsage, greaterThan(30)); // Approximate calculation
    });
    test('should detect memory limit exceeded', () {
      final builder = TypedEventPropertiesBuilder();
      // Add a very large string to exceed 1MB limit
      final largeString = 'a' * (512 * 1024); // 512KB string
      builder.addString('large1', largeString);
      builder.addString('large2', largeString);
      builder.addString('large3', largeString); // Total > 1MB
      final properties = builder.build();
      final errors = properties.getValidationErrors();
      expect(errors.any((e) => e.contains('too large')), isTrue);
    });
    test('should provide property access methods', () {
      final properties = TypedEventPropertiesBuilder()
          .addString('name', 'John')
          .addNumber('age', 25)
          .build();
      expect(properties.getProperty('name'), isA<StringEventProperty>());
      expect(properties.getProperty('age'), isA<NumberEventProperty>());
      expect(properties.getProperty('missing'), isNull);
      expect(properties.keys, containsAll(['name', 'age']));
      expect(properties.count, equals(2));
      expect(properties.isEmpty, isFalse);
      expect(properties.isNotEmpty, isTrue);
    });
    test('should support equality comparison', () {
      final properties1 = TypedEventPropertiesBuilder()
          .addString('name', 'John')
          .addNumber('age', 25)
          .build();
      final properties2 = TypedEventPropertiesBuilder()
          .addString('name', 'John')
          .addNumber('age', 25)
          .build();
      final properties3 = TypedEventPropertiesBuilder()
          .addString('name', 'Jane')
          .addNumber('age', 25)
          .build();
      expect(properties1, equals(properties2));
      expect(properties1, isNot(equals(properties3)));
      // Note: hashCode equality is not guaranteed for different instances
    });
    test('should handle empty properties', () {
      const properties = TypedEventPropertiesImpl({});
      expect(properties.isEmpty, isTrue);
      expect(properties.isNotEmpty, isFalse);
      expect(properties.count, equals(0));
      expect(properties.keys, isEmpty);
      expect(properties.toMap(), isEmpty);
      expect(properties.isValid(), isTrue);
      expect(properties.getValidationErrors(), isEmpty);
    });
  });
  group('EventProperties Factory', () {
    test('should create builder', () {
      final builder = EventProperties.builder();
      expect(builder, isA<TypedEventPropertiesBuilder>());
      expect(builder.count, equals(0));
    });
    test('should create empty properties', () {
      final properties = EventProperties.empty();
      expect(properties.isEmpty, isTrue);
      expect(properties.isValid(), isTrue);
    });
    test('should create from map', () {
      final map = {
        'name': 'John',
        'age': 25,
        'active': true,
      };
      final properties = EventProperties.fromMap(map);
      expect(properties.count, equals(3));
      expect(properties.toMap()['name'], equals('John'));
      expect(properties.toMap()['age'], equals(25));
      expect(properties.toMap()['active'], isTrue);
    });
    test('should handle null and empty maps', () {
      final emptyProperties = EventProperties.fromMap({});
      expect(emptyProperties.isEmpty, isTrue);
      expect(emptyProperties.isValid(), isTrue);
    });
  });
  group('Edge Cases and Integration', () {
    test('should handle complex nested data structures', () {
      final complexMap = {
        'user': {
          'id': 123,
          'profile': {
            'name': 'John Doe',
          },
        },
        'metadata': {
          'version': '1.0.0',
        },
      };
      final properties = EventProperties.fromMap(complexMap);
      expect(properties.count, equals(2));
      expect(properties.isValid(), isTrue);
      // Complex objects should be converted to strings
      expect(properties.toMap()['user'], isA<String>());
      expect(properties.toMap()['metadata'], isA<String>());
    });
    test('should handle special numeric values', () {
      final builder = TypedEventPropertiesBuilder()
          .addNumber('zero', 0)
          .addNumber('negative', -42.5)
          .addNumber('large', 1e15)
          .addNumber('small', 1e-15);
      final properties = builder.build();
      expect(properties.isValid(), isTrue);
      expect(properties.toMap()['zero'], equals(0));
      expect(properties.toMap()['negative'], equals(-42.5));
      expect(properties.toMap()['large'], equals(1e15));
      expect(properties.toMap()['small'], equals(1e-15));
    });
    test('should handle unicode and special characters', () {
      final properties = TypedEventPropertiesBuilder()
          .addString('unicode', '🌍🚀✨')
          .addString('special', 'Line 1\nLine 2\tTabbed')
          .addString('quotes', 'He said "Hello World"')
          .addString('path', 'C:\\Users\\Test\\file.txt')
          .build();
      expect(properties.isValid(), isTrue);
      final map = properties.toMap();
      expect(map['unicode'], equals('🌍🚀✨'));
      expect(map['special'], contains('\n'));
      expect(map['quotes'], contains('"'));
      expect(map['path'], contains('\\'));
    });
    test('should maintain type information through serialization', () {
      final original = TypedEventPropertiesBuilder()
          .addString('name', 'John')
          .addNumber('age', 25)
          .addBoolean('active', true)
          .build();
      // Simulate serialization/deserialization cycle
      final map = original.toMap();
      final restored = EventProperties.fromMap(map);
      expect(restored.count, equals(3));
      expect(restored.toMap()['name'], equals('John'));
      expect(restored.toMap()['age'], equals(25));
      expect(restored.toMap()['active'], isTrue);
    });
    test('should handle performance with large valid datasets', () {
      final builder = TypedEventPropertiesBuilder();
      // Add maximum allowed properties with valid data
      for (int i = 0; i < 50; i++) {
        builder.addString('prop$i', 'value$i');
      }
      final properties = builder.build();
      expect(properties.isValid(), isTrue);
      expect(properties.count, equals(50));
      final stopwatch = Stopwatch()..start();
      final map = properties.toMap();
      stopwatch.stop();
      expect(map, hasLength(50));
      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
    });
    test('should validate property key patterns correctly', () {
      final validKeys = ['validKey', '_privateKey', 'key123', 'KEY_CONSTANT'];
      final invalidKeys = [
        '123invalid',
        'invalid-key',
        'invalid.key',
        'invalid key'
      ];
      for (final key in validKeys) {
        final properties = TypedEventPropertiesImpl({
          key: const EventPropertyValue.string('value'),
        });
        expect(properties.isValid(), isTrue,
            reason: 'Key "$key" should be valid');
      }
      for (final key in invalidKeys) {
        final properties = TypedEventPropertiesImpl({
          key: const EventPropertyValue.string('value'),
        });
        expect(properties.isValid(), isFalse,
            reason: 'Key "$key" should be invalid');
      }
    });
  });
}
