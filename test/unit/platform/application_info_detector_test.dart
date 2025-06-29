import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/device_info_detector.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/application_info.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ApplicationInfoDetector', () {
    group('detectApplicationInfo', () {
      test('should return ApplicationInfo with valid data', () async {
        // Note: This test will use the actual PackageInfo.fromPlatform()
        // In a real testing environment, this would be mocked
        final result = await ApplicationInfoDetector.detectApplicationInfo();
        // The result should either be null or a valid ApplicationInfo
        if (result != null) {
          expect(result, isA<ApplicationInfo>());
          expect(result.appName, isA<String?>());
          expect(result.packageName, isA<String?>());
          expect(result.versionName, isA<String?>());
          expect(result.versionCode, isA<int?>());
        }
      });
      test('should handle package info detection gracefully', () async {
        // This test verifies that the method doesn't throw exceptions
        expect(
            () async => await ApplicationInfoDetector.detectApplicationInfo(),
            returnsNormally);
      });
      test('should return consistent results on multiple calls', () async {
        final result1 = await ApplicationInfoDetector.detectApplicationInfo();
        final result2 = await ApplicationInfoDetector.detectApplicationInfo();
        // Both results should be of the same type (both null or both ApplicationInfo)
        expect(result1.runtimeType, equals(result2.runtimeType));
        // If both are ApplicationInfo, they should have the same basic properties
        if (result1 != null && result2 != null) {
          expect(result1.appName, equals(result2.appName));
          expect(result1.packageName, equals(result2.packageName));
          expect(result1.versionName, equals(result2.versionName));
          expect(result1.versionCode, equals(result2.versionCode));
        }
      });
    });
    group('incrementLaunchCount', () {
      test('should increment launch count by 1', () {
        final originalInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          versionName: '1.0.0',
          versionCode: 1,
          launchCount: 5,
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(originalInfo);
        expect(incrementedInfo.launchCount, equals(6));
        expect(incrementedInfo.appName, equals(originalInfo.appName));
        expect(incrementedInfo.packageName, equals(originalInfo.packageName));
        expect(incrementedInfo.versionName, equals(originalInfo.versionName));
        expect(incrementedInfo.versionCode, equals(originalInfo.versionCode));
      });
      test('should preserve all original properties except launch count', () {
        final originalInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          versionName: '2.1.0',
          versionCode: 21,
          installDate: '2024-01-01',
          lastUpdateDate: '2024-06-01',
          buildType: 'release',
          launchCount: 10,
          customAttributes: {'key1': 'value1', 'key2': 'value2'},
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(originalInfo);
        expect(incrementedInfo.appName, equals(originalInfo.appName));
        expect(incrementedInfo.packageName, equals(originalInfo.packageName));
        expect(incrementedInfo.versionName, equals(originalInfo.versionName));
        expect(incrementedInfo.versionCode, equals(originalInfo.versionCode));
        expect(incrementedInfo.installDate, equals(originalInfo.installDate));
        expect(incrementedInfo.lastUpdateDate,
            equals(originalInfo.lastUpdateDate));
        expect(incrementedInfo.buildType, equals(originalInfo.buildType));
        expect(incrementedInfo.customAttributes,
            equals(originalInfo.customAttributes));
        expect(incrementedInfo.launchCount, equals(11));
      });
      test('should handle zero launch count', () {
        final originalInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          launchCount: 0,
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(originalInfo);
        expect(incrementedInfo.launchCount, equals(1));
      });
      test('should handle default launch count', () {
        final originalInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          // launchCount defaults to 1
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(originalInfo);
        expect(incrementedInfo.launchCount, equals(2));
      });
      test('should handle large launch counts', () {
        final originalInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          launchCount: 999999,
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(originalInfo);
        expect(incrementedInfo.launchCount, equals(1000000));
      });
      test('should handle null values in original info', () {
        final originalInfo = ApplicationInfo(
          appName: null,
          packageName: null,
          versionName: null,
          versionCode: null,
          installDate: null,
          lastUpdateDate: null,
          buildType: null,
          launchCount: 1,
          customAttributes: {},
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(originalInfo);
        expect(incrementedInfo.appName, isNull);
        expect(incrementedInfo.packageName, isNull);
        expect(incrementedInfo.versionName, isNull);
        expect(incrementedInfo.versionCode, isNull);
        expect(incrementedInfo.installDate, isNull);
        expect(incrementedInfo.lastUpdateDate, isNull);
        expect(incrementedInfo.buildType, isNull);
        expect(incrementedInfo.launchCount, equals(2));
        expect(incrementedInfo.customAttributes, isEmpty);
      });
      test('should handle empty custom attributes', () {
        final originalInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          launchCount: 5,
          customAttributes: {},
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(originalInfo);
        expect(incrementedInfo.customAttributes, isEmpty);
        expect(incrementedInfo.launchCount, equals(6));
      });
      test('should handle multiple increments correctly', () {
        var info = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          launchCount: 1,
        );
        // Increment multiple times
        for (int i = 2; i <= 10; i++) {
          info = ApplicationInfoDetector.incrementLaunchCount(info);
          expect(info.launchCount, equals(i));
        }
      });
      test('should create new instance, not modify original', () {
        final originalInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          launchCount: 5,
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(originalInfo);
        // Original should remain unchanged
        expect(originalInfo.launchCount, equals(5));
        // New instance should have incremented count
        expect(incrementedInfo.launchCount, equals(6));
        // Should be different instances
        expect(identical(originalInfo, incrementedInfo), isFalse);
      });
    });
    group('Integration Tests', () {
      test('should handle complete workflow', () async {
        // Detect application info
        final detectedInfo =
            await ApplicationInfoDetector.detectApplicationInfo();
        if (detectedInfo != null) {
          // Increment launch count
          final incrementedInfo =
              ApplicationInfoDetector.incrementLaunchCount(detectedInfo);
          // Verify the workflow
          expect(incrementedInfo.launchCount,
              equals(detectedInfo.launchCount + 1));
          expect(incrementedInfo.appName, equals(detectedInfo.appName));
          expect(incrementedInfo.packageName, equals(detectedInfo.packageName));
        }
      });
      test('should handle multiple detection and increment cycles', () async {
        for (int i = 0; i < 5; i++) {
          final detectedInfo =
              await ApplicationInfoDetector.detectApplicationInfo();
          if (detectedInfo != null) {
            final incrementedInfo =
                ApplicationInfoDetector.incrementLaunchCount(detectedInfo);
            expect(incrementedInfo.launchCount,
                equals(detectedInfo.launchCount + 1));
          }
        }
      });
    });
    group('Edge Cases', () {
      test('should handle ApplicationInfo with extreme values', () {
        final extremeInfo = ApplicationInfo(
          appName: 'A' * 1000, // Very long app name
          packageName: 'com.${'x' * 100}.app', // Very long package name
          versionName: '999.999.999',
          versionCode: 2147483647, // Max int value
          launchCount: 2147483646, // Max int - 1
          customAttributes: Map.fromEntries(
            List.generate(100, (i) => MapEntry('key$i', 'value$i')),
          ),
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(extremeInfo);
        expect(incrementedInfo.appName, equals(extremeInfo.appName));
        expect(incrementedInfo.packageName, equals(extremeInfo.packageName));
        expect(incrementedInfo.versionName, equals(extremeInfo.versionName));
        expect(incrementedInfo.versionCode, equals(extremeInfo.versionCode));
        expect(incrementedInfo.launchCount, equals(2147483647)); // Max int
        expect(incrementedInfo.customAttributes.length, equals(100));
      });
      test('should handle ApplicationInfo with special characters', () {
        final specialInfo = ApplicationInfo(
          appName: 'Test App 🎉 with émojis',
          packageName: 'com.test-app.special_chars',
          versionName: '1.0.0-beta+123',
          launchCount: 1,
          customAttributes: {
            'unicode_key_🔑': 'unicode_value_🎯',
            'special-chars': 'value with spaces & symbols!',
          },
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(specialInfo);
        expect(incrementedInfo.appName, equals(specialInfo.appName));
        expect(incrementedInfo.packageName, equals(specialInfo.packageName));
        expect(incrementedInfo.versionName, equals(specialInfo.versionName));
        expect(incrementedInfo.customAttributes,
            equals(specialInfo.customAttributes));
        expect(incrementedInfo.launchCount, equals(2));
      });
      test('should handle negative launch count gracefully', () {
        final negativeInfo = ApplicationInfo(
          appName: 'Test App',
          packageName: 'com.test.app',
          launchCount: -1,
        );
        final incrementedInfo =
            ApplicationInfoDetector.incrementLaunchCount(negativeInfo);
        expect(incrementedInfo.launchCount, equals(0));
      });
    });
  });
}
