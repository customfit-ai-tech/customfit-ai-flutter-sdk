// lib/src/features/graceful_degradation.dart
//
// Graceful degradation support for feature flag system.
// Provides fallback mechanisms when feature flags are unavailable.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:convert';
import '../core/error/cf_result.dart';
import '../logging/logger.dart';
import '../services/preferences_service.dart';

/// Fallback strategies for feature flag evaluation
enum FallbackStrategy {
  /// Use default value immediately
  useDefault,

  /// Try to use cached value, then default
  useCachedOrDefault,

  /// Wait for network with timeout, then use cached or default
  waitWithTimeout,

  /// Use last known good value if available
  useLastKnownGood,
}

/// Configuration for graceful degradation behavior
class GracefulDegradationConfig {
  /// Default fallback strategy
  final FallbackStrategy defaultStrategy;

  /// Timeout for wait strategies
  final Duration networkTimeout;

  /// Whether to cache successful evaluations
  final bool enableCaching;

  /// Whether to track fallback metrics
  final bool trackMetrics;

  /// Whether to emit warnings when using fallbacks
  final bool emitWarnings;

  /// Maximum age for cached values before considered stale
  final Duration cacheMaxAge;

  const GracefulDegradationConfig({
    this.defaultStrategy = FallbackStrategy.useCachedOrDefault,
    this.networkTimeout = const Duration(seconds: 5),
    this.enableCaching = true,
    this.trackMetrics = true,
    this.emitWarnings = true,
    this.cacheMaxAge = const Duration(hours: 24),
  });

  /// Production-ready configuration with aggressive caching
  factory GracefulDegradationConfig.production() {
    return const GracefulDegradationConfig(
      defaultStrategy: FallbackStrategy.useCachedOrDefault,
      networkTimeout: Duration(seconds: 3),
      enableCaching: true,
      trackMetrics: true,
      emitWarnings: false,
      cacheMaxAge: Duration(days: 7),
    );
  }

  /// Development configuration with more logging
  factory GracefulDegradationConfig.development() {
    return const GracefulDegradationConfig(
      defaultStrategy: FallbackStrategy.waitWithTimeout,
      networkTimeout: Duration(seconds: 10),
      enableCaching: true,
      trackMetrics: true,
      emitWarnings: true,
      cacheMaxAge: Duration(hours: 1),
    );
  }
}

/// Tracks fallback usage metrics
class FallbackMetrics {
  int totalEvaluations = 0;
  int successfulEvaluations = 0;
  int fallbacksUsed = 0;
  int cacheHits = 0;
  int networkFailures = 0;
  final Map<String, int> fallbacksByFlag = {};

  double get successRate =>
      totalEvaluations > 0 ? successfulEvaluations / totalEvaluations : 1.0;

  double get fallbackRate =>
      totalEvaluations > 0 ? fallbacksUsed / totalEvaluations : 0.0;

  double get cacheHitRate =>
      totalEvaluations > 0 ? cacheHits / totalEvaluations : 0.0;

  Map<String, dynamic> toJson() => {
        'totalEvaluations': totalEvaluations,
        'successfulEvaluations': successfulEvaluations,
        'fallbacksUsed': fallbacksUsed,
        'cacheHits': cacheHits,
        'networkFailures': networkFailures,
        'successRate': successRate,
        'fallbackRate': fallbackRate,
        'cacheHitRate': cacheHitRate,
        'topFallbackFlags': _getTopFallbackFlags(),
      };

  List<MapEntry<String, int>> _getTopFallbackFlags() {
    final sorted = fallbacksByFlag.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).toList();
  }
}

/// Provides graceful degradation for feature flag evaluation
class GracefulDegradation {
  static const _source = 'GracefulDegradation';
  static const _cacheKeyPrefix = 'cf_flag_cache_';
  static const _lastKnownGoodPrefix = 'cf_flag_lkg_';
  static const _cacheTimestampSuffix = '_ts';
  static const _cacheKeysSetKey = 'cf_cached_keys_set';

