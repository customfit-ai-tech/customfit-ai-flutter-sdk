import 'dart:convert';
import 'dart:async';
import '../../logging/logger.dart';
import '../../services/preferences_service.dart';

/// Cache policy to control caching behavior
class CachePolicy {
  final int ttlSeconds;
  final bool useStaleWhileRevalidate;
  final bool evictOnAppRestart;
  final bool persist;

  const CachePolicy({
    this.ttlSeconds = 3600, // 1 hour default
    this.useStaleWhileRevalidate = true,
    this.evictOnAppRestart = false,
    this.persist = true,
  });

  /// No caching policy - always fetch fresh
  static const noCache = CachePolicy(
    ttlSeconds: 0,
    useStaleWhileRevalidate: false,
    evictOnAppRestart: true,
    persist: false,
  );

  /// Short-lived cache (1 minute)
  static const shortLived = CachePolicy(
    ttlSeconds: 60,
    useStaleWhileRevalidate: true,
    evictOnAppRestart: true,
    persist: true,
  );

  /// Standard cache (1 hour)
  static const standard = CachePolicy(
    ttlSeconds: 3600,
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );

  /// Default config cache policy (7 days)
  static const configCache = CachePolicy(
    ttlSeconds: 7 * 24 * 60 * 60, // 7 days (604800 seconds)
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );

  /// User data cache (24 hours)
  static const userData = CachePolicy(
    ttlSeconds: 24 * 60 * 60, // 24 hours
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );

  /// Long-lived cache (24 hours) - alias for userData
  static const longLived = userData;
}

/// Manages caching of configuration responses
/// This enables immediate access to cached configurations on startup
/// while still fetching updated configurations from the server.
class ConfigCache {
  static const String _configCacheKey = 'cf_config_data';
  static const String _metadataCacheKey = 'cf_config_metadata';

  // In-memory cache for fast access
  final Map<String, dynamic> _memoryConfigCache = {};
  final Map<String, dynamic> _memoryMetadataCache = {};

  // Cache locks for thread safety
  final _cacheLock = Object();

  // Reference to last known values for fast access
  String? _lastModifiedRef;
  String? _eTagRef;

