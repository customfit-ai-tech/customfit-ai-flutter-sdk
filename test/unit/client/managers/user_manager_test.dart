// test/unit/client/managers/user_manager_test.dart
//
// Comprehensive tests for UserManager class to achieve 80%+ coverage
// Tests all user management operations, property handling, contexts, and listeners
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/user_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/evaluation_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/context_type.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/device_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/application_info.dart';
import '../../../helpers/test_storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestStorageHelper.setupTestStorage();
  });
  tearDown(() {
    TestStorageHelper.clearTestStorage();
  });
  group('UserManager Comprehensive Tests', () {
    late UserManager userManager;
    late CFUser initialUser;
    setUp(() {
      initialUser = CFUser.builder('user-123')
          .addStringProperty('email', 'test@example.com')
          .addStringProperty('displayName', 'Test User')
          .addStringProperty('phoneNumber', '+1234567890')
          .build();
      userManager = UserManagerImpl(initialUser);
    });
    group('User Management', () {
      test('should get current user', () {
        final user = userManager.getUser();
        expect(user.userCustomerId, 'user-123');
        expect(user.properties['email'], 'test@example.com');
        expect(user.properties['displayName'], 'Test User');
        expect(user.properties['phoneNumber'], '+1234567890');
      });
      test('should update user', () {
        final newUser = CFUser.builder('user-456')
            .addStringProperty('email', 'new@example.com')
            .addStringProperty('displayName', 'New User')
            .build()
            .getOrThrow();
        userManager.updateUser(newUser).getOrThrow();
        final currentUser = userManager.getUser();
        expect(currentUser.userCustomerId, 'user-456');
        expect(currentUser.properties['email'], 'new@example.com');
        expect(currentUser.properties['displayName'], 'New User');
      });
      test('should clear user to anonymous', () {
        userManager.clearUser().getOrThrow();
        final currentUser = userManager.getUser();
        expect(currentUser.anonymous, true);
        expect(currentUser.userCustomerId,
            startsWith('anon_')); // Anonymous users have generated IDs
        expect(currentUser.properties['email'], isNull);
        expect(currentUser.properties['displayName'], isNull);
      });
    });
    group('Basic Property Management', () {
      test('should add string property', () {
        userManager.addStringProperty('theme', 'dark').getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['theme'], 'dark');
      });
      test('should add number property', () {
        userManager.addNumberProperty('age', 25).getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['age'], 25);
      });
      test('should add boolean property', () {
        userManager.addBooleanProperty('isVip', true).getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['isVip'], true);
      });
      test('should add JSON property', () {
        final jsonData = {
          'level': 'gold',
          'points': 1500,
          'badges': ['early_adopter', 'contributor'],
        };
        userManager.addJsonProperty('profile', jsonData).getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['profile'], jsonData);
      });
      test('should add generic property', () {
        userManager.addUserProperty('customProp', 'customValue').getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['customProp'], 'customValue');
      });
    });
    group('Bulk Property Management', () {
      test('should add multiple properties at once', () {
        final properties = {
          'prop1': 'value1',
          'prop2': 42,
          'prop3': true,
          'prop4': {'nested': 'value'},
        };
        userManager.addUserProperties(properties).getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['prop1'], 'value1');
        expect(user.properties['prop2'], 42);
        expect(user.properties['prop3'], true);
        expect(user.properties['prop4'], {'nested': 'value'});
      });
      test('should get all user properties', () {
        userManager.addStringProperty('key1', 'value1').getOrThrow();
        userManager.addNumberProperty('key2', 123).getOrThrow();
        userManager.addBooleanProperty('key3', false).getOrThrow();
        final properties = userManager.getUserProperties();
        expect(properties['key1'], 'value1');
        expect(properties['key2'], 123);
        expect(properties['key3'], false);
      });
      test('should return copy of properties', () {
        userManager.addStringProperty('test_key', 'test_value').getOrThrow();
        final properties = userManager.getUserProperties();
        properties['modified'] = 'new_value';
        final userProperties = userManager.getUser().properties;
        expect(userProperties.containsKey('modified'), false);
      });
    });
    group('Private Property Management', () {
      test('should add private string property', () {
        userManager
            .addPrivateStringProperty('privateEmail', 'private@example.com')
            .getOrThrow();
        final user = userManager.getUser();
        expect(user.properties.containsKey('privateEmail'), true);
        expect(
            user.privateFields?.attributeNames.contains('privateEmail'), true);
      });
      test('should add private number property', () {
        userManager
            .addPrivateNumberProperty('privateSalary', 100000)
            .getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['privateSalary'], 100000);
        expect(
            user.privateFields?.attributeNames.contains('privateSalary'), true);
      });
      test('should add private boolean property', () {
        userManager.addPrivateBooleanProperty('privateFlag', true).getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['privateFlag'], true);
        expect(
            user.privateFields?.attributeNames.contains('privateFlag'), true);
      });
      test('should add private map property', () {
        final map = {'key1': 'value1', 'key2': 'value2'};
        userManager.addPrivateMapProperty('privateMap', map).getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['privateMap'], map);
        expect(user.privateFields?.attributeNames.contains('privateMap'), true);
      });
      test('should add private JSON property', () {
        final jsonData = {'sensitive': 'data'};
        userManager
            .addPrivateJsonProperty('privateJson', jsonData)
            .getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['privateJson'], jsonData);
        expect(
            user.privateFields?.attributeNames.contains('privateJson'), true);
      });
    });
    group('Property Modification', () {
      test('should remove single property', () {
        userManager.addStringProperty('toRemove', 'removeValue').getOrThrow();
        userManager.addStringProperty('toKeep', 'keepValue').getOrThrow();
        userManager.removeProperty('toRemove').getOrThrow();
        final user = userManager.getUser();
        expect(user.properties.containsKey('toRemove'), false);
        expect(user.properties['toKeep'], 'keepValue');
      });
      test('should remove multiple properties', () {
        userManager.addUserProperties({
          'prop1': 'value1',
          'prop2': 'value2',
          'prop3': 'value3',
          'prop4': 'value4',
        }).getOrThrow();
        userManager.removeProperties(['prop1', 'prop3']).getOrThrow();
        final user = userManager.getUser();
        expect(user.properties.containsKey('prop1'), false);
        expect(user.properties['prop2'], 'value2');
        expect(user.properties.containsKey('prop3'), false);
        expect(user.properties['prop4'], 'value4');
      });
      test('should mark existing property as private', () {
        userManager.addStringProperty('publicProp', 'value').getOrThrow();
        userManager.markPropertyAsPrivate('publicProp').getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['publicProp'], 'value');
        expect(user.privateFields?.attributeNames.contains('publicProp'), true);
      });
      test('should mark multiple properties as private', () {
        userManager.addUserProperties({
          'prop1': 'value1',
          'prop2': 'value2',
          'prop3': 'value3',
        }).getOrThrow();
        userManager.markPropertiesAsPrivate(['prop1', 'prop3']).getOrThrow();
        final user = userManager.getUser();
        expect(user.privateFields?.attributeNames.contains('prop1'), true);
        expect(user.privateFields?.attributeNames.contains('prop2'), false);
        expect(user.privateFields?.attributeNames.contains('prop3'), true);
      });
    });
    group('Context Management', () {
      test('should add evaluation context', () {
        final context = EvaluationContext(
          key: 'region',
          type: ContextType.custom,
          properties: {'value': 'us-west'},
        );
        userManager.addContext(context).getOrThrow();
        final user = userManager.getUser();
        expect(user.contexts.any((c) => c.key == 'region'), true);
      });
      test('should remove context by type and key', () {
        final context1 = EvaluationContext(
          key: 'region',
          type: ContextType.custom,
          properties: {'value': 'us-west'},
        );
        final context2 = EvaluationContext(
          key: 'environment',
          type: ContextType.custom,
          properties: {'value': 'production'},
        );
        userManager.addContext(context1).getOrThrow();
        userManager.addContext(context2).getOrThrow();
        userManager.removeContext(ContextType.custom, 'region').getOrThrow();
        final user = userManager.getUser();
        expect(user.contexts.any((c) => c.key == 'region'), false);
        expect(user.contexts.any((c) => c.key == 'environment'), true);
      });
      test('should update device context', () {
        final deviceContext = DeviceContext(
          osName: 'iOS',
          osVersion: '16.0',
          model: 'iPhone 14',
          appVersion: '1.0.0',
        );
        userManager.updateDeviceContext(deviceContext).getOrThrow();
        final user = userManager.getUser();
        expect(user.device?.osName, 'iOS');
        expect(user.device?.osVersion, '16.0');
        expect(user.device?.model, 'iPhone 14');
        expect(user.device?.appVersion, '1.0.0');
      });
      test('should update application info', () {
        final appInfo = ApplicationInfo(
          packageName: 'com.example.app',
          appName: 'Example App',
          versionName: '2.0.0',
          versionCode: 100,
        );
        userManager.updateApplicationInfo(appInfo).getOrThrow();
        final user = userManager.getUser();
        expect(user.application?.packageName, 'com.example.app');
        expect(user.application?.appName, 'Example App');
        expect(user.application?.versionName, '2.0.0');
        expect(user.application?.versionCode, 100);
      });
    });
    group('User Change Listeners', () {
      test('should add and notify user change listener', () {
        CFUser? notifiedUser;
        int notificationCount = 0;
        void listener(CFUser user) {
          notifiedUser = user;
          notificationCount++;
        }

        userManager.addUserChangeListener(listener);
        userManager.addStringProperty('trigger', 'value').getOrThrow();
        expect(notifiedUser, isNotNull);
        expect(notifiedUser!.properties['trigger'], 'value');
        expect(notificationCount, 1);
      });
      test('should notify multiple listeners', () {
        int listener1Count = 0;
        int listener2Count = 0;
        void listener1(CFUser user) => listener1Count++;
        void listener2(CFUser user) => listener2Count++;
        userManager.addUserChangeListener(listener1);
        userManager.addUserChangeListener(listener2);
        userManager.updateUser(CFUser.builder('new-user').build()).getOrThrow();
        expect(listener1Count, 1);
        expect(listener2Count, 1);
      });
      test('should remove user change listener', () {
        int notificationCount = 0;
        void listener(CFUser user) => notificationCount++;
        userManager.addUserChangeListener(listener);
        userManager.addStringProperty('test_key', 'test_value').getOrThrow();
        expect(notificationCount, 1);
        userManager.removeUserChangeListener(listener);
        userManager.addStringProperty('test_key2', 'test_value2').getOrThrow();
        expect(notificationCount, 1); // Should not increase
      });
      test('should handle listener exceptions gracefully', () {
        void badListener(CFUser user) {
          throw Exception('Listener error');
        }

        void goodListener(CFUser user) {
          // This listener should still be called
        }
        userManager.addUserChangeListener(badListener);
        userManager.addUserChangeListener(goodListener);
        // Should not throw
        expect(
            () => userManager
                .addStringProperty('test_key', 'test_value')
                .getOrThrow(),
            returnsNormally);
      });
      test('should notify on all user modifications', () {
        final notifications = <String>[];
        void listener(CFUser user) {
          notifications.add('notified');
        }

        userManager.addUserChangeListener(listener);
        // Test various modifications
        userManager.updateUser(CFUser.builder('updated').build()).getOrThrow();
        userManager.clearUser().getOrThrow();
        userManager.addStringProperty('test_key', 'test_value').getOrThrow();
        userManager.addPrivateStringProperty('private', 'value').getOrThrow();
        userManager.removeProperty('prop').getOrThrow();
        userManager
            .addContext(EvaluationContext(
              key: 'test',
              type: ContextType.custom,
              properties: {'value': 'context'},
            ))
            .getOrThrow();
        userManager
            .updateDeviceContext(DeviceContext(
              osName: 'Android',
              osVersion: '13',
              model: 'Pixel',
              appVersion: '1.0',
            ))
            .getOrThrow();
        expect(notifications.length, 7);
      });
      test('should setup listeners with convenience method', () {
        int setupListenerCount = 0;
        void onUserChange(CFUser user) {
          setupListenerCount++;
        }

        userManager.setupListeners(onUserChange: onUserChange);
        userManager.addStringProperty('test_key', 'test_value').getOrThrow();
        expect(setupListenerCount, 1);
      });
    });
    group('Complex Scenarios', () {
      test('should handle property overwrites', () {
        userManager.addStringProperty('key', 'original').getOrThrow();
        userManager.addStringProperty('key', 'updated').getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['key'], 'updated');
      });
      test('should handle mixed property types for same key', () {
        userManager.addStringProperty('mixedKey', 'string').getOrThrow();
        userManager.addNumberProperty('mixedKey', 42).getOrThrow();
        userManager.addBooleanProperty('mixedKey', true).getOrThrow();
        final user = userManager.getUser();
        expect(user.properties['mixedKey'], true);
      });
      test('should preserve user immutability', () {
        final originalUser = userManager.getUser();
        final originalProps =
            Map<String, dynamic>.from(originalUser.properties);
        userManager.addStringProperty('newProp', 'newValue').getOrThrow();
        // Original user should not be modified
        expect(originalUser.properties, originalProps);
        // New user should have the property
        final updatedUser = userManager.getUser();
        expect(updatedUser.properties['newProp'], 'newValue');
      });
      test('should handle concurrent listener modifications', () {
        final listeners = <void Function(CFUser)>[];
        // Listener that adds another listener
        void listener1(CFUser user) {
          if (listeners.length < 3) {
            newListener(CFUser u) {}
            listeners.add(newListener);
            userManager.addUserChangeListener(newListener);
          }
        }

        userManager.addUserChangeListener(listener1);
        userManager.addStringProperty('test_key', 'test_value').getOrThrow();
        // Should handle concurrent modifications without issues
        expect(listeners.length, greaterThan(0));
      });
      test('should handle special characters in property keys', () {
        final specialKeys = {
          'key-with-dash': 'value1',
          'key_with_underscore': 'value2',
          'key.with.dots': 'value3',
          // Note: @ and spaces are not allowed in property keys
          // Only alphanumeric, underscore, dash, and dot are allowed
        };
        userManager.addUserProperties(specialKeys).getOrThrow();
        final user = userManager.getUser();
        specialKeys.forEach((key, value) {
          expect(user.properties[key], value);
        });
      });
      test('should handle deep nested JSON properties', () {
        final deepJson = {
          'level1': {
            'level2': {
              'level3': {
                'level4': {
                  'value': 'deep',
                },
              },
            },
          },
        };
        userManager.addJsonProperty('deep', deepJson).getOrThrow();
        final user = userManager.getUser();
        final retrieved = user.properties['deep'] as Map<String, dynamic>;
        expect(
          retrieved['level1']['level2']['level3']['level4']['value'],
          'deep',
        );
      });
    });
  });
}