  final GracefulDegradationConfig _config;
  final FallbackMetrics _metrics = FallbackMetrics();
  final Map<String, Completer<dynamic>> _pendingEvaluations = {};
  final Set<String> _cachedKeys = <String>{}; // Track cached keys in memory

  GracefulDegradation({
    GracefulDegradationConfig? config,
  }) : _config = config ?? const GracefulDegradationConfig() {
    _loadCachedKeysSet();
  }

  /// Get current metrics
  FallbackMetrics get metrics => _metrics;

  /// Evaluate a flag with graceful degradation
  Future<CFResult<T>> evaluateWithFallback<T>({
    required String key,
    required T defaultValue,
    required Future<CFResult<T>> Function() evaluator,
    FallbackStrategy? strategy,
  }) async {
    _metrics.totalEvaluations++;

    strategy ??= _config.defaultStrategy;

    try {
      switch (strategy) {
        case FallbackStrategy.useDefault:
          return await _evaluateWithDefault(
            key: key,
            defaultValue: defaultValue,
            evaluator: evaluator,
          );

        case FallbackStrategy.useCachedOrDefault:
          return await _evaluateWithCache(
            key: key,
            defaultValue: defaultValue,
            evaluator: evaluator,
          );

        case FallbackStrategy.waitWithTimeout:
          return await _evaluateWithTimeout(
            key: key,
            defaultValue: defaultValue,
            evaluator: evaluator,
          );

        case FallbackStrategy.useLastKnownGood:
          return await _evaluateWithLastKnownGood(
            key: key,
            defaultValue: defaultValue,
            evaluator: evaluator,
          );
      }
    } catch (e) {
      Logger.e('Failed to evaluate flag "$key" with fallback: $e');
      _recordFallback(key);
      return CFResult.success(defaultValue);
    }
  }

  /// Try evaluation, fall back to default immediately on any error
  Future<CFResult<T>> _evaluateWithDefault<T>({
    required String key,
    required T defaultValue,
    required Future<CFResult<T>> Function() evaluator,
  }) async {
    try {
      final result = await evaluator();
      if (result.isSuccess) {
        _metrics.successfulEvaluations++;
        await _cacheValue(key, result.getOrNull());
        return result;
      }
    } catch (e) {
      Logger.d('Flag evaluation failed, using default: $e');
    }

    _recordFallback(key);
    return CFResult.success(defaultValue);
  }

  /// Try cached value first, then evaluate, then default
  Future<CFResult<T>> _evaluateWithCache<T>({
    required String key,
    required T defaultValue,
    required Future<CFResult<T>> Function() evaluator,
  }) async {
    // Check cache first
    final cachedResult = await _getCachedValue<T>(key);
    if (cachedResult != null) {
      _metrics.cacheHits++;

      // Try to refresh in background
      _refreshInBackground(key, evaluator);

      return CFResult.success(cachedResult);
    }

    // Try live evaluation
    try {
      final result = await evaluator();
      if (result.isSuccess) {
        _metrics.successfulEvaluations++;
        await _cacheValue(key, result.getOrNull());
        return result;
      }
    } catch (e) {
      Logger.d('Flag evaluation failed, checking cache: $e');
    }

    // Fall back to default
    _recordFallback(key);
    return CFResult.success(defaultValue);
  }

