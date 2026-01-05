// lib/src/client/cf_client_initializer.dart
//
// Initialization logic for CFClient - centralizes complex setup operations
// to reduce the size of the main CFClient class while maintaining separation of concerns.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';

import '../analytics/event/event_data.dart';
import '../client/managers/config_manager.dart';
import '../client/managers/user_manager.dart';
import '../config/core/cf_config.dart';
import '../core/error/error_handler.dart';
import '../core/error/error_severity.dart';
import '../core/model/cf_user.dart';
import '../core/model/device_context.dart';
import '../core/model/application_info.dart';
import '../core/model/evaluation_context.dart';
import '../core/model/context_type.dart';
import '../core/session/session_manager.dart';
import '../infrastructure/storage/internal/cache_manager_impl.dart';
import '../analytics/event/event_tracker.dart';
import '../infrastructure/logging/logger.dart';
import '../infrastructure/platform/internal/device_info_detector.dart'
    as detector;
import '../infrastructure/types.dart';

/// Handles complex initialization logic for CFClient
class CFClientInitializer {
  static const _source = 'CFClientInitializer';

  /// Initialize environment attributes (device and application info)
  static void initializeEnvironmentAttributes(
    CFConfig config,
    CFUser user,
    UserManager userManager,
  ) {
    if (!config.autoEnvAttributesEnabled) {
      Logger.d(
          'Auto environment attributes disabled, skipping automatic collection');
      return;
    }

    Logger.d(
        'Auto environment attributes enabled, collecting device and application info');

    // Collect device context automatically
    _collectDeviceContextAsync(user.device, userManager);

    // Collect application info automatically
    _collectApplicationInfoAsync(user.application, userManager);
  }

  /// Setup connection listeners
  static void setupConnectionListeners(IConnectionManager connectionManager) {
    connectionManager.addConnectionStatusListener(
      _BasicConnectionStatusListener(onStatusChanged: (status, info) {
        Logger.d('Connection status changed: $status');
      }),
    );
  }

  /// Setup background state listeners
  static void setupBackgroundListeners({
    required IBackgroundStateMonitor backgroundStateMonitor,
    required void Function() onPausePolling,
    required void Function() onResumePolling,
    required void Function() onCheckSdkSettings,
    SessionManager? sessionManager,
  }) {
    backgroundStateMonitor.addAppStateListener((state) {
      if (state == AppState.background) {
        onPausePolling();
        // Notify SessionManager about background transition
        sessionManager?.onAppBackground();
      } else if (state == AppState.foreground) {
        onResumePolling();
        onCheckSdkSettings();
        // Notify SessionManager about foreground transition
        sessionManager?.onAppForeground();
        // Update session activity
        sessionManager?.updateActivity();
      }
    });
  }

  /// Setup user change listeners for config refresh
  static void setupUserChangeListeners({
    required UserManager userManager,
    required ConfigManager configManager,
    required bool offlineMode,
  }) {
    userManager.addUserChangeListener((CFUser updatedUser) {
      try {
        Logger.d('👤 User properties changed, refetching configs');

        // Skip config refetch if in offline mode
        if (offlineMode) {
          Logger.d('Skipping config refetch in offline mode');
          return;
        }

        // Trigger config refresh when user properties change
        configManager.refreshConfigs().then((success) {
          if (success) {
            Logger.d('✅ Successfully refetched configs after user change');
          } else {
            Logger.w('⚠️ Failed to refetch configs after user change');
          }
        }).catchError((e) {
          Logger.e('❌ Error refetching configs after user change: $e');
          ErrorHandler.handleException(
            e,
            'Failed to refetch configs after user change',
            source: _source,
            severity: ErrorSeverity.medium,
          );
        });
      } catch (e) {
        Logger.e('Error in user change listener: $e');
        ErrorHandler.handleException(
          e,
          'Error in user change listener',
          source: _source,
          severity: ErrorSeverity.medium,
        );
      }
    });

    Logger.d('User change listener set up for config refetching');
  }

  /// Setup event tracking listeners for rule event config refresh
  static void setupEventTrackingListeners({
    required EventTracker eventTracker,
    required ConfigManager configManager,
    required bool Function() isOfflineMode,
  }) {
    eventTracker.setEventCallback((EventData event) {
      try {
        // Get the latest SDK settings from ConfigManager
        final sdkSettings = configManager.getSdkSettings();
        if (sdkSettings == null) {
          Logger.d(
              'No SDK settings available, skipping event-based config refresh check');
          return;
        }

        // Check if this event is in the rule_events list
        final eventName = event.eventCustomerId.toLowerCase();
        final ruleEvents =
            sdkSettings.ruleEvents.map((e) => e.toLowerCase()).toList();

        if (ruleEvents.contains(eventName)) {
          Logger.d('🎯 Rule event "$eventName" tracked, refetching configs');

          // Skip config refetch if in offline mode
          if (isOfflineMode()) {
            Logger.d('Skipping config refetch in offline mode');
            return;
          }

          // Trigger config refresh when rule event is tracked
          configManager.refreshConfigs().then((success) {
            if (success) {
              Logger.d(
                  '✅ Successfully refetched configs after rule event "$eventName"');
            } else {
              Logger.w(
                  '⚠️ Failed to refetch configs after rule event "$eventName"');
            }
          }).catchError((e) {
            Logger.e(
                '❌ Error refetching configs after rule event "$eventName": $e');
            ErrorHandler.handleException(
              e,
              'Failed to refetch configs after rule event',
              source: _source,
              severity: ErrorSeverity.medium,
            );
          });
        }
      } catch (e) {
        Logger.e('Error in event tracking listener: $e');
        ErrorHandler.handleException(
          e,
          'Error in event tracking listener',
          source: _source,
          severity: ErrorSeverity.medium,
        );
      }
    });

    Logger.d('Event tracking listener set up for rule event config refetching');
  }

