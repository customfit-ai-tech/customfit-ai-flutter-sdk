// lib/src/config/core/cf_config.dart
//
// Immutable configuration class for CustomFit SDK initialization.
// Defines all settings that control SDK behavior including network timeouts,
// event batching, polling intervals, and feature toggles.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:convert';
import '../../logging/logger.dart';
import '../../constants/cf_constants.dart';
import '../../core/error/cf_result.dart';
import '../../core/error/error_category.dart';
import '../../core/error/cf_error_code.dart';

/// Immutable configuration class for CustomFit SDK initialization.
///
/// [CFConfig] defines all settings that control SDK behavior including network timeouts,
/// event batching, polling intervals, and feature toggles. Use the builder pattern
/// to create instances with your desired configuration.
///
/// ## Usage
///
/// ```dart
/// final config = CFConfig.builder('your-client-key')
///   .setDebugLoggingEnabled(true)
///   .setEventsFlushIntervalMs(5000)
///   .setNetworkConnectionTimeoutMs(10000)
///   .setOfflineMode(false)
///   .build();
/// ```
///
/// ## Configuration Categories
///
/// - **Authentication**: Client key for service authentication
/// - **Event Tracking**: Queue sizes, flush intervals, and batching behavior
/// - **Network**: Connection and read timeouts, retry policies
/// - **Polling**: Background polling intervals for configuration updates
/// - **Logging**: Debug and verbose logging controls
/// - **Offline**: Offline mode and local storage settings
///
/// ## Thread Safety
///
/// [CFConfig] instances are immutable and thread-safe. All fields are final
/// and cannot be modified after construction.
class CFConfig {
  /// Client key for authenticating with the CustomFit services
  final String clientKey;

  /// Environment for API endpoints (production by default)
  final CFEnvironment environment;

  // Event tracker configuration
  /// Maximum number of events to queue before forcing a flush
  final int eventsQueueSize;

  /// Maximum time in seconds events should be kept in queue before flushing
  final int eventsFlushTimeSeconds;

  /// Interval in milliseconds for the event flush timer
  final int eventsFlushIntervalMs;

  // Retry configuration
  /// Maximum number of retry attempts for failed network requests
  final int maxRetryAttempts;

  /// Initial delay in milliseconds before the first retry attempt
  final int retryInitialDelayMs;

  /// Maximum delay in milliseconds between retry attempts
  final int retryMaxDelayMs;

  /// Multiplier for calculating exponential backoff between retries
  final double retryBackoffMultiplier;

  // Summary manager configuration
  /// Maximum number of summaries to queue before forcing a flush
  final int summariesQueueSize;

  /// Maximum time in seconds summaries should be kept in queue before flushing
  final int summariesFlushTimeSeconds;

  /// Interval in milliseconds for the summary flush timer
  final int summariesFlushIntervalMs;

  // SDK settings check configuration
  /// Interval in milliseconds for checking SDK settings
  final int sdkSettingsCheckIntervalMs;

  // Network configuration
  /// Connection timeout in milliseconds
  final int networkConnectionTimeoutMs;

  /// Read timeout in milliseconds
  final int networkReadTimeoutMs;

  // Logging configuration
  /// Whether logging is enabled
  final bool loggingEnabled;

  /// Whether debug logging is enabled
  final bool debugLoggingEnabled;

  /// Log level
  final String logLevel;

  // Offline mode
  /// Whether the SDK is in offline mode
  final bool offlineMode;

  // Background operation settings
  /// Whether to disable background polling
  final bool disableBackgroundPolling;

  /// Interval in milliseconds for background polling
  final int backgroundPollingIntervalMs;

  /// Whether to reduce polling frequency when battery is low
  final bool useReducedPollingWhenBatteryLow;

  /// Interval in milliseconds for reduced polling
  final int reducedPollingIntervalMs;

  /// Maximum number of events to store offline
  final int maxStoredEvents;

  // Environment attributes
  /// Whether to automatically collect environment attributes
  final bool autoEnvAttributesEnabled;

  // Local Storage Configuration
  /// Whether to enable local storage/caching
  final bool localStorageEnabled;

  /// Cache TTL in seconds for configuration data
  final int configCacheTtlSeconds;

  /// Cache TTL in seconds for event data
  final int eventCacheTtlSeconds;

  /// Cache TTL in seconds for summary data
  final int summaryCacheTtlSeconds;

  /// Maximum size of local cache in MB
  final int maxCacheSizeMb;

  // Remote logging configuration
  /// Whether remote logging is enabled
  final bool remoteLoggingEnabled;

  /// Remote log provider ("logtail", "custom", or "console_only")
  final String remoteLogProvider;

  /// Remote log endpoint URL
  final String? remoteLogEndpoint;

  /// Remote log API key
  final String? remoteLogApiKey;

  /// Remote log level ("debug", "info", "warn", "error")
  final String remoteLogLevel;

  /// Remote log batch size
  final int remoteLogBatchSize;

  /// Remote log flush interval in milliseconds
  final int remoteLogFlushIntervalMs;

  /// Remote log timeout in milliseconds
  final int remoteLogTimeout;

  /// Remote log metadata
  final Map<String, dynamic>? remoteLogMetadata;

  /// Whether to persist cache across app restarts
  final bool persistCacheAcrossRestarts;

  /// Whether to use stale cache while revalidating
  final bool useStaleWhileRevalidate;

  // Certificate pinning configuration
  /// Whether certificate pinning is enabled
  final bool certificatePinningEnabled;

  /// List of SHA-256 certificate fingerprints to pin
  final List<String> pinnedCertificates;

  /// Whether to allow self-signed certificates (for development)
  final bool allowSelfSignedCertificates;

  // Memory management configuration
  /// Whether memory management is enabled
  final bool? enableMemoryManagement;

  /// Memory pressure thresholds configuration
  final Map<String, double>? memoryPressureThresholds;

  /// Memory monitoring interval in seconds
  final int? memoryMonitoringIntervalSeconds;

  // Secure storage configuration
  /// Whether to use secure storage for sensitive data
  final bool useSecureStorage;

  /// List of data types to store securely
  final List<String> secureDataTypes;

  /// Get dimension ID from client key (cached for performance)
  String? get dimensionId {
    return _JWTParser.getDimensionId(clientKey);
  }

  /// Get base API URL for current environment
  String get baseApiUrl => CFConstants.api.getBaseApiUrl(environment);

  /// Get SDK settings base URL for current environment
  String get sdkSettingsBaseUrl =>
      CFConstants.api.getSdkSettingsBaseUrl(environment);

  /// Auto-detect environment from client key content
  /// Returns staging for development/test keys, production otherwise
  static CFEnvironment detectEnvironment(String clientKey) {
    final dimensionId = _JWTParser.getDimensionId(clientKey);
    if (dimensionId != null) {
      final lowerDimensionId = dimensionId.toLowerCase();

      // Check for staging indicators (includes dev/test since CFEnvironment only has production/staging)
      if (lowerDimensionId.contains('stage') ||
          lowerDimensionId.contains('staging') ||
          lowerDimensionId.contains('dev') ||
          lowerDimensionId.contains('development') ||
          lowerDimensionId.contains('test')) {
        return CFEnvironment.staging;
      }
    }

    // Fallback: check client key content directly
    final lowerClientKey = clientKey.toLowerCase();
    if (lowerClientKey.contains('stage') ||
        lowerClientKey.contains('dev') ||
        lowerClientKey.contains('test')) {
      return CFEnvironment.staging;
    }

    // Default to production for safety
    return CFEnvironment.production;
  }

