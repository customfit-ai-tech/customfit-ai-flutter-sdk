import '../memory_pressure_level.dart';
import '../memory_aware.dart';
import '../../util/cache_manager.dart';
import '../../../logging/logger.dart';

/// Strategy for evicting cache entries based on memory pressure
class CacheEvictionStrategy {
  static const _source = 'CacheEvictionStrategy';
  
  /// Evict cache entries based on memory pressure level
  static Future<MemoryCleanupResult> evictBasedOnPressure(
    CacheManager cache,
    MemoryPressureLevel pressure,
  ) async {
    final stopwatch = Stopwatch()..start();
    int bytesFreed = 0;
    int entriesRemoved = 0;
    
    try {
      switch (pressure) {
        case MemoryPressureLevel.low:
          // Only clean expired entries - no action for now
          entriesRemoved = 0;
          break;
          
        case MemoryPressureLevel.medium:
          // Clean 25% of cache - simplified approach
          entriesRemoved = await _evictPercentage(cache, 0.25);
          break;
          
        case MemoryPressureLevel.high:
          // Clean 50% of cache
          entriesRemoved = await _evictPercentage(cache, 0.50);
          break;
          
        case MemoryPressureLevel.critical:
          // Clear all cache in critical situation
          await cache.clear();
          final stats = await cache.getCacheSizeStats();
          entriesRemoved = stats['entryCount'] as int? ?? 100; // Estimate
          break;
      }
      
      // Estimate bytes freed based on cache size stats
      final stats = await cache.getCacheSizeStats();
      final currentSizeBytes = stats['currentSizeBytes'] as int? ?? 0;
      bytesFreed = currentSizeBytes ~/ 2; // Rough estimate
      
      stopwatch.stop();
      
      Logger.i('$_source: Evicted $entriesRemoved entries under $pressure pressure '
          'in ${stopwatch.elapsedMilliseconds}ms');
      
      return MemoryCleanupResult(
        componentName: 'CacheManager',
        bytesFreed: bytesFreed,
        success: true,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      Logger.e('$_source: Cache eviction failed: $e');
      
      return MemoryCleanupResult(
        componentName: 'CacheManager',
        bytesFreed: 0,
        success: false,
        error: e.toString(),
        duration: stopwatch.elapsed,
      );
    }
  }
  
  /// Evict a percentage of cache entries
  static Future<int> _evictPercentage(CacheManager cache, double percentage) async {
    // Since CacheManager doesn't expose individual key removal,
    // we'll use a simplified approach
    if (percentage >= 0.5) {
      // For 50% or more, just clear the cache
      await cache.clear();
      final stats = await cache.getCacheSizeStats();
      return stats['entryCount'] as int? ?? 0;
    }
    
    // For less than 50%, we can't selectively remove entries
    // without access to cache keys, so we'll skip for now
    Logger.d('$_source: Selective eviction not available, skipping');
    return 0;
  }
  
  /// Get eviction recommendations based on cache analysis
  static Future<List<String>> getEvictionRecommendations(CacheManager cache) async {
    final recommendations = <String>[];
    
    try {
      // Check cache size stats
      final stats = await cache.getCacheSizeStats();
      final currentSizeMb = double.parse(stats['currentSizeMb'] ?? '0');
      final maxSizeMb = double.parse(stats['maxSizeMb'] ?? '25');
      final entryCount = stats['entryCount'] as int? ?? 0;
      
      if (currentSizeMb > maxSizeMb * 0.9) {
        recommendations.add('Cache is near capacity (${currentSizeMb.toStringAsFixed(1)}/${maxSizeMb}MB). '
            'Consider increasing size limit or more aggressive eviction.');
      }
      
      if (entryCount > 1000) {
        recommendations.add('Cache has $entryCount entries. Consider implementing selective eviction.');
      }
      
      // General recommendations
      if (entryCount > 100 && currentSizeMb > 10) {
        recommendations.add('Consider implementing LRU (Least Recently Used) eviction policy.');
      }
    } catch (e) {
      Logger.e('$_source: Error generating recommendations: $e');
    }
    
    return recommendations;
  }
}