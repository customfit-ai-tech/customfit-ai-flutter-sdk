import 'dart:convert';
import '../../logging/logger.dart';
import 'cache_manager.dart';

/// Callback for when entries need to be removed due to size constraints
typedef CacheEvictionCallback = Future<bool> Function(String key);

/// Encapsulated cache size management for better testability and separation of concerns
class CacheSizeManager {
  int _maxCacheSizeBytes;
  int _currentCacheSizeBytes = 0;
  final Map<String, int> _entrySizes = {};
  CacheEvictionCallback? _evictionCallback;

  /// Constructor with configurable max size
  CacheSizeManager({
    int maxSizeMb = 50, // Default 50MB
  }) : _maxCacheSizeBytes = maxSizeMb * 1024 * 1024;

  /// Set the eviction callback for when entries need to be removed
  void setEvictionCallback(CacheEvictionCallback callback) {
    _evictionCallback = callback;
  }

  /// Configure the maximum cache size in MB
  Future<void> configureMaxCacheSize(int maxSizeMb) async {
    _maxCacheSizeBytes = maxSizeMb * 1024 * 1024;
    Logger.d('Cache size limit configured to $maxSizeMb MB');
    
    // Trigger cleanup if needed
    await _enforceCacheSizeLimit();
  }

  /// Get current cache size in MB
  double getCurrentCacheSizeMb() {
    return _currentCacheSizeBytes / (1024 * 1024);
  }

  /// Get maximum cache size in MB
  double getMaxCacheSizeMb() {
    return _maxCacheSizeBytes / (1024 * 1024);
  }

  /// Track size when adding entries
  void trackCacheEntrySize(String key, dynamic value) {
    try {
      // Estimate size by converting to JSON
      final jsonStr = jsonEncode(value);
      final sizeBytes = utf8.encode(jsonStr).length;
      
      // Update size tracking
      if (_entrySizes.containsKey(key)) {
        _currentCacheSizeBytes -= _entrySizes[key]!;
      }
      
      _entrySizes[key] = sizeBytes;
      _currentCacheSizeBytes += sizeBytes;
      
      Logger.trace('Cache entry "$key" size: $sizeBytes bytes. Total cache: ${getCurrentCacheSizeMb().toStringAsFixed(2)} MB');
      
      // Check if we need to evict
      if (_currentCacheSizeBytes > _maxCacheSizeBytes) {
        // Don't await here to avoid blocking cache operations
        _enforceCacheSizeLimit();
      }
    } catch (e) {
      Logger.w('Failed to track cache entry size: $e');
    }
  }

  /// Remove size tracking for an entry
  void untrackCacheEntrySize(String key) {
    if (_entrySizes.containsKey(key)) {
      _currentCacheSizeBytes -= _entrySizes[key]!;
      _entrySizes.remove(key);
      Logger.trace('Untracked cache entry "$key". New total: ${getCurrentCacheSizeMb().toStringAsFixed(2)} MB');
    }
  }

  /// Enforce cache size limit by evicting oldest entries
  Future<void> _enforceCacheSizeLimit() async {
    if (_currentCacheSizeBytes <= _maxCacheSizeBytes) {
      return;
    }
    
    if (_evictionCallback == null) {
      Logger.w('Cache size exceeded but no eviction callback set');
      return;
    }
    
    Logger.d('Cache size ${getCurrentCacheSizeMb().toStringAsFixed(2)} MB exceeds limit ${getMaxCacheSizeMb().toStringAsFixed(2)} MB');
    
    // Calculate target size (keep 80% after eviction)
    final targetSize = (_maxCacheSizeBytes * 0.8).round();
    var removedCount = 0;
    
    // Simple eviction: remove entries until we're under target
    final keysToRemove = <String>[];
    var projectedSize = _currentCacheSizeBytes;
    
    for (final entry in _entrySizes.entries) {
      if (projectedSize <= targetSize) {
        break;
      }
      
      keysToRemove.add(entry.key);
      projectedSize -= entry.value;
      removedCount++;
    }
    
    // Remove the entries using the callback
    for (final key in keysToRemove) {
      try {
        final success = await _evictionCallback!(key);
        if (!success) {
          Logger.w('Failed to evict cache entry: $key');
        }
      } catch (e) {
        Logger.e('Error evicting cache entry $key: $e');
      }
    }
    
    Logger.d('Evicted $removedCount cache entries. New size: ${getCurrentCacheSizeMb().toStringAsFixed(2)} MB');
  }

  /// Get cache statistics including size information
  Map<String, dynamic> getCacheSizeStats() {
    return {
      'entryCount': _entrySizes.length,
      'currentSizeBytes': _currentCacheSizeBytes,
      'maxSizeBytes': _maxCacheSizeBytes,
      'currentSizeMb': getCurrentCacheSizeMb().toStringAsFixed(2),
      'maxSizeMb': getMaxCacheSizeMb().toStringAsFixed(2),
      'utilizationPercent': ((_currentCacheSizeBytes / _maxCacheSizeBytes) * 100).toStringAsFixed(1),
    };
  }

  /// Get the list of tracked entry keys
  List<String> getTrackedKeys() {
    return _entrySizes.keys.toList();
  }

  /// Get the size of a specific entry
  int? getEntrySize(String key) {
    return _entrySizes[key];
  }

  /// Check if cache is approaching size limit
  bool isApproachingLimit({double threshold = 0.9}) {
    return (_currentCacheSizeBytes / _maxCacheSizeBytes) >= threshold;
  }

  /// Clear all size tracking data
  void clearSizeTracking() {
    _entrySizes.clear();
    _currentCacheSizeBytes = 0;
    Logger.d('Cache size tracking cleared');
  }
}

/// Extension to integrate CacheSizeManager with CacheManager
extension CacheSizeManagement on CacheManager {
  // Single shared instance for backward compatibility
  static CacheSizeManager? _sizeManager;
  
  /// Get or create the size manager instance
  CacheSizeManager get _getSizeManager {
    _sizeManager ??= CacheSizeManager();
    return _sizeManager!;
  }

  /// Configure the maximum cache size in MB
  Future<void> configureMaxCacheSize(int maxSizeMb) async {
    await _getSizeManager.configureMaxCacheSize(maxSizeMb);
    // Set up the eviction callback
    _getSizeManager.setEvictionCallback((key) => remove(key));
  }

  /// Get current cache size in MB
  double getCurrentCacheSizeMb() {
    return _getSizeManager.getCurrentCacheSizeMb();
  }

  /// Get maximum cache size in MB
  double getMaxCacheSizeMb() {
    return _getSizeManager.getMaxCacheSizeMb();
  }

  /// Track size when adding entries
  void trackCacheEntrySize(String key, dynamic value) {
    _getSizeManager.trackCacheEntrySize(key, value);
  }

  /// Remove size tracking for an entry
  void untrackCacheEntrySize(String key) {
    _getSizeManager.untrackCacheEntrySize(key);
  }

  /// Clear all size tracking data
  void clearSizeTracking() {
    _getSizeManager.clearSizeTracking();
  }
}

/// Helper class to integrate cache size management with CFConfig
class CacheSizeConfigurator {
  /// Configure cache manager with size from CFConfig
  static void configureFromCFConfig(int maxCacheSizeMb) {
    final cacheManager = CacheManager.instance;
    cacheManager.configureMaxCacheSize(maxCacheSizeMb);
  }
}