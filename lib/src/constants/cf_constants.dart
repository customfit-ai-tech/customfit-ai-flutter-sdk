// lib/src/constants/cf_constants.dart
//
// Central repository of constants used throughout the CustomFit SDK.
// Defines API endpoints, configuration values, timeouts, and other
// SDK-wide constants to ensure consistency across the codebase.
//
// This file is part of the CustomFit SDK for Flutter.

/// Constants used throughout the SDK.
class CFConstants {
  // Private constructor to prevent instantiation
  CFConstants._();

  /// General SDK constants
  static const general = _GeneralConstants();

  /// API constants
  static const api = _APIConstants();

  /// HTTP constants
  static const http = _HttpConstants();

  /// Storage constants
  static const storage = _StorageConstants();

  /// Event-related constants
  static const eventDefaults = _EventConstants();

  /// Summary-related constants
  static const summaryDefaults = _SummaryConstants();

  /// Retry-related constants
  static const retryConfig = _RetryConstants();

  /// Background polling-related constants
  static const backgroundPolling = _BackgroundPollingConstants();

  /// Network-related constants
  static const network = _NetworkConstants();

  /// Logging-related constants
  static const logging = _LoggingConstants();

  /// Cache-related constants
  static const cache = _CacheConstants();

  /// Session-related constants
  static const session = _SessionConstants();

  /// Analytics-related constants
  static const analytics = _AnalyticsConstants();

  /// Network health monitoring constants
  static const networkHealth = _NetworkHealthConstants();

  /// Error boundary constants
  static const errorBoundary = _ErrorBoundaryConstants();

  /// URL constants
  static const urls = _UrlConstants();

  /// Object pool constants
  static const objectPool = _ObjectPoolConstants();

  /// Polling strategy constants
  static const pollingStrategy = _PollingStrategyConstants();

  /// Remote logging constants
  static const remoteLogging = _RemoteLoggingConstants();

  /// Network optimizer constants
  static const networkOptimizer = _NetworkOptimizerConstants();

  /// Error recovery constants
  static const errorRecovery = _ErrorRecoveryConstants();
}

/// General SDK constants
class _GeneralConstants {
  const _GeneralConstants();

  /// SDK version
  final String sdkVersion = '1.0.0';

  /// SDK name
  final String sdkName = 'flutter-client-sdk';

  /// Default user ID (anonymous)
  final String defaultUserId = 'anonymous';
}

/// Environment types for API endpoints
enum CFEnvironment {
  /// Production environment
  production,

  /// Staging environment
  staging,
}

/// Log levels for the SDK (standardized across all platforms)
enum LogLevel {
  /// No logging (0)
  off(0, 'OFF'),

  /// Error level logging (1)
  error(1, 'ERROR'),

  /// Warning level logging (2)
  warn(2, 'WARN'),

  /// Info level logging (3)
  info(3, 'INFO'),

  /// Debug level logging (4)
  debug(4, 'DEBUG'),

  /// Trace level logging (5)
  trace(5, 'TRACE');

  const LogLevel(this.value, this.stringValue);

  /// Numeric value for comparison
  final int value;

  /// String representation
  final String stringValue;

  /// Convert from string to LogLevel
  static LogLevel fromString(String level) {
    switch (level.toUpperCase()) {
      case 'OFF':
        return LogLevel.off;
      case 'ERROR':
        return LogLevel.error;
      case 'WARN':
        return LogLevel.warn;
      case 'INFO':
        return LogLevel.info;
      case 'DEBUG':
        return LogLevel.debug;
      case 'TRACE':
        return LogLevel.trace;
      default:
        return LogLevel.info; // Default fallback
    }
  }

  /// Check if this level should log given another level
  bool shouldLog(LogLevel messageLevel) {
    return messageLevel.value <= value && value > 0;
  }
}

/// API constants
class _APIConstants {
  const _APIConstants();

  /// Get base API URL for environment
  String getBaseApiUrl(CFEnvironment environment) {
    switch (environment) {
      case CFEnvironment.production:
        return 'https://api.customfit.ai';
      case CFEnvironment.staging:
        return 'https://stageapi.customfit.ai';
    }
  }

