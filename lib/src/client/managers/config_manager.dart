// lib/src/client/managers/config_manager.dart
//
// Configuration management for the CustomFit SDK.
// Handles fetching, caching, and providing access to feature flags.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:convert';

import '../../network/config/config_fetcher.dart';
import '../../config/core/cf_config.dart';
import '../../core/error/cf_result.dart';
import '../../core/util/config_cache.dart';
import '../../logging/logger.dart';
import '../../analytics/summary/summary_manager.dart';
import '../../network/connection/connection_manager.dart';
import '../../network/connection/connection_status.dart';
import '../../network/connection/connection_information.dart';
import '../../core/model/sdk_settings.dart';

/// Interface for ConfigManager
abstract class ConfigManager {
  /// Get a string feature flag value
  String getString(String key, String defaultValue);

  /// Get a boolean feature flag value
  bool getBoolean(String key, bool defaultValue);

  /// Get a number feature flag value
  num getNumber(String key, num defaultValue);

  /// Get a JSON feature flag value
  Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue);

  /// Get a generic feature flag value
  T getConfigValue<T>(String key, T defaultValue);

  /// Add a listener for a specific feature flag
  void addConfigListener<T>(String key, void Function(T) listener);

  /// Remove a listener for a specific feature flag
  void removeConfigListener<T>(String key, void Function(T) listener);

  /// Clear all listeners for a specific feature flag
  void clearConfigListeners(String key);

  /// Returns a map of all feature flags with their current values
  Map<String, dynamic> getAllFlags();

  /// Get full config data for a specific flag (including experience_behaviour_response)
  Map<String, dynamic>? getFullFlagConfig(String key);

  /// Check if configuration is available (not empty)
  bool hasConfiguration();

  /// Shutdown the config manager
  void shutdown();

  /// Manually trigger a refresh of configs
  Future<bool> refreshConfigs();

  /// Debug method to dump the entire config map in detail
  void dumpConfigMap();

  /// Returns whether SDK functionality is currently enabled
  bool isSdkFunctionalityEnabled();

  /// Update configs directly from client
  void updateConfigsFromClient(Map<String, dynamic> newConfigs);

  /// Get the current SDK settings
  SdkSettings? getSdkSettings();

  /// Wait for initial configuration load to complete
  Future<void> waitForInitialLoad();

  /// Setup configuration change listeners
  /// This method centralizes the config change listener setup that was previously in CFClient
  void setupListeners({
    required void Function(CFConfig) onConfigChange,
    required SummaryManager summaryManager,
  });
}

/// Implementation of ConfigManager
class ConfigManagerImpl implements ConfigManager, ConnectionStatusListener {
  final CFConfig _config;
  final ConfigFetcher _configFetcher;
  final SummaryManager? _summaryManager;
  final ConnectionManager? _connectionManager;

  // Configuration cache
  final ConfigCache _configCache = ConfigCache();

  // Cache for feature flags
  final Map<String, dynamic> _configMap = {};

  // Track whether SDK functionality is enabled (default to true)
  bool _isSdkFunctionalityEnabled = true;

  // Listeners for feature flag changes
  final Map<String, List<void Function(dynamic)>> _configListeners = {};

  // Lock for config map operations
  final _configLock = Object();

  // Timer for SDK settings check
  Timer? _sdkSettingsTimer;

  // Last modified timestamp for SDK settings
  String? _previousLastModified;

  // Completer for SDK settings initialization
  final Completer<void> _sdkSettingsCompleter = Completer<void>();

  // Flag to track if we've loaded from cache
  bool _initialCacheLoadComplete = false;

  // Store the current SDK settings
  SdkSettings? _currentSdkSettings;

  /// Flag to prevent concurrent SDK settings checks
  bool _isCheckingSdkSettings = false;

  /// Timer for debouncing connection status changes
  Timer? _connectionDebounceTimer;

  /// Create a new ConfigManagerImpl
  ConfigManagerImpl({
    required CFConfig config,
    required ConfigFetcher configFetcher,
    SummaryManager? summaryManager,
    ConnectionManager? connectionManager,
  })  : _config = config,
        _configFetcher = configFetcher,
        _summaryManager = summaryManager,
        _connectionManager = connectionManager {
    // Default to enabled unless explicitly disabled
    _isSdkFunctionalityEnabled = true;
    Logger.d(
        'ConfigManagerImpl initialized with isSdkFunctionalityEnabled=true');

    // Add self as connection status listener if connection manager is available
    _connectionManager?.addConnectionStatusListener(this);

    // Load from cache first
    _loadFromCache().then((_) {
      // Start SDK settings check after loading from cache
      _startSdkSettingsCheck();
    });
  }

