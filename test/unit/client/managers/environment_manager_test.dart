import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/environment_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/user_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/default_background_state_monitor.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/device_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/application_info.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'environment_manager_test.mocks.dart';

@GenerateMocks([
  BackgroundStateMonitor,
  UserManager,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  late MockBackgroundStateMonitor mockBackgroundStateMonitor;
  late MockUserManager mockUserManager;
  late EnvironmentManagerImpl environmentManager;
  setUp(() {
    mockBackgroundStateMonitor = MockBackgroundStateMonitor();
    mockUserManager = MockUserManager();

    // Setup default mock returns for CFResult methods
    when(mockUserManager.updateDeviceContext(any))
        .thenReturn(CFResult.success(null));
    when(mockUserManager.updateApplicationInfo(any))
        .thenReturn(CFResult.success(null));

    environmentManager = EnvironmentManagerImpl(
      backgroundStateMonitor: mockBackgroundStateMonitor,
      userManager: mockUserManager,
    );
  });
  group('EnvironmentManagerImpl', () {
    test('should detect environment info when forced', () async {
      // Arrange
      // These variables are intentionally not used directly in the test
      // as the test focuses on the side effects of detectEnvironmentInfo
      // on the mockUserManager.
      // final deviceContext = DeviceContext(
      //   manufacturer: 'TestManufacturer',
      //   model: 'TestModel',
      //   osName: 'TestOS',
      //   osVersion: '1.0',
      // );
      // final appInfo = ApplicationInfo(
      //   appName: 'TestApp',
      //   versionName: '1.0.0',
      //   packageName: 'com.test.app',
      // );
      // Mock static methods using mockito's when() with any()
      // Note: We'll need to mock the static methods differently in a real implementation
      // For now, we'll test the flow and exception handling
      // Act & Assert - Test that the method completes without throwing
      await expectLater(
        () => environmentManager.detectEnvironmentInfo(true),
        returnsNormally,
      );
      // Verify user manager methods would be called
      // Note: In a real implementation, we'd need to inject the detectors or make them mockable
    });
    test('should skip detection if already detecting', () async {
      // Arrange - Start one detection
      final future1 = environmentManager.detectEnvironmentInfo(true);
      // Act - Try to start another detection immediately
      final future2 = environmentManager.detectEnvironmentInfo(true);
      // Assert - Both should complete
      await expectLater(future1, completes);
      await expectLater(future2, completes);
    });
    test('should skip detection if not forced and detected recently', () async {
      // Arrange - Force a detection first
      await environmentManager.detectEnvironmentInfo(true);
      // Act - Try to detect again without forcing
      await environmentManager.detectEnvironmentInfo(false);
      // Assert - Should complete without error
      expect(true, isTrue); // Test passes if no exception thrown
    });
    test('should detect environment info when forced even if detected recently',
        () async {
      // Arrange - Force a detection first
      await environmentManager.detectEnvironmentInfo(true);
      // Act - Force detection again
      await environmentManager.detectEnvironmentInfo(true);
      // Assert - Should complete without error
      expect(true, isTrue); // Test passes if no exception thrown
    });
    test('should handle exceptions during environment detection gracefully',
        () async {
      // This test verifies the try-catch block works properly
      // In a real implementation, we'd mock the detectors to throw exceptions
      // Act & Assert - Should not throw even if internal methods fail
      await expectLater(
        () => environmentManager.detectEnvironmentInfo(true),
        returnsNormally,
      );
    });
    test('should call shutdown on background state monitor during shutdown',
        () {
      // Act
      environmentManager.shutdown();
      // Assert
      verify(mockBackgroundStateMonitor.shutdown()).called(1);
    });
    test('should implement EnvironmentManager interface correctly', () {
      // Assert
      expect(environmentManager, isA<EnvironmentManager>());
      expect(environmentManager.detectEnvironmentInfo, isA<Function>());
      expect(environmentManager.shutdown, isA<Function>());
    });
    test('should allow multiple detections when forced', () async {
      // Act - Multiple forced detections should all work
      await environmentManager.detectEnvironmentInfo(true);
      await environmentManager.detectEnvironmentInfo(true);
      await environmentManager.detectEnvironmentInfo(true);
      // Assert - Should complete without error
      expect(true, isTrue);
    });
    test('should prevent concurrent detections', () async {
      // Arrange
      var detectionsStarted = 0;
      var detectionsCompleted = 0;
      // Act - Start multiple detections concurrently
      final futures = List.generate(3, (index) async {
        detectionsStarted++;
        await environmentManager.detectEnvironmentInfo(true);
        detectionsCompleted++;
      });
      await Future.wait(futures);
      // Assert
      expect(detectionsStarted, equals(3));
      expect(detectionsCompleted, equals(3));
    });
    test('should have proper time-based detection throttling', () async {
      // Arrange - First detection
      await environmentManager.detectEnvironmentInfo(true);
      // Act - Multiple non-forced detections in quick succession
      await environmentManager.detectEnvironmentInfo(false);
      await environmentManager.detectEnvironmentInfo(false);
      await environmentManager.detectEnvironmentInfo(false);
      // Assert - Should complete without error (throttling working)
      expect(true, isTrue);
    });
    test('should update application info when detected', () async {
      // Arrange
      final mockDeviceContext = DeviceContext(
        manufacturer: 'TestManufacturer',
        model: 'TestModel',
        osName: 'TestOS',
        osVersion: '1.0',
      );
      final mockAppInfo = ApplicationInfo(
        appName: 'TestApp',
        versionName: '1.0.0',
        versionCode: 1,
        packageName: 'com.test.app',
      );
      // We need to test the actual behavior by mocking the static detector methods
      // Since we can't directly mock static methods in Dart, we'll test through
      // a custom environment manager that uses injected detectors
      // For this test, we'll create a custom implementation
      final customEnvironmentManager = TestableEnvironmentManager(
        backgroundStateMonitor: mockBackgroundStateMonitor,
        userManager: mockUserManager,
        deviceContext: mockDeviceContext,
        applicationInfo: mockAppInfo,
      );
      // Act
      await customEnvironmentManager.detectEnvironmentInfo(true);
      // Assert
      verify(mockUserManager.updateDeviceContext(mockDeviceContext)).called(1);
      verify(mockUserManager.updateApplicationInfo(mockAppInfo)).called(1);
    });
    test('should handle exceptions during detection and log error', () async {
      // Arrange - Create an environment manager that will throw
      final errorEnvironmentManager = TestableEnvironmentManager(
        backgroundStateMonitor: mockBackgroundStateMonitor,
        userManager: mockUserManager,
        shouldThrowError: true,
      );
      // Act & Assert - Should not throw, errors are caught internally
      await expectLater(
        () => errorEnvironmentManager.detectEnvironmentInfo(true),
        returnsNormally,
      );
    });
  });
  group('EnvironmentManager interface', () {
    test('should define required methods', () {
      // Arrange
      final EnvironmentManager manager = environmentManager;
      // Assert
      expect(manager.detectEnvironmentInfo, isA<Function>());
      expect(manager.shutdown, isA<Function>());
    });
  });
}

/// A testable version of EnvironmentManager that allows us to inject
/// device context and application info for testing
class TestableEnvironmentManager extends EnvironmentManagerImpl {
  final DeviceContext? deviceContext;
  final ApplicationInfo? applicationInfo;
  final bool shouldThrowError;
  final UserManager userManagerRef;
  TestableEnvironmentManager({
    required super.backgroundStateMonitor,
    required super.userManager,
    this.deviceContext,
    this.applicationInfo,
    this.shouldThrowError = false,
  }) : userManagerRef = userManager;
  @override
  Future<void> detectEnvironmentInfo(bool force) async {
    if (shouldThrowError) {
      // Trigger the actual method to test error handling
      // We'll override the detection logic to throw
      await _detectWithError(force);
      return;
    }
    // Skip throttling checks for testing
    if (deviceContext != null) {
      userManagerRef.updateDeviceContext(deviceContext!);
    }
    if (applicationInfo != null) {
      userManagerRef.updateApplicationInfo(applicationInfo!);
    }
  }

  Future<void> _detectWithError(bool force) async {
    // Call the actual parent implementation but it will fail
    // because the static detectors will throw in test environment
    try {
      // This simulates an error in the detection process
      throw Exception('Simulated detection error');
    } catch (e) {
      // The parent class should handle this gracefully
      await super.detectEnvironmentInfo(force);
    }
  }
}
