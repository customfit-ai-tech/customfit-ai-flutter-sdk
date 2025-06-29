import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/private_attributes_request.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PrivateAttributesRequest', () {
    group('Constructor', () {
      test('should create instance with default values', () {
        final request = PrivateAttributesRequest();
        expect(request.properties, isEmpty);
        expect(request.attributeNames, isEmpty);
      });
      test('should create instance with properties', () {
        final properties = {'email', 'phone', 'address'};
        final request = PrivateAttributesRequest(properties: properties);
        expect(request.properties, equals(properties));
        expect(request.attributeNames, equals(properties));
      });
      test('should handle empty properties', () {
        final request = PrivateAttributesRequest(properties: <String>{});
        expect(request.properties, isEmpty);
        expect(request.attributeNames, isEmpty);
      });
    });
    group('Factory Constructor fromAttributeNames', () {
      test('should create from attribute names', () {
        final attributeNames = {'email', 'phone'};
        final request =
            PrivateAttributesRequest.fromAttributeNames(attributeNames);
        expect(request.properties, equals(attributeNames));
        expect(request.attributeNames, equals(attributeNames));
      });
    });
    group('Serialization - fromMap/toMap', () {
      test('should handle minimal map with new format', () {
        final map = {
          'properties': ['email', 'phone'],
        };
        final request = PrivateAttributesRequest.fromMap(map);
        expect(request.properties, equals({'email', 'phone'}));
      });
      test('should handle empty map', () {
        final map = <String, dynamic>{};
        final request = PrivateAttributesRequest.fromMap(map);
        expect(request.properties, isEmpty);
      });
      test('should handle map with empty properties list', () {
        final map = {
          'properties': <String>[],
        };
        final request = PrivateAttributesRequest.fromMap(map);
        expect(request.properties, isEmpty);
      });
      test('should create correct map structure for backend', () {
        final request = PrivateAttributesRequest(
          properties: {'email', 'phone', 'address'},
        );
        final map = request.toMap();
        expect(map['properties'], isA<List<String>>());
        expect(map['properties'], containsAll(['email', 'phone', 'address']));
        expect(map['properties'].length, equals(3));
      });
      test('should handle empty properties in toMap', () {
        final request = PrivateAttributesRequest(properties: <String>{});
        final map = request.toMap();
        expect(map['properties'], isA<List<String>>());
        expect(map['properties'], isEmpty);
      });
      test('should maintain set ordering in toMap', () {
        final request = PrivateAttributesRequest(
          properties: {'c', 'a', 'b'}, // Unordered set
        );
        final map = request.toMap();
        final resultList = map['properties'] as List<String>;
        // Set should contain all elements regardless of order
        expect(resultList, containsAll(['a', 'b', 'c']));
        expect(resultList.length, equals(3));
      });
    });
    group('Round-trip Serialization', () {
      test('should maintain data integrity through map cycle', () {
        final original = PrivateAttributesRequest(
          properties: {'email', 'phone', 'address'},
        );
        final map = original.toMap();
        final restored = PrivateAttributesRequest.fromMap(map);
        expect(restored.properties, equals(original.properties));
      });
    });
    group('Edge Cases', () {
      test('should handle large number of properties', () {
        final largeProperties =
            Set<String>.from(List.generate(1000, (i) => 'property_$i'));
        final request = PrivateAttributesRequest(properties: largeProperties);
        expect(request.properties, hasLength(1000));
        expect(request.properties, contains('property_999'));
        final map = request.toMap();
        final restored = PrivateAttributesRequest.fromMap(map);
        expect(restored.properties, equals(largeProperties));
      });
      test('should handle special characters in property names', () {
        final specialProperties = {
          'email@domain.com',
          'field-with-dashes',
          'field_with_underscores',
          'field.with.dots',
          'field with spaces',
          'field🚀with🌟emojis',
        };
        final request = PrivateAttributesRequest(properties: specialProperties);
        expect(request.properties, equals(specialProperties));
        final map = request.toMap();
        final restored = PrivateAttributesRequest.fromMap(map);
        expect(restored.properties, equals(specialProperties));
      });
      test('should handle duplicate property names in set', () {
        final properties = {'email', 'phone'};
        final request = PrivateAttributesRequest(properties: properties);
        expect(request.properties, hasLength(2));
        expect(request.properties, equals(properties));
      });
      test('should handle empty and whitespace property names', () {
        final properties = {'', 'valid_field', '   '};
        final request = PrivateAttributesRequest(properties: properties);
        expect(request.properties, equals(properties));
        expect(request.properties, hasLength(3));
      });
    });
    group('Immutability', () {
      test('should not affect original when properties are modified externally',
          () {
        final originalProperties = {'email', 'phone'};
        final request =
            PrivateAttributesRequest(properties: originalProperties);
        // Modify original set
        originalProperties.add('address');
        // Request should not be affected
        expect(request.properties, hasLength(2));
        expect(request.properties, contains('email'));
        expect(request.properties, contains('phone'));
        expect(request.properties, isNot(contains('address')));
      });
      test('should create defensive copies', () {
        final originalProperties = {'field1', 'field2'};
        final request =
            PrivateAttributesRequest(properties: originalProperties);
        // The properties should be a copy, so modifying the original doesn't affect the request
        originalProperties.add('field3');
        expect(request.properties, hasLength(2));
        expect(request.properties, isNot(contains('field3')));
      });
    });
    group('Type Safety', () {
      test('should maintain correct types', () {
        final request = PrivateAttributesRequest(
          properties: {'email', 'phone'},
        );
        expect(request.properties, isA<Set<String>>());
        expect(request.attributeNames, isA<Set<String>>());
      });
    });
    group('Validation', () {
      test('should handle null properties gracefully', () {
        final request = PrivateAttributesRequest(properties: null);
        expect(request.properties, isEmpty);
      });
      test('should handle various property name formats', () {
        final validProperties = {
          'simple',
          'with_underscores',
          'with-dashes',
          'with.dots',
          'with123numbers',
          'CamelCase',
          'snake_case',
          'kebab-case',
        };
        final request = PrivateAttributesRequest(properties: validProperties);
        expect(request.properties, equals(validProperties));
        expect(request.properties, hasLength(8));
      });
    });
  });
}
