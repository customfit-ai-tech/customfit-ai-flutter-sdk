// lib/src/features/simplified_graceful_degradation.dart
//
// Simplified graceful degradation with basic fallback logic.
// Provides essential fallback mechanisms without over-engineering.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import '../core/error/cf_result.dart';
import '../infrastructure/logging/logger.dart';

/// Simple fallback strategies
enum FallbackStrategy {
  /// Use default value immediately
  useDefault,

  /// Try cached value, then default
  useCachedOrDefault,
}

/// Simplified graceful degradation configuration
class GracefulDegradationConfig {
  final FallbackStrategy defaultStrategy;
  final Duration networkTimeout;
  final bool enableCaching;

  const GracefulDegradationConfig({
    this.defaultStrategy = FallbackStrategy.useCachedOrDefault,
    this.networkTimeout = const Duration(seconds: 5),
    this.enableCaching = true,
  });

  /// Production configuration
  factory GracefulDegradationConfig.production() {
    return const GracefulDegradationConfig(
      defaultStrategy: FallbackStrategy.useCachedOrDefault,
      networkTimeout: Duration(seconds: 30),
      enableCaching: true,
    );
  }

  /// Development configuration
  factory GracefulDegradationConfig.development() {
    return const GracefulDegradationConfig(
      defaultStrategy: FallbackStrategy.useCachedOrDefault,
      networkTimeout: Duration(seconds: 10),
      enableCaching: true,
    );
  }
}

/// Simple metrics tracking
class FallbackMetrics {
  int totalEvaluations = 0;
  int cacheHits = 0;
  int fallbacksUsed = 0;

  double get cacheHitRate =>
      totalEvaluations > 0 ? cacheHits / totalEvaluations : 0.0;

  Map<String, dynamic> toJson() => {
        'totalEvaluations': totalEvaluations,
        'cacheHits': cacheHits,
        'fallbacksUsed': fallbacksUsed,
        'cacheHitRate': cacheHitRate,
      };
}

/// Simplified graceful degradation
class GracefulDegradation {
  final GracefulDegradationConfig _config;
  final Map<String, dynamic> _cache = {};
  final FallbackMetrics _metrics = FallbackMetrics();

  GracefulDegradation({
    GracefulDegradationConfig? config,
  }) : _config = config ?? const GracefulDegradationConfig();

  /// Get metrics
  FallbackMetrics get metrics => _metrics;

  /// Evaluate with simple fallback logic
  Future<CFResult<T>> evaluateWithFallback<T>({
    required String key,
    required T defaultValue,
    required Future<CFResult<T>> Function() evaluator,
    FallbackStrategy? strategy,
  }) async {
    _metrics.totalEvaluations++;
    strategy ??= _config.defaultStrategy;

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
    }
  }

  /// Try evaluation, fall back to default on error
  Future<CFResult<T>> _evaluateWithDefault<T>({
    required String key,
    required T defaultValue,
    required Future<CFResult<T>> Function() evaluator,
  }) async {
    try {
      final result = await evaluator().timeout(_config.networkTimeout);
      if (result.isSuccess) {
        if (_config.enableCaching) {
          _cache[key] = result.getOrNull();
        }
        return result;
      }
    } catch (e) {
      Logger.d('Flag evaluation failed for "$key", using default: $e');
    }

    return CFResult.success(defaultValue);
  }

  /// Try cached value first, then evaluate, then default
  Future<CFResult<T>> _evaluateWithCache<T>({
    required String key,
    required T defaultValue,
    required Future<CFResult<T>> Function() evaluator,
  }) async {
    // Check cache first
    if (_config.enableCaching && _cache.containsKey(key)) {
      final cached = _cache[key] as T?;
      if (cached != null) {
        _metrics.cacheHits++;
        return CFResult.success(cached);
      }
    }

    // Try live evaluation
    try {
      final result = await evaluator().timeout(_config.networkTimeout);
      if (result.isSuccess) {
        if (_config.enableCaching) {
          _cache[key] = result.getOrNull();
        }
        return result;
      }
    } catch (e) {
      Logger.d('Flag evaluation failed for "$key", using default: $e');
    }

    // Use default
    _metrics.fallbacksUsed++;
    return CFResult.success(defaultValue);
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    Logger.d('Feature flag cache cleared');
  }

  /// Clear specific flag cache
  void clearFlagCache(String key) {
    _cache.remove(key);
    Logger.d('Cache cleared for flag: $key');
  }

  /// Get simple cache stats
  Map<String, dynamic> getCacheStats() {
    return {
      'totalKeys': _cache.length,
      'enableCaching': _config.enableCaching,
    };
  }

  /// Get degradation summary
  Map<String, dynamic> getDegradationSummary() {
    return {
      'metrics': _metrics.toJson(),
      'config': {
        'strategy': _config.defaultStrategy.name,
        'networkTimeout': _config.networkTimeout.inMilliseconds,
        'caching': _config.enableCaching,
      },
    };
  }
}
