// infrastructure/network/interfaces/config_fetcher.dart
//
// Abstract interface for configuration fetching operations.
// Defines the contract for fetching feature flags and SDK settings from the API.

import 'dart:async';
import '../../../core/error/cf_result.dart';

/// Abstract interface for configuration fetching operations
abstract class IConfigFetcher {
  /// Returns whether the client is in offline mode
  bool isOffline();

  /// Sets the offline mode status
  void setOffline(bool offline);

  /// Fetches configuration from the API with conditional request support
  Future<bool> fetchConfig({String? lastModified, String? etag});

  /// Fetches metadata headers from a URL for conditional requests
  Future<CFResult<Map<String, String>>> fetchMetadata([String? url]);

  /// Fetches SDK settings configuration
  Future<CFResult<Map<String, dynamic>>> fetchSdkSettings();

  /// Returns the last successfully fetched configuration map
  CFResult<Map<String, dynamic>> getConfigs();

  /// Get configuration for a specific flag
  CFResult<Map<String, dynamic>> getConfig(String flagKey);

  /// Check if a flag exists in the configuration
  bool hasFlag(String flagKey);

  /// Get flag configuration for a specific flag (nullable return)
  Map<String, dynamic>? getFlagConfig(String flagKey);

  /// Check if a flag exists
  bool flagExists(String flagKey);

  /// Clear all configurations
  void clearConfigs();
}
