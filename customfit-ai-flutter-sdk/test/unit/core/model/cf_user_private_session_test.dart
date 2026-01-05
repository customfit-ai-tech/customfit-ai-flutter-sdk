import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/private_attributes_request.dart';

void main() {
  group('CFUser Private and Session Fields', () {
    group('Private Fields with Boolean Flags', () {
      test('adds private properties using boolean flags in builder', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addStringProperty('name', 'John Doe')
            .addNumberProperty('ssn', 123456789, isPrivate: true)
            .build();
        expect(user.properties['email'], equals('user@example.com'));
        expect(user.properties['name'], equals('John Doe'));
        expect(user.properties['ssn'], equals(123456789));
        expect(user.privateFields, isNotNull);
        expect(user.privateFields!.properties, contains('email'));
        expect(user.privateFields!.properties, contains('ssn'));
        expect(user.privateFields!.properties, isNot(contains('name')));
      });
      test('adds private properties using instance methods', () {
        final user = CFUser(userCustomerId: 'user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addNumberProperty('age', 25)
            .addBooleanProperty('verified', true, isPrivate: true);
        expect(user.privateFields, isNotNull);
        expect(user.privateFields!.properties, contains('email'));
        expect(user.privateFields!.properties, contains('verified'));
        expect(user.privateFields!.properties, isNot(contains('age')));
      });
      test('marks existing properties as private', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com')
            .makeAttributePrivate('email')
            .build();
        expect(user.privateFields, isNotNull);
        expect(user.privateFields!.properties, contains('email'));
      });
      test('supports different property types as private', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addNumberProperty('age', 25, isPrivate: true)
            .addBooleanProperty('verified', true, isPrivate: true)
            .addMapProperty('preferences', {'theme': 'dark'}, isPrivate: true)
            .addJsonProperty('metadata', {'version': '1.0'}, isPrivate: true)
            .addGeoPointProperty('location', 37.7749, -122.4194,
                isPrivate: true)
            .build();
        expect(
            user.privateFields!.properties,
            containsAll([
              'email',
              'age',
              'verified',
              'preferences',
              'metadata',
              'location'
            ]));
      });
    });
    group('Session Fields with Boolean Flags', () {
      test('adds session properties using boolean flags in builder', () {
        final user = CFUser.builder('user123')
            .addStringProperty('token', 'abc123', isSession: true)
            .addStringProperty('name', 'John Doe')
            .addNumberProperty('temp_score', 100, isSession: true)
            .build();
        expect(user.properties['token'], equals('abc123'));
        expect(user.properties['name'], equals('John Doe'));
        expect(user.properties['temp_score'], equals(100));
        expect(user.sessionFields, isNotNull);
        expect(user.sessionFields!.properties, contains('token'));
        expect(user.sessionFields!.properties, contains('temp_score'));
        expect(user.sessionFields!.properties, isNot(contains('name')));
      });
      test('adds session properties using instance methods', () {
        final user = CFUser(userCustomerId: 'user123')
            .addStringProperty('token', 'abc123', isSession: true)
            .addNumberProperty('age', 25)
            .addBooleanProperty('temp_flag', true, isSession: true);
        expect(user.sessionFields, isNotNull);
        expect(user.sessionFields!.properties, contains('token'));
        expect(user.sessionFields!.properties, contains('temp_flag'));
        expect(user.sessionFields!.properties, isNot(contains('age')));
      });
      test('marks existing properties as session-level', () {
        final user = CFUser.builder('user123')
            .addStringProperty('token', 'abc123')
            .makeAttributeSessionLevel('token')
            .build();
        expect(user.sessionFields, isNotNull);
        expect(user.sessionFields!.properties, contains('token'));
      });
      test('supports different property types as session', () {
        final user = CFUser.builder('user123')
            .addStringProperty('token', 'abc123', isSession: true)
            .addNumberProperty('temp_score', 100, isSession: true)
            .addBooleanProperty('temp_flag', true, isSession: true)
            .addMapProperty('temp_data', {'theme': 'dark'}, isSession: true)
            .addJsonProperty('temp_meta', {'session': 'data'}, isSession: true)
            .addGeoPointProperty('temp_location', 37.7749, -122.4194,
                isSession: true)
            .build();
        expect(
            user.sessionFields!.properties,
            containsAll([
              'token',
              'temp_score',
              'temp_flag',
              'temp_data',
              'temp_meta',
              'temp_location'
            ]));
      });
    });
    group('Combined Private and Session Fields', () {
      test('supports both private and session flags', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addStringProperty('token', 'abc123', isSession: true)
            .addStringProperty('name', 'John Doe')
            .build();
        expect(user.privateFields, isNotNull);
        expect(user.privateFields!.properties, contains('email'));
        expect(user.privateFields!.properties, isNot(contains('token')));
        expect(user.privateFields!.properties, isNot(contains('name')));
        expect(user.sessionFields, isNotNull);
        expect(user.sessionFields!.properties, contains('token'));
        expect(user.sessionFields!.properties, isNot(contains('email')));
        expect(user.sessionFields!.properties, isNot(contains('name')));
      });
      test('handles property removal from both private and session fields', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addStringProperty('token', 'abc123', isSession: true)
            .addStringProperty('name', 'John Doe')
            .build();
        final updatedUser = user.removeProperty('email');
        expect(updatedUser.properties, isNot(contains('email')));
        expect(updatedUser.privateFields, isNull);
        expect(updatedUser.sessionFields, isNotNull);
        expect(updatedUser.sessionFields!.properties, contains('token'));
      });
      test('handles property updates correctly', () {
        final user =
            CFUser.builder('user123').addStringProperty('name', 'John').build();
        final updatedUser = user.addStringProperty('name', 'Jane',
            isPrivate: true, isSession: true);
        expect(updatedUser.properties['name'], equals('Jane'));
        expect(updatedUser.privateFields!.properties, contains('name'));
        expect(updatedUser.sessionFields!.properties, contains('name'));
      });
    });
    group('Backend Format Serialization', () {
      test('serializes to correct backend format', () {
        final user = CFUser.builder('user123')
            .addStringProperty('name', 'John Doe')
            .addNumberProperty('age', 30)
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addStringProperty('token', 'abc123', isSession: true)
            .build();
        final map = user.toMap();
        expect(map['user_customer_id'], equals('user123'));
        expect(map['anonymous'], isFalse);
        expect(map['properties']['name'], equals('John Doe'));
        expect(map['properties']['age'], equals(30));
        expect(map['properties']['email'], equals('user@example.com'));
        expect(map['properties']['token'], equals('abc123'));
        // Check private_fields format matches backend expectation
        expect(map['private_fields'], isNotNull);
        expect(map['private_fields']['properties'], isA<List>());
        expect(map['private_fields']['properties'], contains('email'));
        // Check session_fields format matches backend expectation
        expect(map['session_fields'], isNotNull);
        expect(map['session_fields']['properties'], isA<List>());
        expect(map['session_fields']['properties'], contains('token'));
      });
      test('excludes empty private and session fields', () {
        final user = CFUser.builder('user123')
            .addStringProperty('name', 'John Doe')
            .build();
        final map = user.toMap();
        expect(map['private_fields'], isNull);
        expect(map['session_fields'], isNull);
      });
      test('deserializes from backend format correctly', () {
        final map = {
          'user_customer_id': 'user123',
          'anonymous': false,
          'properties': {
            'name': 'John Doe',
            'email': 'user@example.com',
            'token': 'abc123',
          },
          'private_fields': {
            'properties': ['email'],
          },
          'session_fields': {
            'properties': ['token'],
          },
        };
        final user = CFUser.fromMap(map);
        expect(user.userCustomerId, equals('user123'));
        expect(user.properties['name'], equals('John Doe'));
        expect(user.properties['email'], equals('user@example.com'));
        expect(user.properties['token'], equals('abc123'));
        expect(user.privateFields, isNotNull);
        expect(user.privateFields!.properties, contains('email'));
        expect(user.sessionFields, isNotNull);
        expect(user.sessionFields!.properties, contains('token'));
      });
    });
    group('PrivateAttributesRequest Backend Format', () {
      test('serializes to backend format', () {
        final request = PrivateAttributesRequest(
          properties: {'email', 'ssn', 'phone'},
        );
        final map = request.toMap();
        expect(map['properties'], isA<List>());
        expect(map['properties'], containsAll(['email', 'ssn', 'phone']));
      });
      test('deserializes from backend format', () {
        final map = {
          'properties': ['email', 'ssn', 'phone'],
        };
        final request = PrivateAttributesRequest.fromMap(map);
        expect(request.properties, containsAll(['email', 'ssn', 'phone']));
      });
    });
    group('Edge Cases', () {
      test('handles null and empty values correctly', () {
        final user = CFUser.builder('user123').build();
        expect(user.privateFields, isNull);
        expect(user.sessionFields, isNull);
        expect(user.properties['cf_device_type'], equals('mobile'));
      });
      test('handles multiple property updates', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'old@example.com',
                isPrivate: true, isSession: true)
            .build();
        final updatedUser = user
            .addStringProperty('email', 'new@example.com',
                isPrivate: true, isSession: true)
            .addStringProperty('phone', '+1234567890', isPrivate: true);
        expect(updatedUser.properties['email'], equals('new@example.com'));
        expect(updatedUser.properties['phone'], equals('+1234567890'));
        expect(updatedUser.privateFields!.properties, contains('email'));
        expect(updatedUser.privateFields!.properties, contains('phone'));
        expect(updatedUser.sessionFields!.properties, contains('email'));
      });
      test('handles property removal correctly', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addStringProperty('token', 'abc123', isSession: true)
            .addStringProperty('name', 'John Doe')
            .build();
        final userWithoutEmail = user.removeProperty('email');
        expect(userWithoutEmail.privateFields, isNull);
        expect(userWithoutEmail.sessionFields!.properties, contains('token'));
        final userWithoutToken = userWithoutEmail.removeProperty('token');
        expect(userWithoutToken.sessionFields, isNull);
      });
    });
    group('API Usage Examples', () {
      test('demonstrates clean API usage', () {
        // Using builder pattern with boolean flags
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addStringProperty('ssn', '123-45-6789', isPrivate: true)
            .addStringProperty('token', 'abc123', isSession: true)
            .addStringProperty('sessionId', 'sess123', isSession: true)
            .addNumberProperty('age', 30)
            .addBooleanProperty('premium', true)
            .build();
        expect(user.properties.length, equals(7)); // 6 + cf_device_type
        expect(user.privateFields!.properties.length, equals(2));
        expect(user.sessionFields!.properties.length, equals(2));
        // Using instance methods
        final updatedUser = user
            .addStringProperty('phone', '+1234567890', isPrivate: true)
            .addStringProperty('apiKey', 'key123', isSession: true);
        expect(updatedUser.privateFields!.properties.length, equals(3));
        expect(updatedUser.sessionFields!.properties.length, equals(3));
      });
    });
  });
}