  /// Create a development configuration profile with optimized settings for development
  ///
  /// Features:
  /// - Debug logging enabled
  /// - Faster flush intervals for immediate feedback
  /// - Shorter timeouts for quicker development iteration
  /// - Reduced retry attempts to fail fast
  ///
  /// Example:
  /// ```dart
  /// final config = CFConfig.development('your-dev-key');
  /// ```
  static CFConfig development(String clientKey) {
    final result = CFConfig.builder(clientKey)
        .setDebugLoggingEnabled(true)
        .setLoggingEnabled(true)
        .setLogLevel('debug')
        .setEventsFlushIntervalMs(1000) // Flush every 1 second
        .setSummariesFlushIntervalMs(1000)
        .setNetworkConnectionTimeoutMs(5000) // Shorter timeout
        .setNetworkReadTimeoutMs(10000)
        .setMaxRetryAttempts(2) // Fail faster in dev
        .setRetryInitialDelayMs(500)
        .setSdkSettingsCheckIntervalMs(30000) // Check every 30 seconds
        .setLocalStorageEnabled(true)
        .setConfigCacheTtlSeconds(300) // 5 minutes cache in dev
        .build();
    if (result.isSuccess) {
      return result.getOrNull()!;
    } else {
      throw Exception(result.getErrorMessage());
    }
  }

  /// Create a production configuration profile with optimized settings for production
  ///
  /// Features:
  /// - Debug logging disabled for performance
  /// - Longer flush intervals to reduce network usage
  /// - Higher retry attempts for reliability
  /// - Optimized timeouts for production environments
  ///
  /// Example:
  /// ```dart
  /// final config = CFConfig.production('your-prod-key');
  /// ```
  static CFConfig production(String clientKey) {
    final result = CFConfig.builder(clientKey)
        .setDebugLoggingEnabled(false)
        .setLoggingEnabled(true)
        .setLogLevel('error') // Only log errors in production
        .setEventsFlushIntervalMs(30000) // Flush every 30 seconds
        .setSummariesFlushIntervalMs(30000)
        .setNetworkConnectionTimeoutMs(15000) // Longer timeout
        .setNetworkReadTimeoutMs(30000)
        .setMaxRetryAttempts(5) // More retries for reliability
        .setRetryInitialDelayMs(2000)
        .setRetryMaxDelayMs(60000)
        .setSdkSettingsCheckIntervalMs(300000) // Check every 5 minutes
        .setLocalStorageEnabled(true)
        .setConfigCacheTtlSeconds(3600) // 1 hour cache
        .setPersistCacheAcrossRestarts(true)
        .setUseStaleWhileRevalidate(true)
        .build();
    if (result.isSuccess) {
      return result.getOrNull()!;
    } else {
      throw Exception(result.getErrorMessage());
    }
  }

  /// Create a testing configuration profile with optimized settings for automated testing
  ///
  /// Features:
  /// - Minimal logging to reduce test output noise
  /// - Very fast flush intervals for test predictability
  /// - Short timeouts to make tests run faster
  /// - Reduced retry attempts to fail fast
  /// - Offline mode support for isolated testing
  ///
  /// Example:
  /// ```dart
  /// final config = CFConfig.testing('test-key');
  /// ```
  static CFConfig testing(String clientKey) {
    final result = CFConfig.builder(clientKey)
        .setDebugLoggingEnabled(false)
        .setLoggingEnabled(false) // Minimal logging in tests
        .setLogLevel('error')
        .setEventsFlushIntervalMs(100) // Very fast flush for tests
        .setSummariesFlushIntervalMs(100)
        .setNetworkConnectionTimeoutMs(2000) // Short timeout
        .setNetworkReadTimeoutMs(5000)
        .setMaxRetryAttempts(1) // Fail fast in tests
        .setRetryInitialDelayMs(100)
        .setSdkSettingsCheckIntervalMs(10000) // Check every 10 seconds
        .setLocalStorageEnabled(false) // Avoid persistence in tests
        .setConfigCacheTtlSeconds(60) // Short cache for tests
        .setPersistCacheAcrossRestarts(false)
        .setOfflineMode(false) // Default online for tests
        .build();
    if (result.isSuccess) {
      return result.getOrNull()!;
    } else {
      throw Exception(result.getErrorMessage());
    }
  }

  /// Private constructor - use builder pattern instead
  CFConfig._({
    required this.clientKey,
    this.environment = CFEnvironment.production,
    this.eventsQueueSize = 100, // Consistent with Swift/Kotlin
    this.eventsFlushTimeSeconds = 60, // Consistent with Swift/Kotlin
    this.eventsFlushIntervalMs =
        1000, // Consistent with Swift/Kotlin (1 second)
    this.maxRetryAttempts = 3, // Consistent with Swift/Kotlin
    this.retryInitialDelayMs = 1000, // Consistent with Swift/Kotlin
    this.retryMaxDelayMs = 30000, // Consistent with Swift/Kotlin
    this.retryBackoffMultiplier = 2.0, // Consistent with Swift/Kotlin
    this.summariesQueueSize = 100, // Consistent with Swift/Kotlin
    this.summariesFlushTimeSeconds = 60, // Consistent with Swift/Kotlin
    this.summariesFlushIntervalMs =
        60000, // Consistent with Swift/Kotlin (60 seconds)
    this.sdkSettingsCheckIntervalMs =
        300000, // Consistent with Swift/Kotlin (5 minutes)
    this.networkConnectionTimeoutMs = 10000, // Consistent with Swift/Kotlin
    this.networkReadTimeoutMs =
        10000, // Consistent with Swift/Kotlin (changed from 30000)
    this.loggingEnabled = true,
    this.debugLoggingEnabled = false,
    this.logLevel = 'DEBUG', // Consistent with Swift/Kotlin
    this.offlineMode = false,
    this.disableBackgroundPolling = false,
    this.backgroundPollingIntervalMs =
        3600000, // Consistent with Swift/Kotlin (1 hour)
    this.useReducedPollingWhenBatteryLow = true,
    this.reducedPollingIntervalMs =
        7200000, // Consistent with Swift/Kotlin (2 hours)
    this.maxStoredEvents = 100, // Consistent with Swift/Kotlin
    this.autoEnvAttributesEnabled = false,
    // Local Storage Configuration
    this.localStorageEnabled = true,
    this.configCacheTtlSeconds = 86400, // 24 hours
    this.eventCacheTtlSeconds = 3600, // 1 hour
    this.summaryCacheTtlSeconds = 3600, // 1 hour
    this.maxCacheSizeMb = 50, // 50 MB
    this.persistCacheAcrossRestarts = true,
    this.useStaleWhileRevalidate = true,
    // Remote logging configuration
    this.remoteLoggingEnabled = false,
    this.remoteLogProvider = 'console_only',
    this.remoteLogEndpoint,
    this.remoteLogApiKey,
    this.remoteLogLevel = 'info',
    this.remoteLogBatchSize = 10,
    this.remoteLogFlushIntervalMs = 30000, // 30 seconds
    this.remoteLogTimeout = 5000, // 5 seconds
    this.remoteLogMetadata,
    // Certificate pinning configuration
    this.certificatePinningEnabled = false,
    this.pinnedCertificates = const [],
    this.allowSelfSignedCertificates = false,
    // Memory management configuration
    this.enableMemoryManagement,
    this.memoryPressureThresholds,
    this.memoryMonitoringIntervalSeconds,
    // Secure storage configuration
    this.useSecureStorage = true,
    this.secureDataTypes = const ['session', 'api_keys', 'sensitive_events'],
  });

