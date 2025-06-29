// test/shared/helpers/config_builder_helper.dart
//
// Test utility for creating CFConfig instances with different configurations.
// Provides a fluent API for building test configurations and common presets
// for different testing scenarios.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../utils/test_constants.dart';

/// Test helper for building CFConfig instances
class TestConfigBuilder {
  String _clientKey = TestConstants.validJwtToken;
  bool _debugLoggingEnabled = true;
  bool _offlineMode = true; // Default to offline for tests
  int _eventsFlushIntervalMs = 30000;
  int _networkConnectionTimeoutMs = 10000;
  int _networkReadTimeoutMs = 10000;
  int _configRefreshIntervalMs = 60000;
  int _eventsMaxBatchSize = 100;
  String _environment = 'test';
  bool _remoteLoggingEnabled = false;
  String _remoteLogProvider = '';
  String _remoteLogLevel = '';

  /// Create a new test config builder
  TestConfigBuilder();

  /// Create a builder with minimal configuration
  factory TestConfigBuilder.minimal() {
    return TestConfigBuilder()
      .._debugLoggingEnabled = false
      .._offlineMode = true
      .._eventsFlushIntervalMs = 60000
      .._networkConnectionTimeoutMs = 5000
      .._networkReadTimeoutMs = 5000;
  }

  /// Create a builder for performance testing
  factory TestConfigBuilder.performance() {
    return TestConfigBuilder()
      .._debugLoggingEnabled = false
      .._offlineMode = false
      .._eventsFlushIntervalMs = 1000
      .._networkConnectionTimeoutMs = 2000
      .._networkReadTimeoutMs = 2000
      .._configRefreshIntervalMs = 10000
      .._eventsMaxBatchSize = 50;
  }

  /// Create a builder for error testing
  factory TestConfigBuilder.errorTesting() {
    return TestConfigBuilder()
      .._clientKey = 'invalid.jwt.token'
      .._debugLoggingEnabled = true
      .._offlineMode = false
      .._networkConnectionTimeoutMs = 100
      .._networkReadTimeoutMs = 100;
  }

  /// Create a builder for offline testing
  factory TestConfigBuilder.offline() {
    return TestConfigBuilder()
      .._offlineMode = true
      .._debugLoggingEnabled = true
      .._eventsFlushIntervalMs = 10000;
  }

  /// Create a builder for integration testing
  factory TestConfigBuilder.integration() {
    return TestConfigBuilder()
      .._offlineMode = false
      .._debugLoggingEnabled = true
      .._networkConnectionTimeoutMs = 15000
      .._networkReadTimeoutMs = 15000
      .._configRefreshIntervalMs = 30000;
  }

  /// Set the client key
  TestConfigBuilder withClientKey(String key) {
    _clientKey = key;
    return this;
  }

  /// Set debug logging
  TestConfigBuilder withDebugLogging(bool enabled) {
    _debugLoggingEnabled = enabled;
    return this;
  }

  /// Set offline mode
  TestConfigBuilder withOfflineMode(bool offline) {
    _offlineMode = offline;
    return this;
  }

  /// Set events flush interval
  TestConfigBuilder withEventsFlushInterval(Duration interval) {
    _eventsFlushIntervalMs = interval.inMilliseconds;
    return this;
  }

  /// Set network connection timeout
  TestConfigBuilder withConnectionTimeout(Duration timeout) {
    _networkConnectionTimeoutMs = timeout.inMilliseconds;
    return this;
  }

  /// Set network read timeout
  TestConfigBuilder withReadTimeout(Duration timeout) {
    _networkReadTimeoutMs = timeout.inMilliseconds;
    return this;
  }

  /// Set config refresh interval
  TestConfigBuilder withConfigRefreshInterval(Duration interval) {
    _configRefreshIntervalMs = interval.inMilliseconds;
    return this;
  }

  /// Set events max batch size
  TestConfigBuilder withEventsMaxBatchSize(int size) {
    _eventsMaxBatchSize = size;
    return this;
  }

  /// Set environment
  TestConfigBuilder withEnvironment(String env) {
    _environment = env;
    return this;
  }

  /// Set remote logging
  TestConfigBuilder withRemoteLogging(bool enabled) {
    _remoteLoggingEnabled = enabled;
    return this;
  }

  /// Set remote log provider
  TestConfigBuilder withRemoteLogProvider(String provider) {
    _remoteLogProvider = provider;
    return this;
  }

  /// Set remote log level
  TestConfigBuilder withRemoteLogLevel(String level) {
    _remoteLogLevel = level;
    return this;
  }

  /// Build the CFConfig instance
  CFConfig build() {
    final builder = CFConfig.builder(_clientKey)
      ..setDebugLoggingEnabled(_debugLoggingEnabled)
      ..setOfflineMode(_offlineMode)
      ..setEventsFlushIntervalMs(_eventsFlushIntervalMs)
      ..setNetworkConnectionTimeoutMs(_networkConnectionTimeoutMs)
      ..setRemoteLoggingEnabled(_remoteLoggingEnabled)
      ..setRemoteLogProvider(_remoteLogProvider)
      ..setRemoteLogLevel(_remoteLogLevel);
    // Note: Some setters might not be available in the public API
    // This builder provides the interface for when they are added
    return builder.build().getOrThrow();
  }