  /// Load configuration from cache during initialization
  Future<void> _loadFromCache() async {
    if (_initialCacheLoadComplete) {
      return;
    }

    // Skip cache loading if local storage is disabled
    if (!_config.localStorageEnabled) {
      Logger.i('Local storage disabled, skipping cache loading');
      _initialCacheLoadComplete = true;
      return;
    }

    Logger.i('Loading configuration from cache...');

    // Cache policy configuration (for future use)
    // final cachePolicy = CachePolicy(
    //   ttlSeconds: _config.configCacheTtlSeconds,
    //   useStaleWhileRevalidate: _config.useStaleWhileRevalidate,
    //   evictOnAppRestart: !_config.persistCacheAcrossRestarts,
    //   persist: _config.persistCacheAcrossRestarts,
    // );

    // Try to get cached config, allow expired entries if needed
    final cacheResult = await _configCache.getCachedConfig(
        allowExpired: _config.useStaleWhileRevalidate);

    if (cacheResult.configMap != null) {
      Logger.i(
          'Found cached configuration with ${cacheResult.configMap!.length} entries');

      // Update the config map with cached values
      _updateConfigMap(cacheResult.configMap!);

      // Set metadata for future conditional requests
      _previousLastModified = cacheResult.lastModified;

      Logger.i('Successfully initialized from cached configuration');
    } else {
      Logger.i('No cached configuration found, will wait for server response');
    }

    _initialCacheLoadComplete = true;
  }

  /// Start periodic SDK settings check
  void _startSdkSettingsCheck() {
    // Skip SDK settings check entirely if in offline mode
    if (_configFetcher.isOffline()) {
      Logger.i('SKIPPING SDK settings check in offline mode');
      // Complete the completer immediately to signal initialization is done
      if (!_sdkSettingsCompleter.isCompleted) {
        _sdkSettingsCompleter.complete();
      }
      return;
    }

    // Cancel any existing timer first
    _sdkSettingsTimer?.cancel();

    // Get the configured interval from CFConfig
    final intervalMs = _config.sdkSettingsCheckIntervalMs;

    // Recommended interval for production use
    const recommendedInterval =
        300000; // 5 minutes recommended (matches CFConstants)

    // Only validate that the interval is positive (matching other SDKs)
    if (intervalMs <= 0) {
      Logger.e('SDK settings check interval must be greater than 0');
      return;
    }

    // Log warning if interval is shorter than recommended
    if (intervalMs < recommendedInterval) {
      Logger.w(
          'INFO: Configured interval ${intervalMs}ms is shorter than recommended ${recommendedInterval}ms (5 minutes).');
      Logger.w(
          'This may increase network usage and battery drain. Consider using a longer interval for production.');
    }

    // Log the interval being used
    Logger.i(
        'Starting SDK settings check timer with interval: ${intervalMs}ms');

    // Create a new timer with the configured interval
    _sdkSettingsTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (timer) {
        // Silently check SDK settings - no need to log timer fires
        _checkSdkSettings();
      },
    );