  /// Get SDK settings base URL for environment
  String getSdkSettingsBaseUrl(CFEnvironment environment) {
    switch (environment) {
      case CFEnvironment.production:
        return 'https://sdk.customfit.ai';
      case CFEnvironment.staging:
        return 'https://sdk.customfit.ai';
    }
  }

  /// Get SDK settings path pattern for environment
  String getSdkSettingsPathPattern(
      CFEnvironment environment, String dimensionId) {
    switch (environment) {
      case CFEnvironment.production:
        return '/$dimensionId/cf-sdk-settings.json';
      case CFEnvironment.staging:
        return '/stage/$dimensionId/stagecf-sdk-settings.json';
    }
  }

  /// Base API URL (production default)
  final String baseApiUrl = 'https://api.customfit.ai';

  /// User configs path
  final String userConfigsPath = '/v1/users/configs';

  /// Events path
  final String eventsPath = '/v1/cfe';

  /// Summaries path
  final String summariesPath = '/v1/config/request/summary';

  /// SDK settings base URL (production default)
  final String sdkSettingsBaseUrl = 'https://sdk.customfit.ai';

  /// SDK settings path pattern
  final String sdkSettingsPathPattern = '/%s/cf-sdk-settings.json';
}

/// HTTP constants
class _HttpConstants {
  const _HttpConstants();

  /// Content-Type header name
  final String headerContentType = 'Content-Type';

  /// Content-Type value for JSON
  final String contentTypeJson = 'application/json';

  /// If-Modified-Since header name
  final String headerIfModifiedSince = 'If-Modified-Since';

  /// If-None-Match header name for ETag conditional requests
  final String headerIfNoneMatch = 'If-None-Match';

  /// ETag header name
  final String headerEtag = 'ETag';

  /// Last-Modified header name
  final String headerLastModified = 'Last-Modified';
}

/// Storage constants
class _StorageConstants {
  const _StorageConstants();

  /// User preferences key
  final String userPreferencesKey = 'cf_user';

  /// Events database name
  final String eventsDatabaseName = 'cf_events.db';

  /// Config cache name
  final String configCacheName = 'cf_config.json';

  /// Session ID key
  final String sessionIdKey = 'cf_session_id';

  /// Install time key
  final String installTimeKey = 'cf_app_install_time';
}

/// Event-related constants
class _EventConstants {
  const _EventConstants();

  /// Default queue size for events
  static const int queueSize = 100;

  /// Default flush time in seconds for events
  static const int flushTimeSeconds = 60;

  /// Default flush interval in milliseconds for events
  static const int flushIntervalMs =
      1000; // 1 second - appropriate for event flushing

  /// Maximum number of events to store offline
  static const int maxStoredEvents = 1000;

  /// Persistence timeout in seconds
  static const int persistenceTimeoutSeconds = 5;

  /// Persistence debounce delay in milliseconds
  static const int persistenceDebounceMs = 100;

  /// Event expiration time in days
  static const int eventExpirationDays = 7;
}

/// Summary-related constants
class _SummaryConstants {
  const _SummaryConstants();

  /// Default queue size for summaries
  static const int queueSize = 100;

  /// Default flush time in seconds for summaries
  static const int flushTimeSeconds = 60;

  /// Default flush interval in milliseconds for summaries
  static const int flushIntervalMs = 60000;
}

/// Retry-related constants
class _RetryConstants {
  const _RetryConstants();

  /// Default maximum number of retry attempts
  final int maxRetryAttempts = 3;

  /// Default initial delay in milliseconds before the first retry
  final int initialDelayMs = 1000;

  /// Default maximum delay in milliseconds between retries
  final int maxDelayMs = 30000;

  /// Default backoff multiplier for exponential backoff
  final double backoffMultiplier = 2.0;

  /// Circuit breaker failure threshold
  final int circuitBreakerFailureThreshold = 3;

  /// Circuit breaker reset timeout in milliseconds
  final int circuitBreakerResetTimeoutMs = 30000;
}

/// Background polling-related constants
class _BackgroundPollingConstants {
  const _BackgroundPollingConstants();

  /// Default SDK settings check interval in milliseconds
  final int sdkSettingsCheckIntervalMs = 300000; // 5 minutes

  /// Default background polling interval in milliseconds
  final int backgroundPollingIntervalMs = 3600000; // 1 hour

