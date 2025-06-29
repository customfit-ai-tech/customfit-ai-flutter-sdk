import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
/// Utility class to setup plugin mocks for testing
class TestPluginMocks {
  static bool _mocksInitialized = false;
  /// Initialize all plugin mocks required for testing
  static void initializePluginMocks() {
    if (_mocksInitialized) return;
    // Ensure Flutter bindings are initialized
    TestWidgetsFlutterBinding.ensureInitialized();
    // Set SharedPreferences mock initial values first
    SharedPreferences.setMockInitialValues({});
    // Mock SharedPreferences
    _mockSharedPreferences();
    // Mock package_info_plus
    _mockPackageInfoPlus();
    // Mock device_info_plus
    _mockDeviceInfoPlus();
    // Mock connectivity_plus
    _mockConnectivityPlus();
    // Mock battery_plus
    _mockBatteryPlus();
    // Mock path_provider
    _mockPathProvider();
    _mocksInitialized = true;
  }
  /// Quick setup for SharedPreferences only (to prevent MissingPluginException)
  static void setupSharedPreferencesOnly() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  }
  /// Reset all mocks (useful for tearDown)
  static void resetMocks() {
    _mocksInitialized = false;
    // Clear method call handlers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/battery'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  }
  static void _mockSharedPreferences() {
    // Also set mock initial values for SharedPreferences
    try {
      // Try to import SharedPreferences and set mock values
      // This prevents MissingPluginException errors
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/shared_preferences'),
              (MethodCall methodCall) async {
        // Return empty data for all getAll calls to prevent errors
        switch (methodCall.method) {
          case 'getAll':
            return <String, dynamic>{};
          case 'remove':
            return true;
          case 'clear':
            return true;
          case 'setString':
          case 'setBool':
          case 'setInt':
          case 'setDouble':
          case 'setStringList':
            return true;
          case 'getString':
            return null;
          case 'getBool':
            return null;
          case 'getInt':
            return null;
          case 'getDouble':
            return null;
          case 'getStringList':
            return null;
          default:
            // Return null instead of throwing to prevent error messages
            return null;
        }
      });
    } catch (e) {
      // Silently ignore any setup errors
    }
  }
  static void _mockPackageInfoPlus() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getAll':
          return <String, dynamic>{
            'appName': 'CustomFit Flutter SDK Test',
            'packageName': 'com.customfit.flutter.test',
            'version': '1.0.0+test',
            'buildNumber': '1',
            'buildSignature': '',
          };
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: "The method '${methodCall.method}' is not implemented.",
          );
      }
    });
  }
  static void _mockDeviceInfoPlus() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/device_info'),
            (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getAndroidDeviceInfo':
          return <String, dynamic>{
            'version': <String, dynamic>{
              'baseOS': '',
              'codename': '',
              'incremental': '',
              'previewSdkInt': null,
              'release': '12',
              'sdkInt': 31,
              'securityPatch': '',
            },
            'board': 'test_board',
            'bootloader': 'test_bootloader',
            'brand': 'Test Brand',
            'device': 'test_device',
            'display': 'test_display',
            'fingerprint': 'test_fingerprint',
            'hardware': 'test_hardware',
            'host': 'test_host',
            'id': 'test_id',
            'manufacturer': 'Test Manufacturer',
            'model': 'Test Model',
            'product': 'test_product',
            'tags': 'test_tags',
            'type': 'test_type',
            'isPhysicalDevice': true,
            'systemFeatures': <String>[],
            'serialNumber': 'test_serial',
          };
        case 'getIosDeviceInfo':
          return <String, dynamic>{
            'name': 'Test iPhone',
            'systemName': 'iOS',
            'systemVersion': '15.0',
            'model': 'iPhone',
            'localizedModel': 'iPhone',
            'identifierForVendor': 'test-vendor-id',
            'isPhysicalDevice': true,
            'utsname': <String, dynamic>{
              'sysname': 'Darwin',
              'nodename': 'test-node',
              'release': '21.0.0',
              'version': 'test-version',
              'machine': 'arm64',
            },
          };
        case 'getWebBrowserInfo':
          return <String, dynamic>{
            'browserName': 'chrome',
            'appCodeName': 'Mozilla',
            'appName': 'Netscape',
            'appVersion': 'test-version',
            'deviceMemory': null,
            'language': 'en-US',
            'languages': ['en-US', 'en'],
            'platform': 'MacIntel',
            'product': 'Gecko',
            'productSub': '20030107',
            'userAgent': 'test-user-agent',
            'vendor': 'Google Inc.',
            'vendorSub': '',
            'hardwareConcurrency': 8,
            'maxTouchPoints': 0,
          };
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: "The method '${methodCall.method}' is not implemented.",
          );
      }
    });
  }
  static void _mockConnectivityPlus() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'check':
          return 'wifi';
        case 'wifiName':
          return 'Test WiFi';
        case 'wifiBSSID':
          return 'test:bssid';
        case 'wifiIPAddress':
          return '192.168.1.1';
        case 'requestLocationServiceAuthorization':
          return 'authorizedAlways';
        case 'getLocationServiceAuthorization':
          return 'authorizedAlways';
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: "The method '${methodCall.method}' is not implemented.",
          );
      }
    });
  }
  static void _mockBatteryPlus() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/battery'),
            (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getBatteryLevel':
          return 85;
        case 'getBatteryState':
          return 'charging';
        case 'isInBatterySaveMode':
          return false;
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: "The method '${methodCall.method}' is not implemented.",
          );
      }
    });
  }
  static void _mockPathProvider() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getTemporaryDirectory':
          return '/tmp/customfit_test';
        case 'getApplicationDocumentsDirectory':
          return '/tmp/customfit_test/documents';
        case 'getApplicationSupportDirectory':
          return '/tmp/customfit_test/support';
        case 'getLibraryDirectory':
          return '/tmp/customfit_test/library';
        case 'getExternalStorageDirectory':
          return '/tmp/customfit_test/external';
        case 'getExternalCacheDirectories':
          return ['/tmp/customfit_test/external_cache'];
        case 'getExternalStorageDirectories':
          return ['/tmp/customfit_test/external_storage'];
        case 'getApplicationCacheDirectory':
          return '/tmp/customfit_test/cache';
        case 'getDownloadsDirectory':
          return '/tmp/customfit_test/downloads';
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: "The method '${methodCall.method}' is not implemented.",
          );
      }
    });
  }
}
