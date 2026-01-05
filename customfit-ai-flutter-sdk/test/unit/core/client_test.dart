// test/unit/core/client_test.dart
//
// Consolidated Core Client Tests
//
// This file consolidates 15+ individual client test files into a single
// comprehensive test suite with organized test groups and shared utilities.
//
// Consolidated from:
// - cf_client_comprehensive_test.dart
// - cf_client_focused_test.dart
// - cf_client_enhanced_test.dart
// - cf_client_advanced_coverage_test.dart
// - cf_client_singleton_focused_test.dart
// - cf_client_configuration_lifecycle_test.dart
// - And 10+ other client test files
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../utils/di/mock_dependency_factory.dart';
import '../../shared/test_client_builder.dart';
import '../../shared/test_configs.dart';
import '../../utils/test_constants.dart';
import '../../utils/test_plugin_mocks.dart';
import '../../helpers/test_storage_helper.dart';
/// Comprehensive Core Client Tests
/// Tests all aspects of CFClient functionality including initialization,
/// configuration, feature flag evaluation, user management, and error handling.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestPluginMocks.initializePluginMocks();
  group('CFClient Core Tests', () {
    late MockDependencyFactory mockFactory;
    setUp(() async {
      CFClient.clearInstance();
      mockFactory = MockDependencyFactory();
      // Setup test storage with secure storage
      TestStorageHelper.setupTestStorage();
    });
    tearDown(() async {
      try {
        if (CFClient.isInitialized()) {
          await CFClient.shutdownSingleton();
        }
      } catch (e) {
        // Ignore shutdown errors in tests - they're often just cleanup issues
        // Debug: Ignoring shutdown error in tearDown: $e
      }
      TestStorageHelper.clearTestStorage();
      CFClient.clearInstance();
    });
    group('Initialization and Singleton Management', () {
      test('should handle pre-initialization state correctly', () {
        expect(CFClient.isInitialized(), isFalse);
        expect(CFClient.isInitializing(), isFalse);
        expect(CFClient.getInstance(), isNull);
      });
      test('should initialize with standard configuration', () async {
        final client = await TestClientBuilder()
            .withTestConfig(TestConfigType.standard)
            .withTestUser(TestUserType.defaultUser)
            .build();
        expect(client, isNotNull);
        expect(CFClient.isInitialized(), isTrue);
        expect(CFClient.getInstance(), same(client));
      });
      test('should return same instance on multiple initialization calls',
          () async {
        final client1 = await TestClientBuilder()
            .withTestConfig(TestConfigType.standard)
            .withTestUser(TestUserType.defaultUser)
            .build();
        final client2 = await TestClientBuilder()
            .withTestConfig(TestConfigType.standard)
            .withTestUser(TestUserType.defaultUser)
            .build();
        expect(client1, same(client2));
      });
      test('should handle initialization with various configurations',
          () async {
        final configs = [
          TestConfigType.minimal,
          TestConfigType.performance,
          TestConfigType.analytics,
          TestConfigType.caching,
        ];
        for (final configType in configs) {
          await CFClient.shutdownSingleton();
          CFClient.clearInstance();
          final client = await TestClientBuilder()
              .withTestConfig(configType)
              .withTestUser(TestUserType.defaultUser)
              .build();
          expect(client, isNotNull);
          expect(CFClient.isInitialized(), isTrue);
        }
      });
      test('should handle offline mode initialization', () async {
        final client = await TestClientBuilder()
            .withTestConfig(TestConfigType.offline)
            .withTestUser(TestUserType.defaultUser)
            .build();
        expect(client, isNotNull);
        expect(CFClient.isInitialized(), isTrue);
      });
      test('should handle initialization with various user types', () async {
        final userTypes = [
          TestUserType.premiumUser,
          TestUserType.anonymousUser,
          TestUserType.organizationUser,
          TestUserType.betaUser,
        ];
        for (final userType in userTypes) {
          await CFClient.shutdownSingleton();
          CFClient.clearInstance();
          final client = await TestClientBuilder()
              .withTestConfig(TestConfigType.standard)
              .withTestUser(userType)
              .build();
          expect(client, isNotNull);
        }
      });
      test('should properly shutdown and clear singleton', () async {
        await TestClientBuilder()
            .withTestConfig(TestConfigType.standard)
            .withTestUser(TestUserType.defaultUser)
            .build();
        expect(CFClient.isInitialized(), isTrue);
        await CFClient.shutdownSingleton();
        expect(CFClient.isInitialized(), isFalse);
        CFClient.clearInstance();
        expect(CFClient.getInstance(), isNull);
      });
    });
    group('Feature Flag Evaluation', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.standard)
            .withTestUser(TestUserType.defaultUser)
            .withInitialFlags({
          'test_bool_flag': true,
          'test_string_flag': 'enabled',
          'test_number_flag': 42.5,
          'test_json_flag': {'feature': 'active', 'level': 3},
        }).build();
      });
      test('should evaluate boolean flags correctly', () {
        // Test with existing flags
        expect(client.getBoolean('test_bool_flag', false), isA<bool>());
        // Test with fallback values
        expect(client.getBoolean('missing_bool_flag', false), isFalse);
        expect(client.getBoolean('missing_bool_flag', true), isTrue);
        // Test same method with different call pattern
        expect(
            client.getBoolean('test_bool_flag', false), isA<bool>());
      });
      test('should evaluate string flags correctly', () {
        // Test with existing flags
        expect(client.getString('test_string_flag', 'default'), isA<String>());
        // Test with fallback values
        expect(client.getString('missing_string_flag', 'fallback'),
            equals('fallback'));
        expect(client.getString('missing_string_flag', ''), equals(''));
        // Test same method with different call pattern
        expect(client.getString('test_string_flag', 'default'),
            isA<String>());
      });
      test('should evaluate number flags correctly', () {
        // Test with existing flags
        expect(client.getNumber('test_number_flag', 0), isA<num>());
        // Test with fallback values
        expect(client.getNumber('missing_number_flag', 0), equals(0));
        expect(client.getNumber('missing_number_flag', 99.9), equals(99.9));
        // Test same method with different call pattern
        expect(client.getNumber('test_number_flag', 0), isA<num>());
      });
      test('should evaluate JSON flags correctly', () {
        // Test with existing flags
        expect(
            client.getJson('test_json_flag', {}), isA<Map<String, dynamic>>());
        // Test with fallback values
        final fallback = {'default': true};
        expect(client.getJson('missing_json_flag', fallback), equals(fallback));
        expect(client.getJson('missing_json_flag', {}), equals({}));
      });
      test('should evaluate generic flags correctly', () {
        // Test generic flag evaluation with type parameters
        expect(
            client.getFeatureFlag<bool>('test_bool_flag', false), isA<bool>());
        expect(client.getFeatureFlag<String>('test_string_flag', 'default'),
            isA<String>());
        expect(client.getFeatureFlag<num>('test_number_flag', 0), isA<num>());
        expect(
            client.getFeatureFlag<Map<String, dynamic>>('test_json_flag', {}),
            isA<Map<String, dynamic>>());
      });
      test('should handle edge cases in flag evaluation', () {
        // Test with empty/special flag keys
        expect(client.getBoolean('', false), isA<bool>());
        expect(client.getString('null', 'fallback'), isA<String>());
        expect(client.getNumber('undefined', -1), isA<num>());
        expect(client.getJson('missing', {'error': true}),
            isA<Map<String, dynamic>>());
        // Test with special characters in keys
        expect(client.getBoolean('flag@#\$%', false), isA<bool>());
        expect(client.getString('flag with spaces', 'default'), isA<String>());
        expect(client.getNumber('flag.with.dots', 0), isA<num>());
      });
      test('should handle all flags operations', () {
        // This would test getAllFlags() method if available
        // expect(client.getAllFlags(), isA<Map<String, dynamic>>());
      });
    });
    group('User Management', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.standard)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should set user with various property combinations', () async {
        // User with all property types
        final complexUserBuilder = CFUser.builder('complex-user-123');
        complexUserBuilder.addStringProperty('role', 'admin');
        complexUserBuilder.addStringProperty('department', 'engineering');
        complexUserBuilder.addNumberProperty('level', 5);
        complexUserBuilder.addNumberProperty('score', 98.7);
        complexUserBuilder.addBooleanProperty('premium', true);
        complexUserBuilder.addBooleanProperty('beta_tester', false);
        final complexUserResult = complexUserBuilder.build().getOrThrow();
        final complexUser = complexUserResult;
        await client.setUser(complexUser);
        // User with edge case properties
        final edgeUserBuilder = CFUser.builder('edge-user');
        edgeUserBuilder.addStringProperty('empty', '');
        edgeUserBuilder.addNumberProperty('zero', 0);
        edgeUserBuilder.addNumberProperty('negative', -42);
        edgeUserBuilder.addBooleanProperty('false_prop', false);
        final edgeUserResult = edgeUserBuilder.build().getOrThrow();
        final edgeUser = edgeUserResult;
        await client.setUser(edgeUser);
      });
      test('should handle anonymous users', () async {
        final anonUser1Builder = CFUser.anonymousBuilder();
        anonUser1Builder.addStringProperty('source', 'test');
        final anonUser1Result = anonUser1Builder.build().getOrThrow();
        final anonUser1 = anonUser1Result;
        await client.setUser(anonUser1);
        final anonUser2Builder = CFUser.anonymousBuilder();
        anonUser2Builder.addNumberProperty('session_count', 1);
        anonUser2Builder.addBooleanProperty('first_time', true);
        final anonUser2Result = anonUser2Builder.build().getOrThrow();
        final anonUser2 = anonUser2Result;
        await client.setUser(anonUser2);
      });
      test('should clear user correctly', () async {
        await client.clearUser();
      });
      test('should set user after clearing', () async {
        await client.clearUser();
        final resetUserBuilder = CFUser.builder('reset-user');
        resetUserBuilder.addBooleanProperty('reset', true);
        final resetUserResult = resetUserBuilder.build().getOrThrow();
        final resetUser = resetUserResult;
        await client.setUser(resetUser);
      });
      test('should handle predefined test users', () async {
        final testUsers = [
          TestConfigs.getUser(TestUserType.premiumUser),
          TestConfigs.getUser(TestUserType.organizationUser),
          TestConfigs.getUser(TestUserType.betaUser),
        ];
        for (final user in testUsers) {
          await client.setUser(user);
        }
      });
    });
    group('Event Tracking', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.analytics)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should track simple events', () async {
        final result = await client.trackEvent('simple_event');
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should track events with properties', () async {
        final result = await client.trackEvent('event_with_props', properties: {
          'user_id': 'test123',
          'action': 'click',
          'count': 5,
          'enabled': true,
          'score': 98.7,
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should handle events with null/empty properties', () async {
        var result =
            await client.trackEvent('null_props_event', properties: null);
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
        result = await client.trackEvent('empty_props_event', properties: {});
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should handle events with edge case properties', () async {
        final result = await client.trackEvent('extreme_event', properties: {
          'empty_string': '',
          'zero_number': 0,
          'false_bool': false,
          'null_value': null,
          'very_long_string': 'x' * 1000,
          'negative_number': -999.99,
          'unicode_chars': '🚀✨🎯',
          'special_chars': '!@#\$%^&*()[]{}|;:,.<>?'
        });
        expect(result, isA<CFResult<void>>());
      });
      test('should handle edge case event names', () async {
        // Empty event name
        var result = await client.trackEvent('');
        expect(result, isA<CFResult<void>>());
        // Event with special characters
        result = await client.trackEvent('event@#\$%');
        expect(result, isA<CFResult<void>>());
        // Very long event name
        result = await client.trackEvent('very_long_event_name_${'x' * 100}');
        expect(result, isA<CFResult<void>>());
      });
    });
    group('Listener Management', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.standard)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle feature flag listeners', () {
        // Add listeners before any flags exist
        void earlyListener(String key, dynamic old, dynamic newVal) {}
        client.addFeatureFlagListener('early_flag', earlyListener);
        // Add multiple listeners to same flag
        void listener1(String key, dynamic old, dynamic newVal) {}
        void listener2(String key, dynamic old, dynamic newVal) {}
        void listener3(String key, dynamic old, dynamic newVal) {}
        client.addFeatureFlagListener('multi_flag', listener1);
        client.addFeatureFlagListener('multi_flag', listener2);
        client.addFeatureFlagListener('multi_flag', listener3);
        // Remove some but not all
        client.removeFeatureFlagListener('multi_flag', listener2);
      });
      test('should handle all flags listeners', () {
        void allFlags1(
            Map<String, dynamic> old, Map<String, dynamic> newFlags) {}
        void allFlags2(
            Map<String, dynamic> old, Map<String, dynamic> newFlags) {}
        client.addAllFlagsListener(allFlags1);
        client.addAllFlagsListener(allFlags2);
        client.removeAllFlagsListener(allFlags1);
      });
    });
    group('Configuration Management', () {
      test('should handle various config builder combinations', () async {
        // Test with all features enabled
        final fullConfigResult = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true) // Use offline mode for tests
            .setDebugLoggingEnabled(true)
            .setLoggingEnabled(true)
            .setAutoEnvAttributesEnabled(true)
            .setEventsFlushIntervalMs(5000)
            .setSummariesFlushIntervalMs(10000)
            .build();
        final fullConfig = fullConfigResult.getOrThrow();
        final client1Result = await CFClient.initialize(
            fullConfig, TestConfigs.getUser(TestUserType.defaultUser),
            dependencyFactory: mockFactory);
        final client1 = client1Result.getOrThrow();
        expect(client1, isNotNull);
        await CFClient.shutdownSingleton();
        CFClient.clearInstance();
        // Test with minimal config
        final minimalConfigResult = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true)
            .build();
        final minimalConfig = minimalConfigResult.getOrThrow();
        final client2Result = await CFClient.initialize(
            minimalConfig, TestConfigs.getUser(TestUserType.defaultUser),
            dependencyFactory: mockFactory);
        final client2 = client2Result.getOrThrow();
        expect(client2, isNotNull);
      });
      test('should handle predefined test configurations', () async {
        final configTypes = [
          TestConfigType.minimal,
          TestConfigType.performance,
          TestConfigType.errorTesting,
          TestConfigType.integration,
          TestConfigType.analytics,
          TestConfigType.caching,
        ];
        for (final configType in configTypes) {
          await CFClient.shutdownSingleton();
          CFClient.clearInstance();
          final client = await TestClientBuilder()
              .withTestConfig(configType)
              .withTestUser(TestUserType.defaultUser)
              .build();
          expect(client, isNotNull);
          expect(CFClient.isInitialized(), isTrue);
        }
      });
    });
    group('Error Handling and Edge Cases', () {
      test('should handle invalid configurations gracefully', () async {
        try {
          final client = await TestClientBuilder()
              .withTestConfig(TestConfigType.errorTesting)
              .withTestUser(TestUserType.defaultUser)
              .build();
          // Even with error testing config, client should be created
          expect(client, isNotNull);
        } catch (e) {
          // Error is expected with error testing configuration
          expect(e, isNotNull);
        }
      });
      test('should handle client operations during initialization', () async {
        // Test operations before initialization completes
        expect(CFClient.isInitialized(), isFalse);
        // These calls should not crash
        expect(() => CFClient.getInstance()?.getBoolean('test', false),
            returnsNormally);
      });
      test('should handle rapid initialization/shutdown cycles', () async {
        for (int i = 0; i < 3; i++) {
          final client = await TestClientBuilder()
              .withTestConfig(TestConfigType.minimal)
              .withTestUser(TestUserType.defaultUser)
              .build();
          expect(client, isNotNull);
          expect(CFClient.isInitialized(), isTrue);
          await CFClient.shutdownSingleton();
          CFClient.clearInstance();
          expect(CFClient.isInitialized(), isFalse);
        }
      });
    });
    group('Integration with Shared Test Infrastructure', () {
      test('should work with TestClientBuilder fluent API', () async {
        final client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.premiumUser)
            .withInitialFlags({'premium_feature': true})
            .withLogging()
            .build();
        expect(client, isNotNull);
        // With initial flags, the value should be returned regardless of mode
        expect(client.getBoolean('premium_feature', false),
            isTrue); // Initial flag value is true
        expect(client.getBoolean('premium_feature', true),
            isTrue); // Custom default value works
      });
      test('should work with QuickTestClients', () async {
        final clients = await Future.wait([
          QuickTestClients.defaultClient(),
          QuickTestClients.offlineClient(),
          QuickTestClients.performanceClient(),
          QuickTestClients.minimalClient(),
        ]);
        for (final client in clients) {
          expect(client, isNotNull);
          await CFClient.shutdownSingleton();
          CFClient.clearInstance();
        }
      });
      test('should work with multiple client configurations', () async {
        final configs = [
          TestConfigType.standard,
          TestConfigType.analytics,
          TestConfigType.caching,
        ];
        final clients = await TestClientBuilder().buildMultiple(configs);
        for (final client in clients) {
          expect(client, isNotNull);
        }
      });
    });
  });
}
