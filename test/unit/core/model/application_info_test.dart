import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/application_info.dart';
import 'package:package_info_plus/package_info_plus.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ApplicationInfo', () {
    group('Constructor', () {
      test('should create instance with default values', () {
        final appInfo = ApplicationInfo();
        expect(appInfo.appName, isNull);
        expect(appInfo.packageName, isNull);
        expect(appInfo.versionName, isNull);
        expect(appInfo.versionCode, isNull);
        expect(appInfo.installDate, isNull);
        expect(appInfo.lastUpdateDate, isNull);
        expect(appInfo.buildType, isNull);
        expect(appInfo.launchCount, equals(1));
        expect(appInfo.customAttributes, isEmpty);
      });
      test('should create instance with provided values', () {
        final customAttrs = {'key1': 'value1', 'key2': 'value2'};
        final appInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          versionName: '1.2.3',
          versionCode: 123,
          installDate: '2023-01-01',
          lastUpdateDate: '2023-06-01',
          buildType: 'release',
          launchCount: 5,
          customAttributes: customAttrs,
        );
        expect(appInfo.appName, equals('Test App'));
        expect(appInfo.packageName, equals('com.test.app'));
        expect(appInfo.versionName, equals('1.2.3'));
        expect(appInfo.versionCode, equals(123));
        expect(appInfo.installDate, equals('2023-01-01'));
        expect(appInfo.lastUpdateDate, equals('2023-06-01'));
        expect(appInfo.buildType, equals('release'));
        expect(appInfo.launchCount, equals(5));
        expect(appInfo.customAttributes, equals(customAttrs));
      });
    });
    group('fromMap', () {
      test('should create instance from complete map', () {
        final map = {
          'app_name': 'Test App',
          'package_name': 'com.test.app',
          'version_name': '1.2.3',
          'version_code': 123,
          'install_date': '2023-01-01',
          'last_update_date': '2023-06-01',
          'build_type': 'release',
          'launch_count': 5,
          'custom_attributes': {'key1': 'value1', 'key2': 'value2'},
        };
        final appInfo = ApplicationInfo.fromMap(map);
        expect(appInfo.appName, equals('Test App'));
        expect(appInfo.packageName, equals('com.test.app'));
        expect(appInfo.versionName, equals('1.2.3'));
        expect(appInfo.versionCode, equals(123));
        expect(appInfo.installDate, equals('2023-01-01'));
        expect(appInfo.lastUpdateDate, equals('2023-06-01'));
        expect(appInfo.buildType, equals('release'));
        expect(appInfo.launchCount, equals(5));
        expect(appInfo.customAttributes,
            equals({'key1': 'value1', 'key2': 'value2'}));
      });
      test('should handle empty map', () {
        final appInfo = ApplicationInfo.fromMap({});
        expect(appInfo.appName, isNull);
        expect(appInfo.packageName, isNull);
        expect(appInfo.versionName, isNull);
        expect(appInfo.versionCode, isNull);
        expect(appInfo.installDate, isNull);
        expect(appInfo.lastUpdateDate, isNull);
        expect(appInfo.buildType, isNull);
        expect(appInfo.launchCount, equals(0));
        expect(appInfo.customAttributes, isEmpty);
      });
      test('should handle null values in map', () {
        final map = {
          'app_name': null,
          'package_name': null,
          'version_name': null,
          'version_code': null,
          'install_date': null,
          'last_update_date': null,
          'build_type': null,
          'launch_count': null,
          'custom_attributes': null,
        };
        final appInfo = ApplicationInfo.fromMap(map);
        expect(appInfo.appName, isNull);
        expect(appInfo.packageName, isNull);
        expect(appInfo.versionName, isNull);
        expect(appInfo.versionCode, isNull);
        expect(appInfo.installDate, isNull);
        expect(appInfo.lastUpdateDate, isNull);
        expect(appInfo.buildType, isNull);
        expect(appInfo.launchCount, equals(0));
        expect(appInfo.customAttributes, isEmpty);
      });
      test('should handle numeric types properly', () {
        final map = {
          'version_code': 123.0, // double
          'launch_count': 5.0, // double
        };
        final appInfo = ApplicationInfo.fromMap(map);
        expect(appInfo.versionCode, equals(123));
        expect(appInfo.launchCount, equals(5));
      });
      test('should convert custom attributes to string values', () {
        final map = {
          'custom_attributes': {
            'string_key': 'string_value',
            'int_key': 123,
            'double_key': 45.67,
            'bool_key': true,
          },
        };
        final appInfo = ApplicationInfo.fromMap(map);
        expect(
            appInfo.customAttributes,
            equals({
              'string_key': 'string_value',
              'int_key': '123',
              'double_key': '45.67',
              'bool_key': 'true',
            }));
      });
      test('should handle non-map custom attributes', () {
        final map = {
          'custom_attributes': 'not_a_map',
        };
        final appInfo = ApplicationInfo.fromMap(map);
        expect(appInfo.customAttributes, isEmpty);
      });
    });
    group('fromPackageInfo', () {
      test('should create instance from PackageInfo', () async {
        // Create a mock PackageInfo
        final packageInfo = PackageInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          version: '1.2.3',
          buildNumber: '456',
          buildSignature: 'signature',
          installerStore: null,
        );
        final appInfo = await ApplicationInfo.fromPackageInfo(packageInfo);
        expect(appInfo.appName, equals('Test App'));
        expect(appInfo.packageName, equals('com.test.app'));
        expect(appInfo.versionName, equals('1.2.3'));
        expect(appInfo.versionCode, equals(456));
        expect(appInfo.buildType, isNotNull); // Will be 'debug' or 'release'
        expect(appInfo.installDate, isNull);
        expect(appInfo.lastUpdateDate, isNull);
        expect(appInfo.launchCount, equals(1));
        expect(appInfo.customAttributes, isEmpty);
      });
      test('should handle invalid build number', () async {
        final packageInfo = PackageInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          version: '1.2.3',
          buildNumber: 'invalid',
          buildSignature: 'signature',
          installerStore: null,
        );
        final appInfo = await ApplicationInfo.fromPackageInfo(packageInfo);
        expect(appInfo.versionCode, isNull);
      });
    });
    group('toMap', () {
      test('should convert to map with all fields', () {
        final customAttrs = {'key1': 'value1', 'key2': 'value2'};
        final appInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          versionName: '1.2.3',
          versionCode: 123,
          installDate: '2023-01-01',
          lastUpdateDate: '2023-06-01',
          buildType: 'release',
          launchCount: 5,
          customAttributes: customAttrs,
        );
        final map = appInfo.toMap();
        expect(map['app_name'], equals('Test App'));
        expect(map['package_name'], equals('com.test.app'));
        expect(map['version_name'], equals('1.2.3'));
        expect(map['version_code'], equals(123));
        expect(map['install_date'], equals('2023-01-01'));
        expect(map['last_update_date'], equals('2023-06-01'));
        expect(map['build_type'], equals('release'));
        expect(map['launch_count'], equals(5));
        expect(map['custom_attributes'], equals(customAttrs));
      });
      test('should exclude null values from map', () {
        final appInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: null,
          versionName: null,
          launchCount: 3,
        );
        final map = appInfo.toMap();
        expect(map.containsKey('app_name'), isTrue);
        expect(map.containsKey('package_name'), isFalse);
        expect(map.containsKey('version_name'), isFalse);
        expect(map.containsKey('launch_count'), isTrue);
        expect(map['app_name'], equals('Test App'));
        expect(map['launch_count'], equals(3));
      });
      test('should handle empty custom attributes', () {
        final appInfo = ApplicationInfo(
          appName: 'Test App',
          customAttributes: {},
        );
        final map = appInfo.toMap();
        expect(map['custom_attributes'], equals({}));
      });
    });
    group('JSON serialization', () {
      test('toJson should return same as toMap', () {
        final appInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          versionName: '1.2.3',
        );
        expect(appInfo.toJson(), equals(appInfo.toMap()));
      });
      test('fromJson should work same as fromMap', () {
        final json = {
          'app_name': 'Test App',
          'package_name': 'com.test.app',
          'version_name': '1.2.3',
          'launch_count': 2,
        };
        final fromJson = ApplicationInfo.fromJson(json);
        final fromMap = ApplicationInfo.fromMap(json);
        expect(fromJson.appName, equals(fromMap.appName));
        expect(fromJson.packageName, equals(fromMap.packageName));
        expect(fromJson.versionName, equals(fromMap.versionName));
        expect(fromJson.launchCount, equals(fromMap.launchCount));
      });
    });
    group('Round-trip serialization', () {
      test('should maintain data integrity through serialization cycle', () {
        final original = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          versionName: '1.2.3',
          versionCode: 123,
          installDate: '2023-01-01',
          lastUpdateDate: '2023-06-01',
          buildType: 'release',
          launchCount: 5,
          customAttributes: {'key1': 'value1', 'key2': 'value2'},
        );
        final map = original.toMap();
        final restored = ApplicationInfo.fromMap(map);
        expect(restored.appName, equals(original.appName));
        expect(restored.packageName, equals(original.packageName));
        expect(restored.versionName, equals(original.versionName));
        expect(restored.versionCode, equals(original.versionCode));
        expect(restored.installDate, equals(original.installDate));
        expect(restored.lastUpdateDate, equals(original.lastUpdateDate));
        expect(restored.buildType, equals(original.buildType));
        expect(restored.launchCount, equals(original.launchCount));
        expect(restored.customAttributes, equals(original.customAttributes));
      });
    });
  });
}