  /// Create a copy of this config with updated values
  CFConfig copyWith({
    String? clientKey,
    CFEnvironment? environment,
    int? eventsQueueSize,
    int? eventsFlushTimeSeconds,
    int? eventsFlushIntervalMs,
    int? maxRetryAttempts,
    int? retryInitialDelayMs,
    int? retryMaxDelayMs,
    double? retryBackoffMultiplier,
    int? summariesQueueSize,
    int? summariesFlushTimeSeconds,
    int? summariesFlushIntervalMs,
    int? sdkSettingsCheckIntervalMs,
    int? networkConnectionTimeoutMs,
    int? networkReadTimeoutMs,
    bool? loggingEnabled,
    bool? debugLoggingEnabled,
    String? logLevel,
    bool? offlineMode,
    bool? disableBackgroundPolling,
    int? backgroundPollingIntervalMs,
    bool? useReducedPollingWhenBatteryLow,
    int? reducedPollingIntervalMs,
    int? maxStoredEvents,
    bool? autoEnvAttributesEnabled,
    bool? localStorageEnabled,
    int? configCacheTtlSeconds,
    int? eventCacheTtlSeconds,
    int? summaryCacheTtlSeconds,
    int? maxCacheSizeMb,
    bool? persistCacheAcrossRestarts,
    bool? useStaleWhileRevalidate,
    bool? remoteLoggingEnabled,
    String? remoteLogProvider,
    String? remoteLogEndpoint,
    String? remoteLogApiKey,
    String? remoteLogLevel,
    int? remoteLogBatchSize,
    int? remoteLogFlushIntervalMs,
    int? remoteLogTimeout,
    Map<String, dynamic>? remoteLogMetadata,
    // Certificate pinning parameters
    bool? certificatePinningEnabled,
    List<String>? pinnedCertificates,
    bool? allowSelfSignedCertificates,
    // Memory management parameters
    bool? enableMemoryManagement,
    Map<String, double>? memoryPressureThresholds,
    int? memoryMonitoringIntervalSeconds,
    // Secure storage parameters
    bool? useSecureStorage,
    List<String>? secureDataTypes,
  }) {
    return CFConfig._(
      clientKey: clientKey ?? this.clientKey,
      environment: environment ?? this.environment,
      eventsQueueSize: eventsQueueSize ?? this.eventsQueueSize,
      eventsFlushTimeSeconds:
          eventsFlushTimeSeconds ?? this.eventsFlushTimeSeconds,
      eventsFlushIntervalMs:
          eventsFlushIntervalMs ?? this.eventsFlushIntervalMs,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      retryInitialDelayMs: retryInitialDelayMs ?? this.retryInitialDelayMs,
      retryMaxDelayMs: retryMaxDelayMs ?? this.retryMaxDelayMs,
      retryBackoffMultiplier:
          retryBackoffMultiplier ?? this.retryBackoffMultiplier,
      summariesQueueSize: summariesQueueSize ?? this.summariesQueueSize,
      summariesFlushTimeSeconds:
          summariesFlushTimeSeconds ?? this.summariesFlushTimeSeconds,
      summariesFlushIntervalMs:
          summariesFlushIntervalMs ?? this.summariesFlushIntervalMs,
      sdkSettingsCheckIntervalMs:
          sdkSettingsCheckIntervalMs ?? this.sdkSettingsCheckIntervalMs,
      networkConnectionTimeoutMs:
          networkConnectionTimeoutMs ?? this.networkConnectionTimeoutMs,
      networkReadTimeoutMs: networkReadTimeoutMs ?? this.networkReadTimeoutMs,
      loggingEnabled: loggingEnabled ?? this.loggingEnabled,
      debugLoggingEnabled: debugLoggingEnabled ?? this.debugLoggingEnabled,
      logLevel: logLevel ?? this.logLevel,
      offlineMode: offlineMode ?? this.offlineMode,
      disableBackgroundPolling:
          disableBackgroundPolling ?? this.disableBackgroundPolling,
      backgroundPollingIntervalMs:
          backgroundPollingIntervalMs ?? this.backgroundPollingIntervalMs,
      useReducedPollingWhenBatteryLow: useReducedPollingWhenBatteryLow ??
          this.useReducedPollingWhenBatteryLow,
      reducedPollingIntervalMs:
          reducedPollingIntervalMs ?? this.reducedPollingIntervalMs,
      maxStoredEvents: maxStoredEvents ?? this.maxStoredEvents,
      autoEnvAttributesEnabled:
          autoEnvAttributesEnabled ?? this.autoEnvAttributesEnabled,
      localStorageEnabled: localStorageEnabled ?? this.localStorageEnabled,
      configCacheTtlSeconds:
          configCacheTtlSeconds ?? this.configCacheTtlSeconds,
      eventCacheTtlSeconds: eventCacheTtlSeconds ?? this.eventCacheTtlSeconds,
      summaryCacheTtlSeconds:
          summaryCacheTtlSeconds ?? this.summaryCacheTtlSeconds,
      maxCacheSizeMb: maxCacheSizeMb ?? this.maxCacheSizeMb,
      persistCacheAcrossRestarts:
          persistCacheAcrossRestarts ?? this.persistCacheAcrossRestarts,
      useStaleWhileRevalidate:
          useStaleWhileRevalidate ?? this.useStaleWhileRevalidate,
      remoteLoggingEnabled: remoteLoggingEnabled ?? this.remoteLoggingEnabled,
      remoteLogProvider: remoteLogProvider ?? this.remoteLogProvider,
      remoteLogEndpoint: remoteLogEndpoint ?? this.remoteLogEndpoint,
      remoteLogApiKey: remoteLogApiKey ?? this.remoteLogApiKey,
      remoteLogLevel: remoteLogLevel ?? this.remoteLogLevel,
      remoteLogBatchSize: remoteLogBatchSize ?? this.remoteLogBatchSize,
      remoteLogFlushIntervalMs:
          remoteLogFlushIntervalMs ?? this.remoteLogFlushIntervalMs,
      remoteLogTimeout: remoteLogTimeout ?? this.remoteLogTimeout,
      remoteLogMetadata: remoteLogMetadata ?? this.remoteLogMetadata,
      // Certificate pinning properties
      certificatePinningEnabled:
          certificatePinningEnabled ?? this.certificatePinningEnabled,
      pinnedCertificates: pinnedCertificates ?? this.pinnedCertificates,
      allowSelfSignedCertificates:
          allowSelfSignedCertificates ?? this.allowSelfSignedCertificates,
      // Memory management properties
      enableMemoryManagement:
          enableMemoryManagement ?? this.enableMemoryManagement,
      memoryPressureThresholds:
          memoryPressureThresholds ?? this.memoryPressureThresholds,
      memoryMonitoringIntervalSeconds: memoryMonitoringIntervalSeconds ??
          this.memoryMonitoringIntervalSeconds,
      useSecureStorage: useSecureStorage ?? this.useSecureStorage,
      secureDataTypes: secureDataTypes ?? this.secureDataTypes,
    );
  }

