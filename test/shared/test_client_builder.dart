// test/shared/test_client_builder.dart
//
// Shared test utility for building CFClient instances in tests.
// Reduces test setup redundancy and provides consistent test configurations.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../utils/test_constants.dart';
import 'test_configs.dart';
import '../utils/di/mock_dependency_factory.dart';

/// Builder for creating test CFClient instances with various configurations
class TestClientBuilder {
  CFConfig? _config;
  CFUser? _user;
  bool _useRealNetworking = false;
  bool _useRealStorage = false;
  bool _enableLogging = false;
  Map<String, dynamic>? _initialFlags;
  String? _customApiKey;
  String? _customBaseUrl;
  MockDependencyFactory? _mockFactory;

  /// Create a new test client builder
  TestClientBuilder();

  /// Use a specific configuration
  TestClientBuilder withConfig(CFConfig config) {
    _config = config;
    return this;
  }

  /// Use a predefined test configuration
  TestClientBuilder withTestConfig(TestConfigType type) {
    _config = TestConfigs.getConfig(type);
    return this;
  }

  /// Use a specific user
  TestClientBuilder withUser(CFUser user) {
    _user = user;
    return this;
  }

  /// Use a predefined test user
  TestClientBuilder withTestUser(TestUserType type) {
    _user = TestConfigs.getUser(type);
    return this;
  }

  /// Enable real networking (default: uses mocks)
  TestClientBuilder withRealNetworking() {
    _useRealNetworking = true;
    return this;
  }

  /// Enable real storage (default: uses mocks)
  TestClientBuilder withRealStorage() {
    _useRealStorage = true;
    return this;
  }

  /// Enable logging for debugging
  TestClientBuilder withLogging() {
    _enableLogging = true;
    return this;
  }

  /// Set initial feature flags for testing
  TestClientBuilder withInitialFlags(Map<String, dynamic> flags) {
    _initialFlags = flags;
    return this;
  }

  /// Use custom API key
  TestClientBuilder withApiKey(String apiKey) {
    _customApiKey = apiKey;
    return this;
  }

  /// Use custom base URL
  TestClientBuilder withBaseUrl(String baseUrl) {
    _customBaseUrl = baseUrl;
    return this;
  }

  /// Build a CFClient instance with the configured parameters
  Future<CFClient> build() async {
    final config = _buildConfig();
    final user = _user ?? TestConfigs.getUser(TestUserType.defaultUser);
    // Always set up mock factory when not using real networking
    if (!_useRealNetworking) {
      _mockFactory = MockDependencyFactory();
      // Configure mock to return initial flags if provided
      if (_initialFlags != null) {
        _mockFactory!.mockConfigFetcher.setConfigs(_initialFlags!);
      }
      // Set the config fetcher to offline mode to prevent real network calls
      _mockFactory!.mockConfigFetcher.setOffline(config.offlineMode);
    }
    // Initialize the client using the new API with mock factory if available
    final result = await CFClient.initialize(
      config,
      user,
      dependencyFactory: _mockFactory,
    );
    return result.getOrThrow();
  }

  /// Build a client and wait for initialization
  Future<CFClient> buildAndInitialize() async {
    final client = await build();
    // No need to wait for initialization - the initialize() method already handles this
    return client;
  }

  /// Build multiple clients with different configurations
  Future<List<CFClient>> buildMultiple(List<TestConfigType> configTypes) async {
    final clients = <CFClient>[];
    for (final configType in configTypes) {
      final client = await TestClientBuilder()
          .withTestConfig(configType)
          .withUser(_user ?? TestConfigs.getUser(TestUserType.defaultUser))
          .build();
      clients.add(client);
    }
    return clients;
  }

  CFConfig _buildConfig() {
    if (_config != null) {
      return _config!;
    }
    // Build default config with any custom parameters
    // ALWAYS use offline mode in tests to prevent real network calls
    final offlineMode = !_useRealNetworking;
    final result =
        CFConfig.builder(_customApiKey ?? TestConstants.validJwtToken)
            .setOfflineMode(offlineMode)
            .setDebugLoggingEnabled(true)
            .setNetworkConnectionTimeoutMs(5000)
            .setNetworkReadTimeoutMs(5000)
            .setMaxRetryAttempts(3)
            .build()
            .getOrThrow();
    return result;
  }
}

