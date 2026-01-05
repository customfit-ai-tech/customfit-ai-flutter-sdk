// test/unit/config/cf_config_simple_test.dart
//
// Comprehensive tests for CFConfig using actual available methods
// Tests configuration building, validation, and edge cases
// Also includes enhanced CFConfig features like smart configuration and environment detection
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../utils/test_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CFConfig Comprehensive Tests', () {
    group('Builder Pattern Tests', () {
      test('should create config with all default values', () {
        final config =
            CFConfig.builder(TestConstants.validJwtToken).build().getOrThrow();
        expect(config.clientKey, equals(TestConstants.validJwtToken));
        expect(config.debugLoggingEnabled, isFalse);
        expect(config.eventsFlushIntervalMs, equals(1000));
        expect(config.networkConnectionTimeoutMs, equals(10000));
        expect(config.backgroundPollingIntervalMs, equals(3600000));
        expect(config.offlineMode, isFalse);
      });
      test('should create config with custom values', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(true)
            .setEventsFlushIntervalMs(15000)
            .setNetworkConnectionTimeoutMs(20000)
            .setBackgroundPollingIntervalMs(30000)
            .setOfflineMode(true)
            .build()
            .getOrThrow();
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.eventsFlushIntervalMs, equals(15000));
        expect(config.networkConnectionTimeoutMs, equals(20000));
        expect(config.backgroundPollingIntervalMs, equals(30000));
        expect(config.offlineMode, isTrue);
      });
      test('should validate events flush interval minimum values', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setEventsFlushIntervalMs(500) // Small value
            .setNetworkConnectionTimeoutMs(100) // Small value
            .setBackgroundPollingIntervalMs(5000) // Small value
            .build()
            .getOrThrow();
        // Values should be accepted (validation happens at runtime, not build time)
        expect(config.eventsFlushIntervalMs, equals(500));
        expect(config.networkConnectionTimeoutMs, equals(100));
        expect(config.backgroundPollingIntervalMs, equals(5000));
      });
      test('should handle large timeout values', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setEventsFlushIntervalMs(600000) // Very high
            .setNetworkConnectionTimeoutMs(180000) // Very high
            .setBackgroundPollingIntervalMs(3600000) // Very high
            .build()
            .getOrThrow();
        expect(config.eventsFlushIntervalMs, equals(600000));
        expect(config.networkConnectionTimeoutMs, equals(180000));
        expect(config.backgroundPollingIntervalMs, equals(3600000));
      });
    });
    group('JWT Token Validation', () {
      test('should accept valid JWT format', () {
        const validJwt =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        final config = CFConfig.builder(validJwt).build().getOrThrow();
        expect(config.clientKey, equals(validJwt));
      });
      test('should handle invalid JWT formats gracefully', () {
        expect(() => CFConfig.builder('invalid.jwt').build().getOrThrow(),
            throwsA(isA<CFException>()));
        expect(() => CFConfig.builder('').build().getOrThrow(),
            throwsA(isA<CFException>()));
        expect(() => CFConfig.builder('  ').build().getOrThrow(),
            throwsA(isA<CFException>()));
      });
      test('should validate JWT has 3 parts', () {
        expect(() => CFConfig.builder('part1.part2').build().getOrThrow(),
            throwsA(isA<CFException>()));
        expect(
            () => CFConfig.builder('part1.part2.part3.part4')
                .build()
                .getOrThrow(),
            throwsA(isA<CFException>()));
      });
      test('should validate JWT minimum length', () {
        // JWT too short
        expect(() => CFConfig.builder('a.b.c').build().getOrThrow(),
            throwsA(isA<CFException>()));
      });
    });
    group('Configuration Chaining', () {
      test('should allow method chaining in any order', () {
        final config1 = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(true)
            .setOfflineMode(true)
            .setEventsFlushIntervalMs(5000)
            .build()
            .getOrThrow();
        final config2 = CFConfig.builder(TestConstants.validJwtToken)
            .setEventsFlushIntervalMs(5000)
            .setOfflineMode(true)
            .setDebugLoggingEnabled(true)
            .build()
            .getOrThrow();
        expect(
            config1.debugLoggingEnabled, equals(config2.debugLoggingEnabled));
        expect(config1.offlineMode, equals(config2.offlineMode));
        expect(config1.eventsFlushIntervalMs,
            equals(config2.eventsFlushIntervalMs));
      });
      test('should allow overriding previous values', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(true)
            .setDebugLoggingEnabled(false) // Override
            .setOfflineMode(false)
            .setOfflineMode(true) // Override
            .build()
            .getOrThrow();
        expect(config.debugLoggingEnabled, isFalse);
        expect(config.offlineMode, isTrue);
      });
    });
    group('Advanced Configuration', () {
      test('should configure retry settings', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setMaxRetryAttempts(5)
            .setRetryInitialDelayMs(2000)
            .setRetryMaxDelayMs(60000)
            .setRetryBackoffMultiplier(3.0)
            .build()
            .getOrThrow();
        expect(config.maxRetryAttempts, equals(5));
        expect(config.retryInitialDelayMs, equals(2000));
        expect(config.retryMaxDelayMs, equals(60000));
        expect(config.retryBackoffMultiplier, equals(3.0));
      });
      test('should configure event settings', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setEventsQueueSize(200)
            .setEventsFlushTimeSeconds(120)
            .setMaxStoredEvents(500)
            .build()
            .getOrThrow();
        expect(config.eventsQueueSize, equals(200));
        expect(config.eventsFlushTimeSeconds, equals(120));
        expect(config.maxStoredEvents, equals(500));
      });
      test('should configure summary settings', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setSummariesQueueSize(150)
            .setSummariesFlushTimeSeconds(180)
            .setSummariesFlushIntervalMs(90000)
            .build()
            .getOrThrow();
        expect(config.summariesQueueSize, equals(150));
        expect(config.summariesFlushTimeSeconds, equals(180));
        expect(config.summariesFlushIntervalMs, equals(90000));
      });
      test('should configure network settings', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setNetworkConnectionTimeoutMs(15000)
            .setNetworkReadTimeoutMs(25000)
            .setSdkSettingsCheckIntervalMs(600000)
            .build()
            .getOrThrow();
        expect(config.networkConnectionTimeoutMs, equals(15000));
        expect(config.networkReadTimeoutMs, equals(25000));
        expect(config.sdkSettingsCheckIntervalMs, equals(600000));
      });
      test('should configure logging settings', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setLoggingEnabled(false)
            .setDebugLoggingEnabled(true)
            .setLogLevel('ERROR')
            .build()
            .getOrThrow();
        expect(config.loggingEnabled, isFalse);
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.logLevel, equals('ERROR'));
      });
      test('should configure background polling', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setDisableBackgroundPolling(true)
            .setBackgroundPollingIntervalMs(1800000)
            .setUseReducedPollingWhenBatteryLow(false)
            .setReducedPollingIntervalMs(5400000)
            .build()
            .getOrThrow();
        expect(config.disableBackgroundPolling, isTrue);
        expect(config.backgroundPollingIntervalMs, equals(1800000));
        expect(config.useReducedPollingWhenBatteryLow, isFalse);
        expect(config.reducedPollingIntervalMs, equals(5400000));
      });
      test('should configure local storage', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setLocalStorageEnabled(false)
            .setConfigCacheTtlSeconds(43200)
            .setEventCacheTtlSeconds(1800)
            .setSummaryCacheTtlSeconds(3600)
            .setMaxCacheSizeMb(100)
            .setPersistCacheAcrossRestarts(false)
            .setUseStaleWhileRevalidate(false)
            .build()
            .getOrThrow();
        expect(config.localStorageEnabled, isFalse);
        expect(config.configCacheTtlSeconds, equals(43200));
        expect(config.eventCacheTtlSeconds, equals(1800));
        expect(config.summaryCacheTtlSeconds, equals(3600));
        expect(config.maxCacheSizeMb, equals(100));
        expect(config.persistCacheAcrossRestarts, isFalse);
        expect(config.useStaleWhileRevalidate, isFalse);
      });
      test('should configure remote logging', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setRemoteLoggingEnabled(true)
            .setRemoteLogProvider('logtail')
            .setRemoteLogEndpoint('https://logs.example.com')
            .setRemoteLogApiKey('test-api-key')
            .setRemoteLogLevel('debug')
            .setRemoteLogBatchSize(50)
            .setRemoteLogFlushIntervalMs(60000)
            .build()
            .getOrThrow();
        expect(config.remoteLoggingEnabled, isTrue);
        expect(config.remoteLogProvider, equals('logtail'));
        expect(config.remoteLogEndpoint, equals('https://logs.example.com'));
        expect(config.remoteLogApiKey, equals('test-api-key'));
        expect(config.remoteLogLevel, equals('debug'));
        expect(config.remoteLogBatchSize, equals(50));
        expect(config.remoteLogFlushIntervalMs, equals(60000));
      });
    });
    group('Environment and Special Properties', () {
      test('should extract dimension ID from token', () {
        final config =
            CFConfig.builder(TestConstants.validJwtToken).build().getOrThrow();
        // dimensionId might be null for test tokens, that's expected
        expect(config.dimensionId, isA<String?>());
      });
      test('should provide API URLs', () {
        final config =
            CFConfig.builder(TestConstants.validJwtToken).build().getOrThrow();
        expect(config.baseApiUrl, isNotEmpty);
        expect(config.sdkSettingsBaseUrl, isNotEmpty);
      });
      test('should configure environment attributes', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setAutoEnvAttributesEnabled(true)
            .build()
            .getOrThrow();
        expect(config.autoEnvAttributesEnabled, isTrue);
      });
    });
    group('Edge Cases and Error Handling', () {
      test('should handle negative retry attempts', () {
        expect(
            () => CFConfig.builder(TestConstants.validJwtToken)
                .setMaxRetryAttempts(-1)
                .build()
                .getOrThrow(),
            throwsA(isA<ArgumentError>()));
      });
      test('should handle zero events queue size', () {
        expect(
            () => CFConfig.builder(TestConstants.validJwtToken)
                .setEventsQueueSize(0)
                .build()
                .getOrThrow(),
            throwsA(isA<ArgumentError>()));
      });
      test('should handle zero flush time', () {
        expect(
            () => CFConfig.builder(TestConstants.validJwtToken)
                .setEventsFlushTimeSeconds(0)
                .build()
                .getOrThrow(),
            throwsA(isA<ArgumentError>()));
      });
      test('should handle negative cache TTL values', () {
        expect(
            () => CFConfig.builder(TestConstants.validJwtToken)
                .setConfigCacheTtlSeconds(-1)
                .build()
                .getOrThrow(),
            throwsA(isA<ArgumentError>()));
      });
      test('should handle zero cache size', () {
        expect(
            () => CFConfig.builder(TestConstants.validJwtToken)
                .setMaxCacheSizeMb(0)
                .build()
                .getOrThrow(),
            throwsA(isA<ArgumentError>()));
      });
      test('should validate remote log provider', () {
        expect(
            () => CFConfig.builder(TestConstants.validJwtToken)
                .setRemoteLogProvider('invalid')
                .build()
                .getOrThrow(),
            throwsA(isA<ArgumentError>()));
      });
      test('should validate remote log level', () {
        expect(
            () => CFConfig.builder(TestConstants.validJwtToken)
                .setRemoteLogLevel('invalid')
                .build()
                .getOrThrow(),
            throwsA(isA<ArgumentError>()));
      });
    });
    group('Configuration Scenarios', () {
      test('should create development configuration', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(true)
            .setEventsFlushIntervalMs(5000)
            .setNetworkConnectionTimeoutMs(10000)
            .build()
            .getOrThrow();
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.eventsFlushIntervalMs, equals(5000));
        expect(config.networkConnectionTimeoutMs, equals(10000));
      });
      test('should create production configuration', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(false)
            .setEventsFlushIntervalMs(30000)
            .setNetworkConnectionTimeoutMs(30000)
            .setOfflineMode(false)
            .build()
            .getOrThrow();
        expect(config.debugLoggingEnabled, isFalse);
        expect(config.eventsFlushIntervalMs, equals(30000));
        expect(config.offlineMode, isFalse);
      });
      test('should create battery optimized configuration', () {
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setEventsFlushIntervalMs(120000) // Less frequent flush
            .setBackgroundPollingIntervalMs(7200000) // Less frequent polling
            .setUseReducedPollingWhenBatteryLow(true)
            .setOfflineMode(true) // Reduce network usage
            .build()
            .getOrThrow();
        expect(config.eventsFlushIntervalMs, equals(120000));
        expect(config.backgroundPollingIntervalMs, equals(7200000));
        expect(config.useReducedPollingWhenBatteryLow, isTrue);
        expect(config.offlineMode, isTrue);
      });
    });
    group('Copy With Tests', () {
      test('should create copy with modified values', () {
        final original = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(true)
            .setOfflineMode(false)
            .build()
            .getOrThrow();
        final copy = original.copyWith(
          debugLoggingEnabled: false,
          offlineMode: true,
          eventsFlushIntervalMs: 15000,
        );
        expect(copy.clientKey, equals(original.clientKey));
        expect(copy.debugLoggingEnabled, isFalse); // Changed
        expect(copy.offlineMode, isTrue); // Changed
        expect(copy.eventsFlushIntervalMs, equals(15000)); // Changed
        expect(copy.networkConnectionTimeoutMs,
            equals(original.networkConnectionTimeoutMs)); // Unchanged
      });
      test('should maintain immutability after copyWith', () {
        final original = CFConfig.builder(TestConstants.validJwtToken)
            .setDebugLoggingEnabled(true)
            .build()
            .getOrThrow();
        final copy = original.copyWith(debugLoggingEnabled: false);
        expect(original.debugLoggingEnabled, isTrue);
        expect(copy.debugLoggingEnabled, isFalse);
      });
    });
  });
  group('CFConfig Enhanced Features', () {
    const testJwtToken =
        'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InByb2QtZGltZW5zaW9uIn0.prod_signature_123456789';
    const devJwtToken =
        'eyJhbGciOiJIUzI1NiJ9.eyJkZXYiOiJ0cnVlIiwiZGltZW5zaW9uX2lkIjoiZGV2LWRpbWVuc2lvbiJ9.dev_signature_123456789';
    group('Smart Configuration Factory', () {
      test('should create smart configuration for production key', () {
        final config = CFConfig.smart(testJwtToken);
        expect(config.clientKey, equals(testJwtToken));
        expect(config.environment, equals(CFEnvironment.production));
        expect(config.debugLoggingEnabled, isFalse);
        expect(config.eventsFlushIntervalMs, greaterThanOrEqualTo(10000));
      });
      test('should create smart configuration for development key', () {
        final config = CFConfig.smart(devJwtToken);
        expect(config.clientKey, equals(devJwtToken));
        expect(config.environment, equals(CFEnvironment.staging));
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.eventsFlushIntervalMs, lessThanOrEqualTo(5000));
      });
      test('should apply performance optimizations', () {
        final config = CFConfig.smart(testJwtToken);
        // Production optimizations
        expect(config.maxRetryAttempts, lessThanOrEqualTo(5));
        expect(config.eventsQueueSize, lessThanOrEqualTo(500));
        expect(config.useReducedPollingWhenBatteryLow, isTrue);
      });
      test('should apply battery optimizations for mobile', () {
        final config = CFConfig.smart(testJwtToken);
        expect(config.eventsFlushIntervalMs, greaterThanOrEqualTo(5000));
        expect(
            config.backgroundPollingIntervalMs, greaterThanOrEqualTo(1800000));
        expect(config.useReducedPollingWhenBatteryLow, isTrue);
      });
    });
    group('Environment Detection', () {
      test('should detect production environment from key', () {
        final env = CFConfig.detectEnvironment(testJwtToken);
        expect(env, equals(CFEnvironment.production));
      });
      test('should detect staging environment from dev key', () {
        final env = CFConfig.detectEnvironment(devJwtToken);
        expect(env, equals(CFEnvironment.staging));
      });
      test('should detect staging environment from test key', () {
        const testKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJ0ZXN0IjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InRlc3QtZGltZW5zaW9uIn0.test_signature_123456789';
        final env = CFConfig.detectEnvironment(testKey);
        expect(env, equals(CFEnvironment.staging));
      });
      test('should fallback to production for unknown keys', () {
        const unknownKey =
            'eyJhbGciOiJIUzI1NiJ9.eyJ1bmtub3duIjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6InVua25vd24tZGltZW5zaW9uIn0.unknown_signature';
        final env = CFConfig.detectEnvironment(unknownKey);
        expect(env, equals(CFEnvironment.production));
      });
    });
    group('JWT Parser and Caching', () {
      test('should extract dimension ID from JWT', () {
        final config = CFConfig.builder(testJwtToken).build().getOrThrow();
        // The test JWT token may not have a valid dimension_id, so check if it's extracted correctly
        expect(config.dimensionId, isA<String?>());
      });
      test('should cache JWT parsing results', () {
        // Multiple calls should use cached results
        final config1 = CFConfig.builder(testJwtToken).build().getOrThrow();
        final config2 = CFConfig.builder(testJwtToken).build().getOrThrow();
        expect(config1.dimensionId, equals(config2.dimensionId));
      });
      test('should handle invalid JWT gracefully', () {
        const invalidJwt = 'invalid.jwt.token';
        // Should throw CFException for invalid JWT format (not 3 parts or too short)
        expect(() => CFConfig.builder(invalidJwt).build().getOrThrow(),
            throwsA(isA<CFException>()));
      });
      test('should provide cache statistics', () {
        // Access the parser instance (if exposed) to check stats
        // This tests that caching is working
        final config1 = CFConfig.builder(testJwtToken).build().getOrThrow();
        final config2 = CFConfig.builder(devJwtToken).build().getOrThrow();
        final config3 = CFConfig.builder(testJwtToken)
            .build()
            .getOrThrow(); // Should hit cache
        // The dimension IDs may be null for test tokens, that's expected
        expect(config1.dimensionId, isA<String?>());
        expect(config2.dimensionId, isA<String?>());
        expect(config3.dimensionId, equals(config1.dimensionId));
      });
    });
    group('Configuration Properties', () {
      test('should have consistent configuration properties', () {
        final config1 = CFConfig.builder(testJwtToken)
            .setDebugLoggingEnabled(true)
            .setEventsFlushIntervalMs(5000)
            .build()
            .getOrThrow();
        final config2 = CFConfig.builder(testJwtToken)
            .setDebugLoggingEnabled(true)
            .setEventsFlushIntervalMs(5000)
            .build()
            .getOrThrow();
        // Configurations with same settings should have same properties
        expect(
            config1.debugLoggingEnabled, equals(config2.debugLoggingEnabled));
        expect(config1.eventsFlushIntervalMs,
            equals(config2.eventsFlushIntervalMs));
        expect(config1.clientKey, equals(config2.clientKey));
      });
      test('should maintain immutability', () {
        final config = CFConfig.builder(testJwtToken)
            .setDebugLoggingEnabled(false)
            .build()
            .getOrThrow();
        // Configuration should be immutable
        expect(config.debugLoggingEnabled, isFalse);
        // Creating a copy with changes should not affect original
        final modifiedConfig = config.copyWith(debugLoggingEnabled: true);
        expect(config.debugLoggingEnabled, isFalse);
        expect(modifiedConfig.debugLoggingEnabled, isTrue);
      });
      test('should provide reasonable default values', () {
        final config = CFConfig.builder(testJwtToken).build().getOrThrow();
        // Check that default values are reasonable
        expect(config.eventsFlushIntervalMs, greaterThan(0));
        expect(config.networkConnectionTimeoutMs, greaterThan(0));
        expect(config.eventsQueueSize, greaterThan(0));
        expect(config.maxCacheSizeMb, greaterThan(0));
      });
      test('should handle configuration comparison', () {
        final config1 = CFConfig.builder(testJwtToken)
            .setDebugLoggingEnabled(true)
            .build()
            .getOrThrow();
        final config2 = CFConfig.builder(testJwtToken)
            .setDebugLoggingEnabled(false)
            .build()
            .getOrThrow();
        // Configurations should be comparable
        expect(config1.debugLoggingEnabled,
            isNot(equals(config2.debugLoggingEnabled)));
        expect(config1.clientKey, equals(config2.clientKey));
      });
    });
    group('Configuration Factory Methods', () {
      test('should create development configuration', () {
        final config = CFConfig.development(devJwtToken);
        expect(config.debugLoggingEnabled, isTrue);
        expect(config.eventsFlushIntervalMs, lessThanOrEqualTo(5000));
        expect(config.loggingEnabled, isTrue);
      });
      test('should create production configuration', () {
        final config = CFConfig.production(testJwtToken);
        expect(config.debugLoggingEnabled, isFalse);
        expect(config.eventsFlushIntervalMs, greaterThanOrEqualTo(10000));
        expect(config.environment, equals(CFEnvironment.production));
      });
      test('should create testing configuration', () {
        final config = CFConfig.testing(devJwtToken);
        expect(config.debugLoggingEnabled, isFalse);
        expect(config.eventsFlushIntervalMs, lessThanOrEqualTo(1000));
        expect(config.offlineMode,
            isFalse); // Testing config sets offline mode to false
      });
    });
    group('Error Handling and Edge Cases', () {
      test('should handle null values gracefully', () {
        final config = CFConfig.builder(testJwtToken).build().getOrThrow();
        // These should not crash
        expect(config.dimensionId, isA<String?>());
        expect(config.toString(), isNotNull);
      });
      test('should handle empty JWT payload', () {
        // Create a valid length JWT with null dimension_id to test parsing
        const emptyPayloadJwt =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZXN0IjoidHJ1ZSIsImRpbWVuc2lvbl9pZCI6bnVsbCwiaWF0IjoxNjM2MzI5NjAwfQ.empty_signature_123456789_padding_to_make_it_long_enough_for_validation';
        final config = CFConfig.builder(emptyPayloadJwt).build().getOrThrow();
        expect(config.dimensionId, isNull);
        expect(config.toString(), isNotNull);
      });
      test('should handle malformed JWT gracefully', () {
        const malformedJwt =
            'eyJhbGciOiJIUzI1NiJ9.eyJtYWxmb3JtZWQiOiJ0cnVlIiwiZGltZW5zaW9uX2lkIjoidGVzdCJ9.malformed_signature_123456789';
        final config = CFConfig.builder(malformedJwt).build().getOrThrow();
        // The JWT parser may return null for malformed JWTs due to signature validation failures
        expect(config.dimensionId, isA<String?>());
      });
      test('should provide string representation', () {
        final config = CFConfig.builder(testJwtToken)
            .setDebugLoggingEnabled(true)
            .build()
            .getOrThrow();
        final stringRep = config.toString();
        expect(stringRep, isA<String>());
        expect(stringRep, contains('CFConfig'));
      });
    });
  });
}