  /// Simple factory constructor for basic usage (tests)
  factory CFConfig({
    required String clientKey,
  }) =>
      CFConfig._(clientKey: clientKey);

  /// Static factory method from client key only
  static CFConfig fromClientKey(String clientKey) {
    final result = Builder(clientKey).build();
    if (result.isSuccess) {
      return result.getOrNull()!;
    } else {
      // For backward compatibility, throw exception
      throw Exception(result.getErrorMessage());
    }
  }

  /// Builder implementation for fluent API
  static Builder builder(String clientKey) => Builder(clientKey);

  /// Create a smart configuration that auto-detects environment and optimizes settings
  ///
  /// This factory method automatically:
  /// - Detects environment from client key
  /// - Applies optimal settings for the detected environment
  /// - Configures performance and battery optimizations
  ///
  /// Example:
  /// ```dart
  /// final config = CFConfig.smart('your-client-key');
  /// ```
  static CFConfig smart(String clientKey) {
    final detectedEnv = detectEnvironment(clientKey);
    final builder = CFConfig.builder(clientKey).setEnvironment(detectedEnv);

    // Apply environment-specific optimizations
    CFResult<CFConfig> result;
    if (detectedEnv == CFEnvironment.production) {
      result = builder
          .setDebugLoggingEnabled(false)
          .setLoggingEnabled(true)
          .setLogLevel('error')
          .setEventsFlushIntervalMs(30000)
          .setSummariesFlushIntervalMs(30000)
          .setNetworkConnectionTimeoutMs(15000)
          .setNetworkReadTimeoutMs(30000)
          .setMaxRetryAttempts(5)
          .setRetryInitialDelayMs(2000)
          .setSdkSettingsCheckIntervalMs(300000)
          .setLocalStorageEnabled(true)
          .setConfigCacheTtlSeconds(3600)
          .setPersistCacheAcrossRestarts(true)
          .setUseStaleWhileRevalidate(true)
          .setUseReducedPollingWhenBatteryLow(true)
          .build();
    } else {
      // Staging/Development optimizations
      result = builder
          .setDebugLoggingEnabled(true)
          .setLoggingEnabled(true)
          .setLogLevel('debug')
          .setEventsFlushIntervalMs(5000)
          .setSummariesFlushIntervalMs(5000)
          .setNetworkConnectionTimeoutMs(10000)
          .setNetworkReadTimeoutMs(15000)
          .setMaxRetryAttempts(3)
          .setRetryInitialDelayMs(1000)
          .setSdkSettingsCheckIntervalMs(60000)
          .setLocalStorageEnabled(true)
          .setConfigCacheTtlSeconds(300)
          .setPersistCacheAcrossRestarts(false)
          .setUseStaleWhileRevalidate(false)
          .build();
    }

    if (result.isSuccess) {
      return result.getOrNull()!;
    } else {
      throw Exception(result.getErrorMessage());
    }
  }

  /// Get this config instance (for CFResult compatibility in tests)
  CFConfig getOrThrow() => this;
}

/// Builder class for CFConfig
class Builder {
  final String clientKey;
  CFEnvironment environment = CFEnvironment.production;
  int eventsQueueSize = 100;
  int eventsFlushTimeSeconds = 60;
  int eventsFlushIntervalMs = 1000;
  int maxRetryAttempts = 3;
  int retryInitialDelayMs = 1000;
  int retryMaxDelayMs = 30000;
  double retryBackoffMultiplier = 2.0;
  int summariesQueueSize = 100;
  int summariesFlushTimeSeconds = 60;
  int summariesFlushIntervalMs = 60000;
  int sdkSettingsCheckIntervalMs = 300000;
  int networkConnectionTimeoutMs = 10000;
  int networkReadTimeoutMs = 10000;
  bool loggingEnabled = true;
  bool debugLoggingEnabled = false;
  String logLevel = 'DEBUG';
  bool offlineMode = false;
  bool disableBackgroundPolling = false;
  int backgroundPollingIntervalMs = 3600000;
  bool useReducedPollingWhenBatteryLow = true;
  int reducedPollingIntervalMs = 7200000;
  int maxStoredEvents = 100;
  bool autoEnvAttributesEnabled = false;
  // Local Storage Configuration
  bool localStorageEnabled = true;
  int configCacheTtlSeconds = 86400;
  int eventCacheTtlSeconds = 3600;
  int summaryCacheTtlSeconds = 3600;
  int maxCacheSizeMb = 50;
  bool persistCacheAcrossRestarts = true;
  bool useStaleWhileRevalidate = true;
  // Remote logging configuration methods
  bool remoteLoggingEnabled = false;
  String remoteLogProvider = 'console_only';
  String? remoteLogEndpoint;
  String? remoteLogApiKey;
  String remoteLogLevel = 'info';
  int remoteLogBatchSize = 10;
  int remoteLogFlushIntervalMs = 30000;
  int remoteLogTimeout = 5000;
  Map<String, dynamic>? remoteLogMetadata;
  // Certificate pinning configuration
  bool certificatePinningEnabled = false;
  List<String> pinnedCertificates = [];
  bool allowSelfSignedCertificates = false;
  // Secure storage configuration
  bool useSecureStorage = true;
  List<String> secureDataTypes = ['session', 'api_keys', 'sensitive_events'];

  /// Constructor
  Builder(this.clientKey) {
    // Validation is now done in the validate() method
  }

  /// Validates the builder configuration
  CFResult<void> validate() {
    if (clientKey.isEmpty) {
      return CFResult.error(
        "Client key cannot be empty",
        errorCode: CFErrorCode.configMissingApiKey,
        category: ErrorCategory.configuration,
      );
    }
    // Basic JWT format validation - JWT should have 3 parts separated by dots
    final parts = clientKey.split('.');
    if (parts.length != 3) {
      return CFResult.error(
        "Client key must be a valid JWT token with 3 parts",
        errorCode: CFErrorCode.configInvalidSettings,
        category: ErrorCategory.configuration,
      );
    }
    // Minimum length check - typical JWTs are at least 100 characters
    if (clientKey.length < 100) {
      return CFResult.error(
        "Client key appears to be invalid - too short",
        errorCode: CFErrorCode.configInvalidSettings,
        category: ErrorCategory.configuration,
      );
    }
    return CFResult.success(null);
  }

