// lib/src/core/util/cache_manager.dart
//
// Centralized cache management for the CustomFit SDK.
// Provides a unified caching layer with TTL support, size limits, persistence,
// and memory/disk tiering for optimal performance and resource usage.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../logging/logger.dart';
import '../../services/preferences_service.dart';
import '../util/synchronization.dart';
import 'cache_size_manager.dart';
import 'type_conversion_strategy.dart';
import '../error/cf_result.dart';
import '../error/error_category.dart';
import '../error/cf_error_code.dart';
import '../memory/memory_aware.dart';
import '../memory/memory_pressure_level.dart';
import '../memory/strategies/cache_eviction_strategy.dart';

/// Private cache constants to avoid const access issues
class _CacheConstants {
  static const int refreshThresholdPercent = 10;
  static const int maxCacheSizeBytes = 100000;
  static const int complexObjectSizeEstimate = 1024;
}

/// CacheEntry represents a cached value with metadata
class CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String key;
  final Map<String, String>? metadata;

  CacheEntry({
    required this.value,
    required this.expiresAt,
    required this.createdAt,
    required this.key,
    this.metadata,
  });

  /// Check if this entry has expired
  bool isExpired() {
    return DateTime.now().isAfter(expiresAt);
  }

  /// Calculate how many seconds until this entry expires
  int secondsUntilExpiration() {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return 0;
    return expiresAt.difference(now).inSeconds;
  }

  /// Convert to a JSON representation for storage
  Map<String, dynamic> toJson() {
    return {
      'value': value is Map || value is List ? value : value.toString(),
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'key': key,
      'metadata': metadata,
    };
  }

  /// Create a CacheEntry from JSON (for primitive types)
  static CacheEntry fromJson(Map<String, dynamic> json) {
    dynamic value = json['value'];

    // For primitive types, we'll return as string and let the caller handle conversion
    // Complex objects remain as their original types
    if (value is! Map && value is! List) {
      value = value.toString();
    }

    return CacheEntry(
      value: value,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      key: json['key'],
      metadata: json['metadata'] != null
          ? Map<String, String>.from(json['metadata'])
          : null,
    );
  }
}

/// Cache policy to control caching behavior
class CachePolicy {
  /// Cache TTL in seconds
  final int ttlSeconds;

  /// Whether to use stale data while refreshing
  final bool useStaleWhileRevalidate;

  /// Whether to evict on app restart
  final bool evictOnAppRestart;

  /// Whether to persist to disk (vs memory only)
  final bool persist;

  const CachePolicy({
    this.ttlSeconds = 3600, // 1 hour default
    this.useStaleWhileRevalidate = true,
    this.evictOnAppRestart = false,
    this.persist = true,
  });

  /// No caching policy - always fetch fresh
  static const noCaching = CachePolicy(
    ttlSeconds: 0,
    useStaleWhileRevalidate: false,
    evictOnAppRestart: true,
    persist: false,
  );

  /// Short-lived cache (1 minute)
  static const shortLived = CachePolicy(
    ttlSeconds: 60, // CFConstants.cache.shortLivedTtlSeconds
    useStaleWhileRevalidate: true,
    evictOnAppRestart: true,
    persist: true,
  );

  /// Standard cache (1 hour)
  static const standard = CachePolicy(
    ttlSeconds: 3600, // CFConstants.cache.defaultTtlSeconds
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );

  /// Config cache policy (5 minutes)
  static const configCache = CachePolicy(
    ttlSeconds: 300, // CFConstants.cache.mediumLivedTtlSeconds
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );

  /// Long-lived cache (24 hours)
  static const longLived = CachePolicy(
    ttlSeconds: 86400, // CFConstants.cache.longLivedTtlSeconds
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );

  /// User data cache policy (24 hours)
  static const userData = CachePolicy(
    ttlSeconds: 86400, // 24 hours
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );
}

/// CacheManager provides persistent caching for configurations with TTL
class CacheManager implements MemoryAware {
  static const String _keyPrefix = "cf_cache_";
  static const String _cacheMetaKey = "${_keyPrefix}meta";
  static const String _cacheDir = "cf_cache";

  // In-memory cache for faster access
  final Map<String, CacheEntry<dynamic>> _memoryCache = {};

  // Lock for cache operations - using ReadWriteLock for better concurrency
  final ReadWriteLock _cacheLock = ReadWriteLock();

