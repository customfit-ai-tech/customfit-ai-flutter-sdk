// test/unit/config/cf_config_inheritance_test.dart
//
// Configuration inheritance tests for CFConfig.
// Tests base configs with overrides, environment variables, runtime merging, and partial updates.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import '../../shared/test_shared.dart';
import '../../utils/test_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CFConfig Inheritance Tests', () {
    group('Base Configuration with Overrides', () {
      test('should_create_base_configuration_template', () {
        // Arrange - Create a base config factory
        CFConfig createBaseConfig() {
          return CFConfig.builder(TestConstants.validJwtToken)
              .setEnvironment(CFEnvironment.production)
              .setDebugLoggingEnabled(false)
              .setEventsFlushIntervalMs(30000)
              .setMaxRetryAttempts(3)
              .setNetworkConnectionTimeoutMs(10000)
              .build().getOrThrow();
        }

        // Act - Create variations from base
        final defaultConfig = createBaseConfig();
        final stagingConfig = CFConfig.builder(TestConstants.validJwtToken)
            .setEnvironment(CFEnvironment.staging)
            .setDebugLoggingEnabled(true) // Override for dev
            .setEventsFlushIntervalMs(5000) // Faster for dev
            .setMaxRetryAttempts(1) // Fail fast in dev
            .setNetworkConnectionTimeoutMs(5000)
            .build().getOrThrow();
        // Assert
        expect(defaultConfig.debugLoggingEnabled, isFalse);
        expect(stagingConfig.debugLoggingEnabled, isTrue);
        expect(defaultConfig.eventsFlushIntervalMs, equals(30000));
        expect(stagingConfig.eventsFlushIntervalMs, equals(5000));
      });
      test('should_support_configuration_profiles', () {
        // Arrange - Define configuration profiles
        final profiles = {
          'production': {
            'debugLogging': false,
            'offlineMode': false,
            'retryAttempts': 5,
            'flushInterval': 60000,
          },
          'staging': {
            'debugLogging': true,
            'offlineMode': false,
            'retryAttempts': 2,
            'flushInterval': 10000,
          },
          'testing': {
            'debugLogging': true,
            'offlineMode': true,
            'retryAttempts': 1,
            'flushInterval': 1000,
          },
        };
        // Act - Create configs from profiles
        final configs = <String, CFConfig>{};
        profiles.forEach((profileName, settings) {
          configs[profileName] = CFConfig.builder(TestConstants.validJwtToken)
              .setDebugLoggingEnabled(settings['debugLogging'] as bool)
              .setOfflineMode(settings['offlineMode'] as bool)
              .setMaxRetryAttempts(settings['retryAttempts'] as int)
              .setEventsFlushIntervalMs(settings['flushInterval'] as int)
              .build().getOrThrow();
        });
        // Assert
        expect(configs['production']!.debugLoggingEnabled, isFalse);
        expect(configs['staging']!.debugLoggingEnabled, isTrue);
        expect(configs['testing']!.offlineMode, isTrue);
        expect(configs['testing']!.eventsFlushIntervalMs, equals(1000));
      });
    });
    group('Environment Variable Precedence', () {
      test('should_simulate_environment_variable_overrides', () {
        // Arrange - Simulate environment variables
        final envVars = <String, String>{
          'CF_DEBUG_LOGGING': 'true',
          'CF_OFFLINE_MODE': 'false',
          'CF_EVENTS_FLUSH_INTERVAL': '5000',
          'CF_MAX_RETRY_ATTEMPTS': '10',
        };
        // Helper to get env var as typed value
        T? getEnvVar<T>(String key, T? defaultValue) {
          final value = envVars[key];
          if (value == null) return defaultValue;
          if (T == bool) {
            return (value.toLowerCase() == 'true') as T;
          } else if (T == int) {
            return int.tryParse(value) as T?;
          }
          return value as T;
        }

        // Act - Build config with env var overrides
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(
                getEnvVar<bool>('CF_DEBUG_LOGGING', false) ?? false)
            .setOfflineMode(getEnvVar<bool>('CF_OFFLINE_MODE', false) ?? false)
            .setEventsFlushIntervalMs(
                getEnvVar<int>('CF_EVENTS_FLUSH_INTERVAL', 30000) ?? 30000)
            .setMaxRetryAttempts(
                getEnvVar<int>('CF_MAX_RETRY_ATTEMPTS', 3) ?? 3)
            .build().getOrThrow();
        // Assert - Env vars should override defaults
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.offlineMode, isFalse);
        expect(config.eventsFlushIntervalMs, equals(5000));
        expect(config.maxRetryAttempts, equals(10));
      });
      test('should_handle_invalid_environment_variables_gracefully', () {
        // Arrange - Invalid env vars
        final envVars = <String, String>{
          'CF_EVENTS_FLUSH_INTERVAL': 'not-a-number',
          'CF_DEBUG_LOGGING': 'yes', // Not 'true' or 'false'
          'CF_MAX_RETRY_ATTEMPTS': '-5', // Negative
        };
        // Helper with validation
        T? getValidatedEnvVar<T>(
            String key, T defaultValue, bool Function(T) validator) {
          final strValue = envVars[key];
          if (strValue == null) return defaultValue;
          dynamic parsed;
          if (T == bool) {
            parsed = strValue.toLowerCase() == 'true';
          } else if (T == int) {
            parsed = int.tryParse(strValue);
          } else {
            parsed = strValue;
          }
          if (parsed == null || !validator(parsed as T)) {
            return defaultValue;
          }
          return parsed;
        }

        // Act - Build with validation
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setEventsFlushIntervalMs(getValidatedEnvVar<int>(
                    'CF_EVENTS_FLUSH_INTERVAL', 30000, (val) => val > 0) ??
                30000)
            .setDebugLoggingEnabled(getValidatedEnvVar<bool>('CF_DEBUG_LOGGING',
                    false, (val) => true // All bools are valid
                    ) ??
                false)
            .setMaxRetryAttempts(getValidatedEnvVar<int>(
                    'CF_MAX_RETRY_ATTEMPTS', 3, (val) => val > 0) ??
                3)
            .build().getOrThrow();
        // Assert - Should use defaults for invalid values
        expect(config.eventsFlushIntervalMs, equals(30000)); // Invalid string
        expect(config.debugLoggingEnabled, isFalse); // 'yes' -> false
        expect(config.maxRetryAttempts, equals(3)); // Negative rejected
      });
    });
    group('Runtime Configuration Merging', () {
      test('should_merge_configurations_with_precedence', () {
        // Arrange - Create configs to merge
        final defaultConfig = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(false)
            .setEventsFlushIntervalMs(30000)
            .setMaxRetryAttempts(3)
            .setOfflineMode(false)
            .build().getOrThrow();
        final overrideConfig = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(true) // Override
            .setEventsFlushIntervalMs(5000) // Override
            // maxRetryAttempts not set - should keep default
            .setOfflineMode(true) // Override
            .build().getOrThrow();
        // Act - Simulate merge (using copyWith pattern)
        final mergedConfig = defaultConfig.copyWith(
          debugLoggingEnabled: overrideConfig.debugLoggingEnabled,
          eventsFlushIntervalMs: overrideConfig.eventsFlushIntervalMs,
          offlineMode: overrideConfig.offlineMode,
          // Keep other values from default
        );
        // Assert
        expect(mergedConfig.debugLoggingEnabled, isTrue); // From override
        expect(
            mergedConfig.eventsFlushIntervalMs, equals(5000)); // From override
        expect(mergedConfig.maxRetryAttempts, equals(3)); // From default
        expect(mergedConfig.offlineMode, isTrue); // From override
      });
      test('should_support_deep_merge_for_complex_configurations', () {
        // Arrange - Configs with nested structures
        final baseMetadata = {'app': 'test', 'version': '1.0', 'env': 'prod'};
        final overrideMetadata = {'version': '2.0', 'feature': 'enabled'};
        final baseConfig = CFConfig.builder(TestConstants.validJwtToken)
            .setRemoteLogMetadata(Map.from(baseMetadata))
            .build().getOrThrow();
        // Act - Deep merge metadata
        final mergedMetadata = <String, dynamic>{};
        mergedMetadata.addAll(baseMetadata);
        mergedMetadata.addAll(overrideMetadata); // Override specific keys
        final mergedConfig = baseConfig.copyWith(
          remoteLogMetadata: mergedMetadata,
        );
        // Assert
        expect(mergedConfig.remoteLogMetadata!['app'], equals('test')); // Kept
        expect(mergedConfig.remoteLogMetadata!['version'],
            equals('2.0')); // Updated
        expect(mergedConfig.remoteLogMetadata!['env'], equals('prod')); // Kept
        expect(mergedConfig.remoteLogMetadata!['feature'],
            equals('enabled')); // Added
      });
    });
    group('Partial Configuration Updates', () {
      test('should_update_specific_configuration_sections', () {
        // Arrange - Start with a complete config
        final initialConfig = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(false)
            .setEventsFlushIntervalMs(30000)
            .setMaxRetryAttempts(3)
            .setNetworkConnectionTimeoutMs(10000)
            .build().getOrThrow();
        // Act - Update only network settings
        final networkUpdate = initialConfig.copyWith(
          networkConnectionTimeoutMs: 5000,
          networkReadTimeoutMs: 15000,
        );
        // Update only retry settings
        final retryUpdate = networkUpdate.copyWith(
          maxRetryAttempts: 5,
          retryInitialDelayMs: 2000,
          retryMaxDelayMs: 60000,
        );
        // Assert - Other settings remain unchanged
        expect(retryUpdate.debugLoggingEnabled,
            equals(initialConfig.debugLoggingEnabled));
        expect(retryUpdate.eventsFlushIntervalMs,
            equals(initialConfig.eventsFlushIntervalMs));
        // Network settings updated
        expect(retryUpdate.networkConnectionTimeoutMs, equals(5000));
        expect(retryUpdate.networkReadTimeoutMs, equals(15000));
        // Retry settings updated
        expect(retryUpdate.maxRetryAttempts, equals(5));
        expect(retryUpdate.retryInitialDelayMs, equals(2000));
      });
      test('should_support_configuration_patches', () {
        // Arrange - Define configuration patches
        final patches = [
          // Enable debug logging
          (CFConfig config) => config.copyWith(debugLoggingEnabled: true),
          // Optimize for mobile network
          (CFConfig config) => config.copyWith(
                networkConnectionTimeoutMs: 15000,
                maxRetryAttempts: 5,
                retryBackoffMultiplier: 1.5,
              ),
          // Enable caching
          (CFConfig config) => config.copyWith(
                localStorageEnabled: true,
                configCacheTtlSeconds: 7200,
                persistCacheAcrossRestarts: true,
              ),
        ];
        // Act - Apply patches sequentially
        var config = CFConfig.builder(TestConstants.validJwtToken).build().getOrThrow();
        for (final patch in patches) {
          config = patch(config);
        }
        // Assert - All patches applied
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.networkConnectionTimeoutMs, equals(15000));
        expect(config.localStorageEnabled, isTrue);
        expect(config.configCacheTtlSeconds, equals(7200));
      });
    });
    group('Configuration Versioning and Migration', () {
      test('should_handle_configuration_version_migration', () {
        // Arrange - Simulate old config format
        final oldConfigData = {
          'apiKey': TestConstants.validJwtToken, // Old name
          'environment': 'prod', // Short name
          'enableDebug': true, // Old name
          'flushInterval': 30, // Was in seconds, now ms
        };
        // Migration function
        CFConfig migrateFromV1(Map<String, dynamic> oldData) {
          return CFConfig.builder(oldData['apiKey'] as String)
              .setEnvironment(oldData['environment'] == 'prod'
                  ? CFEnvironment.production
                  : CFEnvironment.staging)
              .setDebugLoggingEnabled(oldData['enableDebug'] as bool? ?? false)
              .setEventsFlushIntervalMs(
                  (oldData['flushInterval'] as int? ?? 30) *
                      1000 // Convert to ms
                  )
              .build().getOrThrow();
        }

        // Act
        final migratedConfig = migrateFromV1(oldConfigData);
        // Assert
        expect(migratedConfig.clientKey, equals(TestConstants.validJwtToken));
        expect(migratedConfig.environment, equals(CFEnvironment.production));
        expect(migratedConfig.debugLoggingEnabled, isTrue);
        expect(migratedConfig.eventsFlushIntervalMs, equals(30000));
      });
      test('should_validate_configuration_compatibility', () {
        // Arrange - Define compatibility rules
        bool isCompatible(CFConfig config, String sdkVersion) {
          final versionParts = sdkVersion.split('.');
          final major = int.parse(versionParts[0]);
          // Version 2.x requires certain settings
          if (major >= 2) {
            if (config.remoteLoggingEnabled &&
                config.remoteLogEndpoint == null) {
              return false; // Incompatible
            }
          }
          // Version 3.x deprecates some settings
          if (major >= 3) {
            if (config.autoEnvAttributesEnabled) {
              return false; // Deprecated
            }
          }
          return true;
        }

        // Act & Assert
        final v1Config = CFConfig.builder(TestConstants.validJwtToken)
            .setAutoEnvAttributesEnabled(true)
            .build().getOrThrow();
        expect(isCompatible(v1Config, '1.5.0'), isTrue);
        expect(isCompatible(v1Config, '3.0.0'), isFalse); // Deprecated feature
        final v2Config = CFConfig.builder(TestConstants.validJwtToken)
            .setRemoteLoggingEnabled(true)
            .setRemoteLogEndpoint('https://logs.example.com')
            .build().getOrThrow();
        expect(isCompatible(v2Config, '2.0.0'), isTrue);
      });
    });
  });
}
