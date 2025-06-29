// =============================================================================
// CONSOLIDATED CONFIG RECOVERY MANAGER TESTS
// =============================================================================
// This file consolidates tests from:
// - config_recovery_manager_test.dart (main tests)
// - config_recovery_manager_simple_test.dart (simple tests)
// - config_recovery_manager_integration_test.dart (integration tests)
// =============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_managers.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/recovery_utils.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/config_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/cache_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/circuit_breaker.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/sdk_settings.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/summary/summary_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:convert';
import '../../../helpers/test_storage_helper.dart';
@GenerateMocks([ConfigManager])
import 'config_recovery_manager_test.mocks.dart';

// Test ConfigManager for integration testing
class TestConfigManager extends ConfigManager {
  Map<String, dynamic> _flags = {};
  bool shouldThrowOnGetFlags = false;
  bool shouldThrowOnUpdate = false;
  void setFlags(Map<String, dynamic> flags) {
    _flags = flags;
  }

  @override
  Map<String, dynamic> getAllFlags() {
    if (shouldThrowOnGetFlags) {
      throw Exception('getAllFlags error');
    }
    return _flags;
  }

  @override
  Map<String, dynamic>? getFullFlagConfig(String key) {
    return _flags[key] as Map<String, dynamic>?;
  }

  @override
  String getString(String key, String defaultValue) {
    return _flags[key]?.toString() ?? defaultValue;
  }

  @override
  bool getBoolean(String key, bool defaultValue) {
    return _flags[key] as bool? ?? defaultValue;
  }

  @override
  num getNumber(String key, num defaultValue) {
    return _flags[key] as num? ?? defaultValue;
  }

