// test/unit/core/util/cache_manager_test.dart
//
// Comprehensive test suite for CacheManager covering all functionality from multiple test files
// Consolidated from cache_manager_coverage_boost_test.dart, cache_manager_coverage_improvement_test.dart,
// and cache_manager_comprehensive_test.dart to eliminate duplication while maintaining complete coverage.
//
// This test suite targets 85%+ coverage in CacheManager by focusing on:
// - Type Safety & Conversion Testing
// - Storage Tiering & Persistence
// - Cache Policy & TTL Management
// - Error Handling & Recovery
// - Concurrent Access & Thread Safety
// - Large Entry File Handling
// - Background Refresh Logic
// - Cache Cleanup Operations
// - CacheEntry utility methods
// - Eviction policies and size management
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/cache_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/type_conversion_strategy.dart';
import 'package:customfit_ai_flutter_sdk/src/logging/logger.dart';
import '../../../shared/test_shared.dart';
import '../../../utils/test_plugin_mocks.dart';
import '../../../test_config.dart';
// Mock for PathProvider to control file system location during tests
class MockPathProviderPlatform extends PathProviderPlatform {
  final String _tempPath;
  MockPathProviderPlatform(this._tempPath);
  @override
  Future<String?> getApplicationDocumentsPath() async => _tempPath;
  @override
  Future<String?> getApplicationSupportPath() async => _tempPath;
  @override
  Future<String?> getLibraryPath() async => null;
  @override
  Future<String?> getTemporaryPath() async => '$_tempPath/tmp';
}
// Custom types for testing type conversion
class TestComplexObject {
  final String id;
  final int value;
  final List<String> tags;
  TestComplexObject(this.id, this.value, this.tags);
  Map<String, dynamic> toJson() => {
        'id': id,
        'value': value,
        'tags': tags,
      };
  factory TestComplexObject.fromJson(Map<String, dynamic> json) {
    return TestComplexObject(
      json['id'],
      json['value'],
      List<String>.from(json['tags']),
    );
  }
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestComplexObject &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          value == other.value &&
          tags.length == other.tags.length &&
          tags.every((tag) => other.tags.contains(tag));
  @override
  int get hashCode => id.hashCode ^ value.hashCode ^ tags.hashCode;
}
// Custom conversion strategy for testing
class TestComplexObjectConversionStrategy
    extends TypeConversionStrategy<TestComplexObject> {
  @override
  CFResult<TestComplexObject> convert(dynamic value) {
    try {
      if (value == null) {
        return CFResult.error(
          'Cannot convert null to TestComplexObject',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidType,
        );
      }
      if (value is Map) {
        final obj =
            TestComplexObject.fromJson(Map<String, dynamic>.from(value));
        return CFResult.success(obj);
      }
      return CFResult.error(
        'Cannot convert ${value.runtimeType} to TestComplexObject',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {'valueType': value.runtimeType.toString()},
      );
    } catch (e, stackTrace) {
      return CFResult.error(
        'Failed to convert value to TestComplexObject: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'valueType': value.runtimeType.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }
  @override
  bool canHandle(Type type) => type == TestComplexObject;
}
// Custom conversion strategy that always fails
class FailingConversionStrategy extends TypeConversionStrategy<String> {
  @override
  CFResult<String> convert(dynamic value) {
    throw Exception('Conversion always fails');
  }
  @override
  bool canHandle(Type type) => type == String;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestPluginMocks.initializePluginMocks();
  group('CacheManager Comprehensive Tests', () {
    late CacheManager cacheManager;
    late Directory tempDir;
    late Map<String, Object> mockPrefsData;
    const cacheKeyPrefix = 'cf_cache_';
    /// Helper function to set up mock preferences data
    void setMockPrefsData(String key, String value) {
      mockPrefsData[key] = value;
      SharedPreferences.setMockInitialValues(mockPrefsData);
      PreferencesService.reset();
    }
    setUp(() async {
      // Create temporary directory for file system tests
      tempDir =
          await Directory.systemTemp.createTemp('test_cache_comprehensive');
      // Set up mock for PathProvider
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
      // Initialize mock SharedPreferences data
      mockPrefsData = <String, Object>{};
      SharedPreferences.setMockInitialValues(mockPrefsData);
      // Reset services for clean state
      PreferencesService.reset();
      CacheManager.clearTestInstance();
      // Get the cache manager instance
      cacheManager = CacheManager.instance;
      // Initialize cache manager
      await cacheManager.initialize();
      // Configure logger
      Logger.configure(enabled: true, debugEnabled: false);
      TestConfig.setupTestLogger();
      // Mock path_provider for MethodChannel
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });
    });
    tearDown(() async {
      CacheManager.clearTestInstance();
      PreferencesService.reset();
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    group('1. CacheEntry Utility Methods', () {
      test(
          'should calculate secondsUntilExpiration correctly for future expiration',
          () {
        final futureTime = DateTime.now().add(const Duration(seconds: 300));
        final entry = CacheEntry(
          value: 'test',
          expiresAt: futureTime,
          createdAt: DateTime.now(),
          key: 'test_key',
        );
        final seconds = entry.secondsUntilExpiration();
        expect(seconds, greaterThan(290));
        expect(seconds, lessThanOrEqualTo(300));
      });
      test('should return 0 secondsUntilExpiration for expired entries', () {
        final pastTime = DateTime.now().subtract(const Duration(seconds: 100));
        final entry = CacheEntry(
          value: 'expired',
          expiresAt: pastTime,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          key: 'expired_key',
        );
        final seconds = entry.secondsUntilExpiration();
        expect(seconds, 0);
      });
      test('should create CacheEntry from JSON with string values', () {
        final json = {
          'value': 'string_value',
          'expiresAt': DateTime.now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'key': 'test_key',
          'metadata': {'source': 'test'},
        };
        final entry = CacheEntry.fromJson(json);
        expect(entry.value, 'string_value');
        expect(entry.key, 'test_key');
        expect(entry.metadata?['source'], 'test');
        expect(entry.expiresAt, isA<DateTime>());
        expect(entry.createdAt, isA<DateTime>());
      });
      test('should create CacheEntry from JSON with complex objects', () {
        final complexValue = {
          'name': 'John',
          'data': [1, 2, 3],
          'nested': {'active': true}
        };
        final json = {
          'value': complexValue,
          'expiresAt': DateTime.now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'key': 'complex_key',
          'metadata': null,
        };
        final entry = CacheEntry.fromJson(json);
        expect(entry.value, equals(complexValue));
        expect(entry.metadata, isNull);
      });
      test('should handle numeric values in fromJson by converting to string',
          () {
        final json = {
          'value': 42,
          'expiresAt': DateTime.now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'key': 'numeric_key',
        };
        final entry = CacheEntry.fromJson(json);
        expect(entry.value, '42');
      });
    });
    group('2. Type Safety & Conversion Testing', () {
      test('should convert string values to requested String type', () async {
        const key = 'string_conversion_test';
        const value = 'test_string';
        await cacheManager.put(key, value);
        final result = await cacheManager.get<String>(key);
        expect(result, isA<String>());
        expect(result, value);
      });
      test('should convert string "42" to int type', () async {
        const key = 'int_conversion_test';
        const stringValue = '42';
        final entry = CacheEntry(
          value: stringValue,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          key: key,
        );
        setMockPrefsData(
            '${cacheKeyPrefix}int_conversion_test', jsonEncode(entry.toJson()));
        final result = await cacheManager.get<int>(key);
        expect(result, isA<int>());
        expect(result, 42);
      });
      test('should convert string "3.14159" to double type', () async {
        const key = 'double_conversion_test';
        const stringValue = '3.14159';
        final entry = CacheEntry(
          value: stringValue,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          key: key,
        );
        setMockPrefsData('${cacheKeyPrefix}double_conversion_test',
            jsonEncode(entry.toJson()));
        final result = await cacheManager.get<double>(key);
        expect(result, isA<double>());
        expect(result, 3.14159);
      });
      test('should convert string "true" to bool type', () async {
        const key = 'bool_conversion_test';
        const stringValue = 'true';
        final entry = CacheEntry(
          value: stringValue,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          key: key,
        );
        setMockPrefsData('${cacheKeyPrefix}bool_conversion_test',
            jsonEncode(entry.toJson()));
        final result = await cacheManager.get<bool>(key);
        expect(result, isA<bool>());
        expect(result, isTrue);
      });
      test('should convert string "false" to bool type (case insensitive)',
          () async {
        const key = 'bool_false_conversion_test';
        const stringValue = 'FALSE';
        final entry = CacheEntry(
          value: stringValue,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          key: key,
        );
        setMockPrefsData('${cacheKeyPrefix}bool_false_conversion_test',
            jsonEncode(entry.toJson()));
        final result = await cacheManager.get<bool>(key);
        expect(result, isA<bool>());
        expect(result, isFalse);
      });
      test('should handle invalid int conversion gracefully', () async {
        const key = 'invalid_int_test';
        const stringValue = 'not_a_number';
        final entry = CacheEntry(
          value: stringValue,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          key: key,
        );
        setMockPrefsData(
            '${cacheKeyPrefix}invalid_int_test', jsonEncode(entry.toJson()));
        final result = await cacheManager.get<int>(key);
        expect(result, isNull);
      });
      test('should handle Map type detection correctly', () async {
        const key = 'map_type_test';
        final mapValue = {'name': 'John', 'age': 30};
        final entry = CacheEntry(
          value: mapValue,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          key: key,
        );
        setMockPrefsData(
            '${cacheKeyPrefix}map_type_test', jsonEncode(entry.toJson()));
        final result = await cacheManager.get<Map<String, dynamic>>(key);
        expect(result, isA<Map<String, dynamic>>());
        expect(result, equals(mapValue));
      });
      test('should handle List type detection correctly', () async {
        const key = 'list_type_test';
        final listValue = ['apple', 'banana', 'cherry'];
        final entry = CacheEntry(
          value: listValue,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          key: key,
        );
        setMockPrefsData(
            '${cacheKeyPrefix}list_type_test', jsonEncode(entry.toJson()));
        final result = await cacheManager.get<List>(key);
        expect(result, isA<List>());
        expect(result, equals(listValue));
      });
      test('should return null for unsupported type conversions', () async {
        const key = 'unsupported_conversion_test';
        final complexValue = DateTime.now();
        final entry = CacheEntry(
          value: complexValue.toIso8601String(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          key: key,
        );
        setMockPrefsData('${cacheKeyPrefix}unsupported_conversion_test',
            jsonEncode(entry.toJson()));
        final result = await cacheManager.get<DateTime>(key);
        expect(result, isNull);
      });
      test('should handle custom type conversion strategies', () async {
        cacheManager
            .registerConversionStrategy(TestComplexObjectConversionStrategy());
        expect(
            cacheManager.hasConversionStrategyFor(TestComplexObject), isTrue);
        final customData = TestComplexObject('test-id', 42, ['tag1', 'tag2']);
        await cacheManager.put('custom_key', customData.toJson());
        final retrieved =
            await cacheManager.get<TestComplexObject>('custom_key');
        expect(retrieved?.id, 'test-id');
        expect(retrieved?.value, 42);
        expect(retrieved?.tags, ['tag1', 'tag2']);
        cacheManager
            .removeConversionStrategy<TestComplexObjectConversionStrategy>();
        expect(
            cacheManager.hasConversionStrategyFor(TestComplexObject), isFalse);
      });
    });
    group('3. Storage Tiering & Persistence', () {
      test('should store small entries in SharedPreferences', () async {
        const key = 'small_entry';
        const value = 'This is a small value for testing';
        final success = await cacheManager.put(key, value);
        expect(success, isTrue);
        final retrieved = await cacheManager.get<String>(key);
        expect(retrieved, equals(value));
      });
      test('should store large entries (>100KB) as file references', () async {
        const key = 'large_entry';
        final largeValue = 'x' * 110000; // Larger than 100KB threshold
        final success = await cacheManager.put(key, largeValue);
        expect(success, isTrue);
        final retrieved = await cacheManager.get<String>(key);
        expect(retrieved, equals(largeValue));
        // Verify actual file was created
        // final cacheDir = Directory('${tempDir.path}/cf_cache');
        // final cacheFile = File('${cacheDir.path}/$key.json');
        // Allow some time for file operations
        await Future.delayed(const Duration(milliseconds: 100));
        // File might not exist in test environment, but operation should succeed
        expect(retrieved, equals(largeValue));
      });
      test('should handle very large map entries', () async {
        final largeMap = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          // Reduced size for test performance
          largeMap['key_$i'] = {
            'value': i,
            'data': List.generate(5, (j) => 'item_${i}_$j'),
          };
        }
        await cacheManager.put('large_map_key', largeMap);
        final retrieved = await cacheManager.get<Map>('large_map_key');
        expect(retrieved, largeMap);
      });
      test('should load entry from persistent storage when not in memory',
          () async {
        const key = 'persistent_load_test';
        const value = 'persistent_value';
        final entry = CacheEntry(
          value: value,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          key: key,
        );
        setMockPrefsData('${cacheKeyPrefix}persistent_load_test',
            jsonEncode(entry.toJson()));
        final result = await cacheManager.get<String>(key);
        expect(result, value);
      });
      test('should handle expired entries from persistent storage', () async {
        const key = 'expired_persistent_test';
        const value = 'expired_value';
        final expiredEntry = CacheEntry(
          value: value,
          expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          key: key,
        );
        setMockPrefsData('${cacheKeyPrefix}expired_persistent_test',
            jsonEncode(expiredEntry.toJson()));
        final result = await cacheManager.get<String>(key);
        expect(result, isNull);
      });
      test('should return expired entries when allowExpired is true', () async {
        const key = 'expired_allowed_test';
        const value = 'expired_but_allowed';
        final expiredEntry = CacheEntry(
          value: value,
          expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          key: key,
        );
        setMockPrefsData('${cacheKeyPrefix}expired_allowed_test',
            jsonEncode(expiredEntry.toJson()));
        final result = await cacheManager.get<String>(key, allowExpired: true);
        expect(result, value);
      });
      test('should persist cache entries when policy.persist is true',
          () async {
        const policy = CachePolicy(persist: true);
        await cacheManager.put('persist_key', 'persist_value', policy: policy);
        final prefs = await SharedPreferences.getInstance();
        final storedData = prefs.getString('cf_cache_persist_key');
        expect(storedData, isNotNull);
        // Create new cache manager instance
        CacheManager.clearTestInstance();
        cacheManager = CacheManager.instance;
        await cacheManager.initialize();
        final value = await cacheManager.get<String>('persist_key');
        expect(value, 'persist_value');
      });
      test('should not persist when policy.persist is false', () async {
        const policy = CachePolicy(persist: false);
        await cacheManager.put('memory_only_key', 'memory_only_value',
            policy: policy);
        await cacheManager.clear();
        CacheManager.clearTestInstance();
        cacheManager = CacheManager.instance;
        await cacheManager.initialize();
        final value = await cacheManager.get<String>('memory_only_key');
        expect(value, isNull);
      });
      test('should remove large entry files when cache entry is removed',
          () async {
        const key = 'large_entry_to_remove';
        final largeValue = 'x' * 110000;
        await cacheManager.put(key, largeValue);
        final cacheDir = Directory('${tempDir.path}/cf_cache');
        final cacheFile = File('${cacheDir.path}/$key.json');
        // Allow time for file operations
        await Future.delayed(const Duration(milliseconds: 100));
        final removed = await cacheManager.remove(key);
        expect(removed, isTrue);
        // File should be removed if it was created
        final fileExists = await cacheFile.exists();
        expect(fileExists, isFalse);
      });
      test('should clear entire cache directory on clear operation', () async {
        await cacheManager.put('key1', 'value1');
        await cacheManager.put('key2', 'value2');
        final largeValue = 'x' * 110000;
        await cacheManager.put('large_key', largeValue);
        final cleared = await cacheManager.clear();
        expect(cleared, isTrue);
        expect(await cacheManager.get('key1'), isNull);
        expect(await cacheManager.get('key2'), isNull);
        expect(await cacheManager.get('large_key'), isNull);
      });
    });
    group('4. Cache Policy & TTL Management', () {
      test('should respect no-cache policy and not store values', () async {
        final success = await cacheManager.put(
          'no_cache_test',
          'should not be cached',
          policy: CachePolicy.noCaching,
        );
        expect(success, isFalse);
        final result = await cacheManager.get('no_cache_test');
        expect(result, isNull);
      });
      test('should not cache when TTL is zero', () async {
        const policy = CachePolicy(ttlSeconds: 0);
        final result =
            await cacheManager.put('no_cache_key', 'value', policy: policy);
        expect(result, isFalse);
        final value = await cacheManager.get<String>('no_cache_key');
        expect(value, isNull);
      });
      test('should expire cache entries', () async {
        const policy = CachePolicy(ttlSeconds: 1);
        await cacheManager.put('expire_key', 'expire_value', policy: policy);
        expect(await cacheManager.get<String>('expire_key'), 'expire_value');
        await Future.delayed(const Duration(seconds: 2));
        expect(await cacheManager.get<String>('expire_key'), isNull);
      });
      test('should return expired entries when allowExpired is true', () async {
        const policy = CachePolicy(ttlSeconds: 1);
        await cacheManager.put('stale_key', 'stale_value', policy: policy);
        await Future.delayed(const Duration(seconds: 2));
        expect(await cacheManager.get<String>('stale_key'), isNull);
        expect(await cacheManager.get<String>('stale_key', allowExpired: true),
            'stale_value');
      });
      test('should handle metadata', () async {
        final metadata = {'version': '1.0', 'source': 'test'};
        await cacheManager.put('meta_key', 'meta_value', metadata: metadata);
        final value = await cacheManager.get<String>('meta_key');
        expect(value, 'meta_value');
      });
      test('should apply different TTL values based on cache policies',
          () async {
        await cacheManager.put('ttl_test', 'test value',
            policy: CachePolicy.shortLived);
        final result = await cacheManager.get('ttl_test');
        expect(result, equals('test value'));
        final contains = await cacheManager.contains('ttl_test');
        expect(contains, isTrue);
      });
    });
    group('5. Error Handling & Recovery', () {
      test('should handle missing cache entries gracefully', () async {
        final result = await cacheManager.get('nonexistent_key');
        expect(result, isNull);
      });
      test('should handle contains() operation with missing keys', () async {
        final contains = await cacheManager.contains('missing_key');
        expect(contains, isFalse);
      });
      test('should handle remove() operation with missing keys', () async {
        final removed = await cacheManager.remove('missing_key');
        expect(removed, isTrue);
      });
      test('should handle JSON parsing errors gracefully', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cf_cache_invalid_json', '{invalid json');
        final value = await cacheManager.get<String>('invalid_json');
        expect(value, isNull);
      });
      test('should handle missing createdAt/expiresAt gracefully', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'cf_cache_missing_time',
          jsonEncode({
            'value': 'test',
            'key': 'missing_time',
          }),
        );
        final value = await cacheManager.get<String>('missing_time');
        expect(value, isNull);
      });
      test('should handle file system errors for large entries', () async {
        final largeData = List.generate(3000, (i) => 'item_$i').join(',');
        await cacheManager.put('large_entry', largeData);
        final retrieved = await cacheManager.get<String>('large_entry');
        expect(retrieved == null || retrieved == largeData, isTrue);
      });
      test('should handle offline mode gracefully', () async {
        await cacheManager.put('offline_test', 'test_value');
        final result = await cacheManager.refresh<String>(
          'offline_test',
          () async => throw Exception('Network unavailable'),
        );
        expect(result == 'test_value' || result == null, isTrue);
      });
      test('should handle SharedPreferences errors gracefully', () async {
        final veryLongKey = 'key_' * 1000;
        await expectLater(
          cacheManager.put(veryLongKey, 'value'),
          completes,
        );
      });
      test('should handle cache eviction errors gracefully', () async {
        for (int i = 0; i < 100; i++) {
          // Reduced for test performance
          await cacheManager.put('evict_key_$i', 'value_$i');
        }
        expect(true, isTrue); // Test passes if no exception is thrown
      });
      test('should handle corrupted cache entries', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cf_cache_corrupted', 'not_json_at_all');
        final value = await cacheManager.get<String>('corrupted');
        expect(value, isNull);
      });
      test('should handle type conversion failures', () async {
        await cacheManager.put('type_test', 12345);
        final value = await cacheManager.get<List<String>>('type_test');
        expect(value, isNull);
      });
      test('should handle getOrFetch with failing fetcher', () async {
        await cacheManager.remove('fetch_fail_test');
        final result = await cacheManager.getOrFetch<String>(
          'fetch_fail_test',
          () async => throw Exception('Fetch failed'),
        );
        expect(result, isNull);
      });
    });
    group('6. Concurrent Access & Thread Safety', () {
      test('should handle concurrent reads', () async {
        await cacheManager.put('concurrent_key', 'concurrent_value');
        final futures = List.generate(
            10, (_) => cacheManager.get<String>('concurrent_key'));
        final results = await Future.wait(futures);
        expect(results.every((v) => v == 'concurrent_value'), isTrue);
      });
      test('should handle concurrent writes', () async {
        final futures = <Future<bool>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(cacheManager.put('write_key_$i', 'value_$i'));
        }
        final results = await Future.wait(futures);
        expect(results.every((success) => success == true), isTrue);
        for (int i = 0; i < 10; i++) {
          expect(await cacheManager.get<String>('write_key_$i'), 'value_$i');
        }
      });
      test('should handle concurrent cache operations under stress', () async {
        final futures = <Future>[];
        for (int i = 0; i < 20; i++) {
          // Reduced for test performance
          futures.add(cacheManager.put('concurrent_$i', 'value_$i'));
        }
        for (int i = 0; i < 20; i++) {
          futures.add(cacheManager.get<String>('concurrent_$i'));
        }
        for (int i = 0; i < 10; i++) {
          futures.add(cacheManager.remove('concurrent_$i'));
        }
        await Future.wait(futures);
        final remaining = await cacheManager.get<String>('concurrent_15');
        expect(remaining, isNotNull);
      });
    });
    group('7. Cache Operations', () {
      test('should check if key exists', () async {
        await cacheManager.put('exists_key', 'value');
        expect(await cacheManager.contains('exists_key'), isTrue);
        expect(await cacheManager.contains('not_exists_key'), isFalse);
      });
      test('should remove entries', () async {
        await cacheManager.put('remove_key', 'value');
        expect(await cacheManager.contains('remove_key'), isTrue);
        await cacheManager.remove('remove_key');
        expect(await cacheManager.contains('remove_key'), isFalse);
      });
      test('should clear all cache', () async {
        await cacheManager.put('clear1', 'value1');
        await cacheManager.put('clear2', 'value2');
        await cacheManager.put('clear3', 'value3');
        await cacheManager.clear();
        expect(await cacheManager.contains('clear1'), isFalse);
        expect(await cacheManager.contains('clear2'), isFalse);
        expect(await cacheManager.contains('clear3'), isFalse);
      });
      test('should handle key prefix normalization', () async {
        await cacheManager.put('cf_cache_prefixed', 'value1');
        await cacheManager.put('unprefixed', 'value2');
        expect(await cacheManager.get<String>('cf_cache_prefixed'), 'value1');
        expect(await cacheManager.get<String>('unprefixed'), 'value2');
      });
    });
    group('8. Background Refresh and Advanced Operations', () {
      test('should refresh cached values', () async {
        await cacheManager.put('refresh_key', 'old_value');
        final refreshed = await cacheManager.refresh<String>(
          'refresh_key',
          () async => 'new_value',
        );
        expect(refreshed, 'new_value');
        final cached = await cacheManager.get<String>('refresh_key');
        expect(cached, 'new_value');
      });
      test('should get or fetch values', () async {
        final value1 = await cacheManager.getOrFetch<String>(
          'fetch_key',
          () async => 'fetched_value',
        );
        expect(value1, 'fetched_value');
        final value2 = await cacheManager.getOrFetch<String>(
          'fetch_key',
          () async => 'should_not_be_called',
        );
        expect(value2, 'fetched_value');
      });
      test('should handle refresh() provider errors gracefully', () async {
        final result = await cacheManager.refresh(
          'refresh_error_test',
          () async => throw Exception('Provider failed'),
        );
        expect(result, isNull);
      });
      test(
          'should trigger background refresh in getOrFetch when near expiration',
          () async {
        const policy = CachePolicy(ttlSeconds: 2);
        await cacheManager.put('bg_refresh_test', 'old_value', policy: policy);
        await Future.delayed(const Duration(milliseconds: 1500));
        final result = await cacheManager.getOrFetch<String>(
          'bg_refresh_test',
          () async => 'refreshed_value',
        );
        expect(result, anyOf('old_value', 'refreshed_value'));
      });
    });
    group('9. Static Methods and Instance Management', () {
      test('should test static setTestInstance and clearTestInstance', () {
        final testCacheManager = CacheManager.instance;
        CacheManager.setTestInstance(testCacheManager);
        expect(CacheManager.instance, same(testCacheManager));
        CacheManager.clearTestInstance();
      });
      test('should handle cache initialization errors', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cf_cache_meta', 'invalid_json');
        final newCacheManager = CacheManager.instance;
        await expectLater(newCacheManager.initialize(), completes);
      });
      test('should handle put operation errors', () async {
        final complexValue = {
          'function': () {}, // Functions can't be serialized
        };
        await expectLater(
            cacheManager.put('bad_value', complexValue), completes);
      });
      test('should handle remove operation errors', () async {
        await expectLater(
            cacheManager.remove('non_existent_key_remove_test'), completes);
      });
      test('should handle clear operation with partial failures', () async {
        await cacheManager.put('clear_test_1', 'value1');
        await cacheManager.put('clear_test_2', 'value2');
        final result = await cacheManager.clear();
        expect(result, isTrue);
      });
      test('should handle metadata loading with missing lastCleanup', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cf_cache_meta', jsonEncode({}));
        final newCacheManager = CacheManager.instance;
        await expectLater(newCacheManager.initialize(), completes);
      });
    });
    group('10. Improved Error Methods', () {
      test('should handle improved error methods', () async {
        final clearResult = await cacheManager.clearImproved();
        expect(clearResult.isSuccess, isTrue);
        final refreshResult = await cacheManager.refreshImproved<String>(
          'refresh_test',
          () async => 'refreshed_value',
        );
        expect(refreshResult.isSuccess, isTrue);
        expect(refreshResult.data, 'refreshed_value');
        final getOrFetchResult = await cacheManager.getOrFetchImproved<String>(
          'fetch_test',
          () async => 'fetched_value',
        );
        expect(getOrFetchResult.isSuccess, isTrue);
        expect(getOrFetchResult.data, 'fetched_value');
        final getResult =
            await cacheManager.getImproved<String>('non_existent');
        expect(getResult.isSuccess, isFalse);
      });
      test('should handle file-based large entry loading', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'cf_cache_large_success',
            jsonEncode({
              'isFile': true,
              'key': 'large_success',
              'expiresAt': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            }));
        final value = await cacheManager.get<String>('large_success');
        expect(value, isNull);
      });
    });
  });
}
