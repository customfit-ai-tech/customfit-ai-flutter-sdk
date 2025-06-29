import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import 'test_constants.dart';
import '../shared/test_configs.dart';
/// Simplified mock factory for creating test doubles with current API
class MockFactory {
  /// Creates a test CFConfig instance
  static CFConfig createTestConfig({
    String? clientKey,
    bool? debugLoggingEnabled,
    bool? offlineMode,
  }) {
    return CFConfig.builder(clientKey ?? TestConstants.validJwtToken)
        .setDebugLoggingEnabled(debugLoggingEnabled ?? true)
        .setOfflineMode(
            offlineMode ?? true) // Default to offline mode for tests
        .setEventsFlushIntervalMs(1000)
        .setNetworkConnectionTimeoutMs(5000)
        .build().getOrThrow();
  }
  /// Creates a test CFUser instance
  static CFUser createTestUser({
    String? userId,
    Map<String, dynamic>? properties,
    bool? anonymous,
  }) {
    final builder = CFUser.builder(userId ?? TestConstants.testUserId);
    final props = properties ?? {'plan': 'test', 'environment': 'test'};
    // Add properties individually based on type
    for (final entry in props.entries) {
      if (entry.value is String) {
        builder.addStringProperty(entry.key, entry.value as String);
      } else if (entry.value is bool) {
        builder.addBooleanProperty(entry.key, entry.value as bool);
      } else if (entry.value is num) {
        builder.addNumberProperty(entry.key, entry.value as num);
      } else {
        builder.addStringProperty(entry.key, entry.value.toString());
      }
    }
    final result = builder.build();
    return result.getOrThrow();
  }
  /// Creates an anonymous test user
  static CFUser createAnonymousUser({
    Map<String, dynamic>? properties,
  }) {
    final builder = CFUser.anonymousBuilder();
    final props = properties ?? {'environment': 'test'};
    // Add properties individually based on type
    for (final entry in props.entries) {
      if (entry.value is String) {
        builder.addStringProperty(entry.key, entry.value as String);
      } else if (entry.value is bool) {
        builder.addBooleanProperty(entry.key, entry.value as bool);
      } else if (entry.value is num) {
        builder.addNumberProperty(entry.key, entry.value as num);
      } else {
        builder.addStringProperty(entry.key, entry.value.toString());
      }
    }
    final result = builder.build();
    return result.getOrThrow();
  }
  /// Helper to create different user types for testing
  static CFUser createUserForType(TestUserType type) {
    switch (type) {
      case TestUserType.defaultUser:
        return createTestUser();
      case TestUserType.premiumUser:
        return createTestUser(
          userId: 'premium-user',
          properties: {'plan': 'premium', 'tier': 'gold'},
        );
      case TestUserType.anonymousUser:
        return createAnonymousUser();
      case TestUserType.organizationUser:
        return createTestUser(
          userId: 'org-user',
          properties: {'type': 'organization', 'size': 'large'},
        );
      case TestUserType.betaUser:
        return createTestUser(
          userId: 'beta-user',
          properties: {'beta': true, 'features': 'all'},
        );
    }
  }
  /// Helper to create configs for different test scenarios
  static CFConfig createConfigForType(TestConfigType type) {
    switch (type) {
      case TestConfigType.standard:
        return createTestConfig();
      case TestConfigType.minimal:
        return createTestConfig(
          debugLoggingEnabled: false,
        );
      case TestConfigType.offline:
        return createTestConfig(
          offlineMode: true,
        );
      case TestConfigType.performance:
        final perfResult = CFConfig.builder(TestConstants.validJwtToken)
            .setEventsFlushIntervalMs(100)
            .setNetworkConnectionTimeoutMs(1000)
            .build().getOrThrow();
        return perfResult;
      case TestConfigType.analytics:
        final analyticsResult = CFConfig.builder(TestConstants.validJwtToken)
            .setEventsFlushIntervalMs(500)
            .build().getOrThrow();
        return analyticsResult;
      case TestConfigType.caching:
        final cachingResult = CFConfig.builder(TestConstants.validJwtToken).build().getOrThrow();
        return cachingResult;
      case TestConfigType.errorTesting:
        final errorResult = CFConfig.builder('invalid.jwt.token')
            .setOfflineMode(false)
            .setDebugLoggingEnabled(true)
            .setEventsFlushIntervalMs(1000)
            .build().getOrThrow();
        return errorResult;
      case TestConfigType.integration:
        final integrationResult = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(false)
            .setDebugLoggingEnabled(true)
            .setEventsFlushIntervalMs(1000)
            .build().getOrThrow();
        return integrationResult;
      case TestConfigType.featureFlags:
        final ffResult = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true)
            .setDebugLoggingEnabled(true)
            .setEventsFlushIntervalMs(2000)
            .build().getOrThrow();
        return ffResult;
    }
  }
}
/// Simple mock environment for testing
class MockEnvironment {
  static Map<String, dynamic> createTestEnvironment() {
    return {
      'platform': 'test',
      'version': '1.0.0',
      'debug': true,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  static Map<String, dynamic> getTestStats() {
    return {
      'tests_run': 0,
      'assertions': 0,
      'errors': 0,
      'warnings': 0,
    };
  }
}
