// lib/src/client/cf_client_config_management.dart
//
// Configuration management component for CustomFit SDK.
// Handles SDK settings checks, configuration fetching, and config map updates.
//
// This component is part of the CFClient facade pattern architecture.

import 'dart:async';
import '../logging/logger.dart';
import '../network/config/config_fetcher.dart';
import '../network/connection/connection_manager.dart';
import '../client/managers/config_manager.dart';
import '../config/core/mutable_cf_config.dart';
import '../constants/cf_constants.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';

/// Configuration management component for the CFClient.
///
/// Handles SDK settings checks, configuration fetching, and config map updates.
/// This component supports the facade pattern by extracting configuration-related
/// operations from the main client class.
class CFClientConfigManagement {
  static const _source = 'CFClientConfigManagement';

  final ConfigFetcher _configFetcher;
  final ConnectionManagerImpl _connectionManager;
  final ConfigManager _configManager;
  final MutableCFConfig _mutableConfig;

  Timer? _sdkSettingsTimer;
  String? _previousLastModified;
  final Map<String, dynamic> _configMap;
  final Completer<void> _sdkSettingsCompleter;

  CFClientConfigManagement({
    required ConfigFetcher configFetcher,
    required ConnectionManagerImpl connectionManager,
    required ConfigManager configManager,
    required MutableCFConfig mutableConfig,
    required Map<String, dynamic> configMap,
    required Completer<void> sdkSettingsCompleter,
  })  : _configFetcher = configFetcher,
        _connectionManager = connectionManager,
        _configManager = configManager,
        _mutableConfig = mutableConfig,
        _configMap = configMap,
        _sdkSettingsCompleter = sdkSettingsCompleter;

  /// Perform initial SDK settings check during client initialization
  Future<void> performInitialSdkSettingsCheck() async {
    // Skip initial SDK settings check if in offline mode
    if (_mutableConfig.config.offlineMode) {
      Logger.d('SKIPPING initial SDK settings check in offline mode');
      // Complete the completer immediately to signal initialization is done
      if (!_sdkSettingsCompleter.isCompleted) {
        _sdkSettingsCompleter.complete();
      }
      return;
    }

    // Check once without relying on timer
    Logger.d('Performing initial SDK settings check (one-time)');
    await checkSdkSettings();

    // Complete the completer to signal initialization is done
    if (!_sdkSettingsCompleter.isCompleted) {
      _sdkSettingsCompleter.complete();
    }

    // Log that future checks will be handled by ConfigManager
    Logger.d(
        'Initial SDK settings check complete. Future checks will be handled by ConfigManager.');
  }

  /// Check SDK settings and fetch configuration if needed
  Future<void> checkSdkSettings() async {
    // Skip SDK settings check if in offline mode
    if (_mutableConfig.config.offlineMode) {
      Logger.d('SKIPPING SDK settings check in offline mode');
      if (!_sdkSettingsCompleter.isCompleted) {
        _sdkSettingsCompleter.complete();
      }
      return;
    }

    try {
      // Get the correct SDK settings URL to match Kotlin implementation
      final String dimensionId = _mutableConfig.config.dimensionId ?? "default";
      final sdkSettingsPath = CFConstants.api.sdkSettingsPathPattern
          .replaceFirst('%s', dimensionId);
      final sdkUrl = "${CFConstants.api.sdkSettingsBaseUrl}$sdkSettingsPath";

      Logger.d('Fetching SDK settings from: $sdkUrl');

      // Match Kotlin implementation by passing URL to fetchMetadata
      final metaResult = await _configFetcher.fetchMetadata(sdkUrl);

      // Check if metadata fetch was successful
      if (!metaResult.isSuccess) {
        Logger.w(
            'Failed to fetch SDK settings metadata: ${metaResult.getErrorMessage()}');
        _connectionManager.recordConnectionFailure(
            metaResult.getErrorMessage() ??
                'Failed to fetch SDK settings metadata');
        return;
      }

      // Record connection success for metadata fetch
      _connectionManager.recordConnectionSuccess();

      // Unwrap directly using null coalescing
      final headers = metaResult.getOrNull() ?? {};
      final lastMod = headers['Last-Modified'];

      Logger.d(
          'SDK settings metadata received, Last-Modified: $lastMod, previous: $_previousLastModified');

      // Handle unchanged case (304 Not Modified)
      if (lastMod == 'unchanged') {
        Logger.d('Metadata unchanged (304), skipping config fetch');
        return;
      }

      // Only fetch configs if Last-Modified has changed (like Kotlin implementation)
      if (lastMod != null && lastMod != _previousLastModified) {
        _previousLastModified = lastMod;
        Logger.d('Last-Modified header changed, fetching configs');
        await fetchAndProcessConfigs(lastModified: lastMod);
      } else if (_configMap.isEmpty && lastMod != null) {
        // If we've never fetched configs, do it at least once with last-modified header
        Logger.d(
            'First run or empty config, fetching configs with Last-Modified: $lastMod');
        await fetchAndProcessConfigs(lastModified: lastMod);
      } else {
        Logger.d('No change in Last-Modified, skipping config fetch');
      }
    } catch (e) {
      final errorMsg = 'SDK settings check failed: ${e.toString()}';
      Logger.e(errorMsg);
      _connectionManager.recordConnectionFailure(errorMsg);
      ErrorHandler.handleException(e, 'SDK settings check failed',
          source: _source, severity: ErrorSeverity.medium);
    }
  }