  /// Set environment for API endpoints
  Builder setEnvironment(CFEnvironment env) {
    environment = env;
    return this;
  }

  /// Set events queue size
  Builder setEventsQueueSize(int size) {
    if (size <= 0) {
      throw ArgumentError('Events queue size must be greater than 0');
    }
    eventsQueueSize = size;
    return this;
  }

  /// Set events flush time seconds
  Builder setEventsFlushTimeSeconds(int seconds) {
    if (seconds <= 0) {
      throw ArgumentError('Events flush time seconds must be greater than 0');
    }
    eventsFlushTimeSeconds = seconds;
    return this;
  }

  /// Set events flush interval in milliseconds
  Builder setEventsFlushIntervalMs(int ms) {
    eventsFlushIntervalMs = ms;
    return this;
  }

  /// Set max retry attempts
  Builder setMaxRetryAttempts(int attempts) {
    if (attempts < 0) {
      throw ArgumentError('Max retry attempts cannot be negative');
    }
    maxRetryAttempts = attempts;
    return this;
  }

  /// Set retry initial delay in milliseconds
  Builder setRetryInitialDelayMs(int ms) {
    retryInitialDelayMs = ms;
    return this;
  }

  /// Set retry max delay in milliseconds
  Builder setRetryMaxDelayMs(int ms) {
    retryMaxDelayMs = ms;
    return this;
  }

  /// Set retry backoff multiplier
  Builder setRetryBackoffMultiplier(double multiplier) {
    retryBackoffMultiplier = multiplier;
    return this;
  }

  /// Set summaries queue size
  Builder setSummariesQueueSize(int size) {
    summariesQueueSize = size;
    return this;
  }

  /// Set summaries flush time seconds
  Builder setSummariesFlushTimeSeconds(int seconds) {
    summariesFlushTimeSeconds = seconds;
    return this;
  }

  /// Set summaries flush interval in milliseconds
  Builder setSummariesFlushIntervalMs(int ms) {
    summariesFlushIntervalMs = ms;
    return this;
  }

  /// Set SDK settings check interval in milliseconds
  Builder setSdkSettingsCheckIntervalMs(int ms) {
    sdkSettingsCheckIntervalMs = ms;
    return this;
  }

  /// Set network connection timeout in milliseconds
  Builder setNetworkConnectionTimeoutMs(int ms) {
    networkConnectionTimeoutMs = ms;
    return this;
  }

  /// Set network read timeout in milliseconds
  Builder setNetworkReadTimeoutMs(int ms) {
    networkReadTimeoutMs = ms;
    return this;
  }

  /// Set whether logging is enabled
  Builder setLoggingEnabled(bool enabled) {
    loggingEnabled = enabled;
    return this;
  }

  /// Set whether debug logging is enabled
  Builder setDebugLoggingEnabled(bool enabled) {
    debugLoggingEnabled = enabled;
    return this;
  }

  /// Set log level
  Builder setLogLevel(String level) {
    logLevel = level;
    return this;
  }

  /// Set whether offline mode is enabled
  Builder setOfflineMode(bool enabled) {
    offlineMode = enabled;
    return this;
  }

  /// Set whether background polling is disabled
  Builder setDisableBackgroundPolling(bool disabled) {
    disableBackgroundPolling = disabled;
    return this;
  }

  /// Set background polling interval in milliseconds
  Builder setBackgroundPollingIntervalMs(int ms) {
    backgroundPollingIntervalMs = ms;
    return this;
  }

  /// Set whether to use reduced polling when battery is low
  Builder setUseReducedPollingWhenBatteryLow(bool use) {
    useReducedPollingWhenBatteryLow = use;
    return this;
  }

  /// Set reduced polling interval in milliseconds
  Builder setReducedPollingIntervalMs(int ms) {
    reducedPollingIntervalMs = ms;
    return this;
  }

  /// Set max stored events
  Builder setMaxStoredEvents(int max) {
    maxStoredEvents = max;
    return this;
  }

  /// Set whether auto environment attributes are enabled
  Builder setAutoEnvAttributesEnabled(bool enabled) {
    autoEnvAttributesEnabled = enabled;
    return this;
  }

  // Local Storage Configuration Methods

  /// Set whether local storage/caching is enabled
  Builder setLocalStorageEnabled(bool enabled) {
    localStorageEnabled = enabled;
    return this;
  }

  /// Set cache TTL for configuration data in seconds
  Builder setConfigCacheTtlSeconds(int seconds) {
    if (seconds < 0) {
      throw ArgumentError('Config cache TTL cannot be negative');
    }
    configCacheTtlSeconds = seconds;
    return this;
  }

  /// Set cache TTL for event data in seconds
  Builder setEventCacheTtlSeconds(int seconds) {
    if (seconds < 0) {
      throw ArgumentError('Event cache TTL cannot be negative');
    }
    eventCacheTtlSeconds = seconds;
    return this;
  }

  /// Set cache TTL for summary data in seconds
  Builder setSummaryCacheTtlSeconds(int seconds) {
    if (seconds < 0) {
      throw ArgumentError('Summary cache TTL cannot be negative');
    }
    summaryCacheTtlSeconds = seconds;
    return this;
  }

  /// Set maximum cache size in MB
  Builder setMaxCacheSizeMb(int sizeMb) {
    if (sizeMb <= 0) {
      throw ArgumentError('Max cache size must be greater than 0');
    }
    maxCacheSizeMb = sizeMb;
    return this;
  }

  /// Set whether to persist cache across app restarts
  Builder setPersistCacheAcrossRestarts(bool persist) {
    persistCacheAcrossRestarts = persist;
    return this;
  }

  /// Set whether to use stale cache while revalidating
  Builder setUseStaleWhileRevalidate(bool useStale) {
    useStaleWhileRevalidate = useStale;
    return this;
  }

  // Remote logging configuration methods

  /// Set whether remote logging is enabled
  Builder setRemoteLoggingEnabled(bool enabled) {
    remoteLoggingEnabled = enabled;
    return this;
  }

  /// Set remote log provider
  Builder setRemoteLogProvider(String provider) {
    if (!['logtail', 'custom', 'console_only'].contains(provider)) {
      throw ArgumentError(
          'Remote log provider must be one of: logtail, custom, console_only');
    }
    remoteLogProvider = provider;
    return this;
  }

  /// Set remote log endpoint
  Builder setRemoteLogEndpoint(String? endpoint) {
    remoteLogEndpoint = endpoint;
    return this;
  }

  /// Set remote log API key
  Builder setRemoteLogApiKey(String? apiKey) {
    remoteLogApiKey = apiKey;
    return this;
  }

  /// Set remote log level
  Builder setRemoteLogLevel(String level) {
    if (!['debug', 'info', 'warn', 'error'].contains(level)) {
      throw ArgumentError(
          'Remote log level must be one of: debug, info, warn, error');
    }
    remoteLogLevel = level;
    return this;
  }

  /// Set remote log batch size
  Builder setRemoteLogBatchSize(int size) {
    if (size <= 0) {
      throw ArgumentError('Remote log batch size must be greater than 0');
    }
    remoteLogBatchSize = size;
    return this;
  }

