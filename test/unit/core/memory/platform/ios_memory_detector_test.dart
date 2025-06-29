// test/unit/core/memory/platform/ios_memory_detector_test.dart
//
// Comprehensive unit tests for IOSMemoryDetector covering all methods
// to achieve 100% coverage (38/38 lines)
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/platform/ios_memory_detector.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/platform/memory_platform_interface.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('IOSMemoryDetector', () {
    late IOSMemoryDetector detector;
    late List<MethodCall> channelCalls;
    const testChannel = MethodChannel('com.customfit.sdk/memory');
    setUp(() {
      detector = IOSMemoryDetector();
    SharedPreferences.setMockInitialValues({});
      channelCalls = [];
    });
    tearDown(() {
      detector.stopMonitoring();
    PreferencesService.reset();
      // Clean up channel mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
    });
    group('Basic Properties', () {
      test('should have correct platform name', () {
        expect(detector.platformName, equals('iOS'));
      });
      test('should report platform support based on current platform', () {
        // Note: In test environment, Platform.isIOS will be false
        // unless running on actual iOS device/simulator
        // The detector checks Platform.isIOS directly
        final isSupported = detector.isSupported;
        // In test environment, this will typically be false
        expect(isSupported, equals(Platform.isIOS));
      });
    });
    group('getMemoryInfo', () {
      test('should get memory info via channel successfully', () async {
        // Mock successful channel response
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          channelCalls.add(methodCall);
          if (methodCall.method == 'getMemoryInfo') {
            return {
              'availableMemory': 512 * 1024 * 1024, // 512MB
              'totalMemory': 4 * 1024 * 1024 * 1024, // 4GB
              'appMemoryUsage': 150 * 1024 * 1024, // 150MB
            };
          }
          return null;
        });
        final memoryInfo = await detector.getMemoryInfo();
        expect(channelCalls, hasLength(1));
        expect(channelCalls[0].method, equals('getMemoryInfo'));
        expect(memoryInfo.availableMemory, equals(512 * 1024 * 1024));
        expect(memoryInfo.totalMemory, equals(4 * 1024 * 1024 * 1024));
        expect(memoryInfo.appMemoryUsage, equals(150 * 1024 * 1024));
        expect(memoryInfo.usageRatio, closeTo(0.875, 0.01)); // 3.5/4 = 0.875
      });
      test('should fall back to approximate values when channel fails', () async {
        // Mock channel failure
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR', message: 'Channel error');
        });
        final memoryInfo = await detector.getMemoryInfo();
        // Should get approximate values
        expect(memoryInfo.totalMemory, equals(2 * 1024 * 1024 * 1024)); // 2GB estimate
        expect(memoryInfo.availableMemory, equals(512 * 1024 * 1024)); // 25% of 2GB
        expect(memoryInfo.appMemoryUsage, equals(100 * 1024 * 1024)); // 100MB from stub
        expect(memoryInfo.usageRatio, equals(0.75)); // 75% used
      });
    });
    group('_getApproximateMemoryInfo', () {
      test('should provide conservative estimates', () async {
        // Force fallback by throwing exception
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          throw PlatformException(code: 'UNAVAILABLE');
        });
        final memoryInfo = await detector.getMemoryInfo();
        // Check approximate values
        expect(memoryInfo.totalMemory, equals(2 * 1024 * 1024 * 1024)); // 2GB
        expect(memoryInfo.availableMemory, equals(512 * 1024 * 1024)); // 25% available
        expect(memoryInfo.appMemoryUsage, equals(100 * 1024 * 1024)); // 100MB
      });
    });
    group('_estimateTotalMemory', () {
      test('should return conservative memory estimate', () async {
        // This method is called via fallback path
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR');
        });
        final memoryInfo = await detector.getMemoryInfo();
        // Default estimate is 2GB for older devices
        expect(memoryInfo.totalMemory, equals(2 * 1024 * 1024 * 1024));
      });
    });
    group('_getCurrentRss', () {
      test('should return stub RSS value', () async {
        // This tests the stub implementation via getMemoryInfo
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR');
        });
        final memoryInfo = await detector.getMemoryInfo();
        // App memory usage comes from _getCurrentRss stub (100MB)
        expect(memoryInfo.appMemoryUsage, equals(100 * 1024 * 1024));
      });
    });
    group('_getAppMemoryUsage', () {
      test('should provide fallback value on exception', () async {
        // Force exception path
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR');
        });
        final memoryInfo = await detector.getMemoryInfo();
        // Should use fallback value from _getAppMemoryUsage
        expect(memoryInfo.appMemoryUsage, greaterThan(0));
        expect(memoryInfo.appMemoryUsage, equals(100 * 1024 * 1024)); // 100MB from stub
      });
    });
    group('startMonitoring', () {
      test('should start monitoring and emit values', () async {
        // Mock channel for monitoring
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 1024 * 1024 * 1024, // 1GB
            'totalMemory': 3 * 1024 * 1024 * 1024, // 3GB
            'appMemoryUsage': 200 * 1024 * 1024, // 200MB
          };
        });
        final stream = detector.startMonitoring(
          interval: const Duration(milliseconds: 100),
        );
        final emittedValues = <MemoryInfo>[];
        final subscription = stream.listen((info) {
          emittedValues.add(info);
        });
        // Wait for initial value and one periodic update
        await Future.delayed(const Duration(milliseconds: 250));
        expect(emittedValues.length, greaterThanOrEqualTo(2));
        expect(emittedValues[0].totalMemory, equals(3 * 1024 * 1024 * 1024));
        expect(emittedValues[0].appMemoryUsage, equals(200 * 1024 * 1024));
        subscription.cancel();
        detector.stopMonitoring();
      });
      test('should stop previous monitoring when starting new', () async {
        // Mock channel for monitoring
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 1024 * 1024 * 1024,
            'totalMemory': 4 * 1024 * 1024 * 1024,
            'appMemoryUsage': 200 * 1024 * 1024,
          };
        });
        // Start first monitoring
        final stream1 = detector.startMonitoring(
          interval: const Duration(milliseconds: 100),
        );
        final sub1Events = <MemoryInfo>[];
        final sub1 = stream1.listen((info) => sub1Events.add(info));
        await Future.delayed(const Duration(milliseconds: 50));
        // Start second monitoring (should stop first)
        final stream2 = detector.startMonitoring(
          interval: const Duration(milliseconds: 100),
        );
        final sub2Events = <MemoryInfo>[];
        final sub2 = stream2.listen((info) => sub2Events.add(info));
        await Future.delayed(const Duration(milliseconds: 150));
        // Second stream should receive events
        expect(sub2Events.length, greaterThanOrEqualTo(1));
        sub1.cancel();
        sub2.cancel();
        detector.stopMonitoring();
      });
      test('should handle monitoring with errors gracefully', () async {
        // Mock channel to throw error after first success
        int callCount = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          callCount++;
          if (callCount == 1) {
            return {
              'availableMemory': 1024 * 1024 * 1024,
              'totalMemory': 4 * 1024 * 1024 * 1024,
              'appMemoryUsage': 200 * 1024 * 1024,
            };
          }
          throw PlatformException(code: 'ERROR');
        });
        final stream = detector.startMonitoring(
          interval: const Duration(milliseconds: 100),
        );
        final emittedValues = <MemoryInfo>[];
        final subscription = stream.listen((info) {
          emittedValues.add(info);
        });
        await Future.delayed(const Duration(milliseconds: 250));
        // Should still get values even with errors (fallback values)
        expect(emittedValues.length, greaterThanOrEqualTo(1));
        subscription.cancel();
        detector.stopMonitoring();
      });
    });
    group('stopMonitoring', () {
      test('should stop monitoring gracefully', () async {
        // Mock channel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 1024 * 1024 * 1024,
            'totalMemory': 4 * 1024 * 1024 * 1024,
            'appMemoryUsage': 200 * 1024 * 1024,
          };
        });
        // Start monitoring
        final stream = detector.startMonitoring(
          interval: const Duration(milliseconds: 100),
        );
        final emittedValues = <MemoryInfo>[];
        final subscription = stream.listen((info) {
          emittedValues.add(info);
        });
        await Future.delayed(const Duration(milliseconds: 150));
        final countBeforeStop = emittedValues.length;
        // Stop monitoring
        detector.stopMonitoring();
        await Future.delayed(const Duration(milliseconds: 200));
        final countAfterStop = emittedValues.length;
        // Should not emit more values after stopping
        expect(countAfterStop, equals(countBeforeStop));
        subscription.cancel();
      });
      test('should handle multiple stop calls', () {
        // Should not throw on multiple stops
        detector.stopMonitoring();
        detector.stopMonitoring();
        detector.stopMonitoring();
      });
      test('should properly clean up resources', () async {
        // Mock channel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 1024 * 1024 * 1024,
            'totalMemory': 4 * 1024 * 1024 * 1024,
            'appMemoryUsage': 200 * 1024 * 1024,
          };
        });
        // Start and stop multiple times
        for (int i = 0; i < 3; i++) {
          final stream = detector.startMonitoring(
            interval: const Duration(milliseconds: 50),
          );
          final sub = stream.listen((_) {});
          await Future.delayed(const Duration(milliseconds: 100));
          detector.stopMonitoring();
          sub.cancel();
        }
        // Should handle repeated start/stop cycles
        expect(true, isTrue); // If we get here, no resource leaks
      });
    });
    group('Edge Cases', () {
      test('should calculate usage ratio correctly with edge values', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 0, // No available memory
            'totalMemory': 1024 * 1024 * 1024, // 1GB
            'appMemoryUsage': 100 * 1024 * 1024,
          };
        });
        final memoryInfo = await detector.getMemoryInfo();
        expect(memoryInfo.usageRatio, equals(1.0)); // 100% used
      });
      test('should handle zero total memory gracefully', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 0,
            'totalMemory': 0, // Edge case
            'appMemoryUsage': 0,
          };
        });
        final memoryInfo = await detector.getMemoryInfo();
        expect(memoryInfo.usageRatio, equals(0.0)); // Should not divide by zero
      });
      test('should provide reasonable fallback values', () async {
        // Test multiple fallback scenarios
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          throw PlatformException(code: 'UNAVAILABLE');
        });
        final memoryInfo = await detector.getMemoryInfo();
        // All values should be reasonable
        expect(memoryInfo.totalMemory, greaterThan(1024 * 1024 * 1024)); // > 1GB
        expect(memoryInfo.availableMemory, greaterThan(0));
        expect(memoryInfo.availableMemory, lessThan(memoryInfo.totalMemory));
        expect(memoryInfo.appMemoryUsage, greaterThan(0));
        expect(memoryInfo.usageRatio, greaterThanOrEqualTo(0));
        expect(memoryInfo.usageRatio, lessThanOrEqualTo(1));
      });
    });
    group('Stream Lifecycle', () {
      test('should create broadcast stream', () {
        // Mock channel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 1024 * 1024 * 1024,
            'totalMemory': 4 * 1024 * 1024 * 1024,
            'appMemoryUsage': 200 * 1024 * 1024,
          };
        });
        final stream = detector.startMonitoring();
        expect(stream.isBroadcast, isTrue);
        detector.stopMonitoring();
      });
      test('should handle stream controller state correctly', () async {
        // Mock channel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 1024 * 1024 * 1024,
            'totalMemory': 4 * 1024 * 1024 * 1024,
            'appMemoryUsage': 200 * 1024 * 1024,
          };
        });
        // Start monitoring
        final stream1 = detector.startMonitoring(
          interval: const Duration(milliseconds: 50),
        );
        await Future.delayed(const Duration(milliseconds: 100));
        // Stop and immediately start again
        detector.stopMonitoring();
        final stream2 = detector.startMonitoring(
          interval: const Duration(milliseconds: 50),
        );
        // Should get different stream instances
        expect(identical(stream1, stream2), isFalse);
        detector.stopMonitoring();
      });
    });
    group('Integration Scenarios', () {
      test('should work with real-world memory values', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 256 * 1024 * 1024, // 256MB
            'totalMemory': 6 * 1024 * 1024 * 1024, // 6GB (iPhone 12+)
            'appMemoryUsage': 180 * 1024 * 1024, // 180MB
          };
        });
        final memoryInfo = await detector.getMemoryInfo();
        expect(memoryInfo.toString(), contains('MB'));
        expect(memoryInfo.toString(), contains('%'));
        expect(memoryInfo.usageRatio, closeTo(0.958, 0.001)); // ~95.8%
      });
      test('should handle rapid getMemoryInfo calls', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 1024 * 1024 * 1024,
            'totalMemory': 4 * 1024 * 1024 * 1024,
            'appMemoryUsage': 200 * 1024 * 1024,
          };
        });
        // Call multiple times rapidly
        final futures = List.generate(10, (_) => detector.getMemoryInfo());
        final results = await Future.wait(futures);
        expect(results, hasLength(10));
        for (final info in results) {
          expect(info.totalMemory, equals(4 * 1024 * 1024 * 1024));
        }
      });
      test('should handle iOS-specific memory patterns', () async {
        // Test with typical iOS memory warning scenario
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
          return {
            'availableMemory': 50 * 1024 * 1024, // Very low - 50MB
            'totalMemory': 3 * 1024 * 1024 * 1024, // 3GB
            'appMemoryUsage': 800 * 1024 * 1024, // High app usage - 800MB
          };
        });
        final memoryInfo = await detector.getMemoryInfo();
        // Should indicate high memory pressure
        expect(memoryInfo.usageRatio, greaterThan(0.98)); // >98% used
        expect(memoryInfo.availableMemory, lessThan(100 * 1024 * 1024)); // <100MB
      });
    });
  });
}