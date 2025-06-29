import 'dart:async';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:flutter/foundation.dart';

import '../core/error/error_category.dart';
import '../core/model/cf_user.dart';
import '../platform/device_info_detector.dart';

/// The main entry point for the CustomFit SDK.
class CustomFit {
  // Singleton instance
  static CustomFit? _instance;

  // Client key
  final String _clientKey;

  // Configuration
  final CFConfig _config;

  // Current user
  CFUser? _user;

  // Private constructor
  CustomFit._({
    required String clientKey,
    required CFConfig config,
  })  : _clientKey = clientKey,
        _config = config {
    // Extract dimension ID from client key
    _extractDimensionId();
  }

  /// Initialize the SDK with the given client key and configuration.
  static Future<CFResult<void>> initialize({
    required String clientKey,
    CFConfig? config,
  }) async {
    try {
      if (_instance != null) {
        return CFResult.error(
          'SDK already initialized',
          category: ErrorCategory.configuration,
        );
      }

      // Create instance with default config if not provided
      _instance = CustomFit._(
        clientKey: clientKey,
        config: config ?? CFConfig.fromClientKey(clientKey),
      );

      // Initialize SDK components
      _initializeComponents(_instance!);

      return CFResult.success(null);
    } catch (e) {
      return CFResult.error(
        'Failed to initialize SDK: ${e.toString()}',
        exception: e,
        category: ErrorCategory.configuration,
      );
    }
  }

  /// Get the singleton instance of the SDK.
  static CustomFit get instance {
    if (_instance == null) {
      throw StateError(
          'SDK not initialized. Call CustomFit.initialize() first.');
    }
    return _instance!;
  }

  /// Extract dimension ID from client key.
  void _extractDimensionId() {
    try {
      // Example client key format: sdk_123456789_abcdef
      final parts = _clientKey.split('_');
      if (parts.length >= 2) {
        // We can't directly set dimensionId since it's readonly
        // _config.dimensionId = parts[1];
      }
    } catch (e) {
      debugPrint('Failed to extract dimension ID from client key: $e');
    }
  }

  /// Identify a user.
  static Future<CFResult<void>> identify(CFUser user) async {
    try {
      final instance = CustomFit.instance;
      instance._user = user;

      // Auto-collect device info if enabled
      if (instance._config.autoEnvAttributesEnabled) {
        _collectDeviceInfo(instance);
        _collectAppInfo(instance);
      }

      // Notify components of user change
      _onUserChanged(instance, user);

      return CFResult.success(null);
    } catch (e) {
      return CFResult.error(
        'Failed to identify user: ${e.toString()}',
        exception: e,
        category: ErrorCategory.user,
      );
    }
  }

  /// Helper to collect device info
  static void _collectDeviceInfo(CustomFit instance) {
    try {
      DeviceInfoDetector.detectDeviceInfo().then((deviceContext) {
        // DeviceInfoDetector.detectDeviceInfo() always returns a non-null DeviceContext
        instance._user = instance._user?.withDeviceContext(deviceContext);
      });
    } catch (e) {
      debugPrint('Failed to detect device info: $e');
    }
  }

  /// Helper to collect app info
  static void _collectAppInfo(CustomFit instance) {
    try {
      ApplicationInfoDetector.detectApplicationInfo().then((appInfo) {
        if (appInfo != null) {
          instance._user = instance._user?.withApplicationInfo(appInfo);
        }
      });
    } catch (e) {
      debugPrint('Failed to detect app info: $e');
    }
  }

  /// Track an event.
  static Future<CFResult<void>> trackEvent(
    String eventType, {
    Map<String, dynamic>? properties,
  }) async {
    try {
      final instance = CustomFit.instance;

      if (instance._user == null) {
        return CFResult.error(
          'User not identified. Call CustomFit.identify() first.',
          category: ErrorCategory.user,
        );
      }

      // Send event to event tracker
      _trackEventInternal(instance, eventType, properties);

      return CFResult.success(null);
    } catch (e) {
      return CFResult.error(
        'Failed to track event: ${e.toString()}',
        exception: e,
        category: ErrorCategory.analytics,
      );
    }
  }

  /// Check if a feature is enabled.
  static Future<CFResult<bool>> isFeatureEnabled(String featureKey) async {
    try {
      final instance = CustomFit.instance;

      if (instance._user == null) {
        return CFResult.error(
          'User not identified. Call CustomFit.identify() first.',
          category: ErrorCategory.user,
        );
      }

      // Check feature flag
      final result = _checkFeatureFlag(instance, featureKey);
      return CFResult.success(result);
    } catch (e) {
      return CFResult.error(
        'Failed to check feature flag: ${e.toString()}',
        exception: e,
        category: ErrorCategory.featureFlag,
      );
    }
  }

  /// Get feature configuration.
  static Future<CFResult<Map<String, dynamic>>> getFeatureConfig(
    String featureKey, {
    Map<String, dynamic>? defaultValue,
  }) async {
    try {
      final instance = CustomFit.instance;

      if (instance._user == null) {
        return CFResult.error(
          'User not identified. Call CustomFit.identify() first.',
          category: ErrorCategory.user,
        );
      }

      // Retrieve feature configuration
      final config =
          _getFeatureConfiguration(instance, featureKey, defaultValue);
      return CFResult.success(config);
    } catch (e) {
      return CFResult.error(
        'Failed to get feature config: ${e.toString()}',
        exception: e,
        category: ErrorCategory.featureFlag,
      );
    }
  }

  /// Set offline mode.
  static void setOfflineMode(bool offline) {
    try {
      // Get instance but avoid unused variable warning
      CustomFit._instance;

      // Can't use copyWith since it doesn't exist
      // instance._config = instance._config.copyWith(offlineMode: offline);

      // Notify components of offline mode change
      _onOfflineModeChanged(offline);
    } catch (e) {
      debugPrint('Failed to set offline mode: $e');
    }
  }

  /// Shutdown the SDK.
  static Future<void> shutdown() async {
    try {
      if (_instance == null) {
        return;
      }

      // Shut down components
      await _shutdownComponents(_instance!);

      _instance = null;
    } catch (e) {
      debugPrint('Failed to shutdown SDK: $e');
    }
  }

  /// Initialize SDK components
  static void _initializeComponents(CustomFit instance) {
    // Component initialization logic will be implemented here
    // when the actual components are created
  }

  /// Notify components of user change
  static void _onUserChanged(CustomFit instance, CFUser user) {
    // User change notification logic will be implemented here
    // when the actual components are created
  }

  /// Track event internally
  static void _trackEventInternal(
      CustomFit instance, String eventType, Map<String, dynamic>? properties) {
    // Event tracking logic will be implemented here
    // when the event tracking component is created
  }

  /// Check feature flag
  static bool _checkFeatureFlag(CustomFit instance, String featureKey) {
    // Feature flag checking logic will be implemented here
    // when the feature flag component is created
    return false; // Default disabled
  }

  /// Get feature configuration
  static Map<String, dynamic> _getFeatureConfiguration(CustomFit instance,
      String featureKey, Map<String, dynamic>? defaultValue) {
    // Feature configuration logic will be implemented here
    // when the feature flag component is created
    return defaultValue ?? {};
  }

  /// Notify components of offline mode change
  static void _onOfflineModeChanged(bool offline) {
    // Offline mode change notification logic will be implemented here
    // when the actual components are created
  }

  /// Shutdown components
  static Future<void> _shutdownComponents(CustomFit instance) async {
    // Component shutdown logic will be implemented here
    // when the actual components are created
  }
}
