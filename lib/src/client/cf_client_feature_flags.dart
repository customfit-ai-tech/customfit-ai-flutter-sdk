// lib/src/client/cf_client_feature_flags.dart
//
// Feature flag evaluation component for CustomFit SDK.
// Handles boolean, string, number, and JSON flag evaluation with caching and fallbacks.
// Extracted from cf_client.dart to improve maintainability.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:convert';

import '../config/core/cf_config.dart';
import '../core/model/cf_user.dart';
import '../features/graceful_degradation.dart';
import '../infrastructure/logging/logger.dart';
import '../core/error/cf_result.dart';
import '../client/managers/config_manager.dart';
import '../analytics/summary/summary_manager.dart';

/// Feature flag evaluation component for CFClient
class CFClientFeatureFlags {
  final CFConfig _config;
  final CFUser _user;
  final ConfigManager _configManager;
  final SummaryManager _summaryManager;
  final String _sessionId;
  late final GracefulDegradation _gracefulDegradation;

  CFClientFeatureFlags({
    required CFConfig config,
    required CFUser user,
    required ConfigManager configManager,
    required SummaryManager summaryManager,
    required String sessionId,
  })  : _config = config,
        _user = user,
        _configManager = configManager,
        _summaryManager = summaryManager,
        _sessionId = sessionId {
    // Initialize graceful degradation based on config
    _gracefulDegradation = GracefulDegradation(
      config: _config.offlineMode
          ? const GracefulDegradationConfig(
              defaultStrategy: FallbackStrategy.useCachedOrDefault,
              networkTimeout: Duration.zero,
              enableCaching: true,
            )
          : _config.debugLoggingEnabled
              ? GracefulDegradationConfig.development()
              : GracefulDegradationConfig.production(),
    );
  }

  /// Evaluate a boolean feature flag
  ///
  /// Returns the flag value if found and valid, otherwise returns [defaultValue].
  /// Automatically tracks summary for flag evaluation.
  /// Includes graceful degradation for network failures and offline scenarios.
  ///
  /// Example:
  /// ```dart
  /// final isEnabled = client.getBoolean('new_feature', false);
  /// if (isEnabled) {
  ///   // Show new feature
  /// }
  /// ```
  bool getBoolean(String key, bool defaultValue) {
    return _evaluateWithDegradation<bool>(
      key: key,
      defaultValue: defaultValue,
      logType: 'Boolean',
    );
  }

  /// Evaluate a string feature flag
  ///
  /// Returns the flag value if found and valid, otherwise returns [defaultValue].
  /// Automatically tracks summary for flag evaluation.
  /// Includes graceful degradation for network failures and offline scenarios.
  ///
  /// Example:
  /// ```dart
  /// final theme = client.getString('app_theme', 'light');
  /// // Use theme value
  /// ```
  String getString(String key, String defaultValue) {
    return _evaluateWithDegradation<String>(
      key: key,
      defaultValue: defaultValue,
      logType: 'String',
    );
  }

  /// Evaluate a number feature flag
  ///
  /// Returns the flag value if found and valid, otherwise returns [defaultValue].
  /// Supports both integer and double values, automatically converting as needed.
  /// Automatically tracks summary for flag evaluation.
  /// Includes graceful degradation for network failures and offline scenarios.
  ///
  /// Example:
  /// ```dart
  /// final maxRetries = client.getNumber('max_retries', 3.0);
  /// final discount = client.getNumber('discount_percentage', 0.0);
  /// ```
  double getNumber(String key, double defaultValue) {
    final numValue = _evaluateWithDegradation<num>(
      key: key,
      defaultValue: defaultValue,
      logType: 'Number',
    );
    return numValue.toDouble();
  }

