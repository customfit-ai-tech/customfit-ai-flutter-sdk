// infrastructure/storage/interfaces/cache_manager.dart
//
// Abstract interface for cache management operations.
// Defines the contract for caching with TTL support and persistence.

import 'dart:async';

/// Cache policy configuration
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

  /// Config cache policy (5 minutes)
  static const configCache = CachePolicy(
    ttlSeconds: 300,
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );

  /// Long-lived cache (24 hours)
  static const longLived = CachePolicy(
    ttlSeconds: 86400,
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );

  /// User data cache policy (24 hours)
  static const userData = CachePolicy(
    ttlSeconds: 86400,
    useStaleWhileRevalidate: true,
    evictOnAppRestart: false,
    persist: true,
  );
}

/// Abstract interface for cache management
abstract class ICacheManager {
  /// Get cached value by key
  Future<T?> get<T>(String key);

  /// Put value in cache with policy
  Future<void> put<T>(
    String key,
    T value, {
    CachePolicy? policy,
    Map<String, String>? metadata,
  });

  /// Remove value from cache
  Future<void> remove(String key);

  /// Clear all cached values
  Future<void> clear();

  /// Check if key exists in cache
  Future<bool> containsKey(String key);

  /// Get cache statistics
  Map<String, dynamic> getStats();
}