  /// Default reduced polling interval in milliseconds
  final int reducedPollingIntervalMs = 7200000; // 2 hours
}

/// Network-related constants
class _NetworkConstants {
  const _NetworkConstants();

  /// Default connection timeout in milliseconds
  final int connectionTimeoutMs = 30000; // 30 seconds (standardized)

  /// Default read timeout in milliseconds
  final int readTimeoutMs = 30000; // 30 seconds (standardized)

  /// Default send timeout in milliseconds
  final int sendTimeoutMs = 30000; // 30 seconds (standardized)

  /// SDK settings request timeout in milliseconds
  final int sdkSettingsTimeoutMs = 30000; // 30 seconds (standardized)

  /// SDK settings check timeout in milliseconds
  final int sdkSettingsCheckTimeoutMs = 30000; // 30 seconds (standardized)

  /// Critical operation timeout (for initialization, config fetch)
  final int criticalOperationTimeoutMs = 60000; // 60 seconds

  /// Event tracking timeout (should be shorter to avoid blocking)
  final int eventTrackingTimeoutMs = 15000; // 15 seconds

  /// Metadata polling timeout (should be quick)
  final int metadataPollingTimeoutMs = 10000; // 10 seconds
}

/// Logging-related constants
class _LoggingConstants {
  const _LoggingConstants();

  /// Log level: ERROR
  static const String levelError = 'ERROR';

  /// Log level: WARN
  static const String levelWarn = 'WARN';

  /// Log level: INFO
  static const String levelInfo = 'INFO';

  /// Log level: DEBUG
  static const String levelDebug = 'DEBUG';

  /// Log level: TRACE
  static const String levelTrace = 'TRACE';

  /// Log level: OFF - disables logging
  static const String levelOff = 'OFF';

  /// Default log level
  static const LogLevel defaultLogLevel = LogLevel.info;

  /// Default log level as string
  static const String defaultLogLevelString = 'INFO';

  /// Valid log levels as strings (for validation)
  static const List<String> validLogLevels = [
    'OFF',
    'ERROR',
    'WARN',
    'INFO',
    'DEBUG',
    'TRACE',
  ];
}

/// Cache-related constants
class _CacheConstants {
  const _CacheConstants();

  /// Config cache TTL in milliseconds (5 minutes)
  static const int configCacheTtlMs = 300000; // 5 minutes

  /// User data cache TTL in milliseconds (24 hours)
  static const int userDataCacheTtlMs = 86400000; // 24 hours

  /// Default cache TTL in seconds (1 hour)
  static const int defaultTtlSeconds = 3600;

  /// Short-lived cache TTL in seconds (1 minute)
  static const int shortLivedTtlSeconds = 60;

  /// Medium-lived cache TTL in seconds (5 minutes)
  static const int mediumLivedTtlSeconds = 300;

  /// Long-lived cache TTL in seconds (24 hours)
  static const int longLivedTtlSeconds = 86400;

  /// Cache refresh threshold percentage (10% of TTL)
  static const int refreshThresholdPercent = 10;

  /// Max cache size in bytes (100KB)
  static const int maxCacheSizeBytes = 100000;

  /// Object size estimate for complex objects
  static const int complexObjectSizeEstimate = 1024;
}

/// HTTP methods for network requests (standardized across all platforms)
enum HttpMethod {
  /// GET method
  get('GET'),

  /// POST method
  post('POST'),

  /// PUT method
  put('PUT'),

  /// DELETE method
  delete('DELETE'),

  /// PATCH method
  patch('PATCH'),

  /// HEAD method
  head('HEAD');

  const HttpMethod(this.value);

  /// String value of the HTTP method
  final String value;
}

/// Content types for HTTP requests (standardized across all platforms)
enum ContentType {
  /// JSON content type
  json('application/json'),

  /// Plain text content type
  text('text/plain'),

  /// Form data content type
  formData('application/x-www-form-urlencoded'),

  /// Multipart content type
  multipart('multipart/form-data');

  const ContentType(this.value);

  /// String value of the content type
  final String value;
}

/// Network types for device connectivity (standardized across all platforms)
enum NetworkType {
  /// Unknown network type
  unknown('unknown'),

  /// Cellular network
  cellular('cellular'),

