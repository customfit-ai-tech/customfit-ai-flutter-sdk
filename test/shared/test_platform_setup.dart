import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
/// Sets up platform mocks to prevent MissingPluginException during tests
class TestPlatformSetup {
  static bool _isSetup = false;
  /// Initialize all platform mocks
  static Future<void> setup() async {
    if (_isSetup) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    // Mock MethodChannel for other platform plugins if needed
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getAll':
            return <String, Object>{};
          case 'setBool':
          case 'setDouble':
          case 'setInt':
          case 'setString':
          case 'setStringList':
            return true;
          case 'remove':
            return true;
          case 'clear':
            return true;
          default:
            return null;
        }
      },
    );
    // Mock other channels that might cause issues
    _mockPackageInfoChannel();
    _mockConnectivityChannel();
    _mockDeviceInfoChannel();
    _mockBatteryChannel();
    _mockPathProviderChannel();
    _isSetup = true;
  }
  /// Clean up mocks
  static void tearDown() {
    if (!_isSetup) return;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      null,
    );
    // Clear other mock handlers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
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
    _isSetup = false;
  }
  static void _mockPackageInfoChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getAll':
            return {
              'appName': 'Test App',
              'packageName': 'com.test.app',
              'version': '1.0.0',
              'buildNumber': '1',
            };
          default:
            return null;
        }
      },
    );
  }
  static void _mockConnectivityChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'check':
            return 'wifi';
          case 'wifiName':
            return 'Test-WiFi';
          case 'wifiBSSID':
            return 'aa:bb:cc:dd:ee:ff';
          case 'wifiIPAddress':
            return '192.168.1.1';
          default:
            return null;
        }
      },
    );
  }
  static void _mockDeviceInfoChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getAndroidDeviceInfo':
            return {
              'version': {'sdkInt': 29},
              'brand': 'Test',
              'model': 'Test Device',
              'manufacturer': 'Test Inc',
              'product': 'test_product',
            };
          case 'getIosDeviceInfo':
            return {
              'systemName': 'iOS',
              'systemVersion': '14.0',
              'model': 'iPhone',
              'name': 'Test iPhone',
            };
          default:
            return null;
        }
      },
    );
  }
  static void _mockBatteryChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/battery'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getBatteryLevel':
            return 85;
          case 'getBatteryState':
            return 'full';
          default:
            return null;
        }
      },
    );
  }
  static void _mockPathProviderChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getTemporaryDirectory':
            return '/tmp';
          case 'getApplicationDocumentsDirectory':
            return '/Documents';
          case 'getApplicationSupportDirectory':
            return '/Library/Application Support';
          default:
            return null;
        }
      },
    );
  }
}
