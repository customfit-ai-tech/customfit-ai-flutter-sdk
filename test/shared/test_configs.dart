// test/shared/test_configs.dart
//
// Predefined test configurations and users for consistent testing.
// Provides common test scenarios and setup patterns.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../utils/test_constants.dart';

/// Types of test configurations available
enum TestConfigType {
  standard,
  minimal,
  offline,
  performance,
  errorTesting,
  integration,
  analytics,
  caching,
  featureFlags,
}

/// Types of test users available
enum TestUserType {
  defaultUser,
  premiumUser,
  anonymousUser,
  organizationUser,
  betaUser,
}

/// Predefined test configurations and users
class TestConfigs {
  /// Get a predefined test configuration
  static CFConfig getConfig(TestConfigType type) {
    switch (type) {
      case TestConfigType.standard:
        return _standardConfig();
      case TestConfigType.minimal:
        return _minimalConfig();
      case TestConfigType.offline:
        return _offlineConfig();
      case TestConfigType.performance:
        return _performanceConfig();
      case TestConfigType.errorTesting:
        return _errorTestingConfig();
      case TestConfigType.integration:
        return _integrationConfig();
      case TestConfigType.analytics:
        return _analyticsConfig();
      case TestConfigType.caching:
        return _cachingConfig();
      case TestConfigType.featureFlags:
        return _featureFlagsConfig();
    }
  }

  /// Get a predefined test user
  static CFUser getUser(TestUserType type) {
    switch (type) {
      case TestUserType.defaultUser:
        return _defaultUser();
      case TestUserType.premiumUser:
        return _premiumUser();
      case TestUserType.anonymousUser:
        return _anonymousUser();
      case TestUserType.organizationUser:
        return _organizationUser();
      case TestUserType.betaUser:
        return _betaUser();
    }
  }

  /// Standard test configuration with balanced settings
  static CFConfig _standardConfig() {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setDebugLoggingEnabled(true)
        .setLoggingEnabled(true)
        .setEventsFlushIntervalMs(1000)
        .setSummariesFlushIntervalMs(1000)
        .setNetworkConnectionTimeoutMs(5000)
        .setNetworkReadTimeoutMs(10000)
        .setMaxRetryAttempts(2)
        .setOfflineMode(false)
        .build()
        .getOrThrow();
  }

  /// Minimal configuration for basic functionality tests
  static CFConfig _minimalConfig() {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setDebugLoggingEnabled(false)
        .setLoggingEnabled(false)
        .setEventsFlushIntervalMs(5000)
        .setSummariesFlushIntervalMs(5000)
        .build()
        .getOrThrow();
  }

  /// Offline configuration for offline scenario tests
  static CFConfig _offlineConfig() {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setDebugLoggingEnabled(true)
        .setLoggingEnabled(true)
        .setOfflineMode(true)
        .setEventsFlushIntervalMs(100)
        .setSummariesFlushIntervalMs(100)
        .build()
        .getOrThrow();
  }

  /// Performance-optimized configuration
  static CFConfig _performanceConfig() {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setDebugLoggingEnabled(false)
        .setLoggingEnabled(true)
        .setEventsFlushIntervalMs(10000)
        .setSummariesFlushIntervalMs(10000)
        .setNetworkConnectionTimeoutMs(30000)
        .setNetworkReadTimeoutMs(60000)
        .setMaxRetryAttempts(5)
        .build()
        .getOrThrow();
  }