  /// WiFi network
  wifi('wifi'),

  /// Ethernet network
  ethernet('ethernet'),

  /// Bluetooth network
  bluetooth('bluetooth'),

  /// VPN network
  vpn('vpn'),

  /// No network connection
  none('none');

  const NetworkType(this.value);

  /// String value of the network type
  final String value;
}

/// Circuit breaker states for resilience patterns (standardized across all platforms)
enum CircuitBreakerState {
  /// Circuit is closed (normal operation)
  closed('closed'),

  /// Circuit is open (blocking requests)
  open('open'),

  /// Circuit is half-open (testing)
  halfOpen('half_open');

  const CircuitBreakerState(this.value);

  /// String value of the circuit breaker state
  final String value;
}

/// Session-related constants
class _SessionConstants {
  const _SessionConstants();

  /// Default session duration in milliseconds (60 minutes)
  static const int defaultSessionDurationMs = 60 * 60 * 1000;

  /// Default background threshold in milliseconds (15 minutes)
  static const int defaultBackgroundThresholdMs = 15 * 60 * 1000;

  /// Session timeout for cleanup in milliseconds (24 hours)
  static const int sessionTimeoutMs = 24 * 60 * 60 * 1000;

  /// Session inactivity timeout in milliseconds (2 hours)
  static const int sessionInactivityTimeoutMs = 2 * 60 * 60 * 1000;

  /// Session rotation interval in milliseconds (1 hour)
  static const int sessionRotationIntervalMs = 60 * 60 * 1000;
}

/// Analytics-related constants
class _AnalyticsConstants {
  const _AnalyticsConstants();

  /// Maximum consecutive failures before circuit breaker opens
  static const int maxConsecutiveFailures = 5;

  /// Backpressure threshold percentage (80% of queue capacity)
  static const int backpressureThreshold = 80;

  /// Event queue debounce delay in milliseconds
  static const int eventQueueDebounceMs = 100;

  /// Exponential backoff base delay in milliseconds
  static const int exponentialBackoffBaseMs = 100;

  /// Exponential backoff maximum delay in milliseconds
  static const int exponentialBackoffMaxMs = 5000;
}

/// Network health monitoring constants
class _NetworkHealthConstants {
  const _NetworkHealthConstants();

  /// Excellent response time threshold in milliseconds
  static const int excellentResponseTimeMs = 100;

  /// Good response time threshold in milliseconds
  static const int goodResponseTimeMs = 500;

  /// Poor response time threshold in milliseconds
  static const int poorResponseTimeMs = 1000;

  /// Health score for excellent response time
  static const double excellentHealthScore = 1.0;

  /// Health score for good response time
  static const double goodHealthScore = 0.8;

  /// Health score for poor response time
  static const double poorHealthScore = 0.5;

  /// Health score for very poor response time
  static const double veryPoorHealthScore = 0.2;
}

/// Error boundary constants
class _ErrorBoundaryConstants {
  const _ErrorBoundaryConstants();

  /// Default error recovery delay in milliseconds
  final int defaultRecoveryDelayMs = 1000;

  /// Minimum network connection timeout in milliseconds
  final int minNetworkTimeoutMs = 1000;

  /// Recommended initial retry delay in milliseconds
  final int recommendedInitialRetryDelayMs = 500;
}

/// URL constants
class _UrlConstants {
  const _UrlConstants();

  /// Main website URL
  final String mainWebsite = 'https://customfit.ai';

  /// API keys settings URL
  final String apiKeysUrl = 'https://app.customfit.ai/settings/api-keys';

  /// Support documentation URL
  final String supportUrl = 'https://customfit.ai/docs';
}

/// Object pool constants
class _ObjectPoolConstants {
  const _ObjectPoolConstants();

  /// Maximum pool size for EventData objects
  static const int maxEventDataPoolSize = 100;

  /// Minimum pool size for EventData objects
  static const int minEventDataPoolSize = 10;

  /// Maximum string cache size for object pool
  static const int maxStringCacheSize = 1000;
}

/// Polling strategy constants
class _PollingStrategyConstants {
  const _PollingStrategyConstants();

  /// Low battery threshold percentage
  final int lowBatteryThreshold = 15;

