import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'test_constants.dart';
/// Helper class to create test configurations
class TestConfigHelper {
  /// Creates a test configuration with offline mode and disabled background polling
  /// This prevents unit tests from making real network calls
  static CFConfig createTestConfig({
    bool offlineMode = true,
    bool disableBackgroundPolling = true,
    bool debugLoggingEnabled = true,
    int networkTimeoutMs = 5000,
  }) {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setOfflineMode(offlineMode)
        .setDisableBackgroundPolling(disableBackgroundPolling)
        .setDebugLoggingEnabled(debugLoggingEnabled)
        .setNetworkConnectionTimeoutMs(networkTimeoutMs)
        .setNetworkReadTimeoutMs(networkTimeoutMs)
        .build()
        .getOrThrow();
  }
  /// Creates a test configuration for integration tests that need real API calls
  static CFConfig createIntegrationTestConfig() {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setOfflineMode(false)
        .setDebugLoggingEnabled(true)
        .setEventsFlushIntervalMs(2000)
        .setSummariesFlushIntervalMs(3000)
        .build()
        .getOrThrow();
  }
}