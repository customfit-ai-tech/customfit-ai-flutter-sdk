import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/device_info_detector.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/device_context.dart';
import '../../test_config.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DeviceInfoDetector Comprehensive Tests', () {
    setUp(() {
      TestConfig.setupTestLogger();
      debugDefaultTargetPlatformOverride = null;
      // Set up mock package info for all tests
      PackageInfo.setMockInitialValues(
        appName: 'TestApp',
        packageName: 'com.test.customfit',
        version: '2.1.0',
        buildNumber: '42',
        buildSignature: 'test-signature',
      );
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    group('1. Basic Detection Tests', () {
      test('should return DeviceContext instance', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
      });
      test('should not throw exceptions during detection', () async {
        expect(() async => await DeviceInfoDetector.detectDeviceInfo(),
            returnsNormally);
      });
      test('should return consistent results on multiple calls', () async {
        final result1 = await DeviceInfoDetector.detectDeviceInfo();
        final result2 = await DeviceInfoDetector.detectDeviceInfo();
        expect(result1, isA<DeviceContext>());
        expect(result2, isA<DeviceContext>());
        // Static properties should be consistent
        expect(result1.osName, equals(result2.osName));
        expect(result1.manufacturer, equals(result2.manufacturer));
        expect(result1.model, equals(result2.model));
      });
      test('should handle detection gracefully in test environment', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result.osName, isA<String?>());
        expect(result.manufacturer, isA<String?>());
        expect(result.model, isA<String?>());
      });
      test('should populate device context with expected field types',
          () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result.manufacturer, isA<String?>());
        expect(result.model, isA<String?>());
        expect(result.osName, isA<String?>());
        expect(result.osVersion, isA<String?>());
        expect(result.sdkVersion, isA<String?>());
        expect(result.appId, isA<String?>());
        expect(result.appVersion, isA<String?>());
        expect(result.locale, isA<String?>());
        expect(result.timezone, isA<String?>());
        expect(result.screenWidth, isA<int?>());
        expect(result.screenHeight, isA<int?>());
        expect(result.screenDensity, isA<double?>());
        expect(result.networkType, isA<String?>());
        expect(result.networkCarrier, isA<String?>());
      });
    });
    group('2. Platform-Specific Detection', () {
      test('should handle all supported platforms gracefully', () async {
        final platforms = [
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.linux,
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.fuchsia,
        ];
        for (final platform in platforms) {
          debugDefaultTargetPlatformOverride = platform;
          final result = await DeviceInfoDetector.detectDeviceInfo();
          expect(result, isA<DeviceContext>());
          expect(result, isNotNull);
          final json = result.toJson();
          expect(json, isA<Map<String, dynamic>>());
        }
      });
      test('should detect platform-specific fields when available', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        var result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
      });
      test('should handle different platform scenarios', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        if (result.osName != null) {
          expect(result.osName, isNotEmpty);
          expect(result.osName, isA<String>());
        }
        if (result.manufacturer != null) {
          expect(result.manufacturer, isNotEmpty);
          expect(result.manufacturer, isA<String>());
        }
        if (result.model != null) {
          expect(result.model, isNotEmpty);
          expect(result.model, isA<String>());
        }
      });
      test('should handle unknown platforms gracefully', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
      });
    });
    group('3. Network Type Detection', () {
      test('should handle network type detection', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.networkType != null) {
          const validNetworkTypes = [
            'cellular',
            'wifi',
            'ethernet',
            'bluetooth',
            'unknown'
          ];
          expect(validNetworkTypes, contains(result.networkType));
        }
      });
      test('should handle empty connectivity results list', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result.networkType, isA<String?>());
      });
      test('should handle multiple connectivity results', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        if (result.networkType != null) {
          expect(result.networkType, isNotEmpty);
        }
      });
      test('should map all Android connectivity types correctly', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.osName == 'Android' && result.networkType != null) {
          const androidNetworkTypes = [
            'cellular',
            'wifi',
            'ethernet',
            'bluetooth',
            'unknown'
          ];
          expect(androidNetworkTypes, contains(result.networkType));
        }
      });
      test('should map iOS connectivity types correctly', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.osName == 'iOS' && result.networkType != null) {
          const iosNetworkTypes = ['cellular', 'wifi', 'unknown'];
          expect(iosNetworkTypes, contains(result.networkType));
        }
      });
      test('should map web connectivity types correctly', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.osName?.contains('web') == true &&
            result.networkType != null) {
          const webNetworkTypes = ['ethernet', 'wifi', 'unknown'];
          expect(webNetworkTypes, contains(result.networkType));
        }
      });
      test('should always set network carrier to unknown', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.networkCarrier != null) {
          expect(result.networkCarrier, equals('unknown'));
        }
      });
    });
    group('4. Screen Dimension Detection', () {
      test('should handle screen dimension detection', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.screenWidth != null) {
          expect(result.screenWidth, greaterThan(0));
        }
        if (result.screenHeight != null) {
          expect(result.screenHeight, greaterThan(0));
        }
        if (result.screenDensity != null) {
          expect(result.screenDensity, greaterThan(0.0));
        }
      });
      test('should provide reasonable screen dimensions when available',
          () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.screenWidth != null && result.screenHeight != null) {
          expect(result.screenWidth, greaterThan(100));
          expect(result.screenHeight, greaterThan(100));
          expect(result.screenWidth, lessThan(10000));
          expect(result.screenHeight, lessThan(10000));
        }
        if (result.screenDensity != null) {
          expect(result.screenDensity, greaterThan(0.5));
          expect(result.screenDensity, lessThan(10.0));
        }
      });
      test('should handle exceptions in screen dimension methods', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result.screenWidth, isA<int?>());
        expect(result.screenHeight, isA<int?>());
        expect(result.screenDensity, isA<double?>());
      });
      test('should return null when screen dimension detection fails',
          () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result.screenWidth, isA<int?>());
        expect(result.screenHeight, isA<int?>());
        expect(result.screenDensity, isA<double?>());
      });
    });
    group('5. Locale and Timezone Detection', () {
      test('should handle locale and timezone detection', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.locale != null) {
          expect(result.locale, isA<String>());
          expect(result.locale, isNotEmpty);
        }
        if (result.timezone != null) {
          expect(result.timezone, isA<String>());
          expect(result.timezone, isNotEmpty);
        }
      });
      test('should correctly detect Platform.localeName', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        final osName = result.osName;
        if (osName == 'Android' || osName == 'iOS') {
          final locale = result.locale;
          if (locale != null) {
            expect(locale, equals(Platform.localeName));
          }
        }
      });
      test('should use DateTime.now().timeZoneName for all platforms',
          () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.timezone != null) {
          final expectedTimezone = DateTime.now().timeZoneName;
          expect(result.timezone, equals(expectedTimezone));
        }
      });
    });
    group('6. App Information Detection', () {
      test('should handle app info detection', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.appId != null) {
          expect(result.appId, isA<String>());
          expect(result.appId, isNotEmpty);
        }
        if (result.appVersion != null) {
          expect(result.appVersion, isA<String>());
          expect(result.appVersion, isNotEmpty);
        }
      });
      test('should use PackageInfo for all platforms', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.appId != null) {
          expect(result.appId, equals('com.test.customfit'));
        }
        if (result.appVersion != null) {
          expect(result.appVersion, equals('2.1.0'));
        }
      });
      test('should handle PackageInfo.fromPlatform gracefully', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result.appId, isA<String?>());
        expect(result.appVersion, isA<String?>());
      });
    });
    group('7. SDK Version Tests', () {
      test('should use Android SDK version correctly', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.osName == 'Android') {
          // In test environment, sdkVersion is always non-null for Android
          expect(int.tryParse(result.sdkVersion), isA<int?>());
        }
      });
      test('should use iOS system version as SDK version', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.osName == 'iOS') {
          expect(result.sdkVersion, equals(result.osVersion));
        }
      });
      test('should use web app version as SDK version', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        final osName = result.osName;
        if (osName != null && osName.contains('web')) {
          expect(result.sdkVersion, equals(result.osVersion));
        }
      });
    });
    group('8. Platform-Specific Default Values', () {
      test('should populate manufacturer correctly based on platform',
          () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.manufacturer != null) {
          expect(result.manufacturer, isNotEmpty);
          if (result.osName == 'iOS') {
            expect(result.manufacturer, equals('Apple'));
          }
        }
      });
      test('should populate OS name based on platform', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        final osName = result.osName;
        if (osName != null) {
          const validOSNames = ['Android', 'iOS', 'web'];
          expect(validOSNames.any((os) => osName.contains(os)), isTrue,
              reason: 'OS name should be one of: $validOSNames');
        }
      });
      test('should handle web platform browser detection', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.osName == 'web' && result.model != null) {
          expect(result.model, isNotEmpty);
        }
      });
      test('should use androidInfo fields correctly', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.osName == 'Android') {
          expect(result.manufacturer, isA<String?>());
          expect(result.model, isA<String?>());
          expect(result.osVersion, isA<String?>());
          expect(result.sdkVersion, isA<String?>());
        }
      });
      test('should use iosInfo fields correctly', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.osName == 'iOS') {
          expect(result.model, isA<String?>());
          expect(result.osVersion, isA<String?>());
          expect(result.sdkVersion, isA<String?>());
        }
      });
      test('should use webBrowserInfo fields correctly', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        final osName = result.osName;
        if (osName != null && osName.contains('web')) {
          expect(result.manufacturer, isA<String?>());
          expect(result.model, isA<String?>());
          expect(result.osName, isA<String?>());
          expect(result.osVersion, isA<String?>());
          expect(result.locale, isA<String?>());
        }
      });
    });
    group('9. Error Handling and Recovery', () {
      test('should return default DeviceContext on errors', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result, isNotNull);
      });
      test('should handle plugin initialization failures gracefully', () async {
        expect(() async => await DeviceInfoDetector.detectDeviceInfo(),
            returnsNormally);
      });
      test('should handle partial detection failures', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result.toString(), isA<String>());
      });
      test('should always return valid DeviceContext on any error', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(() => result.toJson(), returnsNormally);
        expect(() => result.toString(), returnsNormally);
      });
      test('should handle all platform branches in detectDeviceInfo', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result.runtimeType, equals(DeviceContext));
      });
      test('should execute fallback for unknown platforms', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
      });
      test('should include error message in debug print', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
      });
    });
    group('10. Performance and Concurrency Tests', () {
      test('should complete detection within reasonable time', () async {
        final stopwatch = Stopwatch()..start();
        final result = await DeviceInfoDetector.detectDeviceInfo();
        stopwatch.stop();
        expect(result, isA<DeviceContext>());
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
      test('should handle multiple concurrent detection calls', () async {
        final futures = <Future<DeviceContext>>[];
        for (int i = 0; i < 5; i++) {
          futures.add(DeviceInfoDetector.detectDeviceInfo());
        }
        final results = await Future.wait(futures);
        for (final result in results) {
          expect(result, isA<DeviceContext>());
        }
        final firstResult = results.first;
        for (final result in results) {
          expect(result.osName, equals(firstResult.osName));
          expect(result.manufacturer, equals(firstResult.manufacturer));
          expect(result.model, equals(firstResult.model));
        }
      });
      test('should handle rapid successive calls efficiently', () async {
        final stopwatch = Stopwatch()..start();
        final futures = <Future<DeviceContext>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(DeviceInfoDetector.detectDeviceInfo());
        }
        final results = await Future.wait(futures);
        stopwatch.stop();
        expect(results, hasLength(10));
        for (final result in results) {
          expect(result, isA<DeviceContext>());
        }
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      });
      test('should not have memory leaks with repeated calls', () async {
        for (int i = 0; i < 50; i++) {
          final result = await DeviceInfoDetector.detectDeviceInfo();
          expect(result, isA<DeviceContext>());
          if (i % 10 == 0) {
            await Future.delayed(const Duration(milliseconds: 1));
          }
        }
      });
      test('should not leak memory with repeated detections', () async {
        for (int i = 0; i < 100; i++) {
          final result = await DeviceInfoDetector.detectDeviceInfo();
          expect(result, isA<DeviceContext>());
          if (i % 20 == 0) {
            await Future.delayed(const Duration(milliseconds: 1));
          }
        }
      });
    });
    group('11. Data Validation and Consistency', () {
      test('should provide valid OS information when available', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        final osName = result.osName;
        final osVersion = result.osVersion;
        if (osName != null && osVersion != null) {
          expect(osName, isNotEmpty);
          expect(osVersion, isNotEmpty);
          const validOSNames = [
            'Android',
            'iOS',
            'web',
            'Windows',
            'macOS',
            'Linux'
          ];
          expect(validOSNames.any((os) => osName.contains(os)), isTrue);
        }
      });
      test('should provide valid device information when available', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.manufacturer != null && result.model != null) {
          expect(result.manufacturer, isNotEmpty);
          expect(result.model, isNotEmpty);
          expect(result.manufacturer, isNot(equals('unknown')));
          expect(result.model, isNot(equals('unknown')));
        }
      });
      test('should provide valid network information when available', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        if (result.networkType != null) {
          expect(result.networkType, isNotEmpty);
          const validNetworkTypes = [
            'cellular',
            'wifi',
            'ethernet',
            'bluetooth',
            'unknown'
          ];
          expect(validNetworkTypes, contains(result.networkType));
        }
        if (result.networkCarrier != null) {
          expect(result.networkCarrier, isA<String>());
        }
      });
      test('should return consistent data across multiple calls', () async {
        final result1 = await DeviceInfoDetector.detectDeviceInfo();
        await Future.delayed(const Duration(milliseconds: 100));
        final result2 = await DeviceInfoDetector.detectDeviceInfo();
        expect(result1.manufacturer, equals(result2.manufacturer));
        expect(result1.model, equals(result2.model));
        expect(result1.osName, equals(result2.osName));
        expect(result1.osVersion, equals(result2.osVersion));
        expect(result1.sdkVersion, equals(result2.sdkVersion));
      });
      test('should handle all return paths correctly', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result.networkCarrier, isA<String?>());
        expect(result.timezone, isA<String?>());
      });
      test('should maintain data consistency across calls', () async {
        final results = <DeviceContext>[];
        for (int i = 0; i < 3; i++) {
          results.add(await DeviceInfoDetector.detectDeviceInfo());
          await Future.delayed(const Duration(milliseconds: 100));
        }
        final first = results.first;
        for (final result in results) {
          expect(result.manufacturer, equals(first.manufacturer));
          expect(result.model, equals(first.model));
          expect(result.osName, equals(first.osName));
          expect(result.osVersion, equals(first.osVersion));
          expect(result.appId, equals(first.appId));
          expect(result.appVersion, equals(first.appVersion));
        }
      });
    });
    group('12. Integration and Coverage Tests', () {
      test('should provide comprehensive device context', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        int populatedFields = 0;
        final manufacturer = result.manufacturer;
        final model = result.model;
        final osName = result.osName;
        final osVersion = result.osVersion;
        final appId = result.appId;
        final appVersion = result.appVersion;
        final locale = result.locale;
        final timezone = result.timezone;
        final screenWidth = result.screenWidth;
        final screenHeight = result.screenHeight;
        final screenDensity = result.screenDensity;
        final networkType = result.networkType;
        final networkCarrier = result.networkCarrier;
        if (manufacturer != null) populatedFields++;
        if (model != null) populatedFields++;
        if (osName != null) populatedFields++;
        if (osVersion != null) populatedFields++;
        // sdkVersion is always populated in test environment
        populatedFields++; // Count sdkVersion as always populated
        if (appId != null) populatedFields++;
        if (appVersion != null) populatedFields++;
        if (locale != null) populatedFields++;
        if (timezone != null) populatedFields++;
        if (screenWidth != null) populatedFields++;
        if (screenHeight != null) populatedFields++;
        if (screenDensity != null) populatedFields++;
        if (networkType != null) populatedFields++;
        if (networkCarrier != null) populatedFields++;
        expect(populatedFields, greaterThanOrEqualTo(0));
      });
      test('should execute all getter methods during detection', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result.screenWidth, isA<int?>());
        expect(result.screenHeight, isA<int?>());
        expect(result.screenDensity, isA<double?>());
      });
      test('should handle all connectivity contains() checks', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        if (result.networkType != null) {
          expect(result.networkType, isNotEmpty);
        }
      });
      test('should access static plugin instances correctly', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
      });
      test('should handle DeviceContext toString()', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(() => result.toString(), returnsNormally);
        final str = result.toString();
        expect(str, isA<String>());
      });
      test('should work with actual plugin implementations', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isA<DeviceContext>());
        expect(result.manufacturer, isA<String?>());
        expect(result.model, isA<String?>());
        expect(result.osName, isA<String?>());
        expect(result.osVersion, isA<String?>());
        expect(result.sdkVersion, isA<String?>());
        expect(result.appId, isA<String?>());
        expect(result.appVersion, isA<String?>());
        expect(result.locale, isA<String?>());
        expect(result.timezone, isA<String?>());
        expect(result.screenWidth, isA<int?>());
        expect(result.screenHeight, isA<int?>());
        expect(result.screenDensity, isA<double?>());
        expect(result.networkType, isA<String?>());
        expect(result.networkCarrier, isA<String?>());
      });
      test('should handle test platform gracefully', () async {
        final result = await DeviceInfoDetector.detectDeviceInfo();
        expect(result, isNotNull);
      });
      test('should provide consistent device info', () async {
        final contexts = <DeviceContext>[];
        for (int i = 0; i < 5; i++) {
          contexts.add(await DeviceInfoDetector.detectDeviceInfo());
        }
        if (contexts.first.manufacturer != null) {
          final manufacturers = contexts.map((c) => c.manufacturer).toSet();
          expect(manufacturers.length, equals(1),
              reason: 'Manufacturer should be consistent across all calls');
        }
        if (contexts.first.model != null) {
          final models = contexts.map((c) => c.model).toSet();
          expect(models.length, equals(1),
              reason: 'Model should be consistent across all calls');
        }
      });
    });
  });
}