  /// Low battery multiplier for polling interval
  final double lowBatteryMultiplier = 2.0;

  /// Max consecutive polling errors before backoff
  final int maxConsecutiveErrors = 5;

  /// Battery check interval in minutes
  final int batteryCheckIntervalMinutes = 5;

  /// Idle time check interval in minutes
  final int idleTimeCheckMinutes = 5;
}

/// Remote logging constants
class _RemoteLoggingConstants {
  const _RemoteLoggingConstants();

  /// Default remote logging endpoint
  static const String defaultEndpoint = 'https://in.logtail.com';

  /// Circuit breaker failure threshold
  static const int circuitBreakerFailureThreshold = 3;

  /// Circuit breaker timeout in hours
  static const int circuitBreakerTimeoutHours = 1;

  /// Default flush interval in milliseconds (30 seconds)
  static const int defaultFlushIntervalMs = 30000;
}

/// Network optimizer constants
class _NetworkOptimizerConstants {
  const _NetworkOptimizerConstants();

  /// Connection pool constants
  final int maxConnectionsPerHost = 6;
  final int connectionTimeoutMs = 30000;
  final int idleTimeoutMs = 60000;
  final int idleCheckIntervalMinutes = 1;
  final int connectionIdleThresholdMinutes = 5;

  /// Request pipeline constants
  final int maxBatchSize = 10;
  final int batchTimeoutMs = 100;
  final int pipelineMaxWaitMs = 5000;
  final int pipelineCheckIntervalMs = 50;

  /// Bandwidth monitor constants
  final int measurementWindowSeconds = 30;
  final double bandwidthSmoothingFactor = 0.3;
  final double defaultBandwidthKbps = 1000; // 1Mbps default
  final int recentMeasurementsCount = 5;

  /// Bandwidth thresholds in Kbps
  final double excellentBandwidthKbps = 10000; // 10Mbps
  final double goodBandwidthKbps = 5000; // 5Mbps
  final double fairBandwidthKbps = 1000; // 1Mbps
  final double poorBandwidthKbps = 100; // 100Kbps

  /// Payload optimization thresholds
  final int largeStringThreshold = 100;
  final int largeArrayThreshold = 20;
  final int stringTruncateLength = 50;
  final int arrayTruncateLength = 20;

  /// Adaptive config - excellent network
  final int excellentMaxBatchSize = 50;
  final int excellentCompressionLevel = 1;
  final int excellentRequestTimeoutMs = 5000;
  final int excellentRetryIntervalMs = 1000;
  final int excellentMaxConcurrentRequests = 6;

  /// Adaptive config - good network
  final int goodMaxBatchSize = 25;
  final int goodCompressionLevel = 3;
  final int goodRequestTimeoutMs = 10000;
  final int goodRetryIntervalMs = 2000;
  final int goodMaxConcurrentRequests = 4;

  /// Adaptive config - fair network
  final int fairMaxBatchSize = 10;
  final int fairCompressionLevel = 5;
  final int fairRequestTimeoutMs = 15000;
  final int fairRetryIntervalMs = 3000;
  final int fairMaxConcurrentRequests = 2;

  /// Adaptive config - poor network
  final int poorMaxBatchSize = 5;
  final int poorCompressionLevel = 7;
  final int poorRequestTimeoutMs = 30000;
  final int poorRetryIntervalMs = 5000;
  final int poorMaxConcurrentRequests = 1;

  /// Adaptive config - terrible network
  final int terribleMaxBatchSize = 2;
  final int terribleCompressionLevel = 9;
  final int terribleRequestTimeoutMs = 60000;
  final int terribleRetryIntervalMs = 10000;
  final int terribleMaxConcurrentRequests = 1;
}

/// Error recovery constants
class _ErrorRecoveryConstants {
  const _ErrorRecoveryConstants();

  /// Default retry configuration
  final int defaultMaxRetries = 3;
  final int defaultInitialDelayMs = 200;
  final int maxRetryDelayMs = 5000;
  final double backoffMultiplier = 1.5;

  /// Circuit breaker configuration
  final int circuitBreakerFailureThreshold = 5;
  final int circuitBreakerResetTimeoutMs = 30000;

  /// Network connectivity timeouts
  final int connectivityWaitTimeoutSeconds = 30;
}