  /// Fetch configuration and process results
  Future<void> fetchAndProcessConfigs({String? lastModified}) async {
    try {
      Logger.d('Fetching user configs with Last-Modified: $lastModified');
      final success =
          await _configFetcher.fetchConfig(lastModified: lastModified);

      if (success) {
        Logger.d('Successfully fetched user configs');
        // Record connection success for config fetch
        _connectionManager.recordConnectionSuccess();

        // Try to get configs
        try {
          final configsResult = _configFetcher.getConfigs();
          final Map<String, dynamic> configs = configsResult.getOrNull() ?? {};
          Logger.d('Processing ${configs.length} configs');
          updateConfigMap(configs);
        } catch (e) {
          Logger.e('Failed to process configs: $e');
          _connectionManager
              .recordConnectionFailure('Failed to process configs: $e');
        }
      } else {
        Logger.e('Failed to fetch user configs');
        _connectionManager
            .recordConnectionFailure('Failed to fetch user configs');
      }
    } catch (e) {
      Logger.e('Error in fetch and process configs: $e');
      _connectionManager
          .recordConnectionFailure('Error in fetch and process configs: $e');
    }
  }

  /// Update the internal configuration map
  void updateConfigMap(Map<String, dynamic> newConfigs) {
    // Critical section for thread safety
    _configMap.clear();
    _configMap.addAll(newConfigs);

    Logger.d('Config map updated with ${newConfigs.length} configs');

    // Enhanced logging for key config values, like hero_text for debugging
    if (newConfigs.containsKey('hero_text')) {
      final heroText = newConfigs['hero_text'];
      if (heroText is Map<String, dynamic> &&
          heroText.containsKey('variation')) {
        Logger.i(
            '🚩 Received hero_text update: ${heroText['variation']} (version: ${heroText['version'] ?? 'unknown'})');
      }
    }

    // Instead of handling notifications here, pass the config updates to ConfigManager
    // to ensure listeners registered there are properly notified
    if (_configManager is ConfigManagerImpl) {
      Logger.d('Delegating config update notification to ConfigManager');
      (_configManager).updateConfigsFromClient(newConfigs);
    } else {
      Logger.e(
          'ConfigManager is not of expected type, notifications may not work properly');
    }
  }

  /// Force a refresh of the configuration regardless of the Last-Modified header
  Future<bool> forceRefresh() async {
    Logger.i('Force refreshing configurations');
    return await _configManager.refreshConfigs();
  }

  /// Synchronizes fetching configuration and getting all flags, ensuring latest data
  Future<Map<String, dynamic>> fetchAndGetAllFlags(
      {String? lastModified}) async {
    Logger.d('🔄 Starting synchronized fetch and get flags...');
    try {
      // Fetch the latest configuration
      final success = await _configManager.refreshConfigs();
      if (!success) {
        Logger.d(
            '⚠️ Fetch config failed during synchronized fetch. Returning current flags.');
        return _configManager.getAllFlags();
      }
      Logger.d('✅ Fetch config succeeded, returning current flags map.');
      return _configManager.getAllFlags();
    } catch (e) {
      Logger.e('❌ Error during synchronized fetch: $e');
      return _configManager.getAllFlags();
    }
  }

  /// Set offline mode for configuration management
  void setOfflineMode(bool offline) {
    Logger.i('Setting configuration offline mode to $offline');
    if (offline) {
      _mutableConfig.setOfflineMode(true);
      _configFetcher.setOffline(true);
      _connectionManager.setOfflineMode(true);
      Logger.i('Configuration management is now in offline mode');
    } else {
      _mutableConfig.setOfflineMode(false);
      _configFetcher.setOffline(false);
      _connectionManager.setOfflineMode(false);
      Logger.i('Configuration management is now in online mode');
    }
  }

  /// Check if configuration management is in offline mode
  bool isOffline() => _configFetcher.isOffline();

  /// Cancel SDK settings timer during shutdown
  void cancelSdkSettingsTimer() {
    _sdkSettingsTimer?.cancel();
    _sdkSettingsTimer = null;
  }

  /// Clean up resources
  void dispose() {
    cancelSdkSettingsTimer();
    _configMap.clear();
  }
}