  /// Cache configuration data
  ///
  /// [configMap] The configuration map to cache
  /// [lastModified] The Last-Modified header value
  /// [etag] The ETag header value
  /// [policy] Cache policy to use
  /// Returns `Future<bool>` true if successfully cached, false otherwise
  Future<bool> cacheConfig(
    Map<String, dynamic> configMap,
    String? lastModified,
    String? etag, {
    CachePolicy policy = CachePolicy.configCache,
  }) async {
    try {
      // No caching if TTL is 0
      if (policy.ttlSeconds <= 0) {
        return false;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = now + (policy.ttlSeconds * 1000);

      // Store metadata
      final metadata = {
        'lastModified': lastModified ?? '',
        'etag': etag ?? '',
        'timestamp': now,
        'expiresAt': expiresAt,
      };

      // Update in-memory cache
      synchronized(() {
        _memoryConfigCache[_configCacheKey] = configMap;
        _memoryMetadataCache[_metadataCacheKey] = metadata;
        _lastModifiedRef = lastModified;
        _eTagRef = etag;
      });

      // Only persist if policy allows
      if (policy.persist) {
        // Get shared prefs instance
        final prefsService = await PreferencesService.getInstance();

        // Sanitize config map to handle NaN and Infinity values
        final sanitizedConfigMap = _sanitizeForJson(configMap);

        // Serialize the config map to JSON
        final configJson = jsonEncode(sanitizedConfigMap);
        final metadataJson = jsonEncode(metadata);

        // Save both to shared preferences
        await prefsService.setString(_configCacheKey, configJson);
        await prefsService.setString(_metadataCacheKey, metadataJson);
      }

      Logger.d(
          'CACHE: Stored ${configMap.length} config entries (TTL: ${policy.ttlSeconds}s)');

      return true;
    } catch (e) {
      Logger.e('Error caching configuration: $e');
      return false;
    }
  }

  /// Get cached configuration data
  ///
  /// [allowExpired] Whether to return expired entries (stale-while-revalidate)
  /// Returns `Future<ConfigCacheResult>` containing configuration map, Last-Modified value, and ETag value
  Future<ConfigCacheResult> getCachedConfig({bool allowExpired = false}) async {
    try {
      // First check memory cache for the fastest path
      ConfigCacheResult? memoryResult;
      synchronized(() {
        final cachedConfig = _memoryConfigCache[_configCacheKey];
        final cachedMetadata = _memoryMetadataCache[_metadataCacheKey];

        if (cachedConfig != null && cachedMetadata != null) {
          final expiresAt = cachedMetadata['expiresAt'] as int?;
          final now = DateTime.now().millisecondsSinceEpoch;

          // If not expired or we allow stale data
          if ((expiresAt != null && now < expiresAt) || allowExpired) {
            final lastModified = cachedMetadata['lastModified'] as String?;
            final etag = cachedMetadata['etag'] as String?;

            Logger.d(
                'CACHE: Memory hit (${(cachedConfig as Map).length} entries)');
            memoryResult = ConfigCacheResult(
                cachedConfig as Map<String, dynamic>, lastModified, etag);
          }
        }
      });

      // Return the memory result if we found one
      if (memoryResult != null) {
        return Future<ConfigCacheResult>.value(memoryResult);
      }

      // Not found in memory or expired, try persistent storage
      final prefsService = await PreferencesService.getInstance();

      // Get cached config data
      final configJson = await prefsService.getString(_configCacheKey);
      final metadataJson = await prefsService.getString(_metadataCacheKey);

      if (configJson == null ||
          configJson.isEmpty ||
          metadataJson == null ||
          metadataJson.isEmpty) {
        Logger.d('CACHE: No persistent data found');
        return Future<ConfigCacheResult>.value(
            ConfigCacheResult(null, null, null));
      }

      try {
        // Parse the data with additional null safety
        final configDecoded = jsonDecode(configJson);
        final metadataDecoded = jsonDecode(metadataJson);

        if (configDecoded == null || metadataDecoded == null) {
          Logger.w(
              'JSON decode returned null values, clearing corrupted cache');
          await clearCache();
          return Future<ConfigCacheResult>.value(
              ConfigCacheResult(null, null, null));
        }

        if (configDecoded is! Map || metadataDecoded is! Map) {
          Logger.w(
              'JSON decode returned non-Map values, clearing corrupted cache');
          await clearCache();
          return Future<ConfigCacheResult>.value(
              ConfigCacheResult(null, null, null));
        }

        final configMap = Map<String, dynamic>.from(configDecoded);
        final metadata = Map<String, dynamic>.from(metadataDecoded);

        final lastModified = metadata['lastModified'] as String?;
        final etag = metadata['etag'] as String?;
        final expiresAt = metadata['expiresAt'] as int?;

        // Check if cache is still valid
        final now = DateTime.now().millisecondsSinceEpoch;
        final isExpired = expiresAt == null || now > expiresAt;

        // If expired and not allowing expired entries, return null
        if (isExpired && !allowExpired) {
          Logger.d('CACHE: Expired, not using stale data');
          return Future<ConfigCacheResult>.value(
              ConfigCacheResult(null, null, null));
        }

        // Update in-memory cache
        synchronized(() {
          _memoryConfigCache[_configCacheKey] = configMap;
          _memoryMetadataCache[_metadataCacheKey] = metadata;
          _lastModifiedRef = lastModified;
          _eTagRef = etag;
        });

        Logger.d(
            'CACHE: Found ${configMap.length} entries${isExpired ? " (expired, stale-while-revalidate)" : ""}');

        return Future<ConfigCacheResult>.value(
            ConfigCacheResult(configMap, lastModified, etag));
      } catch (jsonError) {
        Logger.w('Failed to parse cached JSON data: $jsonError');
        // Clear corrupted cache
        await clearCache();
        return Future<ConfigCacheResult>.value(
            ConfigCacheResult(null, null, null));
      }
    } catch (e) {
      Logger.e('Error retrieving cached configuration: $e');

      // Try to return in-memory refs as last resort
      if (allowExpired) {
        final lastModified = _lastModifiedRef;
        final etag = _eTagRef;
        if (lastModified != null || etag != null) {
          Logger.d('Returning in-memory metadata refs as emergency fallback');
          return Future<ConfigCacheResult>.value(
              ConfigCacheResult(null, lastModified, etag));
        }
      }

      return Future<ConfigCacheResult>.value(
          ConfigCacheResult(null, null, null));
    }
  }

  /// Clear cached configuration data
  Future<bool> clearCache() async {
    try {
      // Clear memory cache
      synchronized(() {
        _memoryConfigCache.clear();
        _memoryMetadataCache.clear();
        _lastModifiedRef = null;
        _eTagRef = null;
      });

      // Clear persistent storage
      final prefsService = await PreferencesService.getInstance();
      await prefsService.remove(_configCacheKey);
      await prefsService.remove(_metadataCacheKey);

      Logger.d('CACHE: Cleared');
      return true;
    } catch (e) {
      Logger.e('Error clearing configuration cache: $e');
      return false;
    }
  }

  /// Sanitize a map for JSON encoding by handling NaN and Infinity values
  Map<String, dynamic> _sanitizeForJson(Map<String, dynamic> map) {
    final sanitized = <String, dynamic>{};

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;

      sanitized[key] = _sanitizeValue(value);
    }

    return sanitized;
  }

  /// Sanitize a single value for JSON encoding
  dynamic _sanitizeValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _sanitizeForJson(value);
    } else if (value is List) {
      return value.map(_sanitizeValue).toList();
    } else if (value is double) {
      if (value.isNaN) {
        return null; // Convert NaN to null
      } else if (value.isInfinite) {
        return value.isNegative
            ? -double.maxFinite
            : double.maxFinite; // Convert Infinity to max finite values
      }
      return value;
    } else {
      return value;
    }
  }

  /// Perform a simple locking operation for thread safety
  void synchronized(void Function() action) {
    // This is a simple synchronization mechanism
    // In more complex scenarios, consider using a proper lock
    synchronizedInner(_cacheLock, action);
  }

  // Helper for synchronization
  void synchronizedInner(Object lock, void Function() action) {
    action();
  }
}

/// Class to hold cache result values
class ConfigCacheResult {
  final Map<String, dynamic>? configMap;
  final String? lastModified;
  final String? etag;

  ConfigCacheResult(this.configMap, this.lastModified, this.etag);
}
