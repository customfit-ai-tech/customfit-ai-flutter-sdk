// lib/src/client/cf_client_configuration_management.dart
//
// Configuration management facade for CFClient
// Handles all configuration-related operations including offline mode, refresh, and settings

import 'dart:async';
import '../client/managers/config_manager.dart';
import '../network/config/config_fetcher.dart';
import '../network/connection/connection_manager.dart';
import '../config/core/mutable_cf_config.dart';
import '../logging/logger.dart';

/// Facade component for configuration management operations
///
/// This component encapsulates all configuration-related functionality including:
/// - Offline mode management
/// - Configuration refresh and synchronization
/// - Configuration fetching and caching
/// - Network state management
class CFClientConfigurationManagement {
  static const _source = 'CFClientConfigurationManagement';

  final ConfigManager _configManager;
  final ConfigFetcher _configFetcher;
  final ConnectionManagerImpl _connectionManager;
  final MutableCFConfig _mutableConfig;

  CFClientConfigurationManagement({
    required ConfigManager configManager,
    required ConfigFetcher configFetcher,
    required ConnectionManagerImpl connectionManager,
    required MutableCFConfig mutableConfig,
  })  : _configManager = configManager,
        _configFetcher = configFetcher,
        _connectionManager = connectionManager,
        _mutableConfig = mutableConfig;

  // MARK: - Configuration Management

  /// Synchronizes fetching configuration and getting all flags
  Future<Map<String, dynamic>> fetchAndGetAllFlags(
      {String? lastModified}) async {
    try {
      await _configManager.refreshConfigs();
      return _configManager.getAllFlags();
    } catch (e) {
      Logger.e('❌ Error during synchronized fetch: $e');
      return _configManager.getAllFlags();
    }
  }

  /// Puts the client in offline mode
  void setOffline(bool offline) {
    _mutableConfig.setOfflineMode(offline);
    _configFetcher.setOffline(offline);
    _connectionManager.setOfflineMode(offline);
    if (_configManager is ConfigManagerImpl) {
      _configManager.setOfflineMode(offline);
    }
  }

  /// Returns whether the client is in offline mode
  bool isOffline() => _configFetcher.isOffline();

  /// Force a refresh of the configuration
  Future<bool> forceRefresh() async => await _configManager.refreshConfigs();

  /// Increment the application launch count
  void incrementAppLaunchCount() => Logger.i('App launch count incremented');

  /// Get all available feature flags
  Map<String, dynamic> getAllFlags() => _configManager.getAllFlags();

  /// Get a configuration value with type safety
  T getConfigValue<T>(String key, T defaultValue) {
    return _configManager.getConfigValue<T>(key, defaultValue);
  }

  /// Check if a flag exists in the configuration
  bool flagExists(String key) => _configManager.getAllFlags().containsKey(key);

  /// Get configuration manager instance (for internal use)
  ConfigManager get configManager => _configManager;

  /// Get config fetcher instance (for internal use)
  ConfigFetcher get configFetcher => _configFetcher;

  /// Get connection manager instance (for internal use)
  ConnectionManagerImpl get connectionManager => _connectionManager;
}