  /// Wait for evaluation with timeout, then try cache, then default
  Future<CFResult<T>> _evaluateWithTimeout<T>({
    required String key,
    required T defaultValue,
    required Future<CFResult<T>> Function() evaluator,
  }) async {
    // Prevent duplicate concurrent evaluations
    final pendingKey = '$key-${T.toString()}';
    if (_pendingEvaluations.containsKey(pendingKey)) {
      final result = await _pendingEvaluations[pendingKey]!.future;
      return CFResult.success(result as T);
    }

    final completer = Completer<dynamic>();
    _pendingEvaluations[pendingKey] = completer;

    try {
      // Try evaluation with timeout
      final result = await evaluator().timeout(
        _config.networkTimeout,
        onTimeout: () async {
          Logger.d('Flag evaluation timed out after ${_config.networkTimeout}');
          _metrics.networkFailures++;

          // Try cache
          final cached = await _getCachedValue<T>(key);
          if (cached != null) {
            _metrics.cacheHits++;
            return CFResult.success(cached);
          }

          // Use default
          _recordFallback(key);
          return CFResult.success(defaultValue);
        },
      );

      if (result.isSuccess) {
        _metrics.successfulEvaluations++;
        await _cacheValue(key, result.getOrNull());
        completer.complete(result.getOrNull());
        return result;
      }

      // Evaluation failed, try cache
      final cached = await _getCachedValue<T>(key);
      if (cached != null) {
        _metrics.cacheHits++;
        completer.complete(cached);
        return CFResult.success(cached);
      }

      // Use default
      _recordFallback(key);
      completer.complete(defaultValue);
      return CFResult.success(defaultValue);
    } finally {
      _pendingEvaluations.remove(pendingKey);
    }
  }

  /// Use last known good value, with longer cache validity
  Future<CFResult<T>> _evaluateWithLastKnownGood<T>({
    required String key,
    required T defaultValue,
    required Future<CFResult<T>> Function() evaluator,
  }) async {
    // Check last known good first
    final lastKnownGood = await _getLastKnownGood<T>(key);

    // Try live evaluation
    try {
      final result = await evaluator();
      if (result.isSuccess) {
        _metrics.successfulEvaluations++;
        final value = result.getOrNull();
        await _cacheValue(key, value);
        await _saveLastKnownGood(key, value);
        return result;
      }
    } catch (e) {
      Logger.d('Flag evaluation failed, using last known good: $e');
      _metrics.networkFailures++;
    }

    // Use last known good if available
    if (lastKnownGood != null) {
      if (_config.emitWarnings) {
        Logger.w('Using last known good value for flag "$key"');
      }
      return CFResult.success(lastKnownGood);
    }

    // Fall back to default
    _recordFallback(key);
    return CFResult.success(defaultValue);
  }

  /// Cache a flag value
  Future<void> _cacheValue<T>(String key, T? value) async {
    if (!_config.enableCaching || value == null) return;

    try {
      final cacheKey = '$_cacheKeyPrefix$key';
      final timestampKey = '$cacheKey$_cacheTimestampSuffix';

      // Store value and timestamp
      if (value is bool) {
        final service = await PreferencesService.getInstance();
        await service.setBool(cacheKey, value);
      } else if (value is String) {
        final service = await PreferencesService.getInstance();
        await service.setString(cacheKey, value);
      } else if (value is num) {
        final service = await PreferencesService.getInstance();
        await service.setString(cacheKey, value.toString());
      } else if (value is Map<String, dynamic>) {
        final service = await PreferencesService.getInstance();
        await service.setString(cacheKey, jsonEncode(value));
      }

      // Store timestamp
      final service = await PreferencesService.getInstance();
      await service.setInt(
        timestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      // Track the cached key
      _cachedKeys.add(key);
      await _saveCachedKeysSet();
    } catch (e) {
      Logger.d('Failed to cache flag value: $e');
    }
  }

  /// Get cached flag value
  Future<T?> _getCachedValue<T>(String key) async {
    if (!_config.enableCaching) return null;

    try {
      final cacheKey = '$_cacheKeyPrefix$key';
      final timestampKey = '$cacheKey$_cacheTimestampSuffix';

      // Check timestamp
      final service = await PreferencesService.getInstance();
      final timestamp = await service.getInt(timestampKey);
      if (timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > _config.cacheMaxAge.inMilliseconds) {
          Logger.d('Cached value for "$key" is stale');
          return null;
        }
      }

      // Get value based on type
      if (T == bool) {
        final service = await PreferencesService.getInstance();
        return await service.getBool(cacheKey) as T?;
      } else if (T == String) {
        final service = await PreferencesService.getInstance();
        return await service.getString(cacheKey) as T?;
      } else if (T == double || T == num) {
        final service = await PreferencesService.getInstance();
        final stringValue = await service.getString(cacheKey);
        if (stringValue != null) {
          final value = double.tryParse(stringValue);
          return value as T?;
        }
        return null;
      } else if (T == Map<String, dynamic>) {
        final service = await PreferencesService.getInstance();
        final json = await service.getString(cacheKey);
        return json != null ? jsonDecode(json) as T : null;
      }
    } catch (e) {
      Logger.d('Failed to get cached flag value: $e');
    }

    return null;
  }

