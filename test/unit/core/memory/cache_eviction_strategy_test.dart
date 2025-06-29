import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/strategies/cache_eviction_strategy.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/memory_pressure_level.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/cache_manager.dart';
// Mock for PathProvider to control file system location during tests
class MockPathProviderPlatform extends PathProviderPlatform {
  final String _tempPath;
  MockPathProviderPlatform(this._tempPath);
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _tempPath;
  }
  @override
  Future<String?> getApplicationSupportPath() async {
    return _tempPath;
  }
  @override
  Future<String?> getLibraryPath() async {
    return null;
  }
  @override
  Future<String?> getTemporaryPath() async {
    return '$_tempPath/tmp';
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CacheEvictionStrategy', () {
    late CacheManager cache;
    late Directory tempDir;
    setUp(() async {
      // Set up mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      // Create temporary directory for file system tests
      tempDir = await Directory.systemTemp.createTemp('test_cache_eviction');
      // Set up mock for PathProvider
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
      // Reset services for clean state
      PreferencesService.reset();
      CacheManager.clearTestInstance();
      cache = CacheManager.instance;
      await cache.initialize();
      await cache.clear();
      // Add test data to cache
      for (int i = 0; i < 20; i++) {
        await cache.put(
          'test_key_$i',
          'test_value_$i',
          policy: const CachePolicy(ttlSeconds: 3600),
        );
      }
      // Add some critical entries
      await cache.put(
        'config_important',
        {'setting': 'value'},
        policy: const CachePolicy(ttlSeconds: 3600),
      );
      await cache.put(
        'user_data',
        {'id': '123', 'name': 'Test'},
        policy: const CachePolicy(ttlSeconds: 3600),
      );
    });
    tearDown(() async {
      await cache.clear();
      CacheManager.clearTestInstance();
      PreferencesService.reset();
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    test('should handle low pressure by not evicting entries', () async {
      final initialStats = await cache.getCacheSizeStats();
      final initialSize = initialStats['memoryEntriesCount'] as int? ?? 0;
      final result = await CacheEvictionStrategy.evictBasedOnPressure(
        cache,
        MemoryPressureLevel.low,
      );
      expect(result.success, isTrue);
      expect(result.componentName, equals('CacheManager'));
      final finalStats = await cache.getCacheSizeStats();
      final finalSize = finalStats['memoryEntriesCount'] as int? ?? 0;
      // Low pressure should not evict any entries
      expect(finalSize, equals(initialSize));
    });
    test('should handle medium pressure', () async {
      final initialStats = await cache.getCacheSizeStats();
      final initialSize = initialStats['memoryEntriesCount'] as int? ?? 0;
      final result = await CacheEvictionStrategy.evictBasedOnPressure(
        cache,
        MemoryPressureLevel.medium,
      );
      expect(result.success, isTrue);
      final finalStats = await cache.getCacheSizeStats();
      final finalSize = finalStats['memoryEntriesCount'] as int? ?? 0;
      // Medium pressure (25%) - in our implementation it doesn't evict
      // because we can't do selective eviction
      expect(finalSize, equals(initialSize));
    });
    test('should clear cache on high pressure', () async {
      final initialStats = await cache.getCacheSizeStats();
      final initialSize = initialStats['memoryEntriesCount'] as int? ?? 0;
      expect(initialSize, greaterThan(0));
      final result = await CacheEvictionStrategy.evictBasedOnPressure(
        cache,
        MemoryPressureLevel.high,
      );
      expect(result.success, isTrue);
      // High pressure (50%) - clears entire cache in our implementation
      final finalStats = await cache.getCacheSizeStats();
      final finalSize = finalStats['memoryEntriesCount'] as int? ?? 0;
      expect(finalSize, equals(0));
    });
    test('should clear all entries under critical pressure', () async {
      final result = await CacheEvictionStrategy.evictBasedOnPressure(
        cache,
        MemoryPressureLevel.critical,
      );
      expect(result.success, isTrue);
      // All entries should be gone in critical pressure
      expect(await cache.get('config_important'), isNull);
      expect(await cache.get('user_data'), isNull);
      expect(await cache.get('test_key_0'), isNull);
      expect(await cache.get('test_key_10'), isNull);
      final finalStats = await cache.getCacheSizeStats();
      final finalSize = finalStats['memoryEntriesCount'] as int? ?? 0;
      expect(finalSize, equals(0));
    });
    test('should provide eviction recommendations', () async {
      final recommendations =
          await CacheEvictionStrategy.getEvictionRecommendations(cache);
      expect(recommendations, isA<List<String>>());
      // Add many entries to trigger recommendations
      for (int i = 100; i < 1100; i++) {
        await cache.put('bulk_key_$i', 'value_$i');
      }
      final moreRecommendations =
          await CacheEvictionStrategy.getEvictionRecommendations(cache);
      // Verify the method returns a list of strings and doesn't crash
      expect(moreRecommendations, isA<List<String>>());
    });
    test('should handle eviction errors gracefully', () async {
      // Create a scenario that might cause errors
      await cache.clear(); // Empty cache
      final result = await CacheEvictionStrategy.evictBasedOnPressure(
        cache,
        MemoryPressureLevel.high,
      );
      // Should still succeed even with empty cache
      expect(result.success, isTrue);
      expect(result.bytesFreed, greaterThanOrEqualTo(0));
    });
    test('should track eviction duration', () async {
      final result = await CacheEvictionStrategy.evictBasedOnPressure(
        cache,
        MemoryPressureLevel.medium,
      );
      expect(result.duration, isA<Duration>());
      expect(result.duration.inMicroseconds, greaterThan(0));
    });
  });
}