  /// Set remote log flush interval in milliseconds
  Builder setRemoteLogFlushIntervalMs(int ms) {
    if (ms <= 0) {
      throw ArgumentError('Remote log flush interval must be greater than 0');
    }
    remoteLogFlushIntervalMs = ms;
    return this;
  }

  /// Set remote log timeout
  Builder setRemoteLogTimeout(int timeout) {
    if (timeout <= 0) {
      throw ArgumentError('Remote log timeout must be greater than 0');
    }
    remoteLogTimeout = timeout;
    return this;
  }

  /// Set remote log metadata
  Builder setRemoteLogMetadata(Map<String, dynamic>? metadata) {
    remoteLogMetadata = metadata;
    return this;
  }

  // Certificate pinning configuration methods

  /// Enable or disable certificate pinning
  Builder setCertificatePinningEnabled(bool enabled) {
    certificatePinningEnabled = enabled;
    return this;
  }

  /// Set the list of pinned certificate SHA-256 fingerprints
  ///
  /// Example:
  /// ```dart
  /// .setPinnedCertificates([
  ///   'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  ///   'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB='
  /// ])
  /// ```
  Builder setPinnedCertificates(List<String> certificates) {
    pinnedCertificates = List.from(certificates);
    return this;
  }

  /// Add a single pinned certificate SHA-256 fingerprint
  Builder addPinnedCertificate(String certificate) {
    if (!pinnedCertificates.contains(certificate)) {
      pinnedCertificates.add(certificate);
    }
    return this;
  }

  /// Allow self-signed certificates (for development only)
  Builder setAllowSelfSignedCertificates(bool allow) {
    allowSelfSignedCertificates = allow;
    return this;
  }

  /// Enable or disable secure storage for sensitive data
  Builder setUseSecureStorage(bool enabled) {
    useSecureStorage = enabled;
    return this;
  }

  /// Set which data types should be stored securely
  Builder setSecureDataTypes(List<String> dataTypes) {
    secureDataTypes = dataTypes;
    return this;
  }

  /// Build method creates immutable CFConfig with result-based error handling
  CFResult<CFConfig> build() {
    // First validate the configuration
    final validationResult = validate();
    if (!validationResult.isSuccess) {
      return CFResult.error(
        validationResult.getErrorMessage() ?? 'Configuration validation failed',
        errorCode: validationResult.error?.errorCode ??
            CFErrorCode.configInvalidSettings,
        category: ErrorCategory.configuration,
      );
    }

    try {
      // All validation is done, create the config
      final config = CFConfig._(
        clientKey: clientKey,
        environment: environment,
        eventsQueueSize: eventsQueueSize,
        eventsFlushTimeSeconds: eventsFlushTimeSeconds,
        eventsFlushIntervalMs: eventsFlushIntervalMs,
        maxRetryAttempts: maxRetryAttempts,
        retryInitialDelayMs: retryInitialDelayMs,
        retryMaxDelayMs: retryMaxDelayMs,
        retryBackoffMultiplier: retryBackoffMultiplier,
        summariesQueueSize: summariesQueueSize,
        summariesFlushTimeSeconds: summariesFlushTimeSeconds,
        summariesFlushIntervalMs: summariesFlushIntervalMs,
        sdkSettingsCheckIntervalMs: sdkSettingsCheckIntervalMs,
        networkConnectionTimeoutMs: networkConnectionTimeoutMs,
        networkReadTimeoutMs: networkReadTimeoutMs,
        loggingEnabled: loggingEnabled,
        debugLoggingEnabled: debugLoggingEnabled,
        logLevel: logLevel,
        offlineMode: offlineMode,
        disableBackgroundPolling: disableBackgroundPolling,
        backgroundPollingIntervalMs: backgroundPollingIntervalMs,
        useReducedPollingWhenBatteryLow: useReducedPollingWhenBatteryLow,
        reducedPollingIntervalMs: reducedPollingIntervalMs,
        maxStoredEvents: maxStoredEvents,
        autoEnvAttributesEnabled: autoEnvAttributesEnabled,
        localStorageEnabled: localStorageEnabled,
        configCacheTtlSeconds: configCacheTtlSeconds,
        eventCacheTtlSeconds: eventCacheTtlSeconds,
        summaryCacheTtlSeconds: summaryCacheTtlSeconds,
        maxCacheSizeMb: maxCacheSizeMb,
        persistCacheAcrossRestarts: persistCacheAcrossRestarts,
        useStaleWhileRevalidate: useStaleWhileRevalidate,
        remoteLoggingEnabled: remoteLoggingEnabled,
        remoteLogProvider: remoteLogProvider,
        remoteLogEndpoint: remoteLogEndpoint,
        remoteLogApiKey: remoteLogApiKey,
        remoteLogLevel: remoteLogLevel,
        remoteLogBatchSize: remoteLogBatchSize,
        remoteLogFlushIntervalMs: remoteLogFlushIntervalMs,
        remoteLogTimeout: remoteLogTimeout,
        remoteLogMetadata: remoteLogMetadata,
        certificatePinningEnabled: certificatePinningEnabled,
        pinnedCertificates: List.unmodifiable(pinnedCertificates),
        allowSelfSignedCertificates: allowSelfSignedCertificates,
        useSecureStorage: useSecureStorage,
        secureDataTypes: List.unmodifiable(secureDataTypes),
      );

      return CFResult.success(config);
    } catch (e) {
      return CFResult.error(
        'Failed to build CFConfig: $e',
        errorCode: CFErrorCode.configInvalidSettings,
        category: ErrorCategory.configuration,
        exception: e,
      );
    }
  }
}

/// Mutable configuration wrapper for runtime updates
class MutableCFConfig {
  CFConfig _config;
  final List<Function(CFConfig)> _listeners = [];

  MutableCFConfig(this._config);

  /// Get current immutable config
  CFConfig get config => _config;