  /// Save last known good value
  Future<void> _saveLastKnownGood<T>(String key, T? value) async {
    if (!_config.enableCaching || value == null) return;

    try {
      final lkgKey = '$_lastKnownGoodPrefix$key';

      if (value is bool) {
        final service = await PreferencesService.getInstance();
        await service.setBool(lkgKey, value);
      } else if (value is String) {
        final service = await PreferencesService.getInstance();
        await service.setString(lkgKey, value);
      } else if (value is num) {
        final service = await PreferencesService.getInstance();
        await service.setString(lkgKey, value.toString());
      } else if (value is Map<String, dynamic>) {
        final service = await PreferencesService.getInstance();
        await service.setString(lkgKey, jsonEncode(value));
      }
    } catch (e) {
      Logger.d('Failed to save last known good value: $e');
    }
  }

  /// Get last known good value
  Future<T?> _getLastKnownGood<T>(String key) async {
    if (!_config.enableCaching) return null;

    try {
      final lkgKey = '$_lastKnownGoodPrefix$key';

      if (T == bool) {
        final service = await PreferencesService.getInstance();
        return await service.getBool(lkgKey) as T?;
      } else if (T == String) {
        final service = await PreferencesService.getInstance();
        return await service.getString(lkgKey) as T?;
      } else if (T == double || T == num) {
        final service = await PreferencesService.getInstance();
        final stringValue = await service.getString(lkgKey);
        if (stringValue != null) {
          final value = double.tryParse(stringValue);
          return value as T?;
        }
        return null;
      } else if (T == Map<String, dynamic>) {
        final service = await PreferencesService.getInstance();
        final json = await service.getString(lkgKey);
        return json != null ? jsonDecode(json) as T : null;
      }
    } catch (e) {
      Logger.d('Failed to get last known good value: $e');
    }

    return null;
  }

  /// Refresh value in background
  void _refreshInBackground<T>(
    String key,
    Future<CFResult<T>> Function() evaluator,
  ) {
    // Don't wait for this
    evaluator().then((result) {
      if (result.isSuccess) {
        _cacheValue(key, result.getOrNull());
      }
    }).catchError((e) {
      Logger.d('Background refresh failed for "$key": $e');
    });
  }

  /// Record fallback usage
  void _recordFallback(String key) {
    _metrics.fallbacksUsed++;
    _metrics.fallbacksByFlag[key] = (_metrics.fallbacksByFlag[key] ?? 0) + 1;

    if (_config.emitWarnings) {
      Logger.w('Using fallback value for flag "$key"');
    }
  }

  /// Load cached keys set from preferences
  Future<void> _loadCachedKeysSet() async {
    try {
      final service = await PreferencesService.getInstance();
      final keysJson = await service.getString(_cacheKeysSetKey);
      if (keysJson != null) {
        final keysList = jsonDecode(keysJson) as List<dynamic>;
        _cachedKeys.addAll(keysList.cast<String>());
      }
    } catch (e) {
      Logger.d('Failed to load cached keys set: $e');
    }
  }

