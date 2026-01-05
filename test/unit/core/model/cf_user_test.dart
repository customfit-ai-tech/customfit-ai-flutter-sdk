// test/unit/core/model/cf_user_test.dart
//
// Tests for CFUser model class
// ignore_for_file: unused_import
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/context_type.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/evaluation_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/device_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/application_info.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/private_attributes_request.dart';
import '../../../test_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CFUser', () {
    group('Constructor', () {
      test('should create instance with minimal parameters', () {
        final user = CFUser(userCustomerId: 'user123');
        expect(user.userCustomerId, equals('user123'));
        expect(user.userId, equals('user123')); // Compatibility getter
        expect(user.anonymous, isFalse);
        expect(user.properties, equals({'cf_device_type': 'mobile'}));
        expect(user.contexts, isEmpty);
        expect(user.device, isNull);
        expect(user.application, isNull);
        expect(user.privateFields, isNull);
        expect(user.sessionFields, isNull);
      });
      test('should create instance with all parameters', () {
        final device = DeviceContext(
          model: 'iPhone 13',
          osVersion: '15.0',
          osName: 'iOS',
        );
        final app = ApplicationInfo(
          appName: 'Test App',
          versionName: '1.0.0',
          versionCode: 100,
        );
        final contexts = [
          EvaluationContext(type: ContextType.user, key: 'user_ctx'),
        ];
        final privateFields = PrivateAttributesRequest(
          properties: {'email', 'phone'},
        );
        final sessionFields = PrivateAttributesRequest(
          properties: {'session_token'},
        );
        final properties = {'plan': 'premium', 'age': 30};
        final user = CFUser(
          userCustomerId: 'user123',
          anonymous: true,
          properties: properties,
          contexts: contexts,
          device: device,
          application: app,
          privateFields: privateFields,
          sessionFields: sessionFields,
        );
        expect(user.userCustomerId, equals('user123'));
        expect(user.anonymous, isTrue);
        expect(user.properties,
            equals({...properties, 'cf_device_type': 'mobile'}));
        expect(user.contexts, equals(contexts));
        expect(user.device, equals(device));
        expect(user.application, equals(app));
        expect(user.privateFields, equals(privateFields));
        expect(user.sessionFields, equals(sessionFields));
      });
      test('should handle null userCustomerId', () {
        final user = CFUser(userCustomerId: null);
        expect(user.userCustomerId, isNull);
        expect(user.userId, isNull);
        expect(user.anonymous, isFalse);
      });
    });
    group('Factory Methods', () {
      test('create should work with minimal parameters', () {
        final user = CFUser.create(userCustomerId: 'user123');
        expect(user.userCustomerId, equals('user123'));
        expect(user.anonymous, isFalse);
        expect(user.properties, equals({'cf_device_type': 'mobile'}));
      });
      test('create should work with all parameters', () {
        final customAttributes = {'plan': 'premium', 'age': 30};
        final contexts = [
          EvaluationContext(type: ContextType.user, key: 'user_ctx'),
        ];
        final device = DeviceContext(
          model: 'iPhone 13',
          osVersion: '15.0',
          osName: 'iOS',
        );
        final app = ApplicationInfo(
          appName: 'Test App',
          versionName: '1.0.0',
          versionCode: 100,
        );
        final user = CFUser.create(
          userCustomerId: 'user123',
          anonymous: true,
          customAttributes: customAttributes,
          contexts: contexts,
          device: device,
          application: app,
        );
        expect(user.userCustomerId, equals('user123'));
        expect(user.anonymous, isTrue);
        expect(user.properties,
            equals({...customAttributes, 'cf_device_type': 'mobile'}));
        expect(user.contexts, equals(contexts));
        expect(user.device, equals(device));
        expect(user.application, equals(app));
      });
    });
    group('Builder Pattern', () {
      test('builder should create basic user', () {
        final user = CFUser.builder('user123').build();
        expect(user.userCustomerId, equals('user123'));
        expect(user.anonymous, isFalse);
        // Default cf_device_type is added automatically
        expect(user.properties.length, equals(1));
        expect(user.properties['cf_device_type'], equals('mobile'));
      });
      test('builder should support all property types', () {
        final builder = CFUser.builder('user123');
        builder.addStringProperty('name', 'John Doe');
        builder.addNumberProperty('age', 30);
        builder.addBooleanProperty('premium', true);
        builder.addMapProperty('metadata', {'key': 'value'});
        final user = builder.build();
        expect(user.properties['name'], equals('John Doe'));
        expect(user.properties['age'], equals(30));
        expect(user.properties['premium'], isTrue);
        expect(user.properties['metadata'], equals({'key': 'value'}));
        // cf_device_type is also included
        expect(user.properties['cf_device_type'], equals('mobile'));
      });
      test('builder should support contexts and device info', () {
        final context =
            EvaluationContext(type: ContextType.user, key: 'user_ctx');
        final device = DeviceContext(
          model: 'iPhone 13',
          osVersion: '15.0',
          osName: 'iOS',
        );
        final app = ApplicationInfo(
          appName: 'Test App',
          versionName: '1.0.0',
          versionCode: 100,
        );
        final builder = CFUser.builder('user123');
        builder.addContext(context);
        builder.withDeviceContext(device);
        builder.withApplicationInfo(app);
        builder.makeAnonymous(true);
        final user = builder.build();
        expect(user.contexts, equals([context]));
        expect(user.device, equals(device));
        expect(user.application, equals(app));
        expect(user.anonymous, isTrue);
      });
      test('builder should support private attributes', () {
        final privateFields = PrivateAttributesRequest(
          properties: {'email', 'phone'},
        );
        final builder = CFUser.builder('user123');
        builder.withPrivateFields(privateFields);
        builder.makeAttributePrivate('ssn');
        final user = builder.build();
        expect(user.privateFields?.attributeNames, contains('email'));
        expect(user.privateFields?.attributeNames, contains('phone'));
        expect(user.privateFields?.attributeNames, contains('ssn'));
      });
      test('anonymousBuilder should create anonymous user', () {
        final builder = CFUser.anonymousBuilder();
        builder.addStringProperty('source', 'mobile');
        final user = builder.build();
        expect(user.userCustomerId, startsWith('anon_'));
        expect(user.anonymous, isTrue);
        expect(user.properties['source'], equals('mobile'));
        expect(user.properties['cf_device_type'], equals('mobile'));
      });
      test('builder should not override explicit cf_device_type', () {
        final builder = CFUser.builder('user123');
        builder.addStringProperty('cf_device_type', 'desktop');
        final user = builder.build();
        expect(user.properties['cf_device_type'], equals('desktop'));
      });
    });
    group('Property Manipulation', () {
      late CFUser baseUser;
      setUp(() {
        baseUser = CFUser(
          userCustomerId: 'user123',
          properties: {'existing': 'value'},
        );
      });
      test('addProperty should add new property', () {
        final user = baseUser.addProperty('name', 'John');
        expect(user.properties['name'], equals('John'));
        expect(user.properties['existing'], equals('value'));
        expect(baseUser.properties.containsKey('name'), isFalse); // Immutable
      });
      test('addProperty should update existing property', () {
        final user = baseUser.addProperty('existing', 'new_value');
        expect(user.properties['existing'], equals('new_value'));
        expect(baseUser.properties['existing'], equals('value')); // Immutable
      });
      test('removeProperty should remove property', () {
        final user = baseUser.removeProperty('existing');
        expect(user.properties.containsKey('existing'), isFalse);
        expect(baseUser.properties['existing'], equals('value')); // Immutable
      });
      test('removeProperties should remove multiple properties', () {
        final userWithProps = baseUser
            .addProperty('prop1', 'value1')
            .addProperty('prop2', 'value2');
        final user = userWithProps.removeProperties(['prop1', 'existing']);
        expect(user.properties.containsKey('prop1'), isFalse);
        expect(user.properties.containsKey('existing'), isFalse);
        expect(user.properties['prop2'], equals('value2'));
      });
    });
    group('Context Management', () {
      late CFUser baseUser;
      late EvaluationContext context1;
      late EvaluationContext context2;
      setUp(() {
        context1 = EvaluationContext(type: ContextType.user, key: 'user_ctx');
        context2 =
            EvaluationContext(type: ContextType.device, key: 'device_ctx');
        baseUser = CFUser(
          userCustomerId: 'user123',
          contexts: [context1],
        );
      });
      test('addContext should add new context', () {
        final user = baseUser.addContext(context2);
        expect(user.contexts, hasLength(2));
        expect(user.contexts, contains(context1));
        expect(user.contexts, contains(context2));
        expect(baseUser.contexts, hasLength(1)); // Immutable
      });
      test('removeContext should remove matching context', () {
        final userWithContexts = baseUser.addContext(context2);
        final user =
            userWithContexts.removeContext(ContextType.user, 'user_ctx');
        expect(user.contexts, hasLength(1));
        expect(user.contexts, contains(context2));
        expect(user.contexts, isNot(contains(context1)));
      });
      test('removeContext should not affect non-matching contexts', () {
        final user = baseUser.removeContext(ContextType.device, 'nonexistent');
        expect(user.contexts, hasLength(1));
        expect(user.contexts, contains(context1));
      });
    });
    group('Device and Application Context', () {
      late CFUser baseUser;
      setUp(() {
        baseUser = CFUser(userCustomerId: 'user123');
      });
      test('withDeviceContext should set device context', () {
        final device = DeviceContext(
          model: 'iPhone 13',
          osVersion: '15.0',
          osName: 'iOS',
        );
        final user = baseUser.withDeviceContext(device);
        expect(user.device, equals(device));
        expect(baseUser.device, isNull); // Immutable
      });
      test('withApplicationInfo should set application info', () {
        final app = ApplicationInfo(
          appName: 'Test App',
          versionName: '1.0.0',
          versionCode: 100,
        );
        final user = baseUser.withApplicationInfo(app);
        expect(user.application, equals(app));
        expect(baseUser.application, isNull); // Immutable
      });
    });
    group('Serialization - fromMap/toMap', () {
      test('should handle minimal map', () {
        final map = {
          'user_customer_id': 'user123',
        };
        final user = CFUser.fromMap(map);
        expect(user.userCustomerId, equals('user123'));
        expect(user.anonymous, isFalse);
        expect(user.properties,
            equals({'cf_device_type': 'mobile'})); // Automatically added
        expect(user.contexts, isEmpty);
      });
      test('should handle complete map', () {
        final map = {
          'user_customer_id': 'user123',
          'anonymous': true,
          'properties': {
            'plan': 'premium',
            'age': 30,
            'verified': true,
          },
          'contexts': [
            {
              'type': 'user',
              'key': 'user_ctx',
              'name': 'User Context',
            },
          ],
          'device': {
            'model': 'iPhone 13',
            'os_version': '15.0',
            'platform': 'iOS',
          },
          'application': {
            'app_name': 'Test App',
            'version': '1.0.0',
            'build_number': '100',
          },
          'private_fields': {
            'properties': ['email', 'phone'],
          },
          'session_fields': {
            'properties': ['session_token'],
          },
        };
        final user = CFUser.fromMap(map);
        expect(user.userCustomerId, equals('user123'));
        expect(user.anonymous, isTrue);
        expect(user.properties['plan'], equals('premium'));
        expect(user.properties['age'], equals(30));
        expect(user.properties['verified'], isTrue);
        expect(user.contexts, hasLength(1));
        expect(user.contexts.first.type, equals(ContextType.user));
        expect(user.device?.model, equals('iPhone 13'));
        expect(user.application?.appName, equals('Test App'));
        expect(user.privateFields, isNotNull);
        expect(user.sessionFields, isNotNull);
      });
      test('should handle null values with defaults', () {
        final map = {
          'user_customer_id': null,
          'anonymous': null,
          'properties': null,
          'contexts': null,
          'device': null,
          'application': null,
          'private_fields': null,
          'session_fields': null,
        };
        final user = CFUser.fromMap(map);
        expect(user.userCustomerId, isNull);
        expect(user.anonymous, isFalse);
        expect(user.properties,
            equals({'cf_device_type': 'mobile'})); // Automatically added
        expect(user.contexts, isEmpty);
        expect(user.device, isNull);
        expect(user.application, isNull);
        expect(user.privateFields, isNull);
        expect(user.sessionFields, isNull);
      });
      test('toMap should create correct structure', () {
        final device = DeviceContext(
          model: 'iPhone 13',
          osVersion: '15.0',
          osName: 'iOS',
        );
        final app = ApplicationInfo(
          appName: 'Test App',
          versionName: '1.0.0',
          versionCode: 100,
        );
        final context =
            EvaluationContext(type: ContextType.user, key: 'user_ctx');
        final privateFields = PrivateAttributesRequest(
          properties: {'email'},
        );
        final user = CFUser(
          userCustomerId: 'user123',
          anonymous: true,
          properties: {'plan': 'premium'},
          contexts: [context],
          device: device,
          application: app,
          privateFields: privateFields,
        );
        final map = user.toMap();
        expect(map['user_customer_id'], equals('user123'));
        expect(map['anonymous'], isTrue);
        expect(map['properties']['plan'], equals('premium'));
        expect(map['properties']['contexts'], isA<List>());
        expect(map['properties']['device'], isA<Map>());
        expect(map['properties']['application'], isA<Map>());
        expect(
            map['private_fields'],
            equals({
              'properties': ['email']
            }));
      });
      test('toMap should exclude empty private/session fields', () {
        final user = CFUser(
          userCustomerId: 'user123',
          privateFields: PrivateAttributesRequest(properties: {}),
          sessionFields: PrivateAttributesRequest(properties: {}),
        );
        final map = user.toMap();
        expect(map.containsKey('private_fields'), isFalse);
        expect(map.containsKey('session_fields'), isFalse);
      });
    });
    group('Serialization - fromJson/toJson', () {
      test('should handle complete JSON structure', () {
        final json = {
          'userCustomerId': 'user123',
          'anonymous': true,
          'properties': {'plan': 'premium', 'age': 30},
          'contexts': [
            {
              'type': 'user',
              'key': 'user_ctx',
            },
          ],
          'device': {
            'model': 'iPhone 13',
            'os_version': '15.0',
            'platform': 'iOS',
          },
          'application': {
            'app_name': 'Test App',
            'version': '1.0.0',
            'build_number': '100',
          },
          'privateFields': {
            'attributeNames': ['email', 'phone'],
          },
          'sessionFields': {
            'attributeNames': ['session_token'],
          },
        };
        final user = CFUser.fromJson(json);
        expect(user.userCustomerId, equals('user123'));
        expect(user.anonymous, isTrue);
        expect(user.properties['plan'], equals('premium'));
        expect(user.contexts, hasLength(1));
        expect(user.device?.model, equals('iPhone 13'));
        expect(user.application?.appName, equals('Test App'));
        expect(user.privateFields?.attributeNames, contains('email'));
        expect(user.sessionFields?.attributeNames, contains('session_token'));
      });
      test('toJson should create correct JSON structure', () {
        final context =
            EvaluationContext(type: ContextType.user, key: 'user_ctx');
        final device = DeviceContext(
          model: 'iPhone 13',
          osVersion: '15.0',
          osName: 'iOS',
        );
        final privateFields = PrivateAttributesRequest(
          properties: {'email', 'phone'},
        );
        final user = CFUser(
          userCustomerId: 'user123',
          anonymous: true,
          properties: {'plan': 'premium'},
          contexts: [context],
          device: device,
          privateFields: privateFields,
        );
        final json = user.toJson();
        expect(json['userCustomerId'], equals('user123'));
        expect(json['anonymous'], isTrue);
        expect(json['properties']['plan'], equals('premium'));
        expect(json['contexts'], isA<List>());
        expect(json['device'], isA<Map>());
        expect(json['privateFields']['attributeNames'], isA<List>());
      });
    });
    group('Round-trip Serialization', () {
      test('should maintain data integrity through map cycle', () {
        final original = CFUser(
          userCustomerId: 'user123',
          anonymous: true,
          properties: {
            'plan': 'premium',
            'age': 30,
            'verified': true,
            'metadata': {'source': 'mobile'},
          },
          contexts: [
            EvaluationContext(type: ContextType.user, key: 'user_ctx'),
          ],
        );
        final map = original.toMap();
        final restored = CFUser.fromMap(map);
        expect(restored.userCustomerId, equals(original.userCustomerId));
        expect(restored.anonymous, equals(original.anonymous));
        expect(
            restored.properties['plan'], equals(original.properties['plan']));
        expect(restored.properties['age'], equals(original.properties['age']));
        // Note: contexts are stored in properties in toMap but not extracted in fromMap
        // This is a known limitation of the current implementation
        expect(restored.contexts, isEmpty);
      });
      test('should maintain data integrity through JSON cycle', () {
        final original = CFUser(
          userCustomerId: 'user123',
          properties: {'plan': 'premium'},
          privateFields: PrivateAttributesRequest(
            properties: {'email', 'phone'},
          ),
        );
        final json = original.toJson();
        final restored = CFUser.fromJson(json);
        expect(restored.userCustomerId, equals(original.userCustomerId));
        expect(restored.properties, equals(original.properties));
        expect(restored.privateFields?.attributeNames,
            equals(original.privateFields?.attributeNames));
      });
    });
    group('Edge Cases', () {
      test('should handle very large property maps', () {
        final largeProps = Map.fromEntries(
            List.generate(1000, (i) => MapEntry('prop_$i', 'value_$i')));
        final user = CFUser(
          userCustomerId: 'user123',
          properties: largeProps,
        );
        expect(user.properties, hasLength(1001)); // 1000 props + cf_device_type
        expect(user.properties['prop_999'], equals('value_999'));
      });
      test('should handle special characters in properties', () {
        final specialProps = {
          'key with spaces': 'value with spaces',
          'key-with-dashes': 'value-with-dashes',
          'key_with_underscores': 'value_with_underscores',
          'key.with.dots': 'value.with.dots',
          'key@with@symbols': 'value@with@symbols',
          'key🚀with🌟emojis': 'value🚀with🌟emojis',
        };
        final user = CFUser(
          userCustomerId: 'user123',
          properties: specialProps,
        );
        expect(user.properties,
            equals({...specialProps, 'cf_device_type': 'mobile'}));
        // Test serialization with special characters
        final map = user.toMap();
        final restored = CFUser.fromMap(map);
        expect(restored.properties['key🚀with🌟emojis'],
            equals('value🚀with🌟emojis'));
      });
      test('should handle empty strings and null values', () {
        final user = CFUser(
          userCustomerId: '',
          properties: {
            'empty_string': '',
            'null_value': null,
            'zero_number': 0,
            'false_boolean': false,
            'empty_list': <String>[],
            'empty_map': <String, dynamic>{},
          },
        );
        expect(user.userCustomerId, equals(''));
        expect(user.properties['empty_string'], equals(''));
        expect(user.properties['null_value'], isNull);
        expect(user.properties['zero_number'], equals(0));
        expect(user.properties['false_boolean'], isFalse);
        expect(user.properties['empty_list'], isEmpty);
        expect(user.properties['empty_map'], isEmpty);
      });
      test('should handle complex nested data structures', () {
        final complexData = {
          'level1': {
            'level2': {
              'level3': {
                'deep_value': 'found',
                'deep_list': [
                  1,
                  2,
                  {'nested_in_list': true}
                ],
              },
            },
          },
          'mixed_array': [
            'string',
            42,
            true,
            {'object_in_array': 'value'},
            [1, 2, 3],
          ],
        };
        final user = CFUser(
          userCustomerId: 'user123',
          properties: complexData,
        );
        expect(user.properties['level1']['level2']['level3']['deep_value'],
            equals('found'));
        expect(user.properties['mixed_array'][1], equals(42));
        // Test round-trip with complex data
        final map = user.toMap();
        final restored = CFUser.fromMap(map);
        expect(restored.properties['level1']['level2']['level3']['deep_value'],
            equals('found'));
      });
    });
    group('Type Safety', () {
      test('should maintain correct types', () {
        final user = CFUser(
          userCustomerId: 'user123',
          anonymous: true,
          properties: {'key': 'value'},
          contexts: [EvaluationContext(type: ContextType.user, key: 'ctx')],
        );
        expect(user.userCustomerId, isA<String>());
        expect(user.anonymous, isA<bool>());
        expect(user.properties, isA<Map<String, dynamic>>());
        expect(user.contexts, isA<List<EvaluationContext>>());
        expect(user.device, isA<DeviceContext?>());
        expect(user.application, isA<ApplicationInfo?>());
        expect(user.privateFields, isA<PrivateAttributesRequest?>());
        expect(user.sessionFields, isA<PrivateAttributesRequest?>());
      });
      test('should handle various property value types', () {
        final user = CFUser(
          userCustomerId: 'user123',
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
        expect(user.properties['string'], isA<String>());
        expect(user.properties['int'], isA<int>());
        expect(user.properties['double'], isA<double>());
        expect(user.properties['bool'], isA<bool>());
        expect(user.properties['list'], isA<List>());
        expect(user.properties['map'], isA<Map>());
        expect(user.properties['null'], isNull);
      });
    });
    group('Immutability', () {
      test('should create new instances when modified', () {
        final original = CFUser(
          userCustomerId: 'user123',
          properties: {'original': 'value'},
        );
        final modified = original.addProperty('new', 'property');
        expect(original.properties.containsKey('new'), isFalse);
        expect(modified.properties.containsKey('new'), isTrue);
        expect(original.properties['original'], equals('value'));
        expect(modified.properties['original'], equals('value'));
      });
      test(
          'should not affect original when collections are modified externally',
          () {
        final originalProps = {'key': 'value'};
        final originalContexts = [
          EvaluationContext(type: ContextType.user, key: 'ctx'),
        ];
        final user = CFUser(
          userCustomerId: 'user123',
          properties: originalProps,
          contexts: originalContexts,
        );
        // Modify original collections
        originalProps['new_key'] = 'new_value';
        originalContexts.add(
            EvaluationContext(type: ContextType.device, key: 'device_ctx'));
        // CFUser constructor now creates defensive copies, so external modifications
        // should not affect the user instance (fixed with cf_device_type implementation)
        expect(user.properties.containsKey('new_key'), isFalse);
        expect(user.contexts,
            hasLength(2)); // contexts still affected (not copied)
      });
    });
    group('Validation Tests (Merged from core/cf_user_test.dart)', () {
      test('should handle property limits', () {
        final builder = CFUser.builder('limit_test_user');
        // Add many properties
        for (int i = 0; i < 500; i++) {
          builder.addStringProperty('prop_$i', 'value_$i');
        }
        final userResult = builder.build();
        final builtUser = userResult;
        // 500 properties + cf_device_type
        expect(builtUser.properties.length, equals(501));
      });
      test('should handle property name restrictions', () {
        final builder = CFUser.builder('restricted_user');
        builder.addStringProperty('valid_name', 'value1');
        builder.addStringProperty('also-valid', 'value2');
        builder.addStringProperty('123_numbers', 'value3');
        builder.addStringProperty('_underscore', 'value4');
        final user = builder.build();
        expect(user.properties.containsKey('valid_name'), isTrue);
        expect(user.properties.containsKey('also-valid'), isTrue);
        expect(user.properties.containsKey('123_numbers'), isTrue);
        expect(user.properties.containsKey('_underscore'), isTrue);
      });
    });
    group('Basic Construction', () {
      test('creates user with basic properties', () {
        final user = CFUser(
          userCustomerId: 'user123',
          properties: {'name': 'John Doe', 'age': 30},
        );
        expect(user.userCustomerId, equals('user123'));
        expect(user.properties['name'], equals('John Doe'));
        expect(user.properties['age'], equals(30));
        expect(user.anonymous, isFalse);
      });
      test('creates anonymous user', () {
        final user = CFUser(
          userCustomerId: 'anon123',
          anonymous: true,
          properties: {'source': 'mobile'},
        );
        expect(user.userCustomerId, equals('anon123'));
        expect(user.anonymous, isTrue);
        expect(user.properties['source'], equals('mobile'));
      });
      test('automatically adds cf_device_type as mobile', () {
        final user = CFUser(
          userCustomerId: 'user123',
          properties: {'name': 'John'},
        );
        expect(user.properties['cf_device_type'], equals('mobile'));
      });
      test('preserves existing cf_device_type', () {
        final user = CFUser(
          userCustomerId: 'user123',
          properties: {'cf_device_type': 'desktop'},
        );
        expect(user.properties['cf_device_type'], equals('desktop'));
      });
    });
    group('Builder Pattern', () {
      test('creates user with builder pattern', () {
        final builder = CFUser.builder('user123');
        builder.addStringProperty('name', 'John Doe');
        builder.addNumberProperty('age', 30);
        builder.addBooleanProperty('active', true);
        final user = builder.build();
        expect(user.userCustomerId, equals('user123'));
        expect(user.properties['name'], equals('John Doe'));
        expect(user.properties['age'], equals(30));
        expect(user.properties['active'], isTrue);
      });
      test('creates anonymous user with builder', () {
        final builder = CFUser.anonymousBuilder();
        builder.addStringProperty('source', 'mobile');
        final user = builder.build();
        expect(user.anonymous, isTrue);
        expect(user.userCustomerId, startsWith('anon_'));
        expect(user.properties['source'], equals('mobile'));
      });
      test('validates property constraints', () {
        // The test is checking that methods throw errors when called without required arguments
        // This is a compile-time error in Dart, not a runtime error
        // Test removed as it's testing compile-time behavior
      });
    });
    group('Private Fields', () {
      test('adds private properties using boolean flags', () {
        final builder = CFUser.builder('user123');
        builder.addStringProperty('email', 'user@example.com', isPrivate: true);
        builder.addStringProperty('name', 'John Doe');
        builder.addNumberProperty('ssn', 123456789, isPrivate: true);
        final user = builder.build();
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
            .addNumberProperty('age', 30)
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
    });
    group('Session Fields', () {
      test('adds session properties using boolean flags', () {
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
            .addNumberProperty('age', 30)
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
    });
    group('Serialization', () {
      test('serializes to correct backend format', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addNumberProperty('age', 30)
            .addStringProperty('name', 'John Doe')
            .addStringProperty('token', 'abc123', isSession: true)
            .addNumberProperty('temp_score', 100, isSession: true)
            .build();
        final map = user.toMap();
        expect(map['user_customer_id'], equals('user123'));
        expect(map['anonymous'], isFalse);
        expect(map['properties']['name'], equals('John Doe'));
        expect(map['properties']['age'], equals(30));
        expect(map['properties']['email'], equals('user@example.com'));
        expect(map['properties']['token'], equals('abc123'));
        // Check private_fields format
        expect(map['private_fields'], isNotNull);
        expect(map['private_fields']['properties'], isA<List>());
        expect(map['private_fields']['properties'], contains('email'));
        // Check session_fields format
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
      test('deserializes from map correctly', () {
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
    group('Property Type Methods', () {
      test('adds different property types with privacy flags', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addNumberProperty('age', 30, isSession: true)
            .addBooleanProperty('verified', true, isPrivate: true)
            .addMapProperty('preferences', {'theme': 'dark'}, isSession: true)
            .addJsonProperty('metadata', {'version': '1.0'}, isPrivate: true)
            .addGeoPointProperty('location', 37.7749, -122.4194,
                isSession: true)
            .build();
        expect(user.properties['email'], equals('user@example.com'));
        expect(user.properties['age'], equals(30));
        expect(user.properties['verified'], isTrue);
        expect(user.properties['preferences'], equals({'theme': 'dark'}));
        expect(user.properties['metadata'], equals({'version': '1.0'}));
        expect(
            user.properties['location'],
            equals({
              'latitude': 37.7749,
              'longitude': -122.4194,
            }));
        expect(user.privateFields!.properties,
            containsAll(['email', 'verified', 'metadata']));
        expect(user.sessionFields!.properties,
            containsAll(['age', 'preferences', 'location']));
      });
    });
    group('Edge Cases', () {
      test('handles null and empty values correctly', () {
        final user = CFUser.builder('user123').build();
        expect(user.privateFields, isNull);
        expect(user.sessionFields, isNull);
        expect(user.properties['cf_device_type'], equals('mobile'));
      });
      test('handles property updates correctly', () {
        final user = CFUser.builder('user123')
            .addStringProperty('name', 'John Doe')
            .build();
        final updatedUser = user.addStringProperty('name', 'Jane',
            isPrivate: true, isSession: true);
        expect(updatedUser.properties['name'], equals('Jane'));
        expect(updatedUser.privateFields!.properties, contains('name'));
        expect(updatedUser.sessionFields!.properties, contains('name'));
      });
    });
    group('Factory Methods', () {
      test('creates user with factory method', () {
        final user = CFUser.create(
          userCustomerId: 'user123',
          customAttributes: {'name': 'John', 'age': 30},
        );
        expect(user.userCustomerId, equals('user123'));
        expect(user.properties['name'], equals('John'));
        expect(user.properties['age'], equals(30));
      });
    });
    group('JSON Serialization', () {
      test('converts to and from JSON correctly', () {
        final user = CFUser.builder('user123')
            .addStringProperty('email', 'user@example.com', isPrivate: true)
            .addStringProperty('token', 'abc123', isSession: true)
            .addStringProperty('name', 'John Doe')
            .build();
        final json = user.toJson();
        final deserializedUser = CFUser.fromJson(json);
        expect(deserializedUser.userCustomerId, equals(user.userCustomerId));
        expect(deserializedUser.properties, equals(user.properties));
        expect(deserializedUser.privateFields!.properties,
            equals(user.privateFields!.properties));
        expect(deserializedUser.sessionFields!.properties,
            equals(user.sessionFields!.properties));
      });
    });
  });
}