    // Perform initial check outside the timer
    _initialSdkSettingsCheck();
  }

  /// Perform initial SDK settings check
  Future<void> _initialSdkSettingsCheck() async {
    // Skip if in offline mode
    if (_configFetcher.isOffline()) {
      Logger.d('SKIPPING initial SDK settings check in offline mode');
      if (!_sdkSettingsCompleter.isCompleted) {
        _sdkSettingsCompleter.complete();
      }
      return;
    }

    await _checkSdkSettings();
    if (!_sdkSettingsCompleter.isCompleted) {
      _sdkSettingsCompleter.complete();
    }
  }

  /// Check SDK settings for updates
  Future<void> _checkSdkSettings() async {
    // Prevent concurrent checks
    if (_isCheckingSdkSettings) {
      Logger.d('SDK settings check already in progress, skipping');
      return;
    }

    // Skip if in offline mode
    if (_configFetcher.isOffline()) {
      Logger.d('Not checking SDK settings because client is in offline mode');
      return;
    }

    _isCheckingSdkSettings = true;

    try {
      // Silent start - no need to log every poll

      // Fetch metadata
      final metadataResult = await _configFetcher.fetchMetadata();

      if (!metadataResult.isSuccess) {
        Logger.w(
            '🔎 API POLL: Failed to fetch metadata: ${metadataResult.getErrorMessage()}');
        // Record connection failure if we have a connection manager
        _connectionManager?.recordConnectionFailure(
            metadataResult.getErrorMessage() ?? 'Failed to fetch metadata');
        return;
      }

      // Record connection success for metadata fetch
      _connectionManager?.recordConnectionSuccess();

      final headers = metadataResult.getOrNull() ?? {};
      final lastModified = headers['Last-Modified'];
      final etag = headers['ETag'];

      // If we get 'unchanged' for Last-Modified, it means we got a 304 response
      // No need to fetch the config again
      if (lastModified == 'unchanged') {
        // Silent - 304 responses are normal and expected
        return;
      }

      // Check if we need to update based on Last-Modified
      if (lastModified != null && lastModified != _previousLastModified) {
        Logger.i(
            '🔎 API POLL: Last-Modified changed from $_previousLastModified to $lastModified');
        _previousLastModified = lastModified;

        // Fetch SDK settings first
        final sdkSettingsResult = await _configFetcher.fetchSdkSettings();

        if (sdkSettingsResult.isSuccess) {
          // Record connection success for SDK settings fetch
          _connectionManager?.recordConnectionSuccess();

          final settings = sdkSettingsResult.getOrNull();
          if (settings != null) {
            // Process SDK settings
            _processSdkSettings(settings);
          }
        } else {
          Logger.w(
              '🔎 API POLL: Failed to fetch SDK settings: ${sdkSettingsResult.getErrorMessage()}');
          // Record connection failure
          _connectionManager?.recordConnectionFailure(
              sdkSettingsResult.getErrorMessage() ??
                  'Failed to fetch SDK settings');
        }

        // Only fetch configs if SDK functionality is enabled
        if (_isSdkFunctionalityEnabled) {
          // Fetch config
          final configSuccess =
              await _configFetcher.fetchConfig(lastModified: lastModified);

          if (!configSuccess) {
            Logger.w('🔎 API POLL: Failed to fetch config');
            _connectionManager
                ?.recordConnectionFailure('Failed to fetch config');
            return;
          }

          // Record connection success for config fetch
          _connectionManager?.recordConnectionSuccess();

          // Get configs
          final configsResult = _configFetcher.getConfigs();

          if (!configsResult.isSuccess) {
            Logger.w(
                '🔎 API POLL: Failed to get configs: ${configsResult.getErrorMessage()}');
            _connectionManager?.recordConnectionFailure(
                configsResult.getErrorMessage() ?? 'Failed to get configs');
            return;
          }

          final configs = configsResult.getOrNull() ?? {};
          Logger.i(
              '🔎 API POLL: Successfully fetched ${configs.length} config entries');

          // Use config-driven cache policy for storing configurations
          if (_config.localStorageEnabled) {
            final cachePolicy = CachePolicy(
              ttlSeconds: _config.configCacheTtlSeconds,
              useStaleWhileRevalidate: _config.useStaleWhileRevalidate,
              evictOnAppRestart: !_config.persistCacheAcrossRestarts,
              persist: _config.persistCacheAcrossRestarts,
            );

            await _configCache.cacheConfig(configs, lastModified, etag,
                policy: cachePolicy);
          } else {
            Logger.d('Local storage disabled, skipping config caching');
          }

          // Update config map with new values
          _updateConfigMap(configs);
        } else {
          Logger.i(
              '🔎 API POLL: Skipping config fetch because SDK functionality is disabled');
        }
      } else {
        // Silent when no changes - this is the normal case
      }
    } catch (e) {
      Logger.e('🔎 API POLL: Error checking SDK settings: $e');
    } finally {
      _isCheckingSdkSettings = false;
    }
  }

  /// Process SDK settings and update internal flags
  void _processSdkSettings(Map<String, dynamic> settings) {
    try {
      // Parse and store the SDK settings
      _currentSdkSettings = SdkSettings.fromJson(settings);

      // Update the SDK functionality flag (inverse of cfSkipSdk)
      final newValue = !_currentSdkSettings!.cfSkipSdk;

      if (_isSdkFunctionalityEnabled != newValue) {
        Logger.i(
            'SDK functionality ${newValue ? "enabled" : "disabled"} based on cfSkipSdk=${_currentSdkSettings!.cfSkipSdk}');
        _isSdkFunctionalityEnabled = newValue;
      } else {
        Logger.d(
            'SDK functionality unchanged (${newValue ? "enabled" : "disabled"})');
      }

      // Log if rule events are configured
      if (_currentSdkSettings != null &&
          _currentSdkSettings!.ruleEvents.isNotEmpty) {
        Logger.d('Rule events configured: ${_currentSdkSettings!.ruleEvents}');
      }

      // Additional SDK settings processing can be added here if needed
    } catch (e) {
      Logger.e('Error processing SDK settings: $e');
      // Keep SDK functionality enabled by default in case of error
      _isSdkFunctionalityEnabled = true;
    }
  }

  /// Update config map with new values
  void _updateConfigMap(Map<String, dynamic> newConfigs) {
    final updatedKeys = <String>[];

    synchronized(_configLock, () {
      // Update config map
      newConfigs.forEach((key, value) {
        final currentValue = _configMap[key];

        // Extract variation values for comparison
        dynamic currentVariation = currentValue;
        dynamic newVariation = value;

        if (currentValue is Map<String, dynamic> &&
            currentValue.containsKey('variation')) {
          currentVariation = currentValue['variation'];
        }

        if (value is Map<String, dynamic> && value.containsKey('variation')) {
          newVariation = value['variation'];
        }

        // Check if the variation value has actually changed
        bool hasChanged = false;

        // Deep equality check for Maps
        if (currentVariation is Map && newVariation is Map) {
          hasChanged = !_mapsAreEqual(currentVariation, newVariation);
        } else if (currentVariation is List && newVariation is List) {
          hasChanged = !_listsAreEqual(currentVariation, newVariation);
        } else {
          hasChanged = currentVariation != newVariation;
        }

        if (hasChanged) {
          Logger.i(
              '⚡ CONFIG UPDATE: Key "$key" changed: $currentVariation -> $newVariation');
          _configMap[key] = value;
          updatedKeys.add(key);
        } else {
          // Still update the config map to get latest metadata, but don't log or notify
          _configMap[key] = value;
        }
      });
    });

    // Only print config map in verbose mode or when explicitly requested via dumpConfigMap()

    // Notify listeners if anything changed
    if (updatedKeys.isNotEmpty) {
      Logger.i('--- UPDATED CONFIG VALUES ---');
      for (final key in updatedKeys) {
        final config = newConfigs[key];
        if (config is Map<String, dynamic> && config.containsKey('variation')) {
          final variation = config['variation'];
          Logger.i('CONFIG UPDATE: $key: $variation');
        }
      }

      Logger.i(
          '⚡ Notifying listeners about ${updatedKeys.length} changed keys: $updatedKeys');
      _notifyConfigChanges(updatedKeys);
    } else {
      Logger.d('No config keys changed, skipping notification');
    }
  }

  /// Notify listeners of config changes
  void _notifyConfigChanges(List<String> updatedKeys) {
    for (final key in updatedKeys) {
      final value = _configMap[key];
      final listeners = _configListeners[key];

      // Extract the actual value to notify, handling feature flags with variation field
      dynamic valueToNotify = value;

      // If it's a feature flag with variation field, use that value
      if (value is Map<String, dynamic> && value.containsKey('variation')) {
        valueToNotify = value['variation'];
      }

      if (listeners != null && listeners.isNotEmpty) {
        // Log once for all listeners of this key
        Logger.d(
            '⚡ Notifying ${listeners.length} listener(s) for "$key" with value: $valueToNotify');

        for (final listener in List<void Function(dynamic)>.from(listeners)) {
          try {
            listener(valueToNotify);
          } catch (e) {
            Logger.e('Error notifying config change listener: $e');
          }
        }
      }
    }
  }

  @override
  String getString(String key, String defaultValue) {
    // If SDK functionality is disabled, return the default value
    if (!_isSdkFunctionalityEnabled) {
      Logger.d(
          "getString: SDK functionality is disabled, returning fallback for key '$key'");
      Logger.i(
          'CONFIG VALUE: $key: $defaultValue (using fallback, SDK disabled)');
      return defaultValue;
    }

    final variation = _getVariation(key);

    if (variation == null) {
      Logger.i('CONFIG VALUE: $key: $defaultValue (using fallback)');
      return defaultValue;
    }

    if (variation is String) {
      Logger.i('CONFIG VALUE: $key: $variation');

      // Push summary for the retrieved value
      _pushSummaryForKey(key);

      return variation;
    }

    Logger.w(
        'Type mismatch for "$key": expected String, got ${variation.runtimeType}');
    Logger.i(
        'CONFIG VALUE: $key: $defaultValue (using fallback due to type mismatch)');
    return defaultValue;
  }

  @override
  bool getBoolean(String key, bool defaultValue) {
    // If SDK functionality is disabled, return the default value
    if (!_isSdkFunctionalityEnabled) {
      Logger.d(
          "getBoolean: SDK functionality is disabled, returning fallback for key '$key'");
      Logger.i(
          'CONFIG VALUE: $key: $defaultValue (using fallback, SDK disabled)');
      return defaultValue;
    }

    final variation = _getVariation(key);

    if (variation == null) {
      Logger.i('CONFIG VALUE: $key: $defaultValue (using fallback)');
      return defaultValue;
    }

    if (variation is bool) {
      Logger.i('CONFIG VALUE: $key: $variation');

      // Push summary for the retrieved value
      Logger.i(
          '📊 SUMMARY: Calling _pushSummaryForKey for boolean config "$key"');
      _pushSummaryForKey(key);

      return variation;
    }

    Logger.w(
        'Type mismatch for "$key": expected bool, got ${variation.runtimeType}');
    Logger.i(
        'CONFIG VALUE: $key: $defaultValue (using fallback due to type mismatch)');
    return defaultValue;
  }

  @override
  num getNumber(String key, num defaultValue) {
    // If SDK functionality is disabled, return the default value
    if (!_isSdkFunctionalityEnabled) {
      Logger.d(
          "getNumber: SDK functionality is disabled, returning fallback for key '$key'");
      Logger.i(
          'CONFIG VALUE: $key: $defaultValue (using fallback, SDK disabled)');
      return defaultValue;
    }

    final variation = _getVariation(key);

    if (variation == null) {
      Logger.i('CONFIG VALUE: $key: $defaultValue (using fallback)');
      return defaultValue;
    }

    if (variation is num) {
      Logger.i('CONFIG VALUE: $key: $variation');

      // Push summary for the retrieved value
      _pushSummaryForKey(key);

      return variation;
    }

    Logger.w(
        'Type mismatch for "$key": expected num, got ${variation.runtimeType}');
    Logger.i(
        'CONFIG VALUE: $key: $defaultValue (using fallback due to type mismatch)');
    return defaultValue;
  }

  @override
  Map<String, dynamic> getJson(String key, Map<String, dynamic> defaultValue) {
    // If SDK functionality is disabled, return the default value
    if (!_isSdkFunctionalityEnabled) {
      Logger.d(
          "getJson: SDK functionality is disabled, returning fallback for key '$key'");
      Logger.i(
          'CONFIG VALUE: $key: $defaultValue (using fallback, SDK disabled)');
      return defaultValue;
    }

    final variation = _getVariation(key);

    if (variation == null) {
      Logger.i('CONFIG VALUE: $key: $defaultValue (using fallback)');
      return defaultValue;
    }

    if (variation is Map<String, dynamic>) {
      Logger.i('CONFIG VALUE: $key: $variation');

      // Push summary for the retrieved value
      _pushSummaryForKey(key);

      return variation;
    }

    Logger.w(
        'Type mismatch for "$key": expected Map<String, dynamic>, got ${variation.runtimeType}');
    Logger.i(
        'CONFIG VALUE: $key: $defaultValue (using fallback due to type mismatch)');
    return defaultValue;
  }

  @override
  T getConfigValue<T>(String key, T defaultValue) {
    // If SDK functionality is disabled, return the default value
    if (!_isSdkFunctionalityEnabled) {
      Logger.d(
          "getConfigValue: SDK functionality is disabled, returning fallback for key '$key'");
      Logger.i(
          'CONFIG VALUE: $key: $defaultValue (using fallback, SDK disabled)');
      return defaultValue;
    }

    final variation = _getVariation(key);

    if (variation == null) {
      Logger.i('CONFIG VALUE: $key: $defaultValue (using fallback)');
      return defaultValue;
    }

    // Type checking based on the default value type
    if (variation is T) {
      Logger.i('CONFIG VALUE: $key: $variation');

      // Push summary for the retrieved value
      _pushSummaryForKey(key);

      return variation;
    }

    Logger.w(
        'Type mismatch for "$key": expected ${T.toString()}, got ${variation.runtimeType}');
    Logger.i(
        'CONFIG VALUE: $key: $defaultValue (using fallback due to type mismatch)');
    return defaultValue;
  }

  /// Helper method to get the variation value
  dynamic _getVariation(String key) {
    // If SDK functionality is disabled, return null which will cause fallback values to be used
    if (!_isSdkFunctionalityEnabled) {
      Logger.d(
          '_getVariation: SDK functionality is disabled, returning null for key "$key"');
      return null;
    }

    final config = synchronized(_configLock, () => _configMap[key]);

    if (config == null) {
      Logger.d('No config found for key "$key"');
      return null;
    }

    if (config is Map<String, dynamic>) {
      return config['variation'];
    } else {
      Logger.d('Config for "$key" is not a map: $config');
      return null;
    }
  }

  /// Push summary for tracking and analytics
  void _pushSummaryForKey(String key) {
    if (_summaryManager == null) {
      Logger.w(
          '📊 SUMMARY: _summaryManager is null, cannot push summary for key: $key');
      return;
    }

    try {
      final config = synchronized(_configLock, () => _configMap[key]);

      if (config is Map<String, dynamic>) {
        Logger.d('📊 SUMMARY: Raw config for key "$key": $config');

        // Debug: Check if experience_behaviour_response exists
        if (config.containsKey('experience_behaviour_response')) {
          Logger.i(
              '📊 SUMMARY: Found experience_behaviour_response in config for "$key"');
          final ebr = config['experience_behaviour_response'];
          Logger.i('📊 SUMMARY: experience_behaviour_response content: $ebr');
        } else {
          Logger.w(
              '📊 SUMMARY: No experience_behaviour_response found in config for "$key"');
          Logger.w(
              '📊 SUMMARY: Available config keys: ${config.keys.toList()}');
        }

        // Create a copy to avoid modifying the original
        final configMapWithKey = Map<String, dynamic>.from(config);

        // Add key to help with debugging
        configMapWithKey['key'] = key;

        // Extract fields from the API response structure
        // Based on the API response, we need to extract from the config directly and experience_behaviour_response

        // Get config_id (from top level)
        if (!configMapWithKey.containsKey('config_id')) {
          configMapWithKey['config_id'] = configMapWithKey['config_id'] ??
              configMapWithKey['id'] ??
              'default-config-id';
        }

        // Get experience_id from experience_behaviour_response or fallback to id
        if (!configMapWithKey.containsKey('experience_id')) {
          final experienceBehaviourResponse =
              configMapWithKey['experience_behaviour_response']
                  as Map<String, dynamic>?;
          configMapWithKey['experience_id'] =
              experienceBehaviourResponse?['experience_id'] ??
                  configMapWithKey['id'] ??
                  'default-experience-id';
        }

        // Get variation_id from top level or experience_behaviour_response
        if (!configMapWithKey.containsKey('variation_id')) {
          final experienceBehaviourResponse =
              configMapWithKey['experience_behaviour_response']
                  as Map<String, dynamic>?;
          configMapWithKey['variation_id'] = configMapWithKey['variation_id'] ??
              experienceBehaviourResponse?['variation_id'] ??
              configMapWithKey['id'] ??
              'default-variation-id';
        }

        // Extract rule_id from experience_behaviour_response
        if (!configMapWithKey.containsKey('rule_id')) {
          final experienceBehaviourResponse =
              configMapWithKey['experience_behaviour_response']
                  as Map<String, dynamic>?;
          final ruleId = experienceBehaviourResponse?['rule_id'];
          if (ruleId != null) {
            configMapWithKey['rule_id'] = ruleId;
          }
        }

        // Extract behaviour_id from experience_behaviour_response
        if (!configMapWithKey.containsKey('behaviour_id')) {
          final experienceBehaviourResponse =
              configMapWithKey['experience_behaviour_response']
                  as Map<String, dynamic>?;
          final behaviourId = experienceBehaviourResponse?['behaviour_id'];
          if (behaviourId != null) {
            configMapWithKey['behaviour_id'] = behaviourId;
          }
        }

        // Set version from top level or default
        if (!configMapWithKey.containsKey('version')) {
          configMapWithKey['version'] =
              configMapWithKey['version']?.toString() ?? '1.0.0';
        }

        // Use async/await with pushSummary instead of then
        Logger.i(
            '📊 SUMMARY: Pushing summary for key: $key with config: ${json.encode(configMapWithKey)}');
        _summaryManager.pushSummary(configMapWithKey).then((result) {
          Logger.i(
              '📊 SUMMARY: Summary push result for key "$key": ${result.isSuccess ? "SUCCESS" : "FAILED"}');
          if (!result.isSuccess) {
            Logger.w('📊 SUMMARY: Failed reason: ${result.getErrorMessage()}');
          }
        }).catchError((error) {
          Logger.w(
              'Failed to push summary for key "$key": ${error is CFResult ? error.getErrorMessage() : error}');
        });
      } else {
        Logger.d(
            '📊 SUMMARY: Config for "$key" is not a map, skipping summary push');
      }
    } catch (e) {
      Logger.e('Exception while pushing summary for key "$key": $e');
    }
  }

  @override
  void addConfigListener<T>(String key, void Function(T) listener) {
    synchronized(_configLock, () {
      // Get or create list of listeners for this key
      final listeners = _configListeners[key] ?? [];

      // Add listener
      listeners.add((value) {
        if (value is T) {
          listener(value);
        } else {
          Logger.w(
              'Type mismatch for listener on "$key": expected ${T.toString()}, got ${value.runtimeType}');
        }
      });

      // Update map
      _configListeners[key] = listeners;
    });

    // Silent - listener registration is routine

    // Notify immediately if we already have a value
    final variation = _getVariation(key);
    if (variation != null && variation is T) {
      listener(variation);
    }
  }

  @override
  void removeConfigListener<T>(String key, void Function(T) listener) {
    synchronized(_configLock, () {
      // Get listeners for this key
      final listeners = _configListeners[key];

      if (listeners != null) {
        // Remove matching listeners
        // This is a bit tricky since we can't directly compare function references
        // We'll need to use toString() and hope for the best
        final listenerString = listener.toString();
        listeners.removeWhere((l) => l.toString() == listenerString);

        // Update map
        _configListeners[key] = listeners;
      }
    });

    // Silent - listener removal is routine
  }

  @override
  void clearConfigListeners(String key) {
    synchronized(_configLock, () {
      _configListeners.remove(key);
    });

    // Silent - clearing listeners is routine
  }

  @override
  Map<String, dynamic> getAllFlags() {
    final result = <String, dynamic>{};

    synchronized(_configLock, () {
      for (final entry in _configMap.entries) {
        final key = entry.key;
        final value = entry.value;

        // Only handle feature flag configs with variation field
        if (value is Map<String, dynamic> && value.containsKey('variation')) {
          result[key] = value['variation'];
        }
        // Skip configs without variation field
      }
    });

    return result;
  }

  /// Get full config data for a specific flag (including experience_behaviour_response)
  @override
  Map<String, dynamic>? getFullFlagConfig(String key) {
    return synchronized(_configLock, () {
      final config = _configMap[key];
      if (config is Map<String, dynamic>) {
        return Map<String, dynamic>.from(config);
      }
      return null;
    });
  }

  /// Get all full flag configs (including experience_behaviour_response)
  Map<String, Map<String, dynamic>> getAllFullFlagConfigs() {
    final result = <String, Map<String, dynamic>>{};

    synchronized(_configLock, () {
      for (final entry in _configMap.entries) {
        final key = entry.key;
        final value = entry.value;

        // Only handle feature flag configs with variation field
        if (value is Map<String, dynamic> && value.containsKey('variation')) {
          result[key] = Map<String, dynamic>.from(value);
        }
        // Skip configs without variation field
      }
    });

    return result;
  }

  @override
  bool hasConfiguration() {
    return synchronized(_configLock, () {
      return _configMap.isNotEmpty || _initialCacheLoadComplete;
    });
  }

  @override
  void shutdown() {
    Logger.i('Shutting down ConfigManager');
    _sdkSettingsTimer?.cancel();
    _sdkSettingsTimer = null;
    _connectionDebounceTimer?.cancel();
    _connectionDebounceTimer = null;
    _configListeners.clear();
  }

  @override
  Future<bool> refreshConfigs() async {
    // Don't fetch if offline
    if (_configFetcher.isOffline()) {
      Logger.d('Offline mode enabled, skipping config refresh');
      return false;
    }

    Logger.d('Manual refresh of configs triggered');
    try {
      // Add a timeout to the fetch operation to prevent hanging
      final fetchSuccess = await _configFetcher.fetchConfig().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Logger.w('Config fetch timed out after 10 seconds');
          _connectionManager?.recordConnectionFailure('Config fetch timed out');
          return false;
        },
      );

      if (!fetchSuccess) {
        Logger.w('Failed to fetch configs during manual refresh');
        _connectionManager?.recordConnectionFailure('Failed to fetch configs');
        return false;
      }

      // Record connection success after successful fetch
      _connectionManager?.recordConnectionSuccess();

      final configsResult = _configFetcher.getConfigs();

      if (!configsResult.isSuccess) {
        Logger.w(
            'Failed to get configs during manual refresh: ${configsResult.getErrorMessage()}');
        _connectionManager?.recordConnectionFailure(
            configsResult.getErrorMessage() ?? 'Failed to get configs');
        return false;
      }

      final configs = configsResult.getOrNull() ?? {};
      Logger.i('Successfully refreshed ${configs.length} config entries');

      _updateConfigMap(configs);
      return true;
    } catch (e) {
      Logger.e('Error refreshing configs: $e');
      _connectionManager
          ?.recordConnectionFailure('Error refreshing configs: $e');
      return false;
    }
  }

  @override
  void dumpConfigMap() {
    Logger.i('===== CONFIG VALUES =====');

    synchronized(_configLock, () {
      for (final key in _configMap.keys) {
        final value = _configMap[key];

        // Extract variation value if it's a feature flag config
        if (value is Map<String, dynamic> && value.containsKey('variation')) {
          Logger.i('$key: ${value['variation']}');
        } else {
          // For non-feature-flag configs, just print the value
          Logger.i('$key: $value');
        }
      }
    });

    Logger.i('=========================');
  }

  /// Returns whether SDK functionality is currently enabled
  @override
  bool isSdkFunctionalityEnabled() {
    return _isSdkFunctionalityEnabled;
  }

  @override
  SdkSettings? getSdkSettings() {
    return _currentSdkSettings;
  }

  @override
  Future<void> waitForInitialLoad() async {
    // Wait for SDK settings initialization to complete
    await _sdkSettingsCompleter.future;
  }

  @override
  void updateConfigsFromClient(Map<String, dynamic> newConfigs) {
    _updateConfigMap(newConfigs);
  }

  /// Set offline mode for the ConfigManager
  void setOfflineMode(bool offline) {
    _configFetcher.setOffline(offline);
    Logger.i('ConfigManager offline mode set to: $offline');
  }

  @override
  void onConnectionStatusChanged(
      ConnectionStatus status, ConnectionInformation info) {
    Logger.d('🔌 Connection status changed: $status');

    // Cancel any existing debounce timer
    _connectionDebounceTimer?.cancel();

    // If we just connected, check for updates with debouncing
    if (status == ConnectionStatus.connected) {
      Logger.d('🔌 Connection restored, checking for config updates');

      // Debounce the check to prevent rapid successive calls
      _connectionDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _checkSdkSettings();
      });
    }
  }

  void close() {
    Logger.d('Closing ConfigManager');

    // Remove self as connection listener
    _connectionManager?.removeConnectionStatusListener(this);

    _sdkSettingsTimer?.cancel();
    _connectionDebounceTimer?.cancel();
    _configListeners.clear();
  }

  /// Setup configuration change listeners
  /// This method centralizes the config change listener setup that was previously in CFClient
  @override
  void setupListeners({
    required void Function(CFConfig) onConfigChange,
    required SummaryManager summaryManager,
  }) {
    Logger.d('🔧 Setting up configuration change listeners');

    // No direct configuration change mechanism in this implementation
    // Configuration changes happen through SDK settings which are handled internally
    // The onConfigChange callback is available for future extensions
  }

  /// Deep equality check for Maps
  bool _mapsAreEqual(Map<dynamic, dynamic> map1, Map<dynamic, dynamic> map2) {
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;

      final value1 = map1[key];
      final value2 = map2[key];

      if (value1 is Map && value2 is Map) {
        if (!_mapsAreEqual(value1, value2)) return false;
      } else if (value1 is List && value2 is List) {
        if (!_listsAreEqual(value1, value2)) return false;
      } else if (value1 != value2) {
        return false;
      }
    }

    return true;
  }

  /// Deep equality check for Lists
  bool _listsAreEqual(List<dynamic> list1, List<dynamic> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      final value1 = list1[i];
      final value2 = list2[i];

      if (value1 is Map && value2 is Map) {
        if (!_mapsAreEqual(value1, value2)) return false;
      } else if (value1 is List && value2 is List) {
        if (!_listsAreEqual(value1, value2)) return false;
      } else if (value1 != value2) {
        return false;
      }
    }

    return true;
  }
}

/// Helper for synchronized blocks
T synchronized<T>(Object lock, T Function() fn) {
  T result;
  result = fn();
  return result;
}