  /// Initialize cache manager
  static Future<void> initializeCacheManager(CFConfig config) async {
    try {
      await CacheManagerImpl.instance.initialize();

      // Note: Cache size limits simplified - using default memory management
      Logger.d('CacheManager initialized with default settings');

      // Note: Cache stats simplified
      Logger.d('CacheManager ready');
    } catch (e) {
      Logger.e('Failed to initialize CacheManager: $e');
    }
  }

  /// Add main user context
  static EvaluationContext createMainUserContext(
      CFUser user, String sessionId) {
    return EvaluationContext(
      type: ContextType.user,
      key: user.userCustomerId ?? sessionId,
    );
  }

  // Private helper methods

  static void _collectDeviceContextAsync(
    DeviceContext? existingContext,
    UserManager userManager,
  ) {
    detector.DeviceInfoDetector.detectDeviceInfo().then((deviceContext) {
      // Merge with existing context if available
      final mergedContext = _mergeDeviceContext(existingContext, deviceContext);

      userManager.updateDeviceContext(mergedContext);
      Logger.d(
          'Auto-collected device context: ${mergedContext.manufacturer} ${mergedContext.model}');
    }).catchError((error) {
      Logger.e('Failed to collect device context: $error');

      // Fallback to basic context if detection fails
      final fallbackContext = existingContext ?? DeviceContext.createBasic();
      userManager.updateDeviceContext(fallbackContext);
    });
  }

  static void _collectApplicationInfoAsync(
    ApplicationInfo? existingInfo,
    UserManager userManager,
  ) {
    detector.ApplicationInfoDetector.detectApplicationInfo().then((appInfo) {
      if (appInfo != null) {
        // Merge with existing info if available
        final mergedInfo = _mergeApplicationInfo(existingInfo, appInfo);

        userManager.updateApplicationInfo(mergedInfo);
        Logger.d(
            'Auto-collected application info: ${mergedInfo.appName} v${mergedInfo.versionName}');
      } else {
        Logger.w(
            'Failed to detect application info, using existing or default');
        if (existingInfo != null) {
          userManager.updateApplicationInfo(existingInfo);
        }
      }
    }).catchError((error) {
      Logger.e('Failed to collect application info: $error');

      // Use existing info if available
      if (existingInfo != null) {
        userManager.updateApplicationInfo(existingInfo);
      }
    });
  }

  static DeviceContext _mergeDeviceContext(
      DeviceContext? existing, DeviceContext detected) {
    if (existing == null) return detected;

    // Merge custom attributes
    final mergedAttributes =
        Map<String, dynamic>.from(existing.customAttributes);
    mergedAttributes.addAll(detected.customAttributes);

    return DeviceContext(
      manufacturer: detected.manufacturer ?? existing.manufacturer,
      model: detected.model ?? existing.model,
      osName: detected.osName ?? existing.osName,
      osVersion: detected.osVersion ?? existing.osVersion,
      sdkVersion: detected.sdkVersion,
      appId: detected.appId ?? existing.appId,
      appVersion: detected.appVersion ?? existing.appVersion,
      locale: detected.locale ?? existing.locale,
      timezone: detected.timezone ?? existing.timezone,
      screenWidth: detected.screenWidth ?? existing.screenWidth,
      screenHeight: detected.screenHeight ?? existing.screenHeight,
      screenDensity: detected.screenDensity ?? existing.screenDensity,
      networkType: detected.networkType ?? existing.networkType,
      networkCarrier: detected.networkCarrier ?? existing.networkCarrier,
      customAttributes: mergedAttributes,
    );
  }

  static ApplicationInfo _mergeApplicationInfo(
      ApplicationInfo? existing, ApplicationInfo detected) {
    if (existing == null) {
      return ApplicationInfo(
        appName: detected.appName,
        packageName: detected.packageName,
        versionName: detected.versionName,
        versionCode: detected.versionCode,
        installDate: detected.installDate,
        lastUpdateDate: detected.lastUpdateDate,
        buildType: detected.buildType,
        launchCount: 1,
        customAttributes: detected.customAttributes,
      );
    }

    // Merge custom attributes
    final mergedAttributes =
        Map<String, String>.from(existing.customAttributes);
    mergedAttributes.addAll(detected.customAttributes);

    return ApplicationInfo(
      appName: detected.appName ?? existing.appName,
      packageName: detected.packageName ?? existing.packageName,
      versionName: detected.versionName ?? existing.versionName,
      versionCode: detected.versionCode ?? existing.versionCode,
      installDate: existing.installDate ?? detected.installDate,
      lastUpdateDate: detected.lastUpdateDate ?? existing.lastUpdateDate,
      buildType: detected.buildType ?? existing.buildType,
      launchCount: existing.launchCount + 1, // Increment launch count
      customAttributes: mergedAttributes,
    );
  }
}

// Basic listener implementations
class _BasicConnectionStatusListener implements ConnectionStatusListener {
  final void Function(ConnectionStatus, ConnectionInformation) onStatusChanged;

  _BasicConnectionStatusListener({required this.onStatusChanged});

  @override
  void onConnectionStatusChanged(
      ConnectionStatus status, ConnectionInformation info) {
    onStatusChanged(status, info);
  }
}
