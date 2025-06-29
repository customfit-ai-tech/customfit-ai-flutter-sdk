import 'package:customfit_ai_flutter_sdk/src/core/model/device_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/application_info.dart';
/// Mock implementation of DeviceInfoDetector for testing
class MockDeviceInfoDetector {
  /// Get mock device context
  static Future<DeviceContext> detectDeviceInfo() async {
    return DeviceContext(
      manufacturer: 'Test Manufacturer',
      model: 'Test Model',
      osName: 'Test OS',
      osVersion: '1.0.0',
      sdkVersion: '31',
      appId: 'com.customfit.flutter.test',
      appVersion: '1.0.0+test',
      locale: 'en_US',
      timezone: 'UTC',
      screenWidth: 1080,
      screenHeight: 1920,
      screenDensity: 2.0,
      networkType: 'wifi',
      networkCarrier: 'test-carrier',
    );
  }
}
/// Mock implementation of ApplicationInfoDetector for testing
class MockApplicationInfoDetector {
  /// Get mock application info
  static Future<ApplicationInfo?> detectApplicationInfo() async {
    return ApplicationInfo(
      appName: 'CustomFit Flutter SDK Test',
      packageName: 'com.customfit.flutter.test',
      versionName: '1.0.0+test',
      versionCode: 1,
      launchCount: 1,
      installDate: DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      lastUpdateDate: DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
      buildType: 'debug',
      customAttributes: {'test_mode': 'true'},
    );
  }
  /// Get updated application info with incremented launch count
  static ApplicationInfo incrementLaunchCount(ApplicationInfo info) {
    return ApplicationInfo(
      appName: info.appName,
      packageName: info.packageName,
      versionName: info.versionName,
      versionCode: info.versionCode,
      launchCount: (info.launchCount + 1),
      installDate: info.installDate,
      lastUpdateDate: info.lastUpdateDate,
      buildType: info.buildType,
      customAttributes: info.customAttributes,
    );
  }
}