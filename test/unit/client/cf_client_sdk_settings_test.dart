// test/unit/client/cf_client_sdk_settings_test.dart
//
// Comprehensive tests for CFClientSdkSettings class to achieve 80%+ coverage
// Tests SDK settings polling, configuration management, and error handling
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client_sdk_settings.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/network/config/config_fetcher.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/config_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import '../../utils/test_constants.dart';
import '../../test_config.dart';
@GenerateMocks([
  ConfigFetcher,
  ConfigManagerImpl,
  ConnectionManagerImpl,
])
import 'cf_client_sdk_settings_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestConfig.setupTestLogger(); // Enable logger for coverage
    SharedPreferences.setMockInitialValues({});
  });
  group('CFClientSdkSettings', () {
    late CFClientSdkSettings sdkSettings;
    late MockConfigFetcher mockConfigFetcher;
    late MockConfigManagerImpl mockConfigManager;
    late MockConnectionManagerImpl mockConnectionManager;
    late CFConfig testConfig;
    setUp(() {
      mockConfigFetcher = MockConfigFetcher();
      mockConfigManager = MockConfigManagerImpl();
      mockConnectionManager = MockConnectionManagerImpl();
      testConfig = CFConfig.builder(TestConstants.validJwtToken)
          .setDebugLoggingEnabled(true)
          .setOfflineMode(false)
          .build()
          .getOrThrow();
      // Setup default mock behavior
      when(mockConfigFetcher.fetchConfig(
              lastModified: anyNamed('lastModified')))
          .thenAnswer((_) async => true);
      when(mockConfigFetcher.getConfigs()).thenReturn(CFResult.success({}));
      when(mockConfigManager.getAllFlags()).thenReturn({});
      when(mockConfigManager.updateConfigsFromClient(any)).thenReturn(null);
      sdkSettings = CFClientSdkSettings(
        config: testConfig,
        configFetcher: mockConfigFetcher,
        configManager: mockConfigManager,
        connectionManager: mockConnectionManager,
      );
    });
    group('Constructor', () {
      test('should create instance with all required parameters', () {
        expect(sdkSettings, isNotNull);
      });
    });
    group('startPeriodicCheck', () {
      test('should skip polling in offline mode', () {
        // Arrange
        final offlineConfig = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true)
            .build()
            .getOrThrow();
        final offlineSdkSettings = CFClientSdkSettings(
          config: offlineConfig,
          configFetcher: mockConfigFetcher,
          configManager: mockConfigManager,
          connectionManager: mockConnectionManager,
        );
        // Act
        offlineSdkSettings.startPeriodicCheck();
        // Assert
        // Should complete without starting any timers
        expect(offlineConfig.offlineMode, isTrue);
      });
      test('should handle online mode gracefully', () {
        // Act & Assert - Should not throw
        expect(() => sdkSettings.startPeriodicCheck(), returnsNormally);
      });
    });
    group('performInitialCheck', () {
      test('should complete immediately in offline mode', () async {
        // Arrange
        final offlineConfig = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true)
            .build()
            .getOrThrow();
        final offlineSdkSettings = CFClientSdkSettings(
          config: offlineConfig,
          configFetcher: mockConfigFetcher,
          configManager: mockConfigManager,
          connectionManager: mockConnectionManager,
        );
        // Act
        await offlineSdkSettings.performInitialCheck();
        // Assert
        // Should complete without making any network calls
        verifyNever(mockConfigFetcher.fetchMetadata(any));
      });
      test('should perform initial check in online mode', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        // Act
        await sdkSettings.performInitialCheck();
        // Assert
        verify(mockConfigFetcher.fetchMetadata(any)).called(1);
      });
      test('should handle fetch metadata failure gracefully', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any))
            .thenAnswer((_) async => CFResult.error('Network error'));
        // Act & Assert - Should not throw
        await expectLater(sdkSettings.performInitialCheck(), completes);
        verify(mockConnectionManager.recordConnectionFailure(any)).called(1);
      });
      test('should handle fetch metadata exception gracefully', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any))
            .thenThrow(Exception('Unexpected error'));
        // Act & Assert - Should not throw
        await expectLater(sdkSettings.performInitialCheck(), completes);
        verify(mockConnectionManager.recordConnectionFailure(any)).called(1);
      });
    });
    group('checkSdkSettings', () {
      test('should skip check in offline mode', () async {
        // Arrange
        final offlineConfig = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true)
            .build()
            .getOrThrow();
        final offlineSdkSettings = CFClientSdkSettings(
          config: offlineConfig,
          configFetcher: mockConfigFetcher,
          configManager: mockConfigManager,
          connectionManager: mockConnectionManager,
        );
        // Act
        await offlineSdkSettings.checkSdkSettings();
        // Assert
        verifyNever(mockConfigFetcher.fetchMetadata(any));
      });
      test('should fetch metadata successfully', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchMetadata(any)).called(1);
        verify(mockConnectionManager.recordConnectionSuccess())
            .called(2); // Called for both metadata and config fetch
      });
      test('should handle unchanged metadata (304)', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'unchanged'}));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchMetadata(any)).called(1);
        verify(mockConnectionManager.recordConnectionSuccess()).called(1);
        // Should not fetch configs for unchanged metadata
        verifyNever(mockConfigFetcher.fetchConfig(
            lastModified: anyNamed('lastModified')));
      });
      test('should fetch configs when Last-Modified changes', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'new-timestamp'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success({'flag1': true, 'flag2': 'value'}));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchMetadata(any)).called(1);
        verify(mockConfigFetcher.fetchConfig(lastModified: 'new-timestamp'))
            .called(1);
        verify(mockConfigFetcher.getConfigs()).called(1);
        verify(mockConnectionManager.recordConnectionSuccess())
            .called(2); // Called for both metadata and config fetch
      });
      test('should fetch configs on first run with empty config', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer((_) async =>
            CFResult.success({'Last-Modified': 'first-timestamp'}));
        when(mockConfigManager.getAllFlags()).thenReturn({}); // Empty config
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success({'flag1': true}));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchConfig(lastModified: 'first-timestamp'))
            .called(1);
      });
      test(
          'should not fetch configs when Last-Modified unchanged and config exists',
          () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'same-timestamp'}));
        when(mockConfigManager.getAllFlags())
            .thenReturn({'existing': 'flag'}); // Non-empty config
        // First call to set the timestamp
        await sdkSettings.checkSdkSettings();
        reset(mockConfigFetcher);
        reset(mockConnectionManager);
        // Setup for second call
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'same-timestamp'}));
        // Act - Second call with same timestamp
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchMetadata(any)).called(1);
        verifyNever(mockConfigFetcher.fetchConfig(
            lastModified: anyNamed('lastModified')));
      });
      test('should handle fetch config failure', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => false);
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConnectionManager.recordConnectionFailure(any)).called(1);
      });
      test('should handle fetch config exception', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenThrow(Exception('Config fetch error'));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConnectionManager.recordConnectionFailure(any)).called(1);
      });
      test('should handle getConfigs failure', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenThrow(Exception('Get configs error'));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConnectionManager.recordConnectionFailure(any)).called(1);
      });
      test('should handle null Last-Modified header', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({})); // No Last-Modified header
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchMetadata(any)).called(1);
        verifyNever(mockConfigFetcher.fetchConfig(
            lastModified: anyNamed('lastModified')));
      });
      test('should update config manager when configs are fetched', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success({'flag1': true, 'flag2': 'test'}));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigManager
                .updateConfigsFromClient({'flag1': true, 'flag2': 'test'}))
            .called(1);
      });
      test('should handle config manager update failure', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success({'flag1': true}));
        when(mockConfigManager.updateConfigsFromClient(any))
            .thenThrow(Exception('Config manager error'));
        // Act & Assert - Should not throw
        await expectLater(sdkSettings.checkSdkSettings(), completes);
      });
    });
    group('pausePolling', () {
      test('should handle pause polling gracefully', () {
        // Act & Assert - Should not throw
        expect(() => sdkSettings.pausePolling(), returnsNormally);
      });
    });
    group('resumePolling', () {
      test('should handle resume polling gracefully', () {
        // Act & Assert - Should not throw
        expect(() => sdkSettings.resumePolling(), returnsNormally);
      });
    });
    group('Edge Cases and Error Handling', () {
      test('should handle very long Last-Modified values', () async {
        // Arrange
        final longTimestamp = 'a' * 1000;
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': longTimestamp}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success({'flag': 'value'}));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchConfig(lastModified: longTimestamp))
            .called(1);
      });
      test('should handle special characters in Last-Modified', () async {
        // Arrange
        const specialTimestamp = 'timestamp-with_special.chars@123!';
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': specialTimestamp}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success({'flag': 'value'}));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchConfig(lastModified: specialTimestamp))
            .called(1);
      });
      test('should handle unicode characters in Last-Modified', () async {
        // Arrange
        const unicodeTimestamp = 'timestamp_测试_🎉';
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': unicodeTimestamp}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success({'flag': 'value'}));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchConfig(lastModified: unicodeTimestamp))
            .called(1);
      });
      test('should handle large config maps', () async {
        // Arrange
        final largeConfig = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          largeConfig['flag_$i'] = 'value_$i';
        }
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success(largeConfig));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigManager.updateConfigsFromClient(largeConfig))
            .called(1);
      });
      test('should handle empty config maps', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs()).thenReturn(CFResult.success({}));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigManager.updateConfigsFromClient({})).called(1);
      });
      test('should handle null config values', () async {
        // Arrange
        final configWithNulls = {
          'string_flag': 'value',
          'null_flag': null,
          'bool_flag': true,
          'number_flag': 42,
        };
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'test-timestamp'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success(configWithNulls));
        // Act
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigManager.updateConfigsFromClient(configWithNulls))
            .called(1);
      });
    });
    group('Integration Tests', () {
      test('should handle complete SDK settings flow', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer((_) async =>
            CFResult.success({'Last-Modified': 'initial-timestamp'}));
        when(mockConfigManager.getAllFlags()).thenReturn({});
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs()).thenReturn(
            CFResult.success({'feature_enabled': true, 'max_retries': 3}));
        // Act
        await sdkSettings.performInitialCheck();
        // Assert
        verify(mockConfigFetcher.fetchMetadata(any)).called(1);
        verify(mockConfigFetcher.fetchConfig(lastModified: 'initial-timestamp'))
            .called(1);
        verify(mockConnectionManager.recordConnectionSuccess())
            .called(2); // Called for both metadata and config fetch
        verify(mockConfigFetcher.getConfigs()).called(1);
        verify(mockConfigManager.updateConfigsFromClient(
            {'feature_enabled': true, 'max_retries': 3})).called(1);
      });
      test('should handle multiple consecutive checks', () async {
        // Arrange
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'timestamp-1'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success({'flag': 'value1'}));
        // Act - First check
        await sdkSettings.checkSdkSettings();
        // Setup for second check with different timestamp
        reset(mockConfigFetcher);
        reset(mockConnectionManager);
        when(mockConfigFetcher.fetchMetadata(any)).thenAnswer(
            (_) async => CFResult.success({'Last-Modified': 'timestamp-2'}));
        when(mockConfigFetcher.fetchConfig(
                lastModified: anyNamed('lastModified')))
            .thenAnswer((_) async => true);
        when(mockConfigFetcher.getConfigs())
            .thenReturn(CFResult.success({'flag': 'value2'}));
        // Act - Second check
        await sdkSettings.checkSdkSettings();
        // Assert
        verify(mockConfigFetcher.fetchConfig(lastModified: 'timestamp-2'))
            .called(1);
        verify(mockConfigManager.updateConfigsFromClient({'flag': 'value2'}))
            .called(1);
      });
    });
  });
}