  /// Get a map representation of the configuration
  Map<String, dynamic> toMap() {
    return {
      'clientKey': _clientKey,
      'debugLoggingEnabled': _debugLoggingEnabled,
      'offlineMode': _offlineMode,
      'eventsFlushIntervalMs': _eventsFlushIntervalMs,
      'networkConnectionTimeoutMs': _networkConnectionTimeoutMs,
      'networkReadTimeoutMs': _networkReadTimeoutMs,
      'configRefreshIntervalMs': _configRefreshIntervalMs,
      'eventsMaxBatchSize': _eventsMaxBatchSize,
      'environment': _environment,
      'remoteLoggingEnabled': _remoteLoggingEnabled,
      'remoteLogProvider': _remoteLogProvider,
      'remoteLogLevel': _remoteLogLevel,
    };
  }
}

/// Common test configurations
class TestConfigurations {
  // Prevent instantiation
  TestConfigurations._();

  /// Standard test configuration
  static CFConfig standard() {
    return TestConfigBuilder().build();
  }

  /// Minimal configuration for basic tests
  static CFConfig minimal() {
    return TestConfigBuilder.minimal().build();
  }

  /// Performance optimized configuration
  static CFConfig performance() {
    return TestConfigBuilder.performance().build();
  }

  /// Configuration for error testing
  static CFConfig errorTesting() {
    return TestConfigBuilder.errorTesting().build();
  }

  /// Offline mode configuration
  static CFConfig offline() {
    return TestConfigBuilder.offline().build();
  }

  /// Integration testing configuration
  static CFConfig integration() {
    return TestConfigBuilder.integration().build();
  }

  /// Configuration with custom timeouts
  static CFConfig withTimeouts({
    Duration? connectionTimeout,
    Duration? readTimeout,
  }) {
    return TestConfigBuilder()
        .withConnectionTimeout(connectionTimeout ?? const Duration(seconds: 5))
        .withReadTimeout(readTimeout ?? const Duration(seconds: 5))
        .build();
  }

  /// Configuration with custom intervals
  static CFConfig withIntervals({
    Duration? flushInterval,
    Duration? refreshInterval,
  }) {
    return TestConfigBuilder()
        .withEventsFlushInterval(flushInterval ?? const Duration(seconds: 30))
        .withConfigRefreshInterval(
            refreshInterval ?? const Duration(minutes: 1))
        .build();
  }

  /// Create multiple configurations for parameterized tests
  static List<CFConfig> allVariants() {
    return [
      standard(),
      minimal(),
      performance(),
      offline(),
    ];
  }

  /// Create configurations with different client keys
  static List<CFConfig> withDifferentKeys(List<String> keys) {
    return keys
        .map((key) => TestConfigBuilder().withClientKey(key).build())
        .toList();
  }
}

/// Extension methods for CFConfig in tests
extension CFConfigTestExtensions on CFConfig {
  /// Check if this config is valid for testing
  bool get isValidForTesting {
    return clientKey.isNotEmpty &&
        eventsFlushIntervalMs > 0 &&
        networkConnectionTimeoutMs > 0;
  }

  /// Get a description of this config for test naming
  String get testDescription {
    final features = <String>[];
    if (debugLoggingEnabled) features.add('debug');
    if (offlineMode) features.add('offline');
    if (eventsFlushIntervalMs < 10000) features.add('fast-flush');
    if (networkConnectionTimeoutMs < 5000) features.add('quick-timeout');
    return features.isEmpty ? 'standard' : features.join('-');
  }

  /// Create a copy with modifications
  CFConfig copyWith({
    String? clientKey,
    bool? debugLoggingEnabled,
    bool? offlineMode,
    int? eventsFlushIntervalMs,
    int? networkConnectionTimeoutMs,
    bool? remoteLoggingEnabled,
    String? remoteLogProvider,
    String? remoteLogLevel,
  }) {
    return CFConfig.builder(clientKey ?? this.clientKey)
        .setDebugLoggingEnabled(debugLoggingEnabled ?? this.debugLoggingEnabled)
        .setOfflineMode(offlineMode ?? this.offlineMode)
        .setEventsFlushIntervalMs(
            eventsFlushIntervalMs ?? this.eventsFlushIntervalMs)
        .setNetworkConnectionTimeoutMs(
            networkConnectionTimeoutMs ?? this.networkConnectionTimeoutMs)
        .setRemoteLoggingEnabled(
            remoteLoggingEnabled ?? this.remoteLoggingEnabled)
        .setRemoteLogProvider(remoteLogProvider ?? this.remoteLogProvider)
        .setRemoteLogLevel(remoteLogLevel ?? this.remoteLogLevel)
        .build()
        .getOrThrow();
  }
}