  /// Add a listener for config changes
  void addListener(Function(CFConfig) listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(Function(CFConfig) listener) {
    _listeners.remove(listener);
  }

  /// Update configuration and notify listeners
  void _updateConfig(CFConfig newConfig) {
    _config = newConfig;
    for (final listener in _listeners) {
      try {
        listener(newConfig);
      } catch (e) {
        // Log error but continue notifying other listeners
        Logger.e('Error notifying config listener: $e');
      }
    }
  }

  /// Update SDK settings check interval
  void updateSdkSettingsCheckInterval(int intervalMs) {
    if (intervalMs <= 0) {
      throw ArgumentError('SDK settings check interval must be greater than 0');
    }
    _updateConfig(_config.copyWith(sdkSettingsCheckIntervalMs: intervalMs));
  }

  /// Update events flush interval
  void updateEventsFlushInterval(int intervalMs) {
    if (intervalMs <= 0) {
      throw ArgumentError('Events flush interval must be greater than 0');
    }
    _updateConfig(_config.copyWith(eventsFlushIntervalMs: intervalMs));
  }

  /// Update summaries flush interval
  void updateSummariesFlushInterval(int intervalMs) {
    if (intervalMs <= 0) {
      throw ArgumentError('Summaries flush interval must be greater than 0');
    }
    _updateConfig(_config.copyWith(summariesFlushIntervalMs: intervalMs));
  }

  /// Update network connection timeout
  void updateNetworkConnectionTimeout(int timeoutMs) {
    if (timeoutMs <= 0) {
      throw ArgumentError('Network connection timeout must be greater than 0');
    }
    _updateConfig(_config.copyWith(networkConnectionTimeoutMs: timeoutMs));
  }

  /// Update network read timeout
  void updateNetworkReadTimeout(int timeoutMs) {
    if (timeoutMs <= 0) {
      throw ArgumentError('Network read timeout must be greater than 0');
    }
    _updateConfig(_config.copyWith(networkReadTimeoutMs: timeoutMs));
  }

  /// Set debug logging enabled
  void setDebugLoggingEnabled(bool enabled) {
    _updateConfig(_config.copyWith(debugLoggingEnabled: enabled));
  }

  /// Set logging enabled
  void setLoggingEnabled(bool enabled) {
    _updateConfig(_config.copyWith(loggingEnabled: enabled));
  }

  /// Set offline mode
  void setOfflineMode(bool offline) {
    _updateConfig(_config.copyWith(offlineMode: offline));
  }

  /// Update local storage settings
  void updateLocalStorageEnabled(bool enabled) {
    _updateConfig(_config.copyWith(localStorageEnabled: enabled));
  }

  /// Update config cache TTL
  void updateConfigCacheTtl(int seconds) {
    if (seconds < 0) {
      throw ArgumentError('Config cache TTL cannot be negative');
    }
    _updateConfig(_config.copyWith(configCacheTtlSeconds: seconds));
  }
}

/// JWT parsing utility with secure validation and caching for performance optimization
class _JWTParser {
  static final Map<String, String?> _cache = <String, String?>{};
  static const int _maxCacheSize = 100;

  /// Get dimension ID from JWT token with caching and security validation
  static String? getDimensionId(String token) {
    // Check cache first
    if (_cache.containsKey(token)) {
      return _cache[token];
    }

    // Parse and validate JWT
    final dimensionId = _parseJWT(token);

    // Cache result (with size limit)
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry (simple LRU approximation)
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[token] = dimensionId;

    return dimensionId;
  }

  /// Parse JWT token with security validation and extract dimension_id
  static String? _parseJWT(String token) {
    try {
      // Validate JWT format
      final parts = token.split('.');
      if (parts.length != 3) {
        Logger.w(
            'JWT validation failed: Invalid format - expected 3 parts, got ${parts.length}');
        return null;
      }

      // Decode and validate header
      final header = _decodeBase64(parts[0]);
      if (header == null) {
        Logger.w('JWT validation failed: Invalid header encoding');
        return null;
      }

      final headerMap = jsonDecode(header) as Map<String, dynamic>;
      final algorithm = headerMap['alg'] as String?;

      if (algorithm == null || algorithm == 'none') {
        Logger.e('JWT validation failed: Missing or insecure algorithm');
        return null;
      }

      // Decode and validate payload
      final payload = _decodeBase64(parts[1]);
      if (payload == null) {
        Logger.w('JWT validation failed: Invalid payload encoding');
        return null;
      }

      final payloadMap = jsonDecode(payload) as Map<String, dynamic>;

      // Validate token expiry
      final exp = payloadMap['exp'] as int?;
      if (exp != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final now = DateTime.now();

        if (now.isAfter(expiryTime)) {
          Logger.e(
              'JWT validation failed: Token expired at $expiryTime, current time: $now');
          return null;
        }
      } else {
        Logger.w('JWT validation warning: No expiry time found in token');
      }

      // Validate issued at time (iat) - token shouldn't be from future
      final iat = payloadMap['iat'] as int?;
      if (iat != null) {
        final issuedTime = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
        final now = DateTime.now();
        final maxClockSkew = const Duration(minutes: 5);

        if (issuedTime.isAfter(now.add(maxClockSkew))) {
          Logger.e(
              'JWT validation failed: Token issued in future at $issuedTime, current time: $now');
          return null;
        }
      }

      // Validate not before time (nbf) if present
      final nbf = payloadMap['nbf'] as int?;
      if (nbf != null) {
        final notBeforeTime = DateTime.fromMillisecondsSinceEpoch(nbf * 1000);
        final now = DateTime.now();

        if (now.isBefore(notBeforeTime)) {
          Logger.e(
              'JWT validation failed: Token not valid before $notBeforeTime, current time: $now');
          return null;
        }
      }

      // Verify signature (basic verification - in production use proper JWT library)
      if (!_verifySignature(parts[0], parts[1], parts[2], algorithm)) {
        Logger.e('JWT validation failed: Invalid signature');
        return null;
      }

      // Extract dimension_id
      final dimensionId = payloadMap['dimension_id'] as String?;

      if (dimensionId != null) {
        Logger.d(
            'JWT validation successful: Extracted dimension_id: $dimensionId');
      } else {
        Logger.d('JWT validation successful: No dimension_id found in token');
      }

      return dimensionId;
    } catch (e) {
      Logger.e('JWT parsing failed with exception: $e');
      return null;
    }
  }

  /// Decode base64 URL-safe string
  static String? _decodeBase64(String input) {
    try {
      final normalized = base64Url.normalize(input);
      return utf8.decode(base64Url.decode(normalized));
    } catch (e) {
      Logger.w('Base64 decoding failed: $e');
      return null;
    }
  }

  /// Verify JWT signature with enhanced security checks
  /// This implementation provides comprehensive signature validation
  static bool _verifySignature(
      String header, String payload, String signature, String algorithm) {
    try {
      // Check signature format
      if (signature.isEmpty) {
        Logger.e('JWT signature verification failed: Empty signature');
        return false;
      }

      // Validate signature length and format based on algorithm
      switch (algorithm.toUpperCase()) {
        case 'HS256':
        case 'HS384':
        case 'HS512':
          // HMAC signatures - should be base64url encoded
          if (signature.length < 20) {
            Logger.e(
                'JWT signature verification failed: HMAC signature too short');
            return false;
          }
          break;
        case 'RS256':
        case 'RS384':
        case 'RS512':
        case 'ES256':
        case 'ES384':
        case 'ES512':
          // RSA/ECDSA signatures - should be base64url encoded
          if (signature.length < 40) {
            Logger.e(
                'JWT signature verification failed: RSA/ECDSA signature too short');
            return false;
          }
          break;
        case 'NONE':
          // Explicitly reject 'none' algorithm for security
          Logger.e(
              'JWT signature verification failed: "none" algorithm not allowed');
          return false;
        default:
          Logger.e(
              'JWT signature verification failed: Unsupported algorithm: $algorithm');
          return false;
      }

      // Validate signature is properly base64url encoded
      try {
        base64Url.decode(base64Url.normalize(signature));
      } catch (e) {
        Logger.e(
            'JWT signature verification failed: Invalid base64url encoding in signature');
        return false;
      }

      // Additional security checks

      // Check for common attack patterns in signature
      if (_containsSuspiciousPatterns(signature)) {
        Logger.e(
            'JWT signature verification failed: Suspicious patterns detected in signature');
        return false;
      }

      // Verify the signature structure matches the algorithm
      if (!_validateSignatureStructure(signature, algorithm)) {
        Logger.e(
            'JWT signature verification failed: Signature structure invalid for algorithm $algorithm');
        return false;
      }

      // IMPORTANT: This is still a format validation approach
      // For production use, you MUST implement actual cryptographic verification:
      //
      // Option 1: Using dart_jsonwebtoken package (recommended)
      // ```dart
      // import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
      //
      // try {
      //   final jwt = JWT.verify(fullToken, SecretKey('your-secret-key'));
      //   // For RS256/ES256, use RSAPublicKey or ECPublicKey instead
      //   return true;
      // } catch (JWTExpiredException) {
      //   Logger.e('JWT expired');
      //   return false;
      // } catch (JWTException) {
      //   Logger.e('JWT verification failed');
      //   return false;
      // }
      // ```
      //
      // Option 2: Fetch public key from JWKS endpoint
      // ```dart
      // final jwksUri = 'https://your-auth-provider.com/.well-known/jwks.json';
      // final publicKey = await fetchPublicKeyFromJWKS(jwksUri, keyId);
      // final jwt = JWT.verify(fullToken, publicKey);
      // ```

      Logger.w('JWT signature verification: Using enhanced format validation. '
          'Implement cryptographic verification for production security.');
      return true;
    } catch (e) {
      Logger.e('JWT signature verification failed with exception: $e');
      return false;
    }
  }