  // Type conversion manager for extensible type conversion
  final TypeConversionManager _typeConverter = TypeConversionManager();

  // Singleton instance
  static CacheManager? _instance;

  // Test instance for unit testing
  static CacheManager? _testInstance;

  // Private constructor
  CacheManager._();

  /// Get the singleton instance
  static CacheManager get instance {
    // Return test instance if set (for unit testing)
    if (_testInstance != null) {
      return _testInstance!;
    }
    _instance ??= CacheManager._();
    return _instance!;
  }

  /// Set a test instance for unit testing
  static void setTestInstance(CacheManager testInstance) {
    _testInstance = testInstance;
  }

  /// Clear the test instance
  static void clearTestInstance() {
    _testInstance = null;
  }

  /// Initialize the cache system
  Future<void> initialize() async {
    try {
      Logger.d('Initializing cache manager');
      await _loadCacheMetadata();
      await _performCacheCleanup();
    } catch (e) {
      Logger.e('Error initializing cache: $e');
    }
  }

  /// Put a value in the cache with the given policy
  Future<bool> put<T>(
    String key,
    T value, {
    CachePolicy policy = CachePolicy.standard,
    Map<String, String>? metadata,
  }) async {
    try {
      // No caching if TTL is 0
      if (policy.ttlSeconds <= 0) {
        return false;
      }

      key = _normalizeKey(key);

      final now = DateTime.now();
      final expiresAt = now.add(Duration(seconds: policy.ttlSeconds));

      final entry = CacheEntry<T>(
        value: value,
        expiresAt: expiresAt,
        createdAt: now,
        key: key,
        metadata: metadata,
      );

      // Update memory cache with write lock
      await _cacheLock.withWriteLock(() async {
        _memoryCache[key] = entry;
      });

      // Track cache size
      trackCacheEntrySize(key, value);

      // Persist entry if policy requires it
      if (policy.persist) {
        await _persistEntry(key, entry);
      }

      Logger.d('Cached value for key $key, expires in ${policy.ttlSeconds}s');
      return true;
    } catch (e) {
      Logger.e('Error caching value: $e');
      return false;
    }
  }

  /// Get a value from cache
  /// Returns null if not found or expired (unless allowExpired is true)
  Future<T?> get<T>(String key, {bool allowExpired = false}) async {
    key = _normalizeKey(key);

    // First check memory cache with read lock
    final memoryEntry = await _cacheLock.withReadLock<CacheEntry?>(
      () async => _memoryCache[key],
    );

    if (memoryEntry != null) {
      // If not expired or explicitly allowing expired entries
      if (!memoryEntry.isExpired() || allowExpired) {
        // Silent - cache hits are normal
        final result = _typeConverter.convertValue<T>(memoryEntry.value);
        return result.getOrNull();
      } else {
        // Silent - expired cache entries are normal
      }
    }

    // If not in memory, try persistent storage
    try {
      final prefsService = await PreferencesService.getInstance();
      final jsonString = await prefsService.getString('$_keyPrefix$key');

      if (jsonString != null) {
        // Parse JSON and create a cache entry
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

        // Check if this is a file-based large entry
        if (jsonMap['isFile'] == true) {
          // Load large entry from file
          final fileEntry = await _loadLargeEntry(key);
          if (fileEntry != null) {
            // Update memory cache with loaded entry using write lock
            await _cacheLock.withWriteLock(() async {
              _memoryCache[key] = fileEntry;
            });

            // If not expired or explicitly allowing expired entries
            if (!fileEntry.isExpired() || allowExpired) {
              // Silent - cache hits are normal
              final result = _typeConverter.convertValue<T>(fileEntry.value);
              return result.getOrNull();
            } else {
              // Silent - expired cache entries are normal
            }
          }
        } else {
          // Create a new CacheEntry from stored data
          final entry = CacheEntry(
            value: jsonMap['value'],
            expiresAt:
                DateTime.fromMillisecondsSinceEpoch(jsonMap['expiresAt']),
            createdAt:
                DateTime.fromMillisecondsSinceEpoch(jsonMap['createdAt']),
            key: jsonMap['key'],
            metadata: jsonMap['metadata'] != null
                ? Map<String, String>.from(jsonMap['metadata'])
                : null,
          );

          // Update memory cache with write lock
          await _cacheLock.withWriteLock(() async {
            _memoryCache[key] = entry;
          });

          // If not expired or explicitly allowing expired entries
          if (!entry.isExpired() || allowExpired) {
            // Silent - cache hits are normal
            final result = _typeConverter.convertValue<T>(entry.value);
            return result.getOrNull();
          } else {
            // Silent - expired cache entries are normal
          }
        }
      }
    } catch (e) {
      Logger.e('Error reading from cache: $e');
    }

    // Silent - cache misses are normal
    return null;
  }

