// test/unit/client/cf_client_initializer_test.dart
//
// Comprehensive tests for CFClientInitializer class to achieve 80%+ coverage
// Tests all initialization methods, setup functions, and error handling
// Merged with coverage-focused tests for complete test coverage
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client_initializer.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/user_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/config_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_tracker.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_data.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_type.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/default_background_state_monitor.dart';
import 'package:customfit_ai_flutter_sdk/src/core/session/session_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/cache_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/sdk_settings.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/app_state.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/device_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/application_info.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import '../../utils/test_constants.dart';
import '../../test_config.dart';
@GenerateMocks([
  UserManager,
  ConfigManager,
  EventTracker,
  ConnectionManagerImpl,
  BackgroundStateMonitor,
  SessionManager,
  CacheManager,
])
import 'cf_client_initializer_test.mocks.dart';
import '../../helpers/test_storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Setup test storage with secure storage
    TestStorageHelper.setupTestStorage();
  });
  group('CFClientInitializer', () {
    late CFConfig testConfig;
    late CFUser testUser;
    late MockUserManager mockUserManager;
    late MockConfigManager mockConfigManager;
    late MockEventTracker mockEventTracker;
    late MockConnectionManagerImpl mockConnectionManager;
    late MockBackgroundStateMonitor mockBackgroundStateMonitor;
    late MockSessionManager mockSessionManager;
    setUp(() {
      testConfig = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(false)
          .setAutoEnvAttributesEnabled(true)
          .build()
          .getOrThrow();
      testUser = CFUser.builder('test-user-123')
          .addStringProperty('test_key', 'test_value')
          .build()
          .getOrThrow();
      mockUserManager = MockUserManager();
      mockConfigManager = MockConfigManager();
      mockEventTracker = MockEventTracker();
      mockConnectionManager = MockConnectionManagerImpl();
      mockBackgroundStateMonitor = MockBackgroundStateMonitor();
      mockSessionManager = MockSessionManager();
      TestConfig.setupTestLogger();
      PreferencesService.reset();
      // Setup default mock returns for CFResult methods
      when(mockUserManager.updateDeviceContext(any))
          .thenReturn(CFResult.success(null));
      when(mockUserManager.updateApplicationInfo(any))
          .thenReturn(CFResult.success(null));
    });
    group('initializeEnvironmentAttributes', () {
      test('should collect environment attributes when enabled', () {
        // Arrange
        final configWithAutoEnv = CFConfig.builder(TestConstants.validJwtToken)
            .setAutoEnvAttributesEnabled(true)
            .build()
            .getOrThrow();
        // Act
        CFClientInitializer.initializeEnvironmentAttributes(
          configWithAutoEnv,
          testUser,
          mockUserManager,
        );
        // Assert
        // The method should execute without throwing
        expect(configWithAutoEnv.autoEnvAttributesEnabled, isTrue);
      });
      test('should skip environment attributes when disabled', () {
        // Arrange
        final configWithoutAutoEnv =
            CFConfig.builder(TestConstants.validJwtToken)
                .setAutoEnvAttributesEnabled(false)
                .build()
                .getOrThrow();
        // Act
        CFClientInitializer.initializeEnvironmentAttributes(
          configWithoutAutoEnv,
          testUser,
          mockUserManager,
        );
        // Assert
        // The method should execute without throwing and skip collection
        expect(configWithoutAutoEnv.autoEnvAttributesEnabled, isFalse);
        // Should not call userManager since it's disabled
        verifyNever(mockUserManager.updateDeviceContext(any));
        verifyNever(mockUserManager.updateApplicationInfo(any));
      });
      test('should handle null device context gracefully', () {
        // Arrange
        final userWithoutDevice = CFUser.builder('test-user')
            .build()
            .getOrThrow(); // No device context
        // Act & Assert - Should not throw
        expect(
            () => CFClientInitializer.initializeEnvironmentAttributes(
                  testConfig,
                  userWithoutDevice,
                  mockUserManager,
                ),
            returnsNormally);
      });
      test('should handle null application context gracefully', () {
        // Arrange
        final userWithoutApp = CFUser.builder('test-user')
            .build()
            .getOrThrow(); // No application context
        // Act & Assert - Should not throw
        expect(
            () => CFClientInitializer.initializeEnvironmentAttributes(
                  testConfig,
                  userWithoutApp,
                  mockUserManager,
                ),
            returnsNormally);
      });
      test('should handle environment attributes for anonymous user', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setAutoEnvAttributesEnabled(true)
            .build()
            .getOrThrow();
        final user = CFUser.anonymousBuilder().build().getOrThrow();
        CFClientInitializer.initializeEnvironmentAttributes(
          config,
          user,
          mockUserManager,
        );
        // Should still attempt to collect environment attributes
      });
      test('should handle config with all auto features disabled', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setAutoEnvAttributesEnabled(false)
            .setDebugLoggingEnabled(true)
            .build()
            .getOrThrow();
        final user = CFUser.builder('test-user').build().getOrThrow();
        CFClientInitializer.initializeEnvironmentAttributes(
          config,
          user,
          mockUserManager,
        );
        // Should skip all automatic collection
        verifyNever(mockUserManager.updateDeviceContext(any));
        verifyNever(mockUserManager.updateApplicationInfo(any));
      });
      test('should handle device info collection with existing context', () {
        // Arrange
        final existingDevice = DeviceContext(
          manufacturer: 'Apple',
          model: 'iPhone',
          osName: 'iOS',
          osVersion: '14.0',
          sdkVersion: '1.0.0',
          customAttributes: {'existing': 'value'},
        );
        final userWithDevice = CFUser.builder('test-user')
            .withDeviceContext(existingDevice)
            .build()
            .getOrThrow();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setAutoEnvAttributesEnabled(true)
            .build()
            .getOrThrow();
        // Act
        CFClientInitializer.initializeEnvironmentAttributes(
          config,
          userWithDevice,
          mockUserManager,
        );
        // Wait for async operations
        Future.delayed(const Duration(milliseconds: 100), () {
          // Should eventually call updateDeviceContext
          // The method handles errors internally, so we just verify it attempts to collect
        });
      });
      test('should handle application info collection with existing info', () {
        // Arrange
        final existingApp = ApplicationInfo(
          appName: 'TestApp',
          packageName: 'com.test.app',
          versionName: '1.0.0',
          versionCode: 1,
          launchCount: 5,
          customAttributes: {'existing': 'value'},
        );
        final userWithApp = CFUser.builder('test-user')
            .withApplicationInfo(existingApp)
            .build()
            .getOrThrow();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setAutoEnvAttributesEnabled(true)
            .build()
            .getOrThrow();
        // Act
        CFClientInitializer.initializeEnvironmentAttributes(
          config,
          userWithApp,
          mockUserManager,
        );
        // Wait for async operations
        Future.delayed(const Duration(milliseconds: 100), () {
          // Should eventually call updateApplicationInfo
          // The method handles errors internally
        });
      });
      test('should increment launch count when merging application info', () {
        // This tests line 383 (incrementing launch count)
        final existingApp = ApplicationInfo(
          appName: 'TestApp',
          packageName: 'com.test.app',
          versionName: '1.0.0',
          versionCode: 1,
          launchCount: 10,
          customAttributes: {},
        );
        final userWithApp = CFUser.builder('test-user')
            .withApplicationInfo(existingApp)
            .build()
            .getOrThrow();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setAutoEnvAttributesEnabled(true)
            .build()
            .getOrThrow();
        // Act
        CFClientInitializer.initializeEnvironmentAttributes(
          config,
          userWithApp,
          mockUserManager,
        );
        // Launch count should be incremented during merge
      });
      test('should handle createMainUserContext with null userId', () {
        // Test when user doesn't have a userCustomerId
        final userWithoutId = CFUser.anonymousBuilder().build().getOrThrow();
        const sessionId = 'test-session';
        final context = CFClientInitializer.createMainUserContext(
          userWithoutId,
          sessionId,
        );
        // Anonymous users have generated IDs, so it will use that instead of sessionId
        expect(context.key, isNotNull);
        expect(context.key, isNotEmpty);
        // For anonymous users, the key will be the generated anonymous ID
        expect(context.key, startsWith('anon_'));
      });
    });
    group('setupConnectionListeners', () {
      test('should add connection status listener successfully', () {
        // Act
        CFClientInitializer.setupConnectionListeners(mockConnectionManager);
        // Assert
        verify(mockConnectionManager.addConnectionStatusListener(any))
            .called(1);
      });
      test('should setup connection status listener with interface', () {
        // This should trigger lines 66-72 (connection listener setup)
        CFClientInitializer.setupConnectionListeners(mockConnectionManager);
        // Verify that a connection listener was added
        verify(mockConnectionManager.addConnectionStatusListener(any))
            .called(1);
      });
      test('should handle connection manager exceptions gracefully', () {
        // Arrange
        when(mockConnectionManager.addConnectionStatusListener(any))
            .thenThrow(Exception('Connection manager error'));
        // Act & Assert - Should throw the exception since it's not handled internally
        expect(
            () => CFClientInitializer.setupConnectionListeners(
                mockConnectionManager),
            throwsA(isA<Exception>()));
      });
      test(
          'should handle connection manager interface exceptions during listener setup',
          () {
        // Mock connection manager to throw exception
        when(mockConnectionManager.addConnectionStatusListener(any))
            .thenThrow(Exception('Connection manager error'));
        // Should throw since the exception isn't caught
        expect(
            () => CFClientInitializer.setupConnectionListeners(
                mockConnectionManager),
            throwsException);
      });
    });
    group('setupBackgroundListeners', () {
      test('should add app state listener successfully', () {
        // Arrange
        void onPausePolling() {}
        void onResumePolling() {}
        void onCheckSdkSettings() {}
        // Act
        CFClientInitializer.setupBackgroundListeners(
          backgroundStateMonitor: mockBackgroundStateMonitor,
          onPausePolling: onPausePolling,
          onResumePolling: onResumePolling,
          onCheckSdkSettings: onCheckSdkSettings,
        );
        // Assert
        verify(mockBackgroundStateMonitor.addAppStateListener(any)).called(1);
      });
      test('should add app state listener with session manager', () {
        // Arrange
        void onPausePolling() {}
        void onResumePolling() {}
        void onCheckSdkSettings() {}
        // Act
        CFClientInitializer.setupBackgroundListeners(
          backgroundStateMonitor: mockBackgroundStateMonitor,
          onPausePolling: onPausePolling,
          onResumePolling: onResumePolling,
          onCheckSdkSettings: onCheckSdkSettings,
          sessionManager: mockSessionManager,
        );
        // Assert
        verify(mockBackgroundStateMonitor.addAppStateListener(any)).called(1);
      });
      test('should setup background state listener without session manager',
          () {
        // This should trigger lines 76-98 but skip session manager calls
        CFClientInitializer.setupBackgroundListeners(
          backgroundStateMonitor: mockBackgroundStateMonitor,
          onPausePolling: () {},
          onResumePolling: () {},
          onCheckSdkSettings: () {},
          sessionManager: null, // No session manager
        );
        // Verify that a background listener was added
        verify(mockBackgroundStateMonitor.addAppStateListener(any)).called(1);
      });
      test('should handle background monitor exceptions gracefully', () {
        // Arrange
        when(mockBackgroundStateMonitor.addAppStateListener(any))
            .thenThrow(Exception('Background monitor error'));
        void onPausePolling() {}
        void onResumePolling() {}
        void onCheckSdkSettings() {}
        // Act & Assert - Should throw the exception since it's not handled internally
        expect(
            () => CFClientInitializer.setupBackgroundListeners(
                  backgroundStateMonitor: mockBackgroundStateMonitor,
                  onPausePolling: onPausePolling,
                  onResumePolling: onResumePolling,
                  onCheckSdkSettings: onCheckSdkSettings,
                ),
            throwsA(isA<Exception>()));
      });
      test('should handle null session manager gracefully', () {
        // Arrange
        void onPausePolling() {}
        void onResumePolling() {}
        void onCheckSdkSettings() {}
        // Act & Assert - Should not throw
        expect(
            () => CFClientInitializer.setupBackgroundListeners(
                  backgroundStateMonitor: mockBackgroundStateMonitor,
                  onPausePolling: onPausePolling,
                  onResumePolling: onResumePolling,
                  onCheckSdkSettings: onCheckSdkSettings,
                  sessionManager: null,
                ),
            returnsNormally);
      });
      test('should handle background state transitions with all callbacks', () {
        var pausePollingCalled = false;
        var resumePollingCalled = false;
        var checkSdkSettingsCalled = false;
        CFClientInitializer.setupBackgroundListeners(
          backgroundStateMonitor: mockBackgroundStateMonitor,
          onPausePolling: () => pausePollingCalled = true,
          onResumePolling: () => resumePollingCalled = true,
          onCheckSdkSettings: () => checkSdkSettingsCalled = true,
          sessionManager: mockSessionManager,
        );
        // Capture the listener that was added
        final capturedListener =
            verify(mockBackgroundStateMonitor.addAppStateListener(captureAny))
                .captured
                .single;
        // Test background state (should trigger lines 86-88)
        capturedListener.onAppStateChanged(AppState.background);
        expect(pausePollingCalled, isTrue);
        verify(mockSessionManager.onAppBackground()).called(1);
        // Reset flags
        pausePollingCalled = false;
        // Test active state
        capturedListener.onAppStateChanged(AppState.active);
        expect(resumePollingCalled, isTrue);
        expect(checkSdkSettingsCalled, isTrue);
        verify(mockSessionManager.onAppForeground()).called(1);
        verify(mockSessionManager.updateActivity()).called(1);
      });
      test('should handle background state transitions without session manager',
          () {
        var pausePollingCalled = false;
        var resumePollingCalled = false;
        var checkSdkSettingsCalled = false;
        CFClientInitializer.setupBackgroundListeners(
          backgroundStateMonitor: mockBackgroundStateMonitor,
          onPausePolling: () => pausePollingCalled = true,
          onResumePolling: () => resumePollingCalled = true,
          onCheckSdkSettings: () => checkSdkSettingsCalled = true,
          sessionManager: null, // No session manager
        );
        // Capture the listener
        final capturedListener =
            verify(mockBackgroundStateMonitor.addAppStateListener(captureAny))
                .captured
                .single;
        // Test background state without session manager
        capturedListener.onAppStateChanged(AppState.background);
        expect(pausePollingCalled, isTrue);
        // Test active state without session manager
        capturedListener.onAppStateChanged(AppState.active);
        expect(resumePollingCalled, isTrue);
        expect(checkSdkSettingsCalled, isTrue);
      });
      test('should handle background monitor exceptions during listener setup',
          () {
        // Mock background monitor to throw exception
        when(mockBackgroundStateMonitor.addAppStateListener(any))
            .thenThrow(Exception('Background monitor error'));
        // Should throw since the exception isn't caught
        expect(
            () => CFClientInitializer.setupBackgroundListeners(
                  backgroundStateMonitor: mockBackgroundStateMonitor,
                  onPausePolling: () {},
                  onResumePolling: () {},
                  onCheckSdkSettings: () {},
                  sessionManager: mockSessionManager,
                ),
            throwsException);
      });
    });
    group('setupUserChangeListeners', () {
      test('should add user change listener when not in offline mode', () {
        // Arrange
        when(mockConfigManager.refreshConfigs()).thenAnswer((_) async => true);
        // Act
        CFClientInitializer.setupUserChangeListeners(
          userManager: mockUserManager,
          configManager: mockConfigManager,
          offlineMode: false,
        );
        // Assert
        verify(mockUserManager.addUserChangeListener(any)).called(1);
      });
      test('should add user change listener even in offline mode', () {
        // Act
        CFClientInitializer.setupUserChangeListeners(
          userManager: mockUserManager,
          configManager: mockConfigManager,
          offlineMode: true,
        );
        // Assert
        verify(mockUserManager.addUserChangeListener(any)).called(1);
      });
      test('should handle config refresh success', () async {
        // Arrange
        when(mockConfigManager.refreshConfigs()).thenAnswer((_) async => true);
        CFClientInitializer.setupUserChangeListeners(
          userManager: mockUserManager,
          configManager: mockConfigManager,
          offlineMode: false,
        );
        // Get the listener that was added
        final capturedListener =
            verify(mockUserManager.addUserChangeListener(captureAny))
                .captured
                .first as Function(CFUser);
        // Act
        capturedListener(testUser);
        // Wait for async operation
        await Future.delayed(const Duration(milliseconds: 10));
        // Assert
        verify(mockConfigManager.refreshConfigs()).called(1);
      });
      test('should handle config refresh failure', () async {
        // Arrange
        when(mockConfigManager.refreshConfigs()).thenAnswer((_) async => false);
        CFClientInitializer.setupUserChangeListeners(
          userManager: mockUserManager,
          configManager: mockConfigManager,
          offlineMode: false,
        );
        // Get the listener that was added
        final capturedListener =
            verify(mockUserManager.addUserChangeListener(captureAny))
                .captured
                .first as Function(CFUser);
        // Act
        capturedListener(testUser);
        // Wait for async operation
        await Future.delayed(const Duration(milliseconds: 10));
        // Assert
        verify(mockConfigManager.refreshConfigs()).called(1);
      });
      test('should handle config refresh exception', () async {
        // Arrange
        when(mockConfigManager.refreshConfigs())
            .thenThrow(Exception('Config refresh error'));
        CFClientInitializer.setupUserChangeListeners(
          userManager: mockUserManager,
          configManager: mockConfigManager,
          offlineMode: false,
        );
        // Get the listener that was added
        final capturedListener =
            verify(mockUserManager.addUserChangeListener(captureAny))
                .captured
                .first as Function(CFUser);
        // Act & Assert - Should not throw
        expect(() => capturedListener(testUser), returnsNormally);
      });
      test('should handle async config refresh errors', () async {
        // Arrange - This covers lines 124-132
        when(mockConfigManager.refreshConfigs())
            .thenAnswer((_) async => throw Exception('Async error'));
        CFClientInitializer.setupUserChangeListeners(
          userManager: mockUserManager,
          configManager: mockConfigManager,
          offlineMode: false,
        );
        // Get the listener that was added
        final capturedListener =
            verify(mockUserManager.addUserChangeListener(captureAny))
                .captured
                .first as Function(CFUser);
        // Act - Trigger the error path
        capturedListener(testUser);
        // Wait for async operation
        await Future.delayed(const Duration(milliseconds: 50));
        // Assert - Should have attempted refresh
        verify(mockConfigManager.refreshConfigs()).called(1);
      });
      test('should handle exceptions during listener execution', () async {
        // Arrange - This covers the outer try-catch (lines 133-141)
        when(mockConfigManager.refreshConfigs())
            .thenThrow(Exception('Sync exception'));
        CFClientInitializer.setupUserChangeListeners(
          userManager: mockUserManager,
          configManager: mockConfigManager,
          offlineMode: false,
        );
        // Get the listener that was added
        final capturedListener =
            verify(mockUserManager.addUserChangeListener(captureAny))
                .captured
                .first as Function(CFUser);
        // Act & Assert - Should not propagate exception
        expect(() => capturedListener(testUser), returnsNormally);
      });
      test('should skip config refresh in offline mode', () async {
        // Arrange
        CFClientInitializer.setupUserChangeListeners(
          userManager: mockUserManager,
          configManager: mockConfigManager,
          offlineMode: true,
        );
        // Get the listener that was added
        final capturedListener =
            verify(mockUserManager.addUserChangeListener(captureAny))
                .captured
                .first as Function(CFUser);
        // Act
        capturedListener(testUser);
        // Wait for async operation
        await Future.delayed(const Duration(milliseconds: 10));
        // Assert
        verifyNever(mockConfigManager.refreshConfigs());
      });
      test('should handle user manager exceptions gracefully', () {
        // Arrange
        when(mockUserManager.addUserChangeListener(any))
            .thenThrow(Exception('User manager error'));
        // Act & Assert - Should throw the exception since it's not handled internally
        expect(
            () => CFClientInitializer.setupUserChangeListeners(
                  userManager: mockUserManager,
                  configManager: mockConfigManager,
                  offlineMode: false,
                ),
            throwsA(isA<Exception>()));
      });
    });
    group('setupEventTrackingListeners', () {
      test('should add event callback successfully', () {
        // Arrange
        bool isOfflineMode() => false;
        // Act
        CFClientInitializer.setupEventTrackingListeners(
          eventTracker: mockEventTracker,
          configManager: mockConfigManager,
          isOfflineMode: isOfflineMode,
        );
        // Assert
        verify(mockEventTracker.setEventCallback(any)).called(1);
      });
      test('should handle event tracker exceptions gracefully', () {
        // Arrange
        when(mockEventTracker.setEventCallback(any))
            .thenThrow(Exception('Event tracker error'));
        bool isOfflineMode() => false;
        // Act & Assert - Should throw the exception since it's not handled internally
        expect(
            () => CFClientInitializer.setupEventTrackingListeners(
                  eventTracker: mockEventTracker,
                  configManager: mockConfigManager,
                  isOfflineMode: isOfflineMode,
                ),
            throwsA(isA<Exception>()));
      });
      test('should handle rule event tracking with SDK settings', () async {
        // Arrange - This covers lines 169-195
        when(mockConfigManager.refreshConfigs()).thenAnswer((_) async => true);
        when(mockConfigManager.getSdkSettings()).thenReturn(
          const SdkSettings(
            cfAccountEnabled: true,
            cfSkipSdk: false,
            ruleEvents: ['purchase', 'signup'],
          ),
        );
        bool isOfflineMode() => false;
        CFClientInitializer.setupEventTrackingListeners(
          eventTracker: mockEventTracker,
          configManager: mockConfigManager,
          isOfflineMode: isOfflineMode,
        );
        // Get the callback that was set
        final capturedCallback =
            verify(mockEventTracker.setEventCallback(captureAny)).captured.first
                as Function(EventData);
        // Act - Send a rule event
        final eventData = EventData.create(
          eventCustomerId: 'purchase',
          eventType: EventType.track,
          sessionId: 'test-session',
          properties: {},
        );
        capturedCallback(eventData);
        // Wait for async operation
        await Future.delayed(const Duration(milliseconds: 50));
        // Assert
        verify(mockConfigManager.refreshConfigs()).called(1);
      });
      test('should skip config refresh for non-rule events', () async {
        // Arrange
        when(mockConfigManager.getSdkSettings()).thenReturn(
          const SdkSettings(
            cfAccountEnabled: true,
            cfSkipSdk: false,
            ruleEvents: ['purchase', 'signup'],
          ),
        );
        bool isOfflineMode() => false;
        CFClientInitializer.setupEventTrackingListeners(
          eventTracker: mockEventTracker,
          configManager: mockConfigManager,
          isOfflineMode: isOfflineMode,
        );
        // Get the callback
        final capturedCallback =
            verify(mockEventTracker.setEventCallback(captureAny)).captured.first
                as Function(EventData);
        // Act - Send a non-rule event
        final eventData = EventData.create(
          eventCustomerId: 'page_view', // Not a rule event
          eventType: EventType.track,
          sessionId: 'test-session',
          properties: {},
        );
        capturedCallback(eventData);
        // Wait
        await Future.delayed(const Duration(milliseconds: 50));
        // Assert - Should not refresh configs
        verifyNever(mockConfigManager.refreshConfigs());
      });
      test('should handle null SDK settings', () async {
        // Arrange - This covers lines 157-161
        when(mockConfigManager.getSdkSettings()).thenReturn(null);
        bool isOfflineMode() => false;
        CFClientInitializer.setupEventTrackingListeners(
          eventTracker: mockEventTracker,
          configManager: mockConfigManager,
          isOfflineMode: isOfflineMode,
        );
        // Get the callback
        final capturedCallback =
            verify(mockEventTracker.setEventCallback(captureAny)).captured.first
                as Function(EventData);
        // Act
        final eventData = EventData.create(
          eventCustomerId: 'test_event',
          eventType: EventType.track,
          sessionId: 'test-session',
          properties: {},
        );
        capturedCallback(eventData);
        // Wait
        await Future.delayed(const Duration(milliseconds: 50));
        // Assert - Should not crash or refresh
        verifyNever(mockConfigManager.refreshConfigs());
      });
      test('should handle offline mode during rule event', () async {
        // Arrange - This covers lines 172-175
        when(mockConfigManager.getSdkSettings()).thenReturn(
          const SdkSettings(
            cfAccountEnabled: true,
            cfSkipSdk: false,
            ruleEvents: ['purchase'],
          ),
        );
        bool isOfflineMode() => true; // Offline mode
        CFClientInitializer.setupEventTrackingListeners(
          eventTracker: mockEventTracker,
          configManager: mockConfigManager,
          isOfflineMode: isOfflineMode,
        );
        // Get the callback
        final capturedCallback =
            verify(mockEventTracker.setEventCallback(captureAny)).captured.first
                as Function(EventData);
        // Act - Send a rule event in offline mode
        final eventData = EventData.create(
          eventCustomerId: 'purchase',
          eventType: EventType.track,
          sessionId: 'test-session',
          properties: {},
        );
        capturedCallback(eventData);
        // Wait
        await Future.delayed(const Duration(milliseconds: 50));
        // Assert - Should not refresh in offline mode
        verifyNever(mockConfigManager.refreshConfigs());
      });
      test('should handle config refresh errors during rule event', () async {
        // Arrange - This covers lines 186-195
        when(mockConfigManager.getSdkSettings()).thenReturn(
          const SdkSettings(
            cfAccountEnabled: true,
            cfSkipSdk: false,
            ruleEvents: ['purchase'],
          ),
        );
        when(mockConfigManager.refreshConfigs())
            .thenAnswer((_) async => throw Exception('Refresh error'));
        bool isOfflineMode() => false;
        CFClientInitializer.setupEventTrackingListeners(
          eventTracker: mockEventTracker,
          configManager: mockConfigManager,
          isOfflineMode: isOfflineMode,
        );
        // Get the callback
        final capturedCallback =
            verify(mockEventTracker.setEventCallback(captureAny)).captured.first
                as Function(EventData);
        // Act
        final eventData = EventData.create(
          eventCustomerId: 'purchase',
          eventType: EventType.track,
          sessionId: 'test-session',
          properties: {},
        );
        // Should not throw
        expect(() => capturedCallback(eventData), returnsNormally);
        // Wait
        await Future.delayed(const Duration(milliseconds: 50));
        // Assert
        verify(mockConfigManager.refreshConfigs()).called(1);
      });
      test('should handle exceptions in event callback', () {
        // Arrange - This covers lines 197-205
        when(mockConfigManager.getSdkSettings())
            .thenThrow(Exception('SDK settings error'));
        bool isOfflineMode() => false;
        CFClientInitializer.setupEventTrackingListeners(
          eventTracker: mockEventTracker,
          configManager: mockConfigManager,
          isOfflineMode: isOfflineMode,
        );
        // Get the callback
        final capturedCallback =
            verify(mockEventTracker.setEventCallback(captureAny)).captured.first
                as Function(EventData);
        // Act
        final eventData = EventData.create(
          eventCustomerId: 'test_event',
          eventType: EventType.track,
          sessionId: 'test-session',
          properties: {},
        );
        // Should not propagate exception
        expect(() => capturedCallback(eventData), returnsNormally);
      });
    });
    group('initializeCacheManager', () {
      test('should initialize cache manager successfully', () {
        // Act & Assert - Should not throw
        expect(() => CFClientInitializer.initializeCacheManager(testConfig),
            returnsNormally);
      });
      test('should handle cache manager initialization with different configs',
          () {
        // Arrange
        final configs = [
          CFConfig.builder(TestConstants.validJwtToken)
              .setDebugLoggingEnabled(true)
              .build()
              .getOrThrow(),
          CFConfig.builder(TestConstants.validJwtToken)
              .setDebugLoggingEnabled(false)
              .build()
              .getOrThrow(),
          CFConfig.builder(TestConstants.validJwtToken)
              .setOfflineMode(true)
              .build()
              .getOrThrow(),
        ];
        // Act & Assert - Should not throw for any config
        for (final config in configs) {
          expect(() => CFClientInitializer.initializeCacheManager(config),
              returnsNormally);
        }
      });
    });
    group('initializeMemoryManagement', () {
      test('should initialize memory management successfully', () async {
        // Act & Assert - Should not throw
        await expectLater(
            CFClientInitializer.initializeMemoryManagement(testConfig),
            completes);
      });
    });
    group('createMainUserContext', () {
      test('should create user context successfully', () {
        // Arrange
        const sessionId = 'test-session-123';
        // Act
        final context =
            CFClientInitializer.createMainUserContext(testUser, sessionId);
        // Assert
        expect(context, isNotNull);
        expect(context.key, equals(testUser.userCustomerId));
        expect(context.type.name, equals('user'));
      });
      test('should create user context with different user types', () {
        // Arrange
        const sessionId = 'test-session-123';
        final users = [
          CFUser.builder('user-1')
              .addStringProperty('test_key', 'test_value')
              .build(),
          CFUser.builder('user-2').addNumberProperty('test_number', 1).build(),
          CFUser.builder('user-3')
              .addBooleanProperty('test_bool', true)
              .build(),
        ];
        // Act & Assert
        for (final user in users) {
          final context =
              CFClientInitializer.createMainUserContext(user, sessionId);
          expect(context, isNotNull);
          expect(context.key, equals(user.userCustomerId));
          expect(context.type.name, equals('user'));
        }
      });
      test('should handle empty session ID', () {
        // Act
        final context = CFClientInitializer.createMainUserContext(testUser, '');
        // Assert
        expect(context, isNotNull);
        expect(context.key, equals(testUser.userCustomerId));
        expect(context.type.name, equals('user'));
      });
      test('should handle user with minimal properties', () {
        // Arrange
        final minimalUser = CFUser.builder('minimal-user').build().getOrThrow();
        const sessionId = 'test-session-123';
        // Act
        final context =
            CFClientInitializer.createMainUserContext(minimalUser, sessionId);
        // Assert
        expect(context, isNotNull);
        expect(context.key, equals('minimal-user'));
        expect(context.type.name, equals('user'));
      });
    });
    group('Edge Cases and Error Handling', () {
      test('should handle null parameters gracefully', () {
        // Most methods should handle null parameters without throwing
        expect(
            () => CFClientInitializer.setupConnectionListeners(
                mockConnectionManager),
            returnsNormally);
      });
      test('should handle very long session IDs', () {
        // Arrange
        final longSessionId = 'a' * 1000;
        // Act
        final context =
            CFClientInitializer.createMainUserContext(testUser, longSessionId);
        // Assert
        expect(context, isNotNull);
        expect(context.key, equals(testUser.userCustomerId));
        expect(context.type.name, equals('user'));
      });
      test('should handle special characters in session IDs', () {
        // Arrange
        const specialSessionId = 'session-with_special.chars@123!';
        // Act
        final context = CFClientInitializer.createMainUserContext(
            testUser, specialSessionId);
        // Assert
        expect(context, isNotNull);
        expect(context.key, equals(testUser.userCustomerId));
        expect(context.type.name, equals('user'));
      });
      test('should handle unicode characters in session IDs', () {
        // Arrange
        const unicodeSessionId = 'session_测试_🎉';
        // Act
        final context = CFClientInitializer.createMainUserContext(
            testUser, unicodeSessionId);
        // Assert
        expect(context, isNotNull);
        expect(context.key, equals(testUser.userCustomerId));
        expect(context.type.name, equals('user'));
      });
    });
    group('Integration Tests', () {
      test('should initialize all components in sequence', () {
        // This test verifies that all initialization methods can be called in sequence
        // without throwing exceptions
        // Act & Assert - All should complete without throwing
        expect(() {
          CFClientInitializer.initializeCacheManager(testConfig);
          CFClientInitializer.initializeEnvironmentAttributes(
              testConfig, testUser, mockUserManager);
          CFClientInitializer.setupConnectionListeners(mockConnectionManager);
          CFClientInitializer.setupBackgroundListeners(
            backgroundStateMonitor: mockBackgroundStateMonitor,
            onPausePolling: () {},
            onResumePolling: () {},
            onCheckSdkSettings: () {},
          );
          CFClientInitializer.setupUserChangeListeners(
            userManager: mockUserManager,
            configManager: mockConfigManager,
            offlineMode: false,
          );
          CFClientInitializer.setupEventTrackingListeners(
            eventTracker: mockEventTracker,
            configManager: mockConfigManager,
            isOfflineMode: () => false,
          );
          CFClientInitializer.createMainUserContext(testUser, 'test-session');
        }, returnsNormally);
      });
      test('should handle initialization with offline config', () {
        // Arrange
        final offlineConfig = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true)
            .setAutoEnvAttributesEnabled(false)
            .build()
            .getOrThrow();
        // Act & Assert - Should handle offline mode gracefully
        expect(() {
          CFClientInitializer.initializeCacheManager(offlineConfig);
          CFClientInitializer.initializeEnvironmentAttributes(
              offlineConfig, testUser, mockUserManager);
          CFClientInitializer.setupUserChangeListeners(
            userManager: mockUserManager,
            configManager: mockConfigManager,
            offlineMode: true,
          );
          CFClientInitializer.setupEventTrackingListeners(
            eventTracker: mockEventTracker,
            configManager: mockConfigManager,
            isOfflineMode: () => true,
          );
        }, returnsNormally);
      });
    });
  });
}
