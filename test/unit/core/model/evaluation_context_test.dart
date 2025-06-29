import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/evaluation_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/context_type.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EvaluationContext', () {
    group('Constructor', () {
      test('should create instance with required fields', () {
        final context = EvaluationContext(
          type: ContextType.user,
          key: 'user123',
        );
        expect(context.type, equals(ContextType.user));
        expect(context.key, equals('user123'));
        expect(context.name, isNull);
        expect(context.properties, isEmpty);
        expect(context.privateAttributes, isEmpty);
      });
      test('should create instance with all fields', () {
        final properties = {'age': 25, 'country': 'US'};
        final privateAttrs = ['email', 'phone'];
        final context = EvaluationContext(
          type: ContextType.organization,
          key: 'org456',
          name: 'Test Organization',
          properties: properties,
          privateAttributes: privateAttrs,
        );
        expect(context.type, equals(ContextType.organization));
        expect(context.key, equals('org456'));
        expect(context.name, equals('Test Organization'));
        expect(context.properties, equals(properties));
        expect(context.privateAttributes, equals(privateAttrs));
      });
      test('should handle empty collections', () {
        final context = EvaluationContext(
          type: ContextType.device,
          key: 'device789',
          properties: {},
          privateAttributes: [],
        );
        expect(context.type, equals(ContextType.device));
        expect(context.key, equals('device789'));
        expect(context.properties, isEmpty);
        expect(context.privateAttributes, isEmpty);
      });
    });
    group('fromMap', () {
      test('should create instance from complete map', () {
        final map = {
          'type': 'user',
          'key': 'user123',
          'name': 'John Doe',
          'properties': {
            'age': 30,
            'country': 'US',
            'premium': true,
          },
          'private_attributes': ['email', 'phone', 'ssn'],
        };
        final context = EvaluationContext.fromMap(map);
        expect(context.type, equals(ContextType.user));
        expect(context.key, equals('user123'));
        expect(context.name, equals('John Doe'));
        expect(
            context.properties,
            equals({
              'age': 30,
              'country': 'US',
              'premium': true,
            }));
        expect(context.privateAttributes, equals(['email', 'phone', 'ssn']));
      });
      test('should handle minimal map with required fields only', () {
        final map = {
          'type': 'device',
          'key': 'device456',
        };
        final context = EvaluationContext.fromMap(map);
        expect(context.type, equals(ContextType.device));
        expect(context.key, equals('device456'));
        expect(context.name, isNull);
        expect(context.properties, isEmpty);
        expect(context.privateAttributes, isEmpty);
      });
      test('should handle unknown context type with custom fallback', () {
        final map = {
          'type': 'unknown_type',
          'key': 'test123',
        };
        final context = EvaluationContext.fromMap(map);
        expect(context.type, equals(ContextType.custom));
        expect(context.key, equals('test123'));
      });
      test('should handle all context types correctly', () {
        final contextTypes = [
          ('user', ContextType.user),
          ('device', ContextType.device),
          ('app', ContextType.app),
          ('session', ContextType.session),
          ('organization', ContextType.organization),
          ('custom', ContextType.custom),
        ];
        for (final (typeString, expectedType) in contextTypes) {
          final map = {
            'type': typeString,
            'key': 'test_key',
          };
          final context = EvaluationContext.fromMap(map);
          expect(context.type, equals(expectedType),
              reason: 'Failed for type: $typeString');
        }
      });
      test('should handle null values with defaults', () {
        final map = {
          'type': 'user',
          'key': 'user123',
          'name': null,
          'properties': null,
          'private_attributes': null,
        };
        final context = EvaluationContext.fromMap(map);
        expect(context.type, equals(ContextType.user));
        expect(context.key, equals('user123'));
        expect(context.name, isNull);
        expect(context.properties, isEmpty);
        expect(context.privateAttributes, isEmpty);
      });
      test('should handle wrong type for properties', () {
        final map = {
          'type': 'user',
          'key': 'user123',
          'properties': 'not_a_map',
        };
        // This should throw an exception as the implementation doesn't handle non-maps
        expect(() => EvaluationContext.fromMap(map), throwsA(isA<TypeError>()));
      });
      test('should handle mixed types in private_attributes', () {
        final map = {
          'type': 'user',
          'key': 'user123',
          'private_attributes': ['string', 123, true, null],
        };
        // This should handle type conversion gracefully
        expect(() => EvaluationContext.fromMap(map), throwsA(isA<TypeError>()));
      });
      test('should handle complex properties', () {
        final map = {
          'type': 'organization',
          'key': 'org123',
          'properties': {
            'nested': {'department': 'engineering'},
            'employees': [
              {'name': 'John', 'role': 'developer'},
              {'name': 'Jane', 'role': 'designer'},
            ],
            'active': true,
            'revenue': 1000000.50,
            'metadata': null,
          },
        };
        final context = EvaluationContext.fromMap(map);
        expect(context.properties['nested'],
            equals({'department': 'engineering'}));
        expect(context.properties['employees'], isA<List>());
        expect(context.properties['active'], isTrue);
        expect(context.properties['revenue'], equals(1000000.50));
        expect(context.properties['metadata'], isNull);
      });
    });
    group('toMap', () {
      test('should convert to map with all fields', () {
        final context = EvaluationContext(
          type: ContextType.user,
          key: 'user123',
          name: 'John Doe',
          properties: {'age': 30, 'country': 'US'},
          privateAttributes: ['email', 'phone'],
        );
        final map = context.toMap();
        expect(map['type'], equals('user'));
        expect(map['key'], equals('user123'));
        expect(map['name'], equals('John Doe'));
        expect(map['properties'], equals({'age': 30, 'country': 'US'}));
        expect(map['private_attributes'], equals(['email', 'phone']));
      });
      test('should exclude null name from map', () {
        final context = EvaluationContext(
          type: ContextType.device,
          key: 'device456',
          // name is null
        );
        final map = context.toMap();
        expect(map.containsKey('name'), isFalse);
        expect(map['type'], equals('device'));
        expect(map['key'], equals('device456'));
        expect(map['properties'], isEmpty);
        expect(map['private_attributes'], isEmpty);
      });
      test('should handle empty collections', () {
        final context = EvaluationContext(
          type: ContextType.app,
          key: 'app789',
          properties: {},
          privateAttributes: [],
        );
        final map = context.toMap();
        expect(map['type'], equals('app'));
        expect(map['key'], equals('app789'));
        expect(map['properties'], isEmpty);
        expect(map['private_attributes'], isEmpty);
      });
      test('should convert all context types correctly', () {
        final contextTypes = [
          (ContextType.user, 'user'),
          (ContextType.device, 'device'),
          (ContextType.app, 'app'),
          (ContextType.session, 'session'),
          (ContextType.organization, 'organization'),
          (ContextType.custom, 'custom'),
        ];
        for (final (contextType, expectedString) in contextTypes) {
          final context = EvaluationContext(
            type: contextType,
            key: 'test_key',
          );
          final map = context.toMap();
          expect(map['type'], equals(expectedString),
              reason: 'Failed for type: $contextType');
        }
      });
      test('should preserve complex properties', () {
        final complexProperties = {
          'nested': {
            'deep': {'value': 'test'}
          },
          'array': [1, 'two', true],
          'null_val': null,
        };
        final context = EvaluationContext(
          type: ContextType.custom,
          key: 'custom123',
          properties: complexProperties,
        );
        final map = context.toMap();
        expect(map['properties'], equals(complexProperties));
      });
    });
    group('Round-trip Serialization', () {
      test('should maintain data integrity through map cycle', () {
        final original = EvaluationContext(
          type: ContextType.organization,
          key: 'org123',
          name: 'Test Org',
          properties: {
            'size': 'large',
            'industry': 'tech',
            'revenue': 5000000,
            'public': false,
            'metadata': {'founded': 2020},
          },
          privateAttributes: ['financial_data', 'employee_list'],
        );
        final map = original.toMap();
        final restored = EvaluationContext.fromMap(map);
        expect(restored.type, equals(original.type));
        expect(restored.key, equals(original.key));
        expect(restored.name, equals(original.name));
        expect(restored.properties, equals(original.properties));
        expect(restored.privateAttributes, equals(original.privateAttributes));
      });
      test('should handle minimal data in round-trip', () {
        final original = EvaluationContext(
          type: ContextType.session,
          key: 'session456',
        );
        final map = original.toMap();
        final restored = EvaluationContext.fromMap(map);
        expect(restored.type, equals(original.type));
        expect(restored.key, equals(original.key));
        expect(restored.name, equals(original.name));
        expect(restored.properties, equals(original.properties));
        expect(restored.privateAttributes, equals(original.privateAttributes));
      });
    });
    group('Edge Cases', () {
      test('should handle very long keys', () {
        final longKey = 'key_${'x' * 1000}';
        final context = EvaluationContext(
          type: ContextType.user,
          key: longKey,
        );
        expect(context.key, equals(longKey));
        // Test serialization with long key
        final map = context.toMap();
        final restored = EvaluationContext.fromMap(map);
        expect(restored.key, equals(longKey));
      });
      test('should handle special characters in key and name', () {
        const specialKey = 'key@with#special\$characters';
        const specialName = 'Name with 🚀 emojis and spaces';
        final context = EvaluationContext(
          type: ContextType.device,
          key: specialKey,
          name: specialName,
        );
        expect(context.key, equals(specialKey));
        expect(context.name, equals(specialName));
        // Test round-trip with special characters
        final map = context.toMap();
        final restored = EvaluationContext.fromMap(map);
        expect(restored.key, equals(specialKey));
        expect(restored.name, equals(specialName));
      });
      test('should handle empty strings', () {
        final context = EvaluationContext(
          type: ContextType.custom,
          key: '',
          name: '',
          privateAttributes: ['', 'valid_attr', ''],
        );
        expect(context.key, equals(''));
        expect(context.name, equals(''));
        expect(context.privateAttributes, equals(['', 'valid_attr', '']));
      });
      test('should handle very large collections', () {
        final largeProperties = Map.fromEntries(
            List.generate(1000, (i) => MapEntry('prop_$i', 'value_$i')));
        final largePrivateAttrs = List.generate(1000, (i) => 'attr_$i');
        final context = EvaluationContext(
          type: ContextType.user,
          key: 'user_large',
          properties: largeProperties,
          privateAttributes: largePrivateAttrs,
        );
        expect(context.properties, hasLength(1000));
        expect(context.privateAttributes, hasLength(1000));
        // Test round-trip with large data
        final map = context.toMap();
        final restored = EvaluationContext.fromMap(map);
        expect(restored.properties, equals(largeProperties));
        expect(restored.privateAttributes, equals(largePrivateAttrs));
      });
      test('should handle duplicate private attributes', () {
        final duplicateAttrs = ['attr1', 'attr2', 'attr1', 'attr3', 'attr2'];
        final context = EvaluationContext(
          type: ContextType.app,
          key: 'app123',
          privateAttributes: duplicateAttrs,
        );
        expect(context.privateAttributes,
            equals(duplicateAttrs)); // Should preserve duplicates
        expect(context.privateAttributes, hasLength(5));
      });
    });
    group('Type Safety', () {
      test('should maintain correct types', () {
        final context = EvaluationContext(
          type: ContextType.user,
          key: 'user123',
          name: 'John',
          properties: {'age': 30},
          privateAttributes: ['email'],
        );
        expect(context.type, isA<ContextType>());
        expect(context.key, isA<String>());
        expect(context.name, isA<String>());
        expect(context.properties, isA<Map<String, dynamic>>());
        expect(context.privateAttributes, isA<List<String>>());
        // Check individual elements
        for (final attr in context.privateAttributes) {
          expect(attr, isA<String>());
        }
      });
      test('should handle various property value types', () {
        final context = EvaluationContext(
          type: ContextType.organization,
          key: 'org123',
          properties: {
            'string': 'text',
            'int': 42,
            'double': 3.14,
            'bool': true,
            'list': [1, 2, 3],
            'map': {'nested': 'value'},
            'null': null,
          },
        );
        expect(context.properties['string'], isA<String>());
        expect(context.properties['int'], isA<int>());
        expect(context.properties['double'], isA<double>());
        expect(context.properties['bool'], isA<bool>());
        expect(context.properties['list'], isA<List>());
        expect(context.properties['map'], isA<Map>());
        expect(context.properties['null'], isNull);
      });
      test('should support enum operations', () {
        final contexts = [
          EvaluationContext(type: ContextType.user, key: 'user1'),
          EvaluationContext(type: ContextType.device, key: 'device1'),
          EvaluationContext(type: ContextType.app, key: 'app1'),
        ];
        // Test enum comparison
        expect(contexts[0].type == ContextType.user, isTrue);
        expect(contexts[1].type == ContextType.device, isTrue);
        expect(contexts[0].type != contexts[1].type, isTrue);
        // Test enum in collections
        final userContexts =
            contexts.where((c) => c.type == ContextType.user).toList();
        expect(userContexts, hasLength(1));
        expect(userContexts.first.key, equals('user1'));
      });
    });
  });
}