  /// Register a custom type conversion strategy
  void registerConversionStrategy(TypeConversionStrategy strategy) {
    _typeConverter.registerStrategy(strategy);
  }

  /// Remove a type conversion strategy
  void removeConversionStrategy<T extends TypeConversionStrategy>() {
    _typeConverter.removeStrategy<T>();
  }

  /// Check if a conversion strategy exists for the given type
  bool hasConversionStrategyFor(Type type) {
    return _typeConverter.hasStrategyFor(type);
  }

  /// Check if a key exists in cache and is not expired
  Future<bool> contains(String key) async {
    key = _normalizeKey(key);

    // First check memory cache with read lock
    final memoryEntry = await _cacheLock.withReadLock<CacheEntry?>(
      () async => _memoryCache[key],
    );

    if (memoryEntry != null && !memoryEntry.isExpired()) {
      return true;
    }

    // If not in memory, try persistent storage
    try {
      final prefsService = await PreferencesService.getInstance();
      final json = await prefsService.getString('$_keyPrefix$key');

      if (json != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(json);
        final expiresAt =
            DateTime.fromMillisecondsSinceEpoch(jsonMap['expiresAt']);
        return DateTime.now().isBefore(expiresAt);
      }
    } catch (e) {
      Logger.e('Error checking cache: $e');
    }

    return false;
  }

  /// Remove a value from cache
  Future<bool> remove(String key) async {
    key = _normalizeKey(key);

    await _cacheLock.withWriteLock(() async {
      _memoryCache.remove(key);
    });

    // Untrack cache size
    untrackCacheEntrySize(key);

    try {
      // Remove from persistent storage
      final prefsService = await PreferencesService.getInstance();
      final result = await prefsService.remove('$_keyPrefix$key');

      // Also try to remove any large cache file
      await _removeCacheFile(key);

      Logger.d('Removed key $key from cache: $result');
      return result;
    } catch (e) {
      Logger.e('Error removing from cache: $e');
      return false;
    }
  }

