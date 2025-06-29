// test/unit/core/util/config_cache_test.dart
//
// Comprehensive test suite for ConfigCache covering stale-while-revalidate patterns,
// HTTP header handling, cache policies, and memory/persistent storage coordination.
// Merged with edge cases and uncovered lines tests for complete coverage.
//
// This test suite targets the 80% coverage gap in ConfigCache by focusing on
// critical untested areas: SWR behavior, ETag/Last-Modified handling,
// cache expiration logic, and error recovery scenarios.
//
// Test Categories:
// 1. Cache Policy & TTL Management
// 2. Stale-While-Revalidate Behavior
// 3. HTTP Header Handling (ETag/Last-Modified)
// 4. Memory/Persistent Storage Coordination
// 5. Error Handling & Recovery
// 6. Edge Cases & Boundary Conditions
// 7. Uncovered Lines Coverage (89-143, 158-228, 237-239, 249-268)
// 8. Synchronization and Concurrent Operations
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/config_cache.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/logging/logger.dart';
import '../../../shared/test_shared.dart';
import '../../../utils/test_plugin_mocks.dart';
import '../../../test_config.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestPluginMocks.initializePluginMocks();
  group('ConfigCache Comprehensive Tests', () {
    late ConfigCache configCache;
    const configCacheKey = 'cf_config_data';
    const metadataCacheKey = 'cf_config_metadata';
    setUp(() async {
      // Clear SharedPreferences mock for clean state
      SharedPreferences.setMockInitialValues({});
      // Reset PreferencesService singleton before each test
      PreferencesService.reset();
      configCache = ConfigCache();
      // Suppress logging for cleaner test output / Configure logger for coverage
      TestConfig.setupTestLogger();
      Logger.configure(enabled: true, debugEnabled: false);
    });
    tearDown(() {
      PreferencesService.reset();
    });
    group('1. Cache Policy & TTL Management', () {
      test('should cache config with default policy (7 days TTL)', () async {
        // Arrange
        final configMap = {
          'feature1': {'enabled': true},
          'feature2': {
            'enabled': false,
            'config': {'timeout': 5000}
          },
        };
        const lastModified = 'Wed, 21 Oct 2015 07:28:00 GMT';
        const etag = '"33a64df551425fcc55e4d42a148795d9f25f89d4"';
        // Act
        final success = await configCache.cacheConfig(
          configMap,
          lastModified,
          etag,
        );
        // Assert
        expect(success, isTrue);
        // Get SharedPreferences instance to verify stored data
        final prefs = await SharedPreferences.getInstance();
        // Verify config data was stored
        final storedConfigJson = prefs.getString(configCacheKey);
        expect(storedConfigJson, isNotNull);
        final decodedConfig = jsonDecode(storedConfigJson!);
        expect(decodedConfig, equals(configMap));
        // Verify metadata was stored with correct TTL (7 days)
        final storedMetadataJson = prefs.getString(metadataCacheKey);
        expect(storedMetadataJson, isNotNull);
        final decodedMeta = jsonDecode(storedMetadataJson!);
        expect(decodedMeta['lastModified'], lastModified);
        expect(decodedMeta['etag'], etag);
        final expiresAt = decodedMeta['expiresAt'] as int;
        final timestamp = decodedMeta['timestamp'] as int;
        final ttlMs = expiresAt - timestamp;
        expect(ttlMs, 7 * 24 * 60 * 60 * 1000); // 7 days in milliseconds
      });
      test('should not cache when TTL is zero (no-cache policy)', () async {
        // Arrange
        final configMap = {'test': 'value'};
        const noCachePolicy = CachePolicy(ttlSeconds: 0);
        // Act
        final success = await configCache.cacheConfig(
          configMap,
          'last-modified',
          'etag',
          policy: noCachePolicy,
        );
        // Assert
        expect(success, isFalse);
        // Verify nothing was stored in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(configCacheKey), isNull);
        expect(prefs.getString(metadataCacheKey), isNull);
      });
      test('should not cache when TTL is negative', () async {
        // Target line 97: if (policy.ttlSeconds <= 0)
        final config = {'test': 'value'};
        const negativePolicy = CachePolicy(ttlSeconds: -1);
        final result = await configCache.cacheConfig(
          config,
          null,
          null,
          policy: negativePolicy,
        );
        expect(result, isFalse);
        // Verify nothing was stored
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(configCacheKey), isNull);
        expect(prefs.getString(metadataCacheKey), isNull);
      });
      test('should apply custom cache policy TTL', () async {
        // Arrange
        final configMap = {'test': 'value'};
        const customPolicy = CachePolicy(ttlSeconds: 3600); // 1 hour
        // Act
        final success = await configCache.cacheConfig(
          configMap,
          'last-modified',
          'etag',
          policy: customPolicy,
        );
        // Assert
        expect(success, isTrue);
        // Get SharedPreferences instance to verify stored data
        final prefs = await SharedPreferences.getInstance();
        final storedMetadataJson = prefs.getString(metadataCacheKey);
        expect(storedMetadataJson, isNotNull);
        final decodedMeta = jsonDecode(storedMetadataJson!);
        final expiresAt = decodedMeta['expiresAt'] as int;
        final timestamp = decodedMeta['timestamp'] as int;
        final ttlMs = expiresAt - timestamp;
        expect(ttlMs, 3600 * 1000); // 1 hour in milliseconds
      });
      test('should handle persist=false policy correctly', () async {
        // Target lines: 121 (persist check)
        final config = {'test': 'value'};
        const memoryOnlyPolicy = CachePolicy(
          ttlSeconds: 3600,
          persist: false,
        );
        final result = await configCache.cacheConfig(
          config,
          'modified',
          'etag',
          policy: memoryOnlyPolicy,
        );
        expect(result, isTrue);
        // Memory only - nothing persisted
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(configCacheKey), isNull);
        expect(prefs.getString(metadataCacheKey), isNull);
        // Verify it's in memory but not persisted
        final cached = await configCache.getCachedConfig();
        expect(cached.configMap, equals(config));
      });
    });
    group('2. Stale-While-Revalidate Behavior', () {
      test('should return fresh config from memory cache', () async {
        // Arrange - First cache a config
        final configMap = {'feature': 'enabled'};
        const lastModified = 'Wed, 21 Oct 2015 07:28:00 GMT';
        const etag = '"test-etag"';
        await configCache.cacheConfig(configMap, lastModified, etag);
        // Act
        final result = await configCache.getCachedConfig();
        // Assert
        expect(result.configMap, isNotNull);
        expect(result.configMap, equals(configMap));
        expect(result.lastModified, lastModified);
        expect(result.etag, etag);
      });
      test('should return memory cache when available', () async {
        // Target lines 153-176: Memory cache hit path
        final config = {'memory': 'cache'};
        await configCache.cacheConfig(config, 'mem-mod', 'mem-etag');
        // Clear SharedPreferences to ensure memory cache is used
        SharedPreferences.setMockInitialValues({});
        final result = await configCache.getCachedConfig();
        expect(result.configMap, equals(config));
        expect(result.lastModified, 'mem-mod');
        expect(result.etag, 'mem-etag');
      });
      test('should return null for cache miss', () async {
        // Arrange - No cached config (empty SharedPreferences)
        // Act
        final result = await configCache.getCachedConfig();
        // Assert
        expect(result.configMap, isNull);
        expect(result.lastModified, isNull);
        expect(result.etag, isNull);
      });
      test('should return null for expired config when allowExpired is false',
          () async {
        // Arrange - Create expired config data
        final configMap = {'expired': 'config'};
        final now = DateTime.now().millisecondsSinceEpoch;
        final expiredTime = now - 1000; // 1 second ago
        final metadata = {
          'lastModified': 'Wed, 21 Oct 2015 07:28:00 GMT',
          'etag': '"expired-etag"',
          'timestamp': now - 8 * 24 * 60 * 60 * 1000, // 8 days ago
          'expiresAt': expiredTime,
        };
        // Set up SharedPreferences with expired data
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode(configMap),
          metadataCacheKey: jsonEncode(metadata),
        });
        // Reset PreferencesService to use new mock values
        PreferencesService.reset();
        // Act
        final result = await configCache.getCachedConfig(allowExpired: false);
        // Assert
        expect(result.configMap, isNull);
        expect(result.lastModified, isNull);
        expect(result.etag, isNull);
      });
      test('should handle expired cache when allowExpired=false', () async {
        // Target lines 198-210: Expiration check
        final config = {'test': 'expired'};
        final now = DateTime.now().millisecondsSinceEpoch;
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode(config),
          metadataCacheKey: jsonEncode({
            'lastModified': 'expired-mod',
            'etag': 'expired-etag',
            'timestamp': now - 10000,
            'expiresAt': now - 1000, // Expired
          }),
        });
        final result = await configCache.getCachedConfig(allowExpired: false);
        expect(result.configMap, isNull);
      });
      test('should return expired config when allowExpired is true', () async {
        // Arrange - Create expired config data
        final configMap = {'stale': 'config'};
        final now = DateTime.now().millisecondsSinceEpoch;
        final expiredTime = now - 1000; // 1 second ago
        final metadata = {
          'lastModified': 'Wed, 21 Oct 2015 07:28:00 GMT',
          'etag': '"stale-etag"',
          'timestamp': now - 8 * 24 * 60 * 60 * 1000, // 8 days ago
          'expiresAt': expiredTime,
        };
        // Set up SharedPreferences with expired data
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode(configMap),
          metadataCacheKey: jsonEncode(metadata),
        });
        // Reset PreferencesService to use new mock values
        PreferencesService.reset();
        // Act
        final result = await configCache.getCachedConfig(allowExpired: true);
        // Assert
        expect(result.configMap, equals(configMap));
        expect(result.lastModified, 'Wed, 21 Oct 2015 07:28:00 GMT');
        expect(result.etag, '"stale-etag"');
      });
      test('should return expired cache when allowExpired=true', () async {
        // Target lines 212-228: Allow expired path
        final config = {'test': 'expired'};
        final now = DateTime.now().millisecondsSinceEpoch;
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode(config),
          metadataCacheKey: jsonEncode({
            'lastModified': 'expired-mod',
            'etag': 'expired-etag',
            'timestamp': now - 10000,
            'expiresAt': now - 1000, // Expired
          }),
        });
        final result = await configCache.getCachedConfig(allowExpired: true);
        expect(result.configMap, equals(config));
        expect(result.lastModified, 'expired-mod');
        expect(result.etag, 'expired-etag');
      });
      test('should hydrate memory cache from persistent storage', () async {
        // Arrange - Mock persistent storage with config data
        final configMap = {'persistent': 'config'};
        final metadata = {
          'lastModified': 'Wed, 21 Oct 2015 07:28:00 GMT',
          'etag': '"persistent-etag"',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 1000,
          'expiresAt': DateTime.now().millisecondsSinceEpoch +
              1000000, // Future expiration
        };
        // Set up SharedPreferences with persistent data
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode(configMap),
          metadataCacheKey: jsonEncode(metadata),
        });
        // Reset PreferencesService to use new mock values
        PreferencesService.reset();
        // Act - First call should load from persistent storage
        final result1 = await configCache.getCachedConfig();
        // Second call should use memory cache (same instance)
        final result2 = await configCache.getCachedConfig();
        // Assert
        expect(result1.configMap, equals(configMap));
        expect(result2.configMap, equals(configMap));
      });
    });
    group('3. HTTP Header Handling (ETag/Last-Modified)', () {
      test('should store and retrieve ETag values correctly', () async {
        // Arrange
        final configMap = {'test': 'config'};
        const etag = '"W/a54b4b3c-1442951800-gzip"';
        // Act
        await configCache.cacheConfig(configMap, null, etag);
        final result = await configCache.getCachedConfig();
        // Assert
        expect(result.etag, etag);
        expect(result.lastModified, '');
      });
      test('should store and retrieve Last-Modified values correctly',
          () async {
        // Arrange
        final configMap = {'test': 'config'};
        const lastModified = 'Thu, 22 Oct 2015 08:30:00 GMT';
        // Act
        await configCache.cacheConfig(configMap, lastModified, null);
        final result = await configCache.getCachedConfig();
        // Assert
        expect(result.lastModified, lastModified);
        expect(result.etag, '');
      });
      test('should handle both ETag and Last-Modified headers', () async {
        // Arrange
        final configMap = {'test': 'config'};
        const lastModified = 'Thu, 22 Oct 2015 08:30:00 GMT';
        const etag = '"33a64df551425fcc55e4d42a148795d9f25f89d4"';
        // Act
        await configCache.cacheConfig(configMap, lastModified, etag);
        final result = await configCache.getCachedConfig();
        // Assert
        expect(result.lastModified, lastModified);
        expect(result.etag, etag);
      });
      test('should handle empty/null header values gracefully', () async {
        // Arrange
        final configMap = {'test': 'config'};
        // Act
        await configCache.cacheConfig(configMap, '', null);
        final result = await configCache.getCachedConfig();
        // Assert
        expect(result.lastModified, ''); // Empty string should be preserved
        expect(result.etag, ''); // Null should become empty string
      });
      test('should handle null lastModified and etag', () async {
        // Target lines handling null values
        final config = {'test': 'value'};
        final result = await configCache.cacheConfig(
          config,
          null,
          null,
        );
        expect(result, isTrue);
        final cached = await configCache.getCachedConfig();
        expect(cached.configMap, equals(config));
        expect(cached.lastModified, isEmpty);
        expect(cached.etag, isEmpty);
      });
      test('should handle empty string headers', () async {
        final config = {'test': 'value'};
        final result = await configCache.cacheConfig(
          config,
          '', // Empty lastModified
          '', // Empty etag
        );
        expect(result, isTrue);
        final cached = await configCache.getCachedConfig();
        expect(cached.lastModified, isEmpty);
        expect(cached.etag, isEmpty);
      });
    });
    group('4. Memory/Persistent Storage Coordination', () {
      test('should prioritize memory cache over persistent storage', () async {
        // Arrange - Set up memory cache first
        final memoryConfig = {'memory': 'config'};
        await configCache.cacheConfig(
            memoryConfig, 'memory-modified', 'memory-etag');
        // Now set different data in persistent storage (shouldn't be used)
        final persistentConfig = {'persistent': 'config'};
        final persistentMetadata = {
          'lastModified': 'persistent-modified',
          'etag': 'persistent-etag',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 1000,
          'expiresAt': DateTime.now().millisecondsSinceEpoch + 1000000,
        };
        // Directly update SharedPreferences to simulate existing persistent data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(configCacheKey, jsonEncode(persistentConfig));
        await prefs.setString(metadataCacheKey, jsonEncode(persistentMetadata));
        // Act - Should use memory cache
        final result = await configCache.getCachedConfig();
        // Assert - Should return memory cache data, not persistent
        expect(result.configMap, equals(memoryConfig));
        expect(result.lastModified, 'memory-modified');
        expect(result.etag, 'memory-etag');
      });
      test('should update memory cache when loading from persistent storage',
          () async {
        // Arrange - No memory cache, but persistent storage has data
        final persistentConfig = {'persistent': 'config'};
        final persistentMetadata = {
          'lastModified': 'persistent-modified',
          'etag': 'persistent-etag',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 1000,
          'expiresAt': DateTime.now().millisecondsSinceEpoch + 1000000,
        };
        // Set up SharedPreferences with persistent data
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode(persistentConfig),
          metadataCacheKey: jsonEncode(persistentMetadata),
        });
        // Reset PreferencesService to use new mock values
        PreferencesService.reset();
        // Create new ConfigCache instance to ensure no memory cache
        configCache = ConfigCache();
        // Act - First call loads from persistent storage
        final result1 = await configCache.getCachedConfig();
        // Second call should use memory cache
        final result2 = await configCache.getCachedConfig();
        // Assert
        expect(result1.configMap, equals(persistentConfig));
        expect(result1.lastModified, 'persistent-modified');
        expect(result1.etag, 'persistent-etag');
        expect(result2.configMap, equals(persistentConfig));
        expect(result2.lastModified, 'persistent-modified');
        expect(result2.etag, 'persistent-etag');
      });
      test('should clear both memory and persistent caches', () async {
        // Arrange - Cache some data
        final configMap = {'test': 'config'};
        await configCache.cacheConfig(configMap, 'test-modified', 'test-etag');
        // Act
        final cleared = await configCache.clearCache();
        // Assert
        expect(cleared, isTrue);
        // Verify both storage locations were cleared
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(configCacheKey), isNull);
        expect(prefs.getString(metadataCacheKey), isNull);
        // Verify memory cache was cleared by checking subsequent retrieval
        final result = await configCache.getCachedConfig();
        expect(result.configMap, isNull);
      });
    });
    group('5. Error Handling & Recovery', () {
      test('should handle JSON parsing errors during retrieval', () async {
        // Arrange - Set malformed JSON in SharedPreferences
        SharedPreferences.setMockInitialValues({
          configCacheKey: '{"invalid": json}', // Malformed JSON
          metadataCacheKey: '{"valid": "json"}',
        });
        // Reset PreferencesService to use new mock values
        PreferencesService.reset();
        configCache = ConfigCache();
        // Act
        final result = await configCache.getCachedConfig();
        // Assert
        expect(result.configMap, isNull);
        expect(result.lastModified, isNull);
        expect(result.etag, isNull);
      });
      test('should handle JSON decode errors gracefully', () async {
        // Target lines 230-244: Error handling
        SharedPreferences.setMockInitialValues({
          configCacheKey: '{invalid json',
          metadataCacheKey: jsonEncode({
            'lastModified': 'test',
            'etag': 'test',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'expiresAt': DateTime.now().millisecondsSinceEpoch + 10000,
          }),
        });
        final result = await configCache.getCachedConfig();
        expect(result.configMap, isNull);
      });
      test('should handle metadata parsing errors during retrieval', () async {
        // Arrange - Valid config but malformed metadata
        final configMap = {'test': 'config'};
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode(configMap),
          metadataCacheKey: '{"invalid": metadata}', // Malformed JSON
        });
        // Reset PreferencesService to use new mock values
        PreferencesService.reset();
        configCache = ConfigCache();
        // Act
        final result = await configCache.getCachedConfig();
        // Assert
        expect(result.configMap, isNull);
        expect(result.lastModified, isNull);
        expect(result.etag, isNull);
      });
      test('should return emergency fallback when allowExpired is true',
          () async {
        // Arrange - First cache some data successfully
        await configCache.cacheConfig(
          {'test': 'config'},
          'fallback-modified',
          'fallback-etag',
        );
        // Clear SharedPreferences to simulate storage failure
        SharedPreferences.setMockInitialValues({});
        // Reset PreferencesService but keep the same configCache instance (has memory cache)
        PreferencesService.reset();
        // Act
        final result = await configCache.getCachedConfig(allowExpired: true);
        // Assert - Should return the memory cached data
        expect(result.configMap, equals({'test': 'config'}));
        expect(result.lastModified, 'fallback-modified');
        expect(result.etag, 'fallback-etag');
      });
      test('should return emergency fallback refs on error with allowExpired',
          () async {
        // Target lines 237-241: Emergency fallback
        // First cache something to set up refs
        await configCache.cacheConfig(
          {'test': 'value'},
          'emergency-mod',
          'emergency-etag',
        );
        // Now set invalid data
        SharedPreferences.setMockInitialValues({
          configCacheKey: '{invalid json',
          metadataCacheKey: '{invalid metadata',
        });
        final result = await configCache.getCachedConfig(allowExpired: true);
        // Since we have valid memory cache, it should return that
        expect(result.configMap, equals({'test': 'value'}));
        expect(result.lastModified, 'emergency-mod');
        expect(result.etag, 'emergency-etag');
      });
      test('should handle missing metadata gracefully', () async {
        // Arrange - Config exists but no metadata
        final configMap = {'test': 'config'};
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode(configMap),
          // No metadata key
        });
        // Reset PreferencesService to use new mock values
        PreferencesService.reset();
        configCache = ConfigCache();
        // Act
        final result = await configCache.getCachedConfig();
        // Assert - Should return null since metadata is required
        expect(result.configMap, isNull);
      });
      test('should handle missing config data', () async {
        // Target lines 186-190: null checks
        SharedPreferences.setMockInitialValues({
          metadataCacheKey: jsonEncode({
            'lastModified': 'test',
            'etag': 'test',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'expiresAt': DateTime.now().millisecondsSinceEpoch + 10000,
          }),
          // No config data
        });
        final result = await configCache.getCachedConfig();
        expect(result.configMap, isNull);
      });
      test('should handle missing metadata', () async {
        // Target lines 186-190: null checks
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode({'test': 'value'}),
          // No metadata
        });
        final result = await configCache.getCachedConfig();
        expect(result.configMap, isNull);
      });
      test('should handle missing config but present metadata', () async {
        // Set up SharedPreferences with only metadata
        SharedPreferences.setMockInitialValues({
          metadataCacheKey: jsonEncode({'lastModified': 'test'}),
        });
        PreferencesService.reset();
        configCache = ConfigCache();
        final result = await configCache.getCachedConfig();
        expect(result.configMap, isNull);
        expect(result.lastModified, isNull);
        expect(result.etag, isNull);
      });
      test('should handle present config but missing metadata', () async {
        // Set up SharedPreferences with only config data
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode({'test': 'value'}),
        });
        PreferencesService.reset();
        configCache = ConfigCache();
        final result = await configCache.getCachedConfig();
        expect(result.configMap, isNull);
        expect(result.lastModified, isNull);
        expect(result.etag, isNull);
      });
      test('should handle null expiresAt in metadata', () async {
        // Set up data with missing expiresAt
        final config = {'test': 'value'};
        final metadata = {
          'lastModified': 'modified',
          'etag': 'etag',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          // No expiresAt field
        };
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode(config),
          metadataCacheKey: jsonEncode(metadata),
        });
        PreferencesService.reset();
        configCache = ConfigCache();
        final result = await configCache.getCachedConfig();
        // Should treat as expired when expiresAt is null
        expect(result.configMap, isNull);
      });
      test('should handle metadata with missing expiresAt', () async {
        // Target expiration check with null expiresAt
        SharedPreferences.setMockInitialValues({
          configCacheKey: jsonEncode({'test': 'value'}),
          metadataCacheKey: jsonEncode({
            'lastModified': 'test',
            'etag': 'test',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            // No expiresAt field
          }),
        });
        final result = await configCache.getCachedConfig();
        expect(result.configMap, isNull);
      });
      test('should handle JSON decode error and return emergency fallback',
          () async {
        // First set up refs in memory
        await configCache.cacheConfig(
          {'test': 'value'},
          'emergency-modified',
          'emergency-etag',
        );
        // Now set corrupted data in storage
        SharedPreferences.setMockInitialValues({
          configCacheKey: '{corrupted',
          metadataCacheKey: '{corrupted',
        });
        PreferencesService.reset();
        // Should use memory cache since we have the same instance
        final result = await configCache.getCachedConfig(allowExpired: true);
        expect(result.configMap, equals({'test': 'value'}));
        expect(result.lastModified, 'emergency-modified');
        expect(result.etag, 'emergency-etag');
      });
      test('should return null when no fallback refs available', () async {
        // Empty storage
        SharedPreferences.setMockInitialValues({});
        PreferencesService.reset();
        configCache = ConfigCache();
        final result = await configCache.getCachedConfig(allowExpired: true);
        expect(result.configMap, isNull);
        expect(result.lastModified, isNull);
        expect(result.etag, isNull);
      });
    });
    group('6. Edge Cases & Boundary Conditions', () {
      test('should handle very large configs gracefully', () async {
        // Create a large config that will still encode properly
        final config = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          config['key_$i'] = 'value_$i' * 10;
        }
        final result = await configCache.cacheConfig(
          config,
          'modified',
          'etag',
        );
        expect(result, isTrue);
      });
      test('should handle large config maps', () async {
        // Test with large data
        final largeConfig = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          largeConfig['key_$i'] = {
            'value': i,
            'data': List.generate(10, (j) => 'item_${i}_$j'),
          };
        }
        final result = await configCache.cacheConfig(
          largeConfig,
          'large-mod',
          'large-etag',
        );
        expect(result, isTrue);
        final cached = await configCache.getCachedConfig();
        expect(cached.configMap, equals(largeConfig));
      });
      test('should handle cache with special characters in values', () async {
        final config = {
          'special': 'Hello\nWorld\t"Quotes"\'Apostrophe\'\\Backslash',
          'unicode': '🎉 Unicode 测试 тест',
          'html': '<script>alert("xss")</script>',
        };
        final success = await configCache.cacheConfig(
          config,
          'special-modified',
          'special-etag',
        );
        expect(success, isTrue);
        final result = await configCache.getCachedConfig();
        expect(result.configMap, equals(config));
      });
      test('should handle special characters in values', () async {
        final specialConfig = {
          'unicode': '🎉 Unicode 测试 тест',
          'escapes': 'Line1\nLine2\tTab\r\nCRLF',
          'quotes': '"Double" and \'Single\' quotes',
          'backslash': 'C:\\Windows\\Path',
          'html': '<script>alert("xss")</script>',
          'null_char': 'null\u0000char',
        };
        final result = await configCache.cacheConfig(
          specialConfig,
          'special-mod',
          'special-etag',
        );
        expect(result, isTrue);
        final cached = await configCache.getCachedConfig();
        expect(cached.configMap, equals(specialConfig));
      });
      test('should maintain data integrity through cache lifecycle', () async {
        // Complex nested structure
        final complexConfig = {
          'users': {
            'user1': {
              'name': 'John',
              'roles': ['admin', 'user']
            },
            'user2': {
              'name': 'Jane',
              'roles': ['user']
            },
          },
          'settings': {
            'theme': 'dark',
            'notifications': {
              'email': true,
              'push': false,
              'frequency': 'daily',
            },
          },
          'features': ['feature1', 'feature2', 'feature3'],
        };
        // Cache it
        await configCache.cacheConfig(
          complexConfig,
          'complex-modified',
          'complex-etag',
        );
        // Clear memory by creating new instance
        configCache = ConfigCache();
        // Retrieve from persistent storage
        final result = await configCache.getCachedConfig();
        // Verify data integrity
        expect(result.configMap, equals(complexConfig));
        expect(result.lastModified, 'complex-modified');
        expect(result.etag, 'complex-etag');
      });
      test('should update refs after caching', () async {
        // Target lines 136-138: Update refs
        final config = {'test': 'value'};
        const lastModified = 'Modified-Value';
        const etag = 'ETag-Value';
        await configCache.cacheConfig(config, lastModified, etag);
        // Cache again with different values to test ref updates
        await configCache.cacheConfig(
          {'test': 'value2'},
          'Modified-Value-2',
          'ETag-Value-2',
        );
        final cached = await configCache.getCachedConfig();
        expect(cached.lastModified, 'Modified-Value-2');
        expect(cached.etag, 'ETag-Value-2');
      });
    });
    group('7. Clear Cache Operations', () {
      test('should successfully clear all cache data', () async {
        // First cache something
        await configCache.cacheConfig(
          {'test': 'value'},
          'modified',
          'etag',
        );
        // Clear cache
        final result = await configCache.clearCache();
        expect(result, isTrue);
        // Verify storage cleared
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(configCacheKey), isNull);
        expect(prefs.getString(metadataCacheKey), isNull);
        // Verify memory cache cleared
        final cached = await configCache.getCachedConfig();
        expect(cached.configMap, isNull);
      });
      test('should handle clear operation successfully', () async {
        // Cache some data first
        await configCache.cacheConfig(
          {'test': 'clear'},
          'clear-modified',
          'clear-etag',
        );
        final result = await configCache.clearCache();
        expect(result, isTrue);
      });
      test('should clear all cache data successfully', () async {
        // First cache something
        await configCache.cacheConfig(
          {'test': 'value'},
          'mod',
          'etag',
        );
        // Clear cache
        final result = await configCache.clearCache();
        expect(result, isTrue);
        // Verify cache is cleared
        final cached = await configCache.getCachedConfig();
        expect(cached.configMap, isNull);
        expect(cached.lastModified, isNull);
        expect(cached.etag, isNull);
      });
      test('should clear memory cache and refs', () async {
        // Target lines 254-263: Memory cache clearing
        await configCache.cacheConfig(
          {'test': 'value'},
          'mod',
          'etag',
        );
        await configCache.clearCache();
        // Try to get from cache - should be null
        final result = await configCache.getCachedConfig();
        expect(result.configMap, isNull);
        expect(result.lastModified, isNull);
        expect(result.etag, isNull);
      });
    });
    group('8. Synchronization and Concurrent Operations', () {
      test('should handle synchronized operations correctly', () async {
        // Target lines: 273-282
        // This tests the synchronized helper methods
        var counter = 0;
        final operations = <Future>[];
        // Launch multiple concurrent operations
        for (int i = 0; i < 10; i++) {
          operations.add(Future(() async {
            await configCache.cacheConfig(
              {'counter': counter++},
              'modified-$i',
              'etag-$i',
            );
          }));
        }
        await Future.wait(operations);
        // All operations should complete
        expect(counter, 10);
      });
      test('should handle concurrent cache operations', () async {
        // Test synchronization (lines 273-282)
        final futures = <Future<bool>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(
            configCache.cacheConfig(
              {'counter': i},
              'mod-$i',
              'etag-$i',
            ),
          );
        }
        final results = await Future.wait(futures);
        expect(results.every((r) => r == true), isTrue);
      });
      test('should handle rapid cache updates correctly', () async {
        // Rapidly update cache multiple times
        for (int i = 0; i < 100; i++) {
          await configCache.cacheConfig(
            {'iteration': i},
            'modified-$i',
            'etag-$i',
          );
        }
        final result = await configCache.getCachedConfig();
        expect(result.configMap?['iteration'], 99);
      });
    });
    group('9. Additional Coverage Tests', () {
      test('should cache config with default policy successfully', () async {
        // Arrange
        final config = {
          'feature1': true,
          'feature2': {'enabled': false, 'value': 123},
        };
        const lastModified = 'Wed, 21 Oct 2015 07:28:00 GMT';
        const etag = '"33a64df551425fcc55e4d42a148795d9f25f89d4"';
        // Act
        final result = await configCache.cacheConfig(
          config,
          lastModified,
          etag,
        );
        // Assert
        expect(result, isTrue);
        // Verify data was cached by retrieving it
        final cached = await configCache.getCachedConfig();
        expect(cached.configMap, equals(config));
        expect(cached.lastModified, equals(lastModified));
        expect(cached.etag, equals(etag));
      });
      test('should successfully cache config with all parameters', () async {
        // Target lines: 89-143 (cacheConfig method)
        final config = {
          'feature1': true,
          'feature2': {'nested': 'value'},
          'feature3': [1, 2, 3],
        };
        // Act
        final result = await configCache.cacheConfig(
          config,
          'Last-Modified-Header',
          'ETag-Header',
          policy: CachePolicy.standard,
        );
        // Assert
        expect(result, isTrue);
        // Verify data was stored
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(configCacheKey), isNotNull);
        expect(prefs.getString(metadataCacheKey), isNotNull);
      });
      test('should return memory cache hit when available and valid', () async {
        // Target lines: 153-176 (memory cache path)
        // First cache something to populate memory
        final config = {'memory': 'test'};
        await configCache.cacheConfig(
          config,
          'mem-modified',
          'mem-etag',
        );
        // Get from cache (should use memory)
        final result = await configCache.getCachedConfig();
        expect(result.configMap, equals(config));
        expect(result.lastModified, 'mem-modified');
        expect(result.etag, 'mem-etag');
      });
    });
  });
}