  /// Evaluate a JSON feature flag
  ///
  /// Returns the flag value if found and valid, otherwise returns [defaultValue].
  /// Supports complex objects, arrays, and nested structures.
  /// Automatically tracks summary for flag evaluation.
  /// Includes graceful degradation for network failures and offline scenarios.
  ///
  /// Example:
  /// ```dart
  /// final config = client.getJson('feature_config', {});
  /// final features = config['features'] as List<String>? ?? [];
  /// ```
  Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue) {
    return _evaluateWithDegradation<Map<String, dynamic>>(
      key: key,
      defaultValue: defaultValue,
      logType: 'JSON',
    );
  }

  /// Get all available feature flags
  ///
  /// Returns a map of all currently available feature flags and their values.
  /// Useful for debugging or administrative purposes.
  ///
  /// Example:
  /// ```dart
  /// final allFlags = client.getAllFlags();
  /// print('Available flags: ${allFlags.keys.join(', ')}');
  /// ```
  Map<String, dynamic> getAllFlags() {
    try {
      Logger.d('🏁 Getting all feature flags');
      return _configManager.getAllFlags();
    } catch (e) {
      Logger.e('🏁 Error getting all flags: $e');
      return {};
    }
  }

  /// Check if a specific flag exists
  ///
  /// Returns true if the flag is defined in the current configuration,
  /// false otherwise. Does not evaluate the flag value.
  ///
  /// Example:
  /// ```dart
  /// if (client.flagExists('experimental_feature')) {
  ///   final isEnabled = client.getBoolean('experimental_feature', false);
  ///   // Handle experimental feature
  /// }
  /// ```
  bool flagExists(String key) {
    try {
      final allFlags = _configManager.getAllFlags();
      return allFlags.containsKey(key);
    } catch (e) {
      Logger.e('🏁 Error checking flag existence for "$key": $e');
      return false;
    }
  }

  /// Internal flag evaluation with type safety and summary tracking
  CFResult<T> _evaluateFlag<T>(String key, T defaultValue) {
    try {
      // Get flag configuration
      final allFlags = _configManager.getAllFlags();
      final flagValue = allFlags[key];

      if (flagValue == null) {
        Logger.d('🏁 Flag "$key" not found, using default value');
        return CFResult.success(defaultValue);
      }

      // Since ConfigManager now returns direct values, handle them with type conversion
      final convertedValue = _convertDirectValue<T>(flagValue, defaultValue);

      Logger.d(
          '🏁 Flag "$key" has direct value: $flagValue -> $convertedValue');

      // Get full config data for summary tracking (including experience_behaviour_response)
      final fullConfig = _configManager.getFullFlagConfig(key);
      final summaryConfig = fullConfig != null
          ? Map<String, dynamic>.from(fullConfig)
          : <String, dynamic>{};

      // Add evaluation context
      summaryConfig.addAll({
        'key': key,
        'value': flagValue,
        'variation': convertedValue,
      });

      _trackFlagSummary(key, summaryConfig, convertedValue);

      return CFResult.success(convertedValue);
    } catch (e) {
      Logger.e('🏁 Error evaluating flag "$key": $e');
      return CFResult.error('Error evaluating flag: $e');
    }
  }

  /// Convert direct value to expected type
  T _convertDirectValue<T>(dynamic rawValue, T defaultValue) {
    if (rawValue == null) {
      Logger.d('🏁 Raw value is null, using default');
      return defaultValue;
    }

    // Type conversion based on expected type
    if (T == bool) {
      if (rawValue is bool) {
        return rawValue as T;
      }
      // Try to parse string representations
      if (rawValue is String) {
        return (rawValue.toLowerCase() == 'true') as T;
      }
      return defaultValue;
    } else if (T == String) {
      return rawValue.toString() as T;
    } else if (T == double || T == num) {
      if (rawValue is num) {
        return rawValue.toDouble() as T;
      } else if (rawValue is String) {
        final parsed = double.tryParse(rawValue);
        return parsed != null ? parsed as T : defaultValue;
      }
      return defaultValue;
    } else if (T == Map<String, dynamic>) {
      return (rawValue is Map<String, dynamic> ? rawValue : defaultValue) as T;
    } else {
      // For other types, try direct casting
      try {
        return rawValue as T;
      } catch (e) {
        Logger.w(
            '🏁 Failed to cast value to type ${T.toString()}, using default');
        return defaultValue;
      }
    }
  }

  /// Track summary for flag evaluation
  void _trackFlagSummary(
      String key, Map<String, dynamic> flagConfig, dynamic value) {
    try {
      // Debug: Log the flagConfig structure
      Logger.i('🏁 SUMMARY: _trackFlagSummary called for key "$key"');
      Logger.i('🏁 SUMMARY: flagConfig keys: ${flagConfig.keys.toList()}');
      Logger.i('🏁 SUMMARY: Full flagConfig content:');
      Logger.i(json.encode(flagConfig));

      // Create evaluation context for summary tracking
      // Extract experience_behaviour_response if available for rule_id and behaviour_id
      final experienceBehaviourResponse =
          flagConfig['experience_behaviour_response'] as Map<String, dynamic>?;

      if (experienceBehaviourResponse != null) {
        Logger.i('🏁 SUMMARY: Found experience_behaviour_response for "$key"');
        Logger.i(
            '🏁 SUMMARY: experience_behaviour_response content: $experienceBehaviourResponse');
      } else {
        Logger.w(
            '🏁 SUMMARY: No experience_behaviour_response found for "$key"');
      }

      // Extract the actual experience_id from the config
      String actualExperienceId = key; // Default to key if not found

      // Check if experience_behaviour_response contains experience_id
      if (experienceBehaviourResponse != null &&
          experienceBehaviourResponse['experience_id'] != null) {
        actualExperienceId =
            experienceBehaviourResponse['experience_id'] as String;
      } else if (flagConfig['id'] != null) {
        // Fallback to id field if available
        actualExperienceId = flagConfig['id'] as String;
      }

      final summaryData = {
        'config_id': flagConfig['config_id'] ?? flagConfig['id'] ?? key,
        'experience_id': actualExperienceId,
        'variation_id':
            flagConfig['variation_id'] ?? value?.toString() ?? 'default',
        'version': flagConfig['version']?.toString() ?? '1.0.0',
        'user_id': _user.userCustomerId ?? '',
        'session_id': _sessionId,
        ...flagConfig,
      };

      // Add rule_id and behaviour_id if available from experience_behaviour_response
      if (experienceBehaviourResponse != null) {
        final ruleId = experienceBehaviourResponse['rule_id'];
        final behaviourId = experienceBehaviourResponse['behaviour_id'];

        if (ruleId != null) {
          summaryData['rule_id'] = ruleId;
          Logger.i('🏁 SUMMARY: Added rule_id: $ruleId');
        }
        if (behaviourId != null) {
          summaryData['behaviour_id'] = behaviourId;
          Logger.i('🏁 SUMMARY: Added behaviour_id: $behaviourId');
        }
      }

      // Track summary using the correct method
      _summaryManager.pushSummary(summaryData);
    } catch (e) {
      Logger.w('🏁 Failed to track summary for flag "$key": $e');
      // Don't fail flag evaluation if summary tracking fails
    }
  }

  /// Method chaining support - returns the parent client
  /// This allows for fluent API usage
  CFClientFeatureFlags enableMethodChaining() {
    return this;
  }

  /// Evaluate a flag with graceful degradation support
  /// This method provides resilient flag evaluation with fallback mechanisms
  T _evaluateWithDegradation<T>({
    required String key,
    required T defaultValue,
    required String logType,
  }) {
    try {
      Logger.d('🏁 Evaluating $logType flag with degradation: $key');

      // Use async graceful degradation if network conditions are poor or offline mode
      if (_config.offlineMode || !_configManager.isSdkFunctionalityEnabled()) {
        return _evaluateWithDegradationSync<T>(
            key: key, defaultValue: defaultValue, logType: logType);
      }

      // For normal conditions, try direct evaluation first for performance
      final result = _evaluateFlag<T>(key, defaultValue);

      if (result.isSuccess) {
        final value = result.getOrNull() ?? defaultValue;
        Logger.i('🏁 $logType flag "$key" = $value');
        // Metrics tracking simplified
        // Note: Cannot cache value directly as _cacheValue is private
        // The graceful degradation handles caching internally
        return value;
      }

      // If direct evaluation failed, fall back to cached value or default
      return _evaluateWithDegradationSync<T>(
          key: key, defaultValue: defaultValue, logType: logType);
    } catch (e) {
      Logger.e('🏁 Error evaluating $logType flag "$key": $e');
      _gracefulDegradation.metrics.fallbacksUsed++;
      return defaultValue;
    } finally {
      // Metrics tracking simplified
    }
  }

  /// Synchronous degradation evaluation for immediate fallback
  T _evaluateWithDegradationSync<T>({
    required String key,
    required T defaultValue,
    required String logType,
  }) {
    // Try to get cached value synchronously
    final cachedValue = _getCachedValueSync<T>(key);
    if (cachedValue != null) {
      Logger.i('🏁 $logType flag "$key" = $cachedValue (cached)');
      _gracefulDegradation.metrics.cacheHits++;
      return cachedValue;
    }

    // Fall back to default
    Logger.w('🏁 $logType flag "$key" using default value (degraded)');
    _gracefulDegradation.metrics.fallbacksUsed++;
    // Simplified fallback tracking
    return defaultValue;
  }

  /// Evaluate a flag with full async graceful degradation (for critical flags)
  Future<T> evaluateWithFullDegradation<T>({
    required String key,
    required T defaultValue,
    FallbackStrategy? strategy,
  }) async {
    final result = await _gracefulDegradation.evaluateWithFallback<T>(
      key: key,
      defaultValue: defaultValue,
      evaluator: () async {
        final syncResult = _evaluateFlag<T>(key, defaultValue);
        return syncResult;
      },
      strategy: strategy,
    );

    final value = result.getOrNull() ?? defaultValue;

    // Track summary for async evaluation
    try {
      final fullConfig = _configManager.getFullFlagConfig(key);
      final summaryConfig = fullConfig != null
          ? Map<String, dynamic>.from(fullConfig)
          : <String, dynamic>{};

      // Add evaluation context
      summaryConfig.addAll({
        'key': key,
        'value': value,
        'variation': value,
        'async_evaluation': true,
      });

      _trackFlagSummary(key, summaryConfig, value);
    } catch (e) {
      Logger.w('🏁 Failed to track async summary for flag "$key": $e');
    }

    return value;
  }

  /// Get cached value synchronously (simplified version)
  T? _getCachedValueSync<T>(String key) {
    try {
      // Check if ConfigManager has the value in memory
      final allFlags = _configManager.getAllFlags();
      final flagValue = allFlags[key];

      if (flagValue != null) {
        // Create a dummy default to help with type conversion
        final dummyDefault = _createDefaultValueForType<T>();
        if (dummyDefault != null) {
          return _convertDirectValue<T>(flagValue, dummyDefault);
        }
      }
    } catch (e) {
      Logger.d('Failed to get cached value for "$key": $e');
    }
    return null;
  }

  /// Create a default value for a given type (for internal use)
  T? _createDefaultValueForType<T>() {
    if (T == bool) {
      return false as T;
    } else if (T == String) {
      return '' as T;
    } else if (T == double) {
      return 0.0 as T;
    } else if (T == num) {
      return 0 as T;
    } else if (T == int) {
      return 0 as T;
    } else if (T == Map<String, dynamic>) {
      return <String, dynamic>{} as T;
    }
    return null;
  }

  /// Get graceful degradation metrics
  Map<String, dynamic> getDegradationMetrics() {
    return _gracefulDegradation.getDegradationSummary();
  }

  /// Clear graceful degradation cache
  void clearDegradationCache() {
    _gracefulDegradation.clearCache();
  }

  /// Clear cache for a specific flag
  void clearFlagCache(String key) {
    _gracefulDegradation.clearFlagCache(key);
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return _gracefulDegradation.getCacheStats();
  }
}