  @override
  Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue) {
    return _flags[key] as Map<String, dynamic>? ?? defaultValue;
  }

  @override
  T getConfigValue<T>(String key, T defaultValue) {
    return _flags[key] as T? ?? defaultValue;
  }

  @override
  void addConfigListener<T>(String key, void Function(T) listener) {}
  @override
  void removeConfigListener<T>(String key, void Function(T) listener) {}
  @override
  void clearConfigListeners(String key) {}
  @override
  void shutdown() {}
  @override
  Future<bool> refreshConfigs() async {
    return true;
  }

  @override
  void dumpConfigMap() {}
  @override
  SdkSettings? getSdkSettings() {
    return null;
  }

  @override
  bool isSdkFunctionalityEnabled() {
    return true;
  }

  @override
  void updateConfigsFromClient(Map<String, dynamic> newConfigs) {
    _flags = newConfigs;
  }

  @override
  Future<void> waitForInitialLoad() async {
    // No-op for testing
  }
  @override
  void setupListeners({
    required void Function(CFConfig) onConfigChange,
    required SummaryManager summaryManager,
  }) {
    // No-op for testing
  }
  Future<void> updateConfigs(Map<String, dynamic> config) async {
    if (shouldThrowOnUpdate) {
      throw Exception('updateConfigs error');
    }
    _flags = config;
  }

  @override
  bool hasConfiguration() {
    return _flags.isNotEmpty;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockConfigManager mockConfigManager;
  late TestConfigManager testConfigManager;
  late CacheManager cacheManager;
  setUp(() async {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    // Setup test storage with secure storage
    TestStorageHelper.setupTestStorage();
    // Initialize services
    await PreferencesService.getInstance();
    mockConfigManager = MockConfigManager();
    testConfigManager = TestConfigManager();
    cacheManager = CacheManager.instance;
    // Clear cache before each test
    await cacheManager.clear();
    // Reset all circuit breakers to ensure clean test state
    CircuitBreaker.resetAll();
  });
  tearDown(() async {
    // Clean up after each test
    await cacheManager.clear();
    TestStorageHelper.clearTestStorage();
    PreferencesService.reset();
  });
  group('ConfigRecoveryManager Tests', () {
    group('recoverFromConfigUpdateFailure', () {
      test('should handle no last known good config available', () async {
        // Act - without any cached config, should fail
        final result =
            await ConfigRecoveryManager.recoverFromConfigUpdateFailure(
          mockConfigManager,
          failureReason: 'Test failure',
        );
        // Assert - should fail because no last known good config exists
        expect(result.isSuccess, false);
        expect(result.getErrorMessage(),
            contains('No last known good configuration available'));
      });
      test('should handle failed config parameter', () async {
        // Arrange
        final failedConfig = {
          'invalid': 'config',
          'missing': 'required_fields'
        };
        // Act
        final result =
            await ConfigRecoveryManager.recoverFromConfigUpdateFailure(
          mockConfigManager,
          failureReason: 'Validation failed',
          failedConfig: failedConfig,
        );
        // Assert - should still fail due to no last known good config
        expect(result.isSuccess, false);
        expect(result.getErrorMessage(),
            contains('No last known good configuration available'));
      });
      test('should handle null failure reason', () async {
        // Act
        final result =
            await ConfigRecoveryManager.recoverFromConfigUpdateFailure(
          mockConfigManager,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.getErrorMessage(),
            contains('No last known good configuration available'));
      });
    });
    group('safeConfigUpdate', () {
      test('should handle invalid configuration', () async {
        // Arrange
        final currentConfig = {
          'version': '1.0',
          'features': {'feature1': true}
        };
        final invalidConfig =
            <String, dynamic>{}; // Empty config should fail validation
        when(mockConfigManager.getAllFlags()).thenReturn(currentConfig);
        // Act
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          mockConfigManager,
          invalidConfig,
        );
        // Assert - should return error due to validation failure
        expect(result.isSuccess, false);
        expect(result.error, isNotNull);
      });
      test('should handle valid configuration structure', () async {
        // Arrange
        final currentConfig = {
          'version': '1.0',
          'features': {'oldFeature': true}
        };
        final newConfig = {
          'version': '2.0',
          'features': {'newFeature': true}
        };
        when(mockConfigManager.getAllFlags()).thenReturn(currentConfig);
        // Act
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          mockConfigManager,
          newConfig,
        );
        // Assert - should succeed with valid config
        expect(result.isSuccess, true);
        expect(result.data, true);
      });
      test('should handle config manager throwing exception', () async {
        // Arrange
        final newConfig = {
          'version': '2.0',
          'features': {'feature1': true}
        };
        when(mockConfigManager.getAllFlags())
            .thenThrow(Exception('ConfigManager error'));
        // Act
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          mockConfigManager,
          newConfig,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.getErrorMessage(),
            contains('Safe configuration update failed'));
      });
      test('should handle timeout parameter', () async {
        // Arrange
        final currentConfig = {
          'version': '1.0',
          'features': {'feature1': true}
        };
        final newConfig = {
          'version': '2.0',
          'features': {'feature2': true}
        };
        when(mockConfigManager.getAllFlags()).thenReturn(currentConfig);
        // Act - test with normal timeout (avoid actual timeout in tests)
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          mockConfigManager,
          newConfig,
          validationTimeout: const Duration(seconds: 10),
        );
        // Assert - should succeed with normal timeout
        expect(result.isSuccess, true);
        expect(result.data, true);
      });
    });
    group('recoverFromConfigCorruption', () {
      test('should handle no backups available', () async {
        // Act - without any backups, should fail
        final result = await ConfigRecoveryManager.recoverFromConfigCorruption(
          mockConfigManager,
        );
        // Assert - should fail because no backups are available
        expect(result.isSuccess, false);
        expect(result.getErrorMessage(),
            contains('No configuration backups available'));
      });
    });
    group('performConfigHealthCheck', () {
      test('should return invalid for invalid current config', () async {
        // Arrange
        final invalidConfig = <String, dynamic>{}; // Empty config - invalid
        when(mockConfigManager.getAllFlags()).thenReturn(invalidConfig);
        // Act
        final result = await ConfigRecoveryManager.performConfigHealthCheck(
          mockConfigManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, equals(ConfigHealthStatus.invalid));
      });
      test('should handle valid current config', () async {
        // Arrange
        final validConfig = {
          'version': '1.0',
          'features': {'feature1': true}
        };
        when(mockConfigManager.getAllFlags()).thenReturn(validConfig);
        // Act
        final result = await ConfigRecoveryManager.performConfigHealthCheck(
          mockConfigManager,
        );
        // Assert - will return noBackups since no backups exist in cache
        expect(result.isSuccess, true);
        expect(result.data,
            isIn([ConfigHealthStatus.noBackups, ConfigHealthStatus.healthy]));
      });
      test('should handle config manager exception', () async {
        // Arrange
        when(mockConfigManager.getAllFlags())
            .thenThrow(Exception('Config access error'));
        // Act
        final result = await ConfigRecoveryManager.performConfigHealthCheck(
          mockConfigManager,
        );
        // Assert - returns error when config manager throws exception
        expect(result.isSuccess, false);
        expect(result.error, isNotNull);
      });
    });
    group('cleanupOldBackups', () {
      test('should handle empty backup list', () async {
        // Act - with no backups, should return 0 removed
        final result = await ConfigRecoveryManager.cleanupOldBackups();
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, equals(0)); // No backups removed
      });
      test('should handle custom parameters', () async {
        // Act
        final result = await ConfigRecoveryManager.cleanupOldBackups(
          maxBackups: 5,
          maxAge: const Duration(days: 7),
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, isA<int>());
      });
    });
  });
  group('ConfigValidationResult Tests', () {
    test('should create valid result', () {
      final result = ConfigValidationResult(
        isValid: true,
        errors: [],
      );
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });
    test('should create invalid result with errors', () {
      final result = ConfigValidationResult(
        isValid: false,
        errors: ['Missing version', 'Invalid features'],
      );
      expect(result.isValid, false);
      expect(result.errors.length, 2);
      expect(result.errors, contains('Missing version'));
      expect(result.errors, contains('Invalid features'));
    });
    test('should handle empty errors list for valid result', () {
      final result = ConfigValidationResult(
        isValid: true,
        errors: [],
      );
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });
    test('should handle multiple validation errors', () {
      final errors = [
        'Missing version field',
        'Invalid features structure',
        'Missing required configuration keys',
        'JSON serialization failed'
      ];
      final result = ConfigValidationResult(
        isValid: false,
        errors: errors,
      );
      expect(result.isValid, false);
      expect(result.errors.length, 4);
      for (final error in errors) {
        expect(result.errors, contains(error));
      }
    });
  });
  group('ConfigHealthStatus Tests', () {
    test('should have all expected values', () {
      expect(ConfigHealthStatus.values.length, 5);
      expect(ConfigHealthStatus.values, contains(ConfigHealthStatus.healthy));
      expect(ConfigHealthStatus.values, contains(ConfigHealthStatus.invalid));
      expect(ConfigHealthStatus.values, contains(ConfigHealthStatus.stale));
      expect(ConfigHealthStatus.values, contains(ConfigHealthStatus.noBackups));
      expect(ConfigHealthStatus.values, contains(ConfigHealthStatus.invalid));
    });
    test('should convert to string correctly', () {
      expect(
          ConfigHealthStatus.healthy.toString(), 'ConfigHealthStatus.healthy');
      expect(
          ConfigHealthStatus.invalid.toString(), 'ConfigHealthStatus.invalid');
      expect(ConfigHealthStatus.stale.toString(), 'ConfigHealthStatus.stale');
      expect(ConfigHealthStatus.noBackups.toString(),
          'ConfigHealthStatus.noBackups');
      expect(
          ConfigHealthStatus.invalid.toString(), 'ConfigHealthStatus.invalid');
    });
    test('should be comparable', () {
      expect(ConfigHealthStatus.healthy == ConfigHealthStatus.healthy, true);
      expect(ConfigHealthStatus.healthy == ConfigHealthStatus.invalid, false);
      expect(ConfigHealthStatus.healthy != ConfigHealthStatus.stale, true);
    });
    test('should support switch statements', () {
      String getStatusDescription(ConfigHealthStatus status) {
        switch (status) {
          case ConfigHealthStatus.healthy:
            return 'Configuration is healthy';
          case ConfigHealthStatus.invalid:
            return 'Configuration is invalid';
          case ConfigHealthStatus.stale:
            return 'Configuration is stale';
          case ConfigHealthStatus.noBackups:
            return 'No backups available';
        }
      }

      expect(getStatusDescription(ConfigHealthStatus.healthy),
          'Configuration is healthy');
      expect(getStatusDescription(ConfigHealthStatus.invalid),
          'Configuration is invalid');
      expect(getStatusDescription(ConfigHealthStatus.stale),
          'Configuration is stale');
      expect(getStatusDescription(ConfigHealthStatus.noBackups),
          'No backups available');
    });
  });
  group('Exception Tests', () {
    test('ConfigRecoveryException should format message correctly', () {
      final exception = ConfigRecoveryException('Test recovery error');
      expect(
          exception.toString(), 'ConfigRecoveryException: Test recovery error');
      expect(exception.message, 'Test recovery error');
    });
    test('ConfigValidationException should format message correctly', () {
      final exception = ConfigValidationException('Test validation error');
      expect(exception.toString(),
          'ConfigValidationException: Test validation error');
      expect(exception.message, 'Test validation error');
    });
    test('ConfigApplicationException should format message correctly', () {
      final exception = ConfigApplicationException('Test application error');
      expect(exception.toString(),
          'ConfigApplicationException: Test application error');
      expect(exception.message, 'Test application error');
    });
    test('should handle empty error messages', () {
      final exception = ConfigRecoveryException('');
      expect(exception.toString(), 'ConfigRecoveryException: ');
      expect(exception.message, '');
    });
    test('should handle special characters in error messages', () {
      const specialMessage = 'Error with "quotes" and \n newlines & symbols!';
      final exception = ConfigValidationException(specialMessage);
      expect(
          exception.toString(), 'ConfigValidationException: $specialMessage');
      expect(exception.message, specialMessage);
    });
    test('exceptions should be throwable and catchable', () {
      expect(() => throw ConfigRecoveryException('test'),
          throwsA(isA<ConfigRecoveryException>()));
      expect(() => throw ConfigValidationException('test'),
          throwsA(isA<ConfigValidationException>()));
      expect(() => throw ConfigApplicationException('test'),
          throwsA(isA<ConfigApplicationException>()));
      // Test catching
      try {
        throw ConfigRecoveryException('test error');
      } catch (e) {
        expect(e, isA<ConfigRecoveryException>());
        expect((e as ConfigRecoveryException).message, 'test error');
      }
    });
  });
  group('Integration Tests', () {
    test('should handle complex config validation scenarios', () async {
      // Arrange - complex config with nested structures
      final complexConfig = {
        'version': '2.0',
        'features': {
          'feature1': {
            'enabled': true,
            'config': {'param1': 'value1', 'param2': 42}
          },
          'feature2': {
            'enabled': false,
            'config': {
              'param3': ['item1', 'item2']
            }
          }
        },
        'metadata': {
          'lastUpdated': DateTime.now().toIso8601String(),
          'environment': 'test'
        }
      };
      when(mockConfigManager.getAllFlags()).thenReturn(complexConfig);
      // Act
      final result = await ConfigRecoveryManager.safeConfigUpdate(
        mockConfigManager,
        complexConfig,
      );
      // Assert
      expect(result.isSuccess, true);
    });
    test('should handle concurrent operations gracefully', () async {
      // Arrange
      final config = {
        'version': '1.0',
        'features': {'feature1': true}
      };
      when(mockConfigManager.getAllFlags()).thenReturn(config);
      // Act - simulate concurrent operations
      final futures = List.generate(
          5,
          (_) => ConfigRecoveryManager.performConfigHealthCheck(
              mockConfigManager));
      final results = await Future.wait(futures);
      // Assert - all should complete successfully
      for (final result in results) {
        expect(result.isSuccess, true);
        expect(result.data, isA<ConfigHealthStatus>());
      }
    });
    test('should handle edge case configurations', () async {
      // Test various edge cases
      final edgeCases = [
        <String, dynamic>{}, // Empty config
        <String, dynamic>{'version': null}, // Null values
        <String, dynamic>{'version': '1.0'}, // Missing features
        <String, dynamic>{'features': <String, dynamic>{}}, // Missing version
        <String, dynamic>{'version': '1.0', 'features': null}, // Null features
      ];
      for (final config in edgeCases) {
        when(mockConfigManager.getAllFlags()).thenReturn(config);
        final healthResult =
            await ConfigRecoveryManager.performConfigHealthCheck(
          mockConfigManager,
        );
        // Should complete without throwing exceptions
        expect(healthResult.isSuccess, true);
        // Invalid configs should be marked as invalid
        if (config.isEmpty ||
            !config.containsKey('version') ||
            !config.containsKey('features')) {
          expect(healthResult.data, equals(ConfigHealthStatus.invalid));
        }
      }
    });
  });
  // =============================================================================
  // ENHANCED INTEGRATION TESTS (from config_recovery_manager_integration_test.dart)
  // =============================================================================
  group('Enhanced Integration Tests', () {
    group('recoverFromConfigUpdateFailure Integration', () {
      test('should successfully rollback to last known good config', () async {
        // Arrange
        final lastGoodConfig = {
          'version': '1.0',
          'features': {'feature1': true, 'feature2': false}
        };
        // Store last known good config in cache with proper format
        await cacheManager.put(
          'cf_last_good_config',
          jsonEncode({
            'config': lastGoodConfig,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          }),
        );
        // Wait for cache operation to complete
        await Future.delayed(const Duration(milliseconds: 50));
        // Act
        final result =
            await ConfigRecoveryManager.recoverFromConfigUpdateFailure(
          testConfigManager,
          failureReason: 'Test failure',
          failedConfig: {'bad': 'config'},
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, lastGoodConfig);
      });
      test('should validate rollback config before applying', () async {
        // Arrange - create a completely invalid config (empty) that will definitely fail validation
        final invalidConfig = <String, dynamic>{};
        await cacheManager.put(
          'cf_last_good_config',
          jsonEncode({
            'config': invalidConfig,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          }),
        );
        // Wait for cache operation to complete
        await Future.delayed(const Duration(milliseconds: 50));
        // Act
        final result =
            await ConfigRecoveryManager.recoverFromConfigUpdateFailure(
          testConfigManager,
          failureReason: 'Test failure',
        );
        // Assert - should fail due to invalid config validation
        expect(result.isSuccess, false);
        expect(
            result.getErrorMessage(),
            anyOf([
              contains('validation failed'),
              contains('No last known good configuration available'),
              contains('Config validation failed'),
              contains('Last known good config failed validation')
            ]));
      });
      test('should handle corrupted cache data', () async {
        // Arrange - Store invalid JSON directly in preferences
        final prefsService = await PreferencesService.getInstance();
        await prefsService.setString(
            'cf_cache_cf_last_good_config', 'invalid json');
        // Wait for operation to complete
        await Future.delayed(const Duration(milliseconds: 50));
        // Act
        final result =
            await ConfigRecoveryManager.recoverFromConfigUpdateFailure(
          testConfigManager,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.getErrorMessage(),
            contains('No last known good configuration available'));
      });
    });
    group('safeConfigUpdate Integration', () {
      test('should successfully apply valid configuration', () async {
        // Arrange
        final currentConfig = {
          'version': '1.0',
          'features': {'oldFeature': true}
        };
        final newConfig = {
          'version': '2.0',
          'features': {'newFeature': true}
        };
        testConfigManager.setFlags(currentConfig);
        // Act
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          testConfigManager,
          newConfig,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, true);
        // Verify new config was stored as last known good
        final storedConfig =
            await cacheManager.get<String>('cf_last_good_config');
        expect(storedConfig, isNotNull);
        final decoded = jsonDecode(storedConfig!);
        expect(decoded['config'], newConfig);
      });
      test('should handle very large configurations', () async {
        // Arrange
        final currentConfig = {
          'version': '1.0',
          'features': {'feature1': true}
        };
        // Create a large config
        final largeConfig = {
          'version': '2.0',
          'features': Map.fromEntries(
              List.generate(1000, (i) => MapEntry('feature$i', i % 2 == 0)))
        };
        testConfigManager.setFlags(currentConfig);
        // Act
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          testConfigManager,
          largeConfig,
        );
        // Assert
        expect(result.isSuccess, true);
      });
    });
    group('recoverFromConfigCorruption Integration', () {
      test('should recover using most recent valid backup', () async {
        // Arrange
        final backups = [
          {
            'config': {'version': '1.0', 'features': {}},
            'timestamp': DateTime.now()
                .subtract(const Duration(hours: 2))
                .millisecondsSinceEpoch,
          },
          {
            'config': {
              'version': '2.0',
              'features': {'feature1': true}
            },
            'timestamp': DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          },
        ];
        await cacheManager.put('cf_config_backup', jsonEncode(backups));
        // Act
        final result = await ConfigRecoveryManager.recoverFromConfigCorruption(
          testConfigManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, backups[1]['config']); // Most recent valid backup
      });
      test('should skip invalid backups', () async {
        // Arrange
        final backups = [
          {
            'config': {'invalid': 'missing features'},
            'timestamp': DateTime.now()
                .subtract(const Duration(hours: 3))
                .millisecondsSinceEpoch,
          },
          {
            'config': {'version': '1.0', 'features': {}},
            'timestamp': DateTime.now()
                .subtract(const Duration(hours: 2))
                .millisecondsSinceEpoch,
          },
          {
            'config': {'also': 'invalid'},
            'timestamp': DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          },
        ];
        await cacheManager.put('cf_config_backup', jsonEncode(backups));
        // Act
        final result = await ConfigRecoveryManager.recoverFromConfigCorruption(
          testConfigManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, backups[1]['config']); // The only valid backup
      });
      test('should handle all backups being invalid', () async {
        // Arrange
        final backups = [
          {
            'config': {'missing': 'version'},
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'config': {'missing': 'features'},
            'timestamp': DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          },
        ];
        await cacheManager.put('cf_config_backup', jsonEncode(backups));
        // Act
        final result = await ConfigRecoveryManager.recoverFromConfigCorruption(
          testConfigManager,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.getErrorMessage(),
            contains('No valid configuration backup found'));
      });
      test('should handle malformed backup data', () async {
        // Arrange
        await cacheManager.put('cf_config_backup', 'not valid json');
        // Act
        final result = await ConfigRecoveryManager.recoverFromConfigCorruption(
          testConfigManager,
        );
        // Assert
        expect(result.isSuccess, false);
      });
    });
    group('performConfigHealthCheck Integration', () {
      test('should return healthy for valid current config', () async {
        // Arrange
        final currentConfig = {
          'version': '1.0',
          'features': {'feature1': true}
        };
        final lastUpdateTime =
            DateTime.now().subtract(const Duration(hours: 1));
        testConfigManager.setFlags(currentConfig);
        await cacheManager.put(
          'cf_last_good_config',
          jsonEncode({
            'config': currentConfig,
            'timestamp': lastUpdateTime.millisecondsSinceEpoch
          }),
        );
        await cacheManager.put(
          'cf_config_backup',
          jsonEncode([
            {
              'config': currentConfig,
              'timestamp': DateTime.now().millisecondsSinceEpoch
            }
          ]),
        );
        // Act
        final result = await ConfigRecoveryManager.performConfigHealthCheck(
          testConfigManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, ConfigHealthStatus.healthy);
      });
      test('should return stale for old configuration', () async {
        // Arrange
        final currentConfig = {
          'version': '1.0',
          'features': {'feature1': true}
        };
        final lastUpdateTime = DateTime.now().subtract(const Duration(days: 2));
        testConfigManager.setFlags(currentConfig);
        await cacheManager.put(
          'cf_last_good_config',
          jsonEncode({
            'config': currentConfig,
            'timestamp': lastUpdateTime.millisecondsSinceEpoch
          }),
        );
        // Act
        final result = await ConfigRecoveryManager.performConfigHealthCheck(
          testConfigManager,
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, ConfigHealthStatus.stale);
      });
    });
    group('cleanupOldBackups Integration', () {
      test('should remove backups older than max age', () async {
        // Arrange
        final now = DateTime.now();
        final backups = [
          {
            'config': {'version': '1.0', 'features': {}},
            'timestamp':
                now.subtract(const Duration(days: 40)).millisecondsSinceEpoch,
          },
          {
            'config': {'version': '2.0', 'features': {}},
            'timestamp':
                now.subtract(const Duration(days: 20)).millisecondsSinceEpoch,
          },
          {
            'config': {'version': '3.0', 'features': {}},
            'timestamp':
                now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
          },
        ];
        await cacheManager.put('cf_config_backup', jsonEncode(backups));
        // Act
        final result = await ConfigRecoveryManager.cleanupOldBackups(
          maxAge: const Duration(days: 30),
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 1); // One backup removed
        // Verify that only recent backups were kept
        final remainingBackups =
            await cacheManager.get<String>('cf_config_backup');
        final decoded = jsonDecode(remainingBackups!) as List;
        expect(decoded.length, 2);
      });
      test('should limit number of backups to maxBackups', () async {
        // Arrange
        final now = DateTime.now();
        final backups = List.generate(
            15,
            (i) => {
                  'config': {'version': '$i.0', 'features': {}},
                  'timestamp':
                      now.subtract(Duration(days: i)).millisecondsSinceEpoch,
                });
        await cacheManager.put('cf_config_backup', jsonEncode(backups));
        // Act
        final result = await ConfigRecoveryManager.cleanupOldBackups(
          maxBackups: 10,
          maxAge: const Duration(days: 100), // All within age limit
        );
        // Assert
        expect(result.isSuccess, true);
        expect(result.data, 5); // 15 - 10 = 5 removed
        // Verify that only most recent backups were kept
        final remainingBackups =
            await cacheManager.get<String>('cf_config_backup');
        final decoded = jsonDecode(remainingBackups!) as List;
        expect(decoded.length, 10);
      });
    });
    group('Complex Integration Scenarios', () {
      test('should handle concurrent recovery attempts', () async {
        // Arrange
        final lastGoodConfig = {
          'version': '1.0',
          'features': {'feature1': true}
        };
        await cacheManager.put(
          'cf_last_good_config',
          jsonEncode({
            'config': lastGoodConfig,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          }),
        );
        // Wait for cache operation to complete
        await Future.delayed(const Duration(milliseconds: 50));
        // Act - Launch multiple recovery attempts
        final results = await Future.wait([
          ConfigRecoveryManager.recoverFromConfigUpdateFailure(
            testConfigManager,
            failureReason: 'Concurrent test 1',
          ),
          ConfigRecoveryManager.recoverFromConfigUpdateFailure(
            testConfigManager,
            failureReason: 'Concurrent test 2',
          ),
        ]);
        // Assert
        expect(results.every((r) => r.isSuccess), true);
        expect(results.every((r) => r.data != null), true);
      });
      test('should handle concurrent health checks', () async {
        // Arrange
        final config = {
          'version': '1.0',
          'features': {'feature1': true}
        };
        testConfigManager.setFlags(config);
        await cacheManager.put(
          'cf_last_good_config',
          jsonEncode({
            'config': config,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          }),
        );
        await cacheManager.put(
          'cf_config_backup',
          jsonEncode([
            {'config': config}
          ]),
        );
        // Act
        final results = await Future.wait([
          ConfigRecoveryManager.performConfigHealthCheck(testConfigManager),
          ConfigRecoveryManager.performConfigHealthCheck(testConfigManager),
          ConfigRecoveryManager.performConfigHealthCheck(testConfigManager),
        ]);
        // Assert
        expect(results.every((r) => r.isSuccess), true);
        expect(
            results.every((r) => r.data == ConfigHealthStatus.healthy), true);
      });
      test('should validate deeply nested configurations', () async {
        // Arrange
        final complexConfig = {
          'version': '1.0',
          'features': {
            'nested': {
              'deeply': {
                'value': true,
                'another': {
                  'level': {'test': 'value'}
                }
              }
            }
          }
        };
        testConfigManager.setFlags({});
        // Act
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          testConfigManager,
          complexConfig,
        );
        // Assert
        expect(result.isSuccess, true);
      });
      test('should handle rollback after failed update', () async {
        // Arrange
        final currentConfig = {
          'version': '1.0',
          'features': {'feature1': true}
        };
        final newConfig = {
          'version': '2.0',
          'features': {'feature2': false}
        };
        testConfigManager.setFlags(currentConfig);
        // Store a good config for rollback
        await cacheManager.put(
          'cf_last_good_config',
          jsonEncode({
            'config': currentConfig,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          }),
        );
        // Make the update fail
        testConfigManager.shouldThrowOnUpdate = true;
        // Act
        final result = await ConfigRecoveryManager.safeConfigUpdate(
          testConfigManager,
          newConfig,
        );
        // Assert
        expect(result.isSuccess, false);
        expect(result.getErrorMessage(),
            contains('Safe configuration update failed'));
      });
    });
  });
}