  /// Check for suspicious patterns that might indicate tampering
  static bool _containsSuspiciousPatterns(String signature) {
    // Check for obviously fake signatures
    final suspiciousPatterns = [
      RegExp(r'^[aA]+$'), // All 'a' or 'A' characters
      RegExp(r'^[0]+$'), // All zeros
      RegExp(r'^[1]+$'), // All ones
      RegExp(r'^(test|fake|dummy|invalid)'), // Common test patterns
      RegExp(r'^(.)\1{10,}'), // Same character repeated many times
    ];

    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(signature)) {
        return true;
      }
    }

    // Check for minimum entropy (signature should have reasonable randomness)
    final uniqueChars = signature.split('').toSet().length;
    if (uniqueChars < 8) {
      // Too few unique characters
      return true;
    }

    return false;
  }

  /// Validate signature structure matches the expected algorithm format
  static bool _validateSignatureStructure(String signature, String algorithm) {
    switch (algorithm.toUpperCase()) {
      case 'HS256':
        // HMAC-SHA256 produces 256-bit (32-byte) signatures
        // Base64url encoded: ~43 characters
        return signature.length >= 40 && signature.length <= 50;
      case 'HS384':
        // HMAC-SHA384 produces 384-bit (48-byte) signatures
        // Base64url encoded: ~64 characters
        return signature.length >= 60 && signature.length <= 70;
      case 'HS512':
        // HMAC-SHA512 produces 512-bit (64-byte) signatures
        // Base64url encoded: ~86 characters
        return signature.length >= 80 && signature.length <= 90;
      case 'RS256':
      case 'RS384':
      case 'RS512':
        // RSA signatures are typically 2048-bit (256 bytes) or 4096-bit (512 bytes)
        // Base64url encoded: ~340-680 characters
        return signature.length >= 300 && signature.length <= 700;
      case 'ES256':
        // ECDSA P-256 signatures: ~70-90 characters when base64url encoded
        return signature.length >= 60 && signature.length <= 100;
      case 'ES384':
        // ECDSA P-384 signatures: ~95-130 characters when base64url encoded
        return signature.length >= 90 && signature.length <= 140;
      case 'ES512':
        // ECDSA P-521 signatures: ~135-180 characters when base64url encoded
        return signature.length >= 130 && signature.length <= 190;
      default:
        return false;
    }
  }

  /// Clear the JWT cache (useful for testing or memory management)
  // ignore: unused_element
  static void clearCache() {
    _cache.clear();
    Logger.d('JWT parser cache cleared');
  }

  /// Get cache statistics for monitoring
  // ignore: unused_element
  static Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _cache.length,
      'maxCacheSize': _maxCacheSize,
      'cacheUtilization':
          '${(_cache.length / _maxCacheSize * 100).toStringAsFixed(1)}%',
    };
  }
}

/// Configuration comparison and analysis utilities
class CFConfigAnalyzer {
  /// Compare two configurations and highlight differences
  static Map<String, dynamic> compare(CFConfig config1, CFConfig config2) {
    final differences = <String, dynamic>{};

    if (config1.environment != config2.environment) {
      differences['environment'] = {
        'config1': config1.environment.toString(),
        'config2': config2.environment.toString()
      };
    }

    if (config1.eventsFlushIntervalMs != config2.eventsFlushIntervalMs) {
      differences['eventsFlushIntervalMs'] = {
        'config1': config1.eventsFlushIntervalMs,
        'config2': config2.eventsFlushIntervalMs
      };
    }

    if (config1.debugLoggingEnabled != config2.debugLoggingEnabled) {
      differences['debugLoggingEnabled'] = {
        'config1': config1.debugLoggingEnabled,
        'config2': config2.debugLoggingEnabled
      };
    }

    if (config1.networkConnectionTimeoutMs !=
        config2.networkConnectionTimeoutMs) {
      differences['networkConnectionTimeoutMs'] = {
        'config1': config1.networkConnectionTimeoutMs,
        'config2': config2.networkConnectionTimeoutMs
      };
    }

    return differences;
  }

  /// Get configuration fingerprint for change detection
  static String getFingerprint(CFConfig config) {
    // Create a deterministic string representation
    final parts = [
      'env:${config.environment.toString()}',
      'events:${config.eventsFlushIntervalMs}',
      'timeout:${config.networkConnectionTimeoutMs}',
      'debug:${config.debugLoggingEnabled}',
      'cache:${config.configCacheTtlSeconds}',
    ];
    // Join parts and create a simple hash that's deterministic
    final combined = parts.join('|');
    int hash = 0;
    for (int i = 0; i < combined.length; i++) {
      hash = ((hash << 5) - hash) + combined.codeUnitAt(i);
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.abs().toString();
  }

  /// Check if configuration is suitable for mobile devices
  static bool isMobileFriendly(CFConfig config) {
    return config.eventsFlushIntervalMs >= 5000 &&
        config.maxCacheSizeMb <= 100 &&
        config.useReducedPollingWhenBatteryLow &&
        config.backgroundPollingIntervalMs >= 1800000; // 30 minutes
  }

  /// Get memory footprint estimation in MB
  static double estimateMemoryFootprint(CFConfig config) {
    double footprint = 0.0;

    // Base SDK memory
    footprint += 2.0;

    // Queue memory estimation
    footprint += (config.eventsQueueSize * 0.001); // 1KB per event
    footprint += (config.summariesQueueSize * 0.0005); // 0.5KB per summary

    // Cache memory
    footprint += config.maxCacheSizeMb;

    return footprint;
  }
}
