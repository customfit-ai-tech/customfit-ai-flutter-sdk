// lib/src/client/cf_client_sdk_settings.dart
//
// SDK settings management for CFClient - handles polling and updates.
// This extracts complex SDK settings logic from the main CFClient class.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';

import '../config/core/cf_config.dart';
import '../client/managers/config_manager.dart';
import '../constants/cf_constants.dart';
import '../logging/logger.dart';
import '../core/resource_registry.dart';
import '../network/config/config_fetcher.dart';
import '../network/connection/connection_manager.dart';

/// Handles SDK settings polling and management
class CFClientSdkSettings {
  static const _source = 'CFClientSdkSettings';

  final CFConfig _config;
  final ConfigFetcher _configFetcher;
  final ConfigManager _configManager;
  final ConnectionManagerImpl _connectionManager;

  ManagedTimer? _sdkSettingsTimer;
  String? _previousLastModified;
  final Completer<void> _sdkSettingsCompleter = Completer<void>();
  bool _isShutdown = false;

  CFClientSdkSettings({
    required CFConfig config,
    required ConfigFetcher configFetcher,
    required ConfigManager configManager,
    required ConnectionManagerImpl connectionManager,
  })  : _config = config,
        _configFetcher = configFetcher,
        _configManager = configManager,
        _connectionManager = connectionManager;

  /// Start periodic SDK settings check
  void startPeriodicCheck() {
    // Skip SDK settings polling entirely if in offline mode
    if (_config.offlineMode) {
      Logger.d('SKIPPING SDK settings polling in offline mode');
      return;
    }

    // DISABLED - We're using ConfigManager for SDK settings polling instead
    // This avoids duplicate polling which was causing continuous network requests

    Logger.d(
        'SDK settings polling via CFClient is disabled to avoid duplicate polling with ConfigManager');
  }

  /// Perform initial SDK settings check
  Future<void> performInitialCheck() async {
    // Skip initial SDK settings check if in offline mode
    if (_config.offlineMode) {
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

  /// Check SDK settings
  Future<void> checkSdkSettings() async {
    // Skip SDK settings check if in offline mode
    if (_config.offlineMode) {
      Logger.d('SKIPPING SDK settings check in offline mode');
      if (!_sdkSettingsCompleter.isCompleted) {
        _sdkSettingsCompleter.complete();
      }
      return;
    }

    try {
      // Get the correct SDK settings URL to match Kotlin implementation
      final String dimensionId = _config.dimensionId ?? "default";
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
        await _fetchAndProcessConfigs(lastModified: lastMod);
      } else if (_configManager.getAllFlags().isEmpty && lastMod != null) {
        // If we've never fetched configs, do it at least once with last-modified header
        Logger.d(
            'First run or empty config, fetching configs with Last-Modified: $lastMod');
        await _fetchAndProcessConfigs(lastModified: lastMod);
      } else {
        Logger.d('No change in Last-Modified, skipping config fetch');
      }
    } catch (e) {
      final errorMsg = 'SDK settings check failed: ${e.toString()}';
      Logger.e(errorMsg);
      _connectionManager.recordConnectionFailure(errorMsg);
    }
  }

  /// Extract config fetching logic to a separate method for reuse
  Future<void> _fetchAndProcessConfigs({String? lastModified}) async {
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

          // Update configs via ConfigManager
          if (_configManager is ConfigManagerImpl) {
            Logger.d('Delegating config update notification to ConfigManager');
            (_configManager).updateConfigsFromClient(configs);
          } else {
            Logger.e(
                'ConfigManager is not of expected type, notifications may not work properly');
          }
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

  /// Pause polling (called when app goes to background)
  void pausePolling() {
    // No-op since we're using ConfigManager for polling
    Logger.d('Pause polling request ignored - using ConfigManager for polling');
  }

  /// Resume polling (called when app comes to foreground)
  void resumePolling() {
    // No-op since we're using ConfigManager for polling
    Logger.d(
        'Resume polling request ignored - using ConfigManager for polling');
  }

  /// Get the SDK settings completer
  Completer<void> get sdkSettingsCompleter => _sdkSettingsCompleter;

  /// Shutdown and cleanup
  void shutdown() {
    if (_isShutdown) return;

    _isShutdown = true;
    _sdkSettingsTimer?.dispose();
    _sdkSettingsTimer = null;
  }
}