  /// Configuration for error testing scenarios
  static CFConfig _errorTestingConfig() {
    // Use a malformed JWT for error testing (long enough to pass length validation)
    return CFConfig.builder(
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6InRlc3QiLCJpYXQiOjE1MTYyMzkwMjJ9.invalid_signature_for_testing')
        .setOfflineMode(true) // Use offline mode for tests
        .setDebugLoggingEnabled(true)
        .setNetworkConnectionTimeoutMs(1000)
        .setEventsFlushIntervalMs(1000)
        .build()
        .getOrThrow();
  }

  /// Configuration for integration testing
  static CFConfig _integrationConfig() {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setOfflineMode(true) // Use offline mode for tests
        .setDebugLoggingEnabled(true)
        .setNetworkConnectionTimeoutMs(15000)
        .setEventsFlushIntervalMs(15000)
        .build()
        .getOrThrow();
  }

  /// Configuration optimized for analytics testing
  static CFConfig _analyticsConfig() {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setOfflineMode(true) // Use offline mode for tests
        .setDebugLoggingEnabled(true)
        .setNetworkConnectionTimeoutMs(10000)
        .setEventsFlushIntervalMs(5000)
        .build()
        .getOrThrow();
  }

  /// Configuration optimized for caching tests
  static CFConfig _cachingConfig() {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setOfflineMode(true) // Use offline mode for tests
        .setDebugLoggingEnabled(true)
        .setNetworkConnectionTimeoutMs(10000)
        .setEventsFlushIntervalMs(60000)
        .build()
        .getOrThrow();
  }

  /// Configuration optimized for feature flags testing
  static CFConfig _featureFlagsConfig() {
    return CFConfig.builder(TestConstants.validJwtToken)
        .setOfflineMode(true) // Use offline mode for tests
        .setDebugLoggingEnabled(true)
        .setNetworkConnectionTimeoutMs(10000)
        .setEventsFlushIntervalMs(30000)
        .build()
        .getOrThrow();
  }

  // User configurations
  /// Default test user
  static CFUser _defaultUser() {
    final builder = CFUser.builder('test_user_123');
    builder.addStringProperty('name', 'Test User');
    builder.addStringProperty('email', 'test@example.com');
    builder.addStringProperty('user_type', 'standard');
    builder.addBooleanProperty('test_mode', true);
    return builder.build();
  }

  /// Premium user for feature testing
  static CFUser _premiumUser() {
    final builder = CFUser.builder('premium_user_456');
    builder.addStringProperty('name', 'Premium User');
    builder.addStringProperty('email', 'premium@example.com');
    builder.addStringProperty('user_type', 'premium');
    builder.addStringProperty('subscription_tier', 'gold');
    builder.addBooleanProperty('test_mode', true);
    return builder.build();
  }

  /// Anonymous user for anonymous scenario testing
  static CFUser _anonymousUser() {
    // Even anonymous users need an identifier for the SDK to function
    final builder =
        CFUser.builder('anonymous-${DateTime.now().millisecondsSinceEpoch}');
    builder.makeAnonymous(true);
    builder.addStringProperty('user_type', 'anonymous');
    builder.addBooleanProperty('test_mode', true);
    return builder.build();
  }

  /// Organization user for multi-tenant testing
  static CFUser _organizationUser() {
    final builder = CFUser.builder('org_user_789');
    builder.addStringProperty('name', 'Organization User');
    builder.addStringProperty('email', 'org@company.com');
    builder.addStringProperty('user_type', 'organization');
    builder.addStringProperty('organization_id', 'test_org_123');
    builder.addStringProperty('role', 'admin');
    builder.addBooleanProperty('test_mode', true);
    return builder.build();
  }

  /// Beta user for feature flag testing
  static CFUser _betaUser() {
    final builder = CFUser.builder('beta_user_999');
    builder.addStringProperty('name', 'Beta User');
    builder.addStringProperty('email', 'beta@example.com');
    builder.addStringProperty('user_type', 'beta');
    builder.addBooleanProperty('beta_tester', true);
    builder.addStringProperty('feature_access', 'experimental');
    builder.addBooleanProperty('test_mode', true);
    return builder.build();
  }
}

/// Common feature flag configurations for testing
class TestFeatureFlags {
  /// Standard feature flags for most tests
  static Map<String, dynamic> get standard => {
        'feature_a': {'enabled': true, 'value': true},
        'feature_b': {'enabled': true, 'value': 'production'},
        'numeric_config': {'enabled': true, 'value': 42},
        'json_config': {
          'enabled': true,
          'value': {
            'theme': 'dark',
            'features': ['chat', 'notifications'],
            'limits': {'max_users': 100}
          }
        },
      };

  /// Feature flags for A/B testing scenarios
  static Map<String, dynamic> get abTesting => {
        'experiment_variant': {'enabled': true, 'value': 'variant_a'},
        'show_new_ui': {'enabled': true, 'value': true},
        'button_color': {'enabled': true, 'value': '#FF5722'},
        'conversion_funnel': {'enabled': true, 'value': 'optimized'},
      };

  /// Feature flags for error testing
  static Map<String, dynamic> get errorScenarios => {
        'broken_feature': {'enabled': false, 'value': null},
        'invalid_json': {'enabled': true, 'value': 'not a number'},
        'missing_config': null,
      };

  /// Performance testing flags
  static Map<String, dynamic> get performance => {
        'large_config': {
          'enabled': true,
          'value': Map.fromEntries(
            List.generate(100, (i) => MapEntry('key_$i', 'value_$i')),
          )
        },
        'cache_test': {
          'enabled': true,
          'value': DateTime.now().toIso8601String()
        },
      };

  /// Feature flags for offline testing
  static Map<String, dynamic> get offline => {
        'offline_feature': {'enabled': true, 'value': true},
        'cached_config': {'enabled': true, 'value': 'cached_value'},
        'fallback_feature': {'enabled': false, 'value': 'fallback'},
      };
}
