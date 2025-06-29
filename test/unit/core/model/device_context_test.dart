// test/unit/core/model/device_context_test.dart
//
// Tests for DeviceContext model class - covers serialization, deserialization, and factory methods
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/device_context.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DeviceContext', () {
    group('Constructor', () {
      test('should create instance with default values', () {
        final deviceContext = DeviceContext();
        expect(deviceContext.manufacturer, isNull);
        expect(deviceContext.model, isNull);
        expect(deviceContext.osName, isNull);
        expect(deviceContext.osVersion, isNull);
        expect(deviceContext.sdkVersion, equals('1.0.0'));
        expect(deviceContext.appId, isNull);
        expect(deviceContext.appVersion, isNull);
        expect(deviceContext.locale, isNull);
        expect(deviceContext.timezone, isNull);
        expect(deviceContext.screenWidth, isNull);
        expect(deviceContext.screenHeight, isNull);
        expect(deviceContext.screenDensity, isNull);
        expect(deviceContext.networkType, isNull);
        expect(deviceContext.networkCarrier, isNull);
        expect(deviceContext.customAttributes, isEmpty);
      });
      test('should create instance with provided values', () {
        final customAttrs = {'key1': 'value1', 'key2': 123};
        final deviceContext = DeviceContext(
          manufacturer: 'Apple',
          model: 'iPhone 13',
          osName: 'iOS',
          osVersion: '15.0',
          sdkVersion: '2.0.0',
          appId: 'com.test.app',
          appVersion: '1.2.3',
          locale: 'en_US',
          timezone: 'America/New_York',
          screenWidth: 390,
          screenHeight: 844,
          screenDensity: 3.0,
          networkType: 'wifi',
          networkCarrier: 'Verizon',
          customAttributes: customAttrs,
        );
        expect(deviceContext.manufacturer, equals('Apple'));
        expect(deviceContext.model, equals('iPhone 13'));
        expect(deviceContext.osName, equals('iOS'));
        expect(deviceContext.osVersion, equals('15.0'));
        expect(deviceContext.sdkVersion, equals('2.0.0'));
        expect(deviceContext.appId, equals('com.test.app'));
        expect(deviceContext.appVersion, equals('1.2.3'));
        expect(deviceContext.locale, equals('en_US'));
        expect(deviceContext.timezone, equals('America/New_York'));
        expect(deviceContext.screenWidth, equals(390));
        expect(deviceContext.screenHeight, equals(844));
        expect(deviceContext.screenDensity, equals(3.0));
        expect(deviceContext.networkType, equals('wifi'));
        expect(deviceContext.networkCarrier, equals('Verizon'));
        expect(deviceContext.customAttributes, equals(customAttrs));
      });
    });
    group('createBasic', () {
      test('should create basic device context with system properties', () {
        final deviceContext = DeviceContext.createBasic();
        expect(deviceContext.osName, isNotNull);
        expect(deviceContext.osVersion, isNotNull);
        expect(deviceContext.locale, isNotNull);
        expect(deviceContext.timezone, isNotNull);
        expect(deviceContext.sdkVersion, equals('1.0.0'));
        expect(deviceContext.manufacturer, isNull);
        expect(deviceContext.model, isNull);
        expect(deviceContext.customAttributes, isEmpty);
      });
    });
    group('fromMap', () {
      test('should create instance from complete map', () {
        final map = {
          'manufacturer': 'Samsung',
          'model': 'Galaxy S21',
          'os_name': 'Android',
          'os_version': '11',
          'sdk_version': '2.1.0',
          'app_id': 'com.test.android',
          'app_version': '2.0.0',
          'locale': 'en_US',
          'timezone': 'America/Los_Angeles',
          'screen_width': 400,
          'screen_height': 800,
          'screen_density': 2.5,
          'network_type': 'cellular',
          'network_carrier': 'T-Mobile',
          'custom_attributes': {'device_type': 'phone', 'ram': '8GB'},
        };
        final deviceContext = DeviceContext.fromMap(map);
        expect(deviceContext.manufacturer, equals('Samsung'));
        expect(deviceContext.model, equals('Galaxy S21'));
        expect(deviceContext.osName, equals('Android'));
        expect(deviceContext.osVersion, equals('11'));
        expect(deviceContext.sdkVersion, equals('2.1.0'));
        expect(deviceContext.appId, equals('com.test.android'));
        expect(deviceContext.appVersion, equals('2.0.0'));
        expect(deviceContext.locale, equals('en_US'));
        expect(deviceContext.timezone, equals('America/Los_Angeles'));
        expect(deviceContext.screenWidth, equals(400));
        expect(deviceContext.screenHeight, equals(800));
        expect(deviceContext.screenDensity, equals(2.5));
        expect(deviceContext.networkType, equals('cellular'));
        expect(deviceContext.networkCarrier, equals('T-Mobile'));
        expect(deviceContext.customAttributes,
            equals({'device_type': 'phone', 'ram': '8GB'}));
      });
      test('should handle empty map', () {
        final deviceContext = DeviceContext.fromMap({});
        expect(deviceContext.manufacturer, isNull);
        expect(deviceContext.model, isNull);
        expect(deviceContext.osName, isNull);
        expect(deviceContext.osVersion, isNull);
        expect(deviceContext.sdkVersion, equals('1.0.0'));
        expect(deviceContext.appId, isNull);
        expect(deviceContext.appVersion, isNull);
        expect(deviceContext.locale, isNull);
        expect(deviceContext.timezone, isNull);
        expect(deviceContext.screenWidth, isNull);
        expect(deviceContext.screenHeight, isNull);
        expect(deviceContext.screenDensity, isNull);
        expect(deviceContext.networkType, isNull);
        expect(deviceContext.networkCarrier, isNull);
        expect(deviceContext.customAttributes, isEmpty);
      });
      test('should handle null values in map', () {
        final map = {
          'manufacturer': null,
          'model': null,
          'os_name': null,
          'os_version': null,
          'sdk_version': null,
          'app_id': null,
          'app_version': null,
          'locale': null,
          'timezone': null,
          'screen_width': null,
          'screen_height': null,
          'screen_density': null,
          'network_type': null,
          'network_carrier': null,
          'custom_attributes': null,
        };
        final deviceContext = DeviceContext.fromMap(map);
        expect(deviceContext.manufacturer, isNull);
        expect(deviceContext.model, isNull);
        expect(deviceContext.osName, isNull);
        expect(deviceContext.osVersion, isNull);
        expect(deviceContext.sdkVersion, equals('1.0.0')); // Default value
        expect(deviceContext.appId, isNull);
        expect(deviceContext.appVersion, isNull);
        expect(deviceContext.locale, isNull);
        expect(deviceContext.timezone, isNull);
        expect(deviceContext.screenWidth, isNull);
        expect(deviceContext.screenHeight, isNull);
        expect(deviceContext.screenDensity, isNull);
        expect(deviceContext.networkType, isNull);
        expect(deviceContext.networkCarrier, isNull);
        expect(deviceContext.customAttributes, isEmpty);
      });
      test('should handle numeric type conversion', () {
        final map = {
          'screen_width': 400.0, // double to int
          'screen_height': 800.5, // double to int (truncated)
          'screen_density': 2, // int to double
        };
        final deviceContext = DeviceContext.fromMap(map);
        expect(deviceContext.screenWidth, equals(400));
        expect(deviceContext.screenHeight, equals(800));
        expect(deviceContext.screenDensity, equals(2.0));
      });
      test('should handle missing custom attributes', () {
        final map = {
          'manufacturer': 'Test',
          // custom_attributes not provided
        };
        final deviceContext = DeviceContext.fromMap(map);
        expect(deviceContext.customAttributes, isEmpty);
      });
    });
    group('toMap', () {
      test('should convert to map with all fields', () {
        final customAttrs = {'device_type': 'tablet', 'storage': '128GB'};
        final deviceContext = DeviceContext(
          manufacturer: 'Google',
          model: 'Pixel 6',
          osName: 'Android',
          osVersion: '12',
          sdkVersion: '3.0.0',
          appId: 'com.google.test',
          appVersion: '3.1.0',
          locale: 'fr_FR',
          timezone: 'Europe/Paris',
          screenWidth: 411,
          screenHeight: 869,
          screenDensity: 2.625,
          networkType: 'wifi',
          networkCarrier: 'Orange',
          customAttributes: customAttrs,
        );
        final map = deviceContext.toMap();
        expect(map['manufacturer'], equals('Google'));
        expect(map['model'], equals('Pixel 6'));
        expect(map['os_name'], equals('Android'));
        expect(map['os_version'], equals('12'));
        expect(map['sdk_version'], equals('3.0.0'));
        expect(map['app_id'], equals('com.google.test'));
        expect(map['app_version'], equals('3.1.0'));
        expect(map['locale'], equals('fr_FR'));
        expect(map['timezone'], equals('Europe/Paris'));
        expect(map['screen_width'], equals(411));
        expect(map['screen_height'], equals(869));
        expect(map['screen_density'], equals(2.625));
        expect(map['network_type'], equals('wifi'));
        expect(map['network_carrier'], equals('Orange'));
        expect(map['custom_attributes'], equals(customAttrs));
      });
      test('should exclude null values from map', () {
        final deviceContext = DeviceContext(
          manufacturer: 'Apple',
          model: null,
          osName: null,
          sdkVersion: '1.5.0',
          screenWidth: 375,
        );
        final map = deviceContext.toMap();
        expect(map.containsKey('manufacturer'), isTrue);
        expect(map.containsKey('model'), isFalse);
        expect(map.containsKey('os_name'), isFalse);
        expect(map.containsKey('sdk_version'), isTrue);
        expect(map.containsKey('screen_width'), isTrue);
        expect(map['manufacturer'], equals('Apple'));
        expect(map['sdk_version'], equals('1.5.0'));
        expect(map['screen_width'], equals(375));
      });
      test('should handle empty custom attributes', () {
        final deviceContext = DeviceContext(
          manufacturer: 'Test',
          customAttributes: {},
        );
        final map = deviceContext.toMap();
        expect(map['custom_attributes'], equals({}));
      });
    });
    group('JSON serialization', () {
      test('toJson should return same as toMap', () {
        final deviceContext = DeviceContext(
          manufacturer: 'Sony',
          model: 'Xperia 1',
          osName: 'Android',
          osVersion: '10',
        );
        expect(deviceContext.toJson(), equals(deviceContext.toMap()));
      });
      test('fromJson should work same as fromMap', () {
        final json = {
          'manufacturer': 'OnePlus',
          'model': '9 Pro',
          'os_name': 'Android',
          'os_version': '11',
          'screen_width': 412,
          'screen_height': 869,
        };
        final fromJson = DeviceContext.fromJson(json);
        final fromMap = DeviceContext.fromMap(json);
        expect(fromJson.manufacturer, equals(fromMap.manufacturer));
        expect(fromJson.model, equals(fromMap.model));
        expect(fromJson.osName, equals(fromMap.osName));
        expect(fromJson.osVersion, equals(fromMap.osVersion));
        expect(fromJson.screenWidth, equals(fromMap.screenWidth));
        expect(fromJson.screenHeight, equals(fromMap.screenHeight));
      });
    });
    group('Round-trip serialization', () {
      test('should maintain data integrity through serialization cycle', () {
        final original = DeviceContext(
          manufacturer: 'Xiaomi',
          model: 'Mi 11',
          osName: 'Android',
          osVersion: '11',
          sdkVersion: '4.0.0',
          appId: 'com.xiaomi.test',
          appVersion: '4.1.0',
          locale: 'zh_CN',
          timezone: 'Asia/Shanghai',
          screenWidth: 393,
          screenHeight: 851,
          screenDensity: 3.0,
          networkType: 'cellular',
          networkCarrier: 'China Mobile',
          customAttributes: {'brand': 'Xiaomi', 'series': 'Mi'},
        );
        final map = original.toMap();
        final restored = DeviceContext.fromMap(map);
        expect(restored.manufacturer, equals(original.manufacturer));
        expect(restored.model, equals(original.model));
        expect(restored.osName, equals(original.osName));
        expect(restored.osVersion, equals(original.osVersion));
        expect(restored.sdkVersion, equals(original.sdkVersion));
        expect(restored.appId, equals(original.appId));
        expect(restored.appVersion, equals(original.appVersion));
        expect(restored.locale, equals(original.locale));
        expect(restored.timezone, equals(original.timezone));
        expect(restored.screenWidth, equals(original.screenWidth));
        expect(restored.screenHeight, equals(original.screenHeight));
        expect(restored.screenDensity, equals(original.screenDensity));
        expect(restored.networkType, equals(original.networkType));
        expect(restored.networkCarrier, equals(original.networkCarrier));
        expect(restored.customAttributes, equals(original.customAttributes));
      });
    });
    group('Edge cases', () {
      test('should handle zero and negative screen dimensions', () {
        final deviceContext = DeviceContext(
          screenWidth: 0,
          screenHeight: -100,
          screenDensity: 0.0,
        );
        expect(deviceContext.screenWidth, equals(0));
        expect(deviceContext.screenHeight, equals(-100));
        expect(deviceContext.screenDensity, equals(0.0));
        final map = deviceContext.toMap();
        final restored = DeviceContext.fromMap(map);
        expect(restored.screenWidth, equals(0));
        expect(restored.screenHeight, equals(-100));
        expect(restored.screenDensity, equals(0.0));
      });
      test('should handle empty strings', () {
        final deviceContext = DeviceContext(
          manufacturer: '',
          model: '',
          osName: '',
          osVersion: '',
          appId: '',
          appVersion: '',
          locale: '',
          timezone: '',
          networkType: '',
          networkCarrier: '',
        );
        final map = deviceContext.toMap();
        final restored = DeviceContext.fromMap(map);
        expect(restored.manufacturer, equals(''));
        expect(restored.model, equals(''));
        expect(restored.osName, equals(''));
        expect(restored.osVersion, equals(''));
        expect(restored.appId, equals(''));
        expect(restored.appVersion, equals(''));
        expect(restored.locale, equals(''));
        expect(restored.timezone, equals(''));
        expect(restored.networkType, equals(''));
        expect(restored.networkCarrier, equals(''));
      });
      test('should handle complex custom attributes', () {
        final complexAttrs = {
          'nested_object': {'inner': 'value'},
          'array': [1, 2, 3],
          'boolean': true,
          'null_value': null,
          'number': 42.5,
        };
        final deviceContext = DeviceContext(
          customAttributes: complexAttrs,
        );
        expect(deviceContext.customAttributes, equals(complexAttrs));
        final map = deviceContext.toMap();
        final restored = DeviceContext.fromMap(map);
        expect(restored.customAttributes, equals(complexAttrs));
      });
    });
  });
}
