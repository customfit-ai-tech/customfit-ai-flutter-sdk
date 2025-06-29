// lib/src/client/cf_client_feature_flags.dart
//
// Feature flag evaluation component for CustomFit SDK.
// Handles boolean, string, number, and JSON flag evaluation with caching and fallbacks.
// Extracted from cf_client.dart to improve maintainability.
//
// This file is part of the CustomFit SDK for Flutter.

import '../config/core/cf_config.dart';
import '../core/model/cf_user.dart';
import '../features/graceful_degradation.dart';
import '../logging/logger.dart';
import '../core/error/cf_result.dart';
import '../client/managers/config_manager.dart';
import '../analytics/summary/summary_manager.dart';

/// Feature flag evaluation component for CFClient
class CFClientFeatureFlags {
  static const _source = 'CFClientFeatureFlags';

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
              emitWarnings: false,
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
      Logger.d('🏁 SUMMARY: _trackFlagSummary called for key "$key"');
      Logger.d('🏁 SUMMARY: flagConfig keys: ${flagConfig.keys.toList()}');
      Logger.d('🏁 SUMMARY: flagConfig content: $flagConfig');

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

      final summaryData = {
        'config_id': key,
        'experience_id': key,
        'variation_id': value?.toString() ?? 'default',
        'version': '1.0.0',
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

  /// Type-safe generic flag evaluation (Enhanced Type Safety)
  ///
  /// Gets a feature flag value with compile-time type safety.
  /// This method provides better type safety than the individual getBoolean, getString, etc. methods.
  ///
  /// ## Type Parameters
  ///
  /// - [T]: The expected type of the flag value
  ///
  /// ## Parameters
  ///
  /// - [key]: The feature flag key
  /// - [defaultValue]: Default value if flag is not available
  ///
  /// ## Returns
  ///
  /// The flag value cast to type [T], or [defaultValue] if unavailable
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Type-safe boolean flag
  /// final isEnabled = client.getTypedFlag<bool>('new_feature', false);
  ///
  /// // Type-safe string flag
  /// final apiUrl = client.getTypedFlag<String>('api_url', 'https://api.example.com');
  ///
  /// // Type-safe number flag
  /// final timeout = client.getTypedFlag<double>('timeout_ms', 5000.0);
  ///
  /// // Type-safe JSON flag
  /// final config = client.getTypedFlag<Map<String, dynamic>>('feature_config', {});
  /// ```
  T getTypedFlag<T>(String key, T defaultValue) {
    try {
      Logger.d('🏁 Evaluating typed flag: $key (${T.toString()})');

      // Validate type at runtime for safety
      if (!_isValidFlagType<T>()) {
        Logger.w(
            '🏁 Unsupported flag type: ${T.toString()}, returning default');
        return defaultValue;
      }

      final result = _evaluateFlag<T>(key, defaultValue);

      if (result.isSuccess) {
        final value = result.getOrNull() ?? defaultValue;
        Logger.i('🏁 Typed flag "$key" (${T.toString()}) = $value');
        return value;
      } else {
        Logger.w(
            '🏁 Typed flag "$key" evaluation failed: ${result.getErrorMessage()}');
        return defaultValue;
      }
    } catch (e) {
      Logger.e('🏁 Error evaluating typed flag "$key": $e');
      return defaultValue;
    }
  }

  /// Check if the type is a valid flag type
  bool _isValidFlagType<T>() {
    const validTypes = [
      bool,
      String,
      double,
      num,
      int,
      Map<String, dynamic>,
      dynamic,
    ];
    return validTypes.contains(T);
  }

  /// Get flag with nullable safety
  ///
  /// Returns null if the flag doesn't exist or is invalid, instead of using a default.
  /// Useful when you need to distinguish between "flag not set" and "flag set to default value".
  ///
  /// ## Type Parameters
  ///
  /// - [T]: The expected type of the flag value
  ///
  /// ## Parameters
  ///
  /// - [key]: The feature flag key
  ///
  /// ## Returns
  ///
  /// The flag value cast to type [T], or null if unavailable
  ///
  /// ## Example
  ///
  /// ```dart
  /// final feature = client.getFlagOrNull<bool>('optional_feature');
  /// if (feature != null) {
  ///   // Feature flag is explicitly set
  ///   if (feature) {
  ///     // Feature is enabled
  ///   } else {
  ///     // Feature is disabled
  ///   }
  /// } else {
  ///   // Feature flag is not configured - handle differently
  /// }
  /// ```
  T? getFlagOrNull<T>(String key) {
    try {
      Logger.d('🏁 Evaluating nullable flag: $key (${T.toString()})');

      if (!_isValidFlagType<T>()) {
        Logger.w('🏁 Unsupported flag type: ${T.toString()}, returning null');
        return null;
      }

      final allFlags = _configManager.getAllFlags();
      final flagValue = allFlags[key];

      if (flagValue == null) {
        Logger.d('🏁 Flag "$key" not found, returning null');
        return null;
      }

      // Create a temporary default for type extraction
      final tempDefault = _createDefaultValueForType<T>();
      if (tempDefault == null) {
        return null;
      }

      final value = _convertDirectValue<T>(flagValue, tempDefault);

      // Track summary for this flag evaluation
      final fullConfig = _configManager.getFullFlagConfig(key);
      final summaryConfig = fullConfig != null
          ? Map<String, dynamic>.from(fullConfig)
          : <String, dynamic>{};

      // Add evaluation context
      summaryConfig.addAll({
        'key': key,
        'value': flagValue,
        'variation': value,
      });

      _trackFlagSummary(key, summaryConfig, value);

      Logger.i('🏁 Nullable flag "$key" (${T.toString()}) = $value');
      return value;
    } catch (e) {
      Logger.e('🏁 Error evaluating nullable flag "$key": $e');
      return null;
    }
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

  /// Batch flag evaluation for performance
  ///
  /// Evaluates multiple flags in a single operation for better performance.
  /// Useful when you need to check many flags at once.
  ///
  /// ## Parameters
  ///
  /// - [flagRequests]: Map of flag keys to their default values
  ///
  /// ## Returns
  ///
  /// Map of flag keys to their evaluated values
  ///
  /// ## Example
  ///
  /// ```dart
  /// final flags = client.getBatchFlags({
  ///   'feature_a': false,
  ///   'feature_b': true,
  ///   'api_timeout': 5000.0,
  ///   'theme_color': '#007AFF',
  /// });
  ///
  /// final featureA = flags['feature_a'] as bool;
  /// final timeout = flags['api_timeout'] as double;
  /// ```
  Map<String, dynamic> getBatchFlags(Map<String, dynamic> flagRequests) {
    try {
      Logger.d('🏁 Evaluating ${flagRequests.length} flags in batch');

      final results = <String, dynamic>{};
      final allFlags = _configManager.getAllFlags();

      for (final entry in flagRequests.entries) {
        final key = entry.key;
        final defaultValue = entry.value;

        try {
          final flagValue = allFlags[key];

          if (flagValue == null) {
            results[key] = defaultValue;
            continue;
          }

          // Extract value based on default value type
          final value = _extractTypedValueDynamic(flagValue, defaultValue);
          results[key] = value;

          // Track summary for this flag evaluation
          final fullConfig = _configManager.getFullFlagConfig(key);
          final summaryConfig = fullConfig != null
              ? Map<String, dynamic>.from(fullConfig)
              : <String, dynamic>{};

          // Add evaluation context
          summaryConfig.addAll({
            'key': key,
            'value': flagValue,
            'variation': value,
          });

          _trackFlagSummary(key, summaryConfig, value);
        } catch (e) {
          Logger.w('🏁 Error evaluating flag "$key" in batch: $e');
          results[key] = defaultValue;
        }
      }

      Logger.i('🏁 Batch evaluation completed: ${results.length} flags');
      return results;
    } catch (e) {
      Logger.e('🏁 Error in batch flag evaluation: $e');
      // Return defaults for all requested flags
      return Map<String, dynamic>.from(flagRequests);
    }
  }

  /// Extract typed value dynamically based on default value type
  dynamic _extractTypedValueDynamic(dynamic rawValue, dynamic defaultValue) {
    if (rawValue == null) {
      return defaultValue;
    }

    if (defaultValue is bool) {
      if (rawValue is bool) {
        return rawValue;
      }
      if (rawValue is String) {
        return rawValue.toLowerCase() == 'true';
      }
      return defaultValue;
    } else if (defaultValue is String) {
      return rawValue.toString();
    } else if (defaultValue is double || defaultValue is num) {
      if (rawValue is num) {
        return rawValue.toDouble();
      } else if (rawValue is String) {
        return double.tryParse(rawValue) ?? defaultValue;
      } else {
        return defaultValue;
      }
    } else if (defaultValue is int) {
      if (rawValue is num) {
        return rawValue.toInt();
      } else if (rawValue is String) {
        return int.tryParse(rawValue) ?? defaultValue;
      } else {
        return defaultValue;
      }
    } else if (defaultValue is Map<String, dynamic>) {
      return rawValue is Map<String, dynamic> ? rawValue : defaultValue;
    } else {
      return rawValue;
    }
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
        _gracefulDegradation.metrics.successfulEvaluations++;
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
      _gracefulDegradation.metrics.totalEvaluations++;
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
    _gracefulDegradation.metrics.fallbacksByFlag[key] =
        (_gracefulDegradation.metrics.fallbacksByFlag[key] ?? 0) + 1;
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

  /// Get graceful degradation metrics
  Map<String, dynamic> getDegradationMetrics() {
    return _gracefulDegradation.getDegradationSummary();
  }

  /// Clear graceful degradation cache
  Future<void> clearDegradationCache() async {
    await _gracefulDegradation.clearCache();
  }

  /// Clear cache for a specific flag
  Future<void> clearFlagCache(String key) async {
    await _gracefulDegradation.clearFlagCache(key);
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _gracefulDegradation.getCacheStats();
  }

  /// Evaluate a boolean flag with full async graceful degradation
  ///
  /// This method provides the most robust flag evaluation with comprehensive
  /// fallback strategies. Use for critical flags where reliability is paramount.
  ///
  /// ## Parameters
  ///
  /// - [key]: The feature flag key
  /// - [defaultValue]: Default value if flag evaluation fails
  /// - [strategy]: Optional fallback strategy override
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Critical feature with timeout strategy
  /// final isEnabled = await client.getBooleanWithDegradation(
  ///   'critical_feature',
  ///   false,
  ///   strategy: FallbackStrategy.waitWithTimeout,
  /// );
  /// ```
  Future<bool> getBooleanWithDegradation(
    String key,
    bool defaultValue, {
    FallbackStrategy? strategy,
  }) async {
    return await evaluateWithFullDegradation<bool>(
      key: key,
      defaultValue: defaultValue,
      strategy: strategy,
    );
  }

  /// Evaluate a string flag with full async graceful degradation
  Future<String> getStringWithDegradation(
    String key,
    String defaultValue, {
    FallbackStrategy? strategy,
  }) async {
    return await evaluateWithFullDegradation<String>(
      key: key,
      defaultValue: defaultValue,
      strategy: strategy,
    );
  }

  /// Evaluate a number flag with full async graceful degradation
  Future<double> getNumberWithDegradation(
    String key,
    double defaultValue, {
    FallbackStrategy? strategy,
  }) async {
    return await evaluateWithFullDegradation<double>(
      key: key,
      defaultValue: defaultValue,
      strategy: strategy,
    );
  }

  /// Evaluate a JSON flag with full async graceful degradation
  Future<Map<String, dynamic>> getJsonWithDegradation(
    String key,
    Map<String, dynamic> defaultValue, {
    FallbackStrategy? strategy,
  }) async {
    return await evaluateWithFullDegradation<Map<String, dynamic>>(
      key: key,
      defaultValue: defaultValue,
      strategy: strategy,
    );
  }
}