  /// Save cached keys set to preferences
  Future<void> _saveCachedKeysSet() async {
    try {
      final service = await PreferencesService.getInstance();
      final keysJson = jsonEncode(_cachedKeys.toList());
      await service.setString(_cacheKeysSetKey, keysJson);
    } catch (e) {
      Logger.d('Failed to save cached keys set: $e');
    }
  }

  /// Clear all cached values
  Future<void> clearCache() async {
    try {
      Logger.i('Clearing feature flag cache (${_cachedKeys.length} keys)');

      final service = await PreferencesService.getInstance();

      // Clear all tracked cache keys
      for (final key in _cachedKeys) {
        final cacheKey = '$_cacheKeyPrefix$key';
        final timestampKey = '$cacheKey$_cacheTimestampSuffix';
        final lkgKey = '$_lastKnownGoodPrefix$key';

        // Remove cache value, timestamp, and last known good
        await service.remove(cacheKey);
        await service.remove(timestampKey);
        await service.remove(lkgKey);
      }

      // Clear the cached keys set
      await service.remove(_cacheKeysSetKey);
      _cachedKeys.clear();

      Logger.i('Feature flag cache cleared successfully');
    } catch (e) {
      Logger.e('Failed to clear cache: $e');
    }
  }

  /// Clear cache for a specific flag
  Future<void> clearFlagCache(String key) async {
    try {
      Logger.d('Clearing cache for flag: $key');

      final service = await PreferencesService.getInstance();
      final cacheKey = '$_cacheKeyPrefix$key';
      final timestampKey = '$cacheKey$_cacheTimestampSuffix';
      final lkgKey = '$_lastKnownGoodPrefix$key';

      // Remove cache value, timestamp, and last known good
      await service.remove(cacheKey);
      await service.remove(timestampKey);
      await service.remove(lkgKey);

      // Remove from tracked keys
      _cachedKeys.remove(key);
      await _saveCachedKeysSet();

      Logger.d('Cache cleared for flag: $key');
    } catch (e) {
      Logger.e('Failed to clear cache for flag "$key": $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final service = await PreferencesService.getInstance();
      int validCacheCount = 0;
      int staleCacheCount = 0;
      int totalSize = 0;

      for (final key in _cachedKeys) {
        final timestampKey = '$_cacheKeyPrefix$key$_cacheTimestampSuffix';
        final timestamp = await service.getInt(timestampKey);

        if (timestamp != null) {
          final age = DateTime.now().millisecondsSinceEpoch - timestamp;
          if (age <= _config.cacheMaxAge.inMilliseconds) {
            validCacheCount++;
          } else {
            staleCacheCount++;
          }
          totalSize += 1; // Simplified size calculation
        }
      }

      return {
        'totalKeys': _cachedKeys.length,
        'validCacheCount': validCacheCount,
        'staleCacheCount': staleCacheCount,
        'cacheHitRate': _metrics.cacheHitRate,
        'maxAge': _config.cacheMaxAge.inHours,
        'estimatedSize': totalSize,
      };
    } catch (e) {
      Logger.e('Failed to get cache stats: $e');
      return {
        'error': e.toString(),
        'totalKeys': _cachedKeys.length,
      };
    }
  }

  /// Get a summary of degradation performance
  Map<String, dynamic> getDegradationSummary() {
    return {
      'metrics': _metrics.toJson(),
      'config': {
        'strategy': _config.defaultStrategy.name,
        'networkTimeout': _config.networkTimeout.inMilliseconds,
        'cacheMaxAge': _config.cacheMaxAge.inHours,
        'caching': _config.enableCaching,
      },
    };
  }
}

/// Extension on CFClient for graceful degradation
extension GracefulDegradationExtension on dynamic {
  static final _degradationInstance = GracefulDegradation(
    config: GracefulDegradationConfig.production(),
  );

  /// Get the graceful degradation instance
  GracefulDegradation get gracefulDegradation => _degradationInstance;
}