  /// Clear all cached values
  Future<bool> clear() async {
    await _cacheLock.withWriteLock(() async {
      _memoryCache.clear();
    });

    try {
      // Clear persistent storage
      final prefsService = await PreferencesService.getInstance();

      // Find all cache keys
      final keys = (await prefsService.getKeys())
          .where((k) => k.startsWith(_keyPrefix))
          .toList();

      // Remove each key
      for (final key in keys) {
        await prefsService.remove(key);
      }

      // Clear cache directory
      try {
        final dir = await _getCacheDir();
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create();
        }
      } catch (e) {
        Logger.w('Could not clear cache directory: $e');
        // Don't return error - directory cleanup is optional
        // The important part is that we cleared the cache entries
      }

      Logger.d('Cache cleared (${keys.length} entries)');
      return true;
    } catch (e) {
      Logger.e('Error clearing cache: $e');
      return false;
    }
  }

  /// Refresh a cached value using a provider function
  /// Returns the fresh value or null if refresh failed
  Future<T?> refresh<T>(
    String key,
    Future<T> Function() provider, {
    CachePolicy policy = CachePolicy.standard,
    Map<String, String>? metadata,
  }) async {
    try {
      Logger.d('Refreshing cached value for key $key');
      final freshValue = await provider();

      // Cache the fresh value
      await put<T>(
        key,
        freshValue,
        policy: policy,
        metadata: metadata,
      );

      return freshValue;
    } catch (e) {
      Logger.e('Error refreshing cached value: $e');
      return null;
    }
  }

  /// Get a value, using the provider to fetch if missing or expired
  Future<T?> getOrFetch<T>(
    String key,
    Future<T> Function() provider, {
    CachePolicy policy = CachePolicy.standard,
    Map<String, String>? metadata,
  }) async {
    key = _normalizeKey(key);

    // First try to get from cache
    final cachedValue = await get<T>(key);

    // If we have a valid cached value, return it
    if (cachedValue != null) {
      // Check if we need to refresh in background with read lock
      final entry = await _cacheLock.withReadLock<CacheEntry?>(
        () async => _memoryCache[key],
      );

      // If the entry is close to expiring (less than 10% of TTL left)
      // refresh it in the background
      if (entry != null) {
        final expirationSeconds = entry.secondsUntilExpiration();
        final refreshThreshold =
            policy.ttlSeconds ~/ _CacheConstants.refreshThresholdPercent;

        if (expirationSeconds <= refreshThreshold) {
          Logger.d('Background refreshing cache for key $key');
          // Don't await to avoid blocking
          refresh(key, provider, policy: policy, metadata: metadata);
        }
      }

      return cachedValue;
    }

    // Try to fetch fresh value
    return await refresh(key, provider, policy: policy, metadata: metadata);
  }

  /// Normalizes a cache key to avoid special characters
  String _normalizeKey(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  /// Persist a cache entry
  // ignore: unused_element
  Future<void> _persistEntry<T>(String key, CacheEntry<T> entry) async {
    final prefsService = await PreferencesService.getInstance();

    // For small values, use SharedPreferences
    final jsonEntry = jsonEncode(entry.toJson());

    // If the JSON is too large for SharedPreferences (>100KB),
    // store it in a file instead
    if (jsonEntry.length > _CacheConstants.maxCacheSizeBytes) {
      await _persistLargeEntry(key, jsonEntry);
      // Store a reference to the file in SharedPreferences
      await prefsService.setString(
          '$_keyPrefix$key',
          jsonEncode({
            'isFile': true,
            'key': key,
            'expiresAt': entry.expiresAt.millisecondsSinceEpoch,
            'createdAt': entry.createdAt.millisecondsSinceEpoch,
            'metadata': entry.metadata,
          }));
    } else {
      // Store directly in SharedPreferences
      await prefsService.setString('$_keyPrefix$key', jsonEntry);
    }
  }

  /// Store large entries in a file
  Future<void> _persistLargeEntry(String key, String jsonEntry) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$key.json');
      await file.writeAsString(jsonEntry);
      Logger.d('Stored large cache entry in file: ${file.path}');
    } catch (e) {
      Logger.e('Error storing large cache entry: $e');
    }
  }

  /// Load large entries from a file
  Future<CacheEntry?> _loadLargeEntry(String key) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$key.json');

      if (await file.exists()) {
        final jsonEntry = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(jsonEntry);

        final entry = CacheEntry(
          value: jsonMap['value'],
          expiresAt: DateTime.fromMillisecondsSinceEpoch(jsonMap['expiresAt']),
          createdAt: DateTime.fromMillisecondsSinceEpoch(jsonMap['createdAt']),
          key: jsonMap['key'],
          metadata: jsonMap['metadata'] != null
              ? Map<String, String>.from(jsonMap['metadata'])
              : null,
        );

        Logger.d('Loaded large cache entry from file: ${file.path}');
        return entry;
      }

      Logger.w('Large cache file not found for key: $key');
      return null;
    } catch (e) {
      Logger.e('Error loading large cache entry: $e');
      return null;
    }
  }

  /// Remove a cache file for large entries
  Future<void> _removeCacheFile(String key) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$key.json');
      if (await file.exists()) {
        await file.delete();
        Logger.d('Removed cache file: ${file.path}');
      }
    } catch (e) {
      Logger.e('Error removing cache file: $e');
    }
  }

  /// Get the cache directory
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDir');

    // Create the directory if it doesn't exist
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// Load cache metadata
  Future<void> _loadCacheMetadata() async {
    try {
      final prefsService = await PreferencesService.getInstance();
      final metaJson = await prefsService.getString(_cacheMetaKey);

      if (metaJson != null) {
        final meta = jsonDecode(metaJson);

        // Handle any metadata needed (e.g., last cleanup time)
        final lastCleanup = meta['lastCleanup'] ?? 0;
        Logger.d(
            'Cache last cleaned: ${DateTime.fromMillisecondsSinceEpoch(lastCleanup)}');
      }
    } catch (e) {
      Logger.e('Error loading cache metadata: $e');
    }
  }

  /// Clean up expired entries
  Future<void> _performCacheCleanup() async {
    try {
      final now = DateTime.now();
      final prefsService = await PreferencesService.getInstance();

      // Find all cache keys
      final keys = (await prefsService.getKeys())
          .where((k) => k.startsWith(_keyPrefix) && k != _cacheMetaKey)
          .toList();

      var removedCount = 0;

      // Check each key
      for (final fullKey in keys) {
        final jsonStr = await prefsService.getString(fullKey);
        if (jsonStr != null) {
          final json = jsonDecode(jsonStr);
          final expiresAt =
              DateTime.fromMillisecondsSinceEpoch(json['expiresAt']);

          // If expired, remove it
          if (now.isAfter(expiresAt)) {
            // Extract the key (remove prefix)
            final key = fullKey.substring(_keyPrefix.length);

            // Handle file-based caches
            if (json['isFile'] == true) {
              await _removeCacheFile(key);
            }

            await prefsService.remove(fullKey);
            removedCount++;
          }
        }
      }

      // Update metadata with last cleanup time
      await prefsService.setString(
          _cacheMetaKey,
          jsonEncode({
            'lastCleanup': now.millisecondsSinceEpoch,
          }));

      Logger.d('Cache cleanup complete: removed $removedCount expired entries');
    } catch (e) {
      Logger.e('Error during cache cleanup: $e');
    }
  }

  /// Get cache size statistics - stub implementation for memory management
  Future<Map<String, dynamic>> getCacheSizeStats() async {
    try {
      return await _cacheLock.withReadLock<Map<String, dynamic>>(() async {
        final stats = <String, dynamic>{};
        final memoryEntryCount = _memoryCache.length;

        // Calculate approximate memory usage
        var approximateMemoryBytes = 0;
        for (final entry in _memoryCache.values) {
          // Rough estimate - in reality this would be more sophisticated
          approximateMemoryBytes += entry.key.length * 2; // UTF-16 chars
          if (entry.value is String) {
            approximateMemoryBytes += (entry.value as String).length * 2;
          } else if (entry.value is Map || entry.value is List) {
            approximateMemoryBytes += _CacheConstants
                .complexObjectSizeEstimate; // Rough estimate for complex objects
          } else {
            approximateMemoryBytes += 100; // Default estimate
          }
        }

        stats['memoryEntriesCount'] = memoryEntryCount;
        stats['approximateMemoryBytes'] = approximateMemoryBytes;
        stats['approximateMemoryMB'] =
            (approximateMemoryBytes / 1024 / 1024).toStringAsFixed(2);
        stats['lastUpdated'] = DateTime.now().toIso8601String();

        return stats;
      });
    } catch (e) {
      Logger.e('Error getting cache size stats: $e');
      return {
        'error': 'Failed to get cache stats',
        'memoryEntriesCount': 0,
        'approximateMemoryBytes': 0,
      };
    }
  }

  // ========== IMPROVED ERROR HANDLING METHODS ==========

  /// Clear all cached values with improved error handling
  Future<CFResult<bool>> clearImproved() async {
    try {
      await _cacheLock.withWriteLock(() async {
        _memoryCache.clear();
      });

      // Clear persistent storage
      final prefsService = await PreferencesService.getInstance();

      // Find all cache keys
      final keys = (await prefsService.getKeys())
          .where((k) => k.startsWith(_keyPrefix))
          .toList();

      // Remove each key
      var failedRemovals = 0;
      for (final key in keys) {
        final removed = await prefsService.remove(key);
        if (!removed) failedRemovals++;
      }

      // Clear cache directory
      try {
        final dir = await _getCacheDir();
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create();
        }
      } catch (e) {
        Logger.w('Could not clear cache directory: $e');
        // Don't return error - directory cleanup is optional
        // The important part is that we cleared the cache entries
      }

      if (failedRemovals > 0) {
        return CFResult.error(
          'Failed to remove $failedRemovals cache entries',
          category: ErrorCategory.internal,
          errorCode: CFErrorCode.internalCacheError,
          context: {
            'totalEntries': keys.length,
            'failedRemovals': failedRemovals,
            'successfulRemovals': keys.length - failedRemovals,
          },
        );
      }

      Logger.d('Cache cleared (${keys.length} entries)');
      return CFResult.success(true);
    } catch (e, stackTrace) {
      Logger.e('Error clearing cache: $e');
      return CFResult.error(
        'Failed to clear cache: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalCacheError,
        context: {
          'operation': 'clear_cache',
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Refresh a cached value with improved error handling
  Future<CFResult<T>> refreshImproved<T>(
    String key,
    Future<T> Function() provider, {
    CachePolicy policy = CachePolicy.standard,
    Map<String, String>? metadata,
  }) async {
    try {
      Logger.d('Refreshing cached value for key $key');
      final freshValue = await provider();

      // Cache the fresh value
      final cached = await put<T>(
        key,
        freshValue,
        policy: policy,
        metadata: metadata,
      );

      if (!cached) {
        return CFResult.error(
          'Failed to cache refreshed value',
          category: ErrorCategory.internal,
          errorCode: CFErrorCode.internalCacheError,
          context: {
            'key': key,
            'operation': 'cache_after_refresh',
          },
        );
      }

      return CFResult.success(freshValue);
    } catch (e, stackTrace) {
      Logger.e('Error refreshing cached value: $e');
      return CFResult.error(
        'Failed to refresh cached value: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalCacheError,
        context: {
          'key': key,
          'operation': 'refresh',
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Get or fetch value with improved error handling
  Future<CFResult<T>> getOrFetchImproved<T>(
    String key,
    Future<T> Function() provider, {
    CachePolicy policy = CachePolicy.standard,
    Map<String, String>? metadata,
  }) async {
    try {
      key = _normalizeKey(key);

      // First try to get from cache
      final cachedValue = await get<T>(key);

      // If we have a valid cached value, return it
      if (cachedValue != null) {
        // Check if we need to refresh in background
        final entry = await _cacheLock.withReadLock<CacheEntry?>(
          () async => _memoryCache[key],
        );

        // If the entry is close to expiring, refresh in background
        if (entry != null) {
          final expirationSeconds = entry.secondsUntilExpiration();
          final refreshThreshold =
              policy.ttlSeconds ~/ _CacheConstants.refreshThresholdPercent;

          if (expirationSeconds <= refreshThreshold) {
            Logger.d('Background refreshing cache for key $key');
            // Don't await to avoid blocking
            refreshImproved(key, provider, policy: policy, metadata: metadata);
          }
        }

        return CFResult.success(cachedValue);
      }

      // Try to fetch fresh value
      final refreshResult = await refreshImproved(
        key,
        provider,
        policy: policy,
        metadata: metadata,
      );

      return refreshResult;
    } catch (e, stackTrace) {
      Logger.e('Error in getOrFetch: $e');
      return CFResult.error(
        'Failed to get or fetch value: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalCacheError,
        context: {
          'key': key,
          'operation': 'get_or_fetch',
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Get a value from cache with improved error handling
  Future<CFResult<T>> getImproved<T>(String key,
      {bool allowExpired = false}) async {
    try {
      key = _normalizeKey(key);

      // First check memory cache with read lock
      final memoryEntry = await _cacheLock.withReadLock<CacheEntry?>(
        () async => _memoryCache[key],
      );

      if (memoryEntry != null) {
        // If not expired or explicitly allowing expired entries
        if (!memoryEntry.isExpired() || allowExpired) {
          // Use type converter for better error handling
          final convertResult =
              _typeConverter.convertValue<T>(memoryEntry.value);
          if (convertResult.isSuccess) {
            return CFResult.success(convertResult.data as T);
          }
          return convertResult;
        } else {
          return CFResult.error(
            'Cache entry expired',
            category: ErrorCategory.validation,
            errorCode: CFErrorCode.validationInvalidContext,
            context: {
              'key': key,
              'expiredAt': memoryEntry.expiresAt.toIso8601String(),
              'reason': 'expired',
            },
          );
        }
      }

      // If not in memory, try persistent storage
      final prefsService = await PreferencesService.getInstance();
      final jsonString = await prefsService.getString('$_keyPrefix$key');

      if (jsonString != null) {
        // Parse JSON and create a cache entry
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

        // Check if this is a file-based large entry
        if (jsonMap['isFile'] == true) {
          // Load large entry from file
          final loadResult = await _loadLargeEntryImproved(key);
          if (loadResult.isSuccess && loadResult.data != null) {
            final fileEntry = loadResult.data!;

            // Update memory cache with loaded entry
            await _cacheLock.withWriteLock(() async {
              _memoryCache[key] = fileEntry;
            });

            // If not expired or explicitly allowing expired entries
            if (!fileEntry.isExpired() || allowExpired) {
              final convertResult =
                  _typeConverter.convertValue<T>(fileEntry.value);
              if (convertResult.isSuccess) {
                return CFResult.success(convertResult.data as T);
              }
              return convertResult;
            } else {
              return CFResult.error(
                'Cache entry expired',
                category: ErrorCategory.validation,
                errorCode: CFErrorCode.validationInvalidContext,
                context: {
                  'key': key,
                  'expiredAt': fileEntry.expiresAt.toIso8601String(),
                  'reason': 'expired',
                  'source': 'file',
                },
              );
            }
          }
          return loadResult as CFResult<T>;
        } else {
          // Create a new CacheEntry from stored data
          final entry = CacheEntry(
            value: jsonMap['value'],
            expiresAt:
                DateTime.fromMillisecondsSinceEpoch(jsonMap['expiresAt']),
            createdAt:
                DateTime.fromMillisecondsSinceEpoch(jsonMap['createdAt']),
            key: jsonMap['key'],
            metadata: jsonMap['metadata'] != null
                ? Map<String, String>.from(jsonMap['metadata'])
                : null,
          );

          // Update memory cache
          await _cacheLock.withWriteLock(() async {
            _memoryCache[key] = entry;
          });

          // If not expired or explicitly allowing expired entries
          if (!entry.isExpired() || allowExpired) {
            final convertResult = _typeConverter.convertValue<T>(entry.value);
            if (convertResult.isSuccess) {
              return CFResult.success(convertResult.data as T);
            }
            return convertResult;
          } else {
            return CFResult.error(
              'Cache entry expired',
              category: ErrorCategory.validation,
              errorCode: CFErrorCode.validationInvalidContext,
              context: {
                'key': key,
                'expiredAt': entry.expiresAt.toIso8601String(),
                'reason': 'expired',
                'source': 'persistent',
              },
            );
          }
        }
      }

      // Not found in cache
      return CFResult.error(
        'Cache entry not found',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.internalCacheError,
        context: {
          'key': key,
          'reason': 'not_found',
        },
      );
    } catch (e, stackTrace) {
      Logger.e('Error reading from cache: $e');
      return CFResult.error(
        'Failed to read from cache: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalCacheError,
        context: {
          'key': key,
          'operation': 'get',
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Load large entries from file with improved error handling
  Future<CFResult<CacheEntry?>> _loadLargeEntryImproved(String key) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$key.json');

      if (await file.exists()) {
        final jsonEntry = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(jsonEntry);

        final entry = CacheEntry(
          value: jsonMap['value'],
          expiresAt: DateTime.fromMillisecondsSinceEpoch(jsonMap['expiresAt']),
          createdAt: DateTime.fromMillisecondsSinceEpoch(jsonMap['createdAt']),
          key: jsonMap['key'],
          metadata: jsonMap['metadata'] != null
              ? Map<String, String>.from(jsonMap['metadata'])
              : null,
        );

        Logger.d('Loaded large cache entry from file: ${file.path}');
        return CFResult.success(entry);
      }

      return CFResult.error(
        'Large cache file not found',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.internalCacheError,
        context: {
          'key': key,
          'reason': 'file_not_found',
          'filePath': file.path,
        },
      );
    } catch (e, stackTrace) {
      Logger.e('Error loading large cache entry: $e');
      return CFResult.error(
        'Failed to load large cache entry: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalCacheError,
        context: {
          'key': key,
          'operation': 'load_large_entry',
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  // MemoryAware implementation
  @override
  String get componentName => 'CacheManager';

  @override
  int get memoryPriority => MemoryPriority.normal;

  @override
  bool get canCleanup => true;

  @override
  int get estimatedMemoryUsage {
    // Fallback to estimate since getCacheSizeStats is now async
    // This getter needs to be synchronous for compatibility
    // Return rough estimate based on stats
    return 10 * 1024 * 1024; // 10MB estimate
  }

  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    // Use the smart eviction strategy
    final result = await CacheEvictionStrategy.evictBasedOnPressure(
      this,
      level,
    );

    if (!result.success) {
      Logger.e('Cache eviction failed: ${result.error}');
    }
  }
}