/// Extension for CFClient to support test instance creation
extension CFClientTestExtension on CFClient {
  /// Create a test instance with controlled dependencies
  static Future<CFClient> createTestInstance({
    required CFConfig config,
    required CFUser user,
    bool useRealNetworking = false,
    bool useRealStorage = false,
    Map<String, dynamic>? initialFlags,
  }) async {
    // Create a regular client using the initialize method
    final result = await CFClient.initialize(config, user);
    final client = result.getOrThrow();
    // If initial flags provided, set them up
    // Note: This would require implementing mock response setup
    if (initialFlags != null) {
      // Mock response setup for initial flags
      // This is a placeholder for future mock factory implementation
      for (final entry in initialFlags.entries) {
        // Future enhancement: setup mock responses for each flag
        // MockFactory.setupMockConfigResponse(entry.key, entry.value);
        Logger.d('Mock flag setup: ${entry.key} = ${entry.value}');
      }
    }
    return client;
  }
}

/// Quick access methods for common test scenarios
class QuickTestClients {
  /// Default test client with standard configuration
  static Future<CFClient> defaultClient() async {
    return TestClientBuilder().withTestConfig(TestConfigType.standard).build();
  }

  /// Offline test client
  static Future<CFClient> offlineClient() async {
    return TestClientBuilder().withTestConfig(TestConfigType.offline).build();
  }

  /// High-performance test client
  static Future<CFClient> performanceClient() async {
    return TestClientBuilder()
        .withTestConfig(TestConfigType.performance)
        .build();
  }

  /// Client with minimal configuration
  static Future<CFClient> minimalClient() async {
    return TestClientBuilder().withTestConfig(TestConfigType.minimal).build();
  }

  /// Client for error testing scenarios
  static Future<CFClient> errorTestClient() async {
    return TestClientBuilder()
        .withTestConfig(TestConfigType.errorTesting)
        .build();
  }

  /// Client for integration testing
  static Future<CFClient> integrationClient() async {
    return TestClientBuilder()
        .withTestConfig(TestConfigType.integration)
        .withRealNetworking()
        .build();
  }
}

/// Test result wrapper for assertions
class TestResult<T> {
  final T? value;
  final CFError? error;
  final Duration elapsed;
  TestResult({this.value, this.error, required this.elapsed});
  bool get isSuccess => error == null && value != null;
  bool get isError => error != null;
  bool get hasValue => value != null;

  /// Assert that the result is successful
  TestResult<T> assertSuccess([String? message]) {
    if (!isSuccess) {
      throw AssertionError(
        message ?? 'Expected success but got error: ${error?.message}',
      );
    }
    return this;
  }

  /// Assert that the result is an error
  TestResult<T> assertError([String? message]) {
    if (!isError) {
      throw AssertionError(
        message ?? 'Expected error but got success with value: $value',
      );
    }
    return this;
  }

  /// Assert the elapsed time is within bounds
  TestResult<T> assertTimingWithin(Duration min, Duration max) {
    if (elapsed < min || elapsed > max) {
      throw AssertionError(
        'Expected timing between $min and $max, but got $elapsed',
      );
    }
    return this;
  }

  /// Assert the value matches expected
  TestResult<T> assertValue(T expected) {
    if (value != expected) {
      throw AssertionError('Expected value $expected but got $value');
    }
    return this;
  }
}

/// Helper for timing operations in tests
class TestTimer {
  static Future<TestResult<T>> time<T>(Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      return TestResult(
        value: result,
        elapsed: stopwatch.elapsed,
      );
    } catch (error) {
      return TestResult(
        error: error is CFError
            ? error
            : CFError(
                message: error.toString(),
                errorCode: CFErrorCode.internalUnknownError,
              ),
        elapsed: stopwatch.elapsed,
      );
    } finally {
      stopwatch.stop();
    }
  }

  static Future<TestResult<CFResult<T>>> timeResult<T>(
    Future<CFResult<T>> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      return TestResult(
        value: result,
        error: result.isSuccess ? null : result.error,
        elapsed: stopwatch.elapsed,
      );
    } catch (error) {
      return TestResult(
        error: error is CFError
            ? error
            : CFError(
                message: error.toString(),
                errorCode: CFErrorCode.internalUnknownError,
              ),
        elapsed: stopwatch.elapsed,
      );
    } finally {
      stopwatch.stop();
    }
  }
}
