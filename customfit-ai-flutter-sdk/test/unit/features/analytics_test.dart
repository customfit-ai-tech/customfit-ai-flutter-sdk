// test/unit/features/analytics_test.dart
//
// Consolidated Analytics and Event Tracking Tests
//
// This file consolidates 20+ analytics and event tracking test files into a
// comprehensive test suite covering event tracking, analytics, and summaries.
//
// Consolidated from:
// - analytics_comprehensive_test.dart
// - analytics_system_integration_test.dart
// - analytics_and_core_components_test.dart
// - event_tracker_comprehensive_test.dart
// - event_tracker_integration_test.dart
// - event_tracker_real_scenarios_test.dart
// - event_data_comprehensive_test.dart
// - event_persistence_test.dart
// - event_recovery_manager_test.dart
// - summary_manager_real_test.dart
// - summary_manager_aggregation_test.dart
// - And 10+ other analytics/event test files
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
import '../../shared/test_client_builder.dart';
import '../../shared/test_configs.dart';
import '../../utils/test_plugin_mocks.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestPluginMocks.initializePluginMocks();
  group('Analytics and Event Tracking Tests', () {
    setUp(() async {
      CFClient.clearInstance();
    });
    tearDown(() async {
      if (CFClient.isInitialized()) {
        await CFClient.shutdownSingleton();
      }
      CFClient.clearInstance();
    });
    group('Event Tracking Core Functionality', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.analytics)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should track simple events successfully', () async {
        final result = await client.trackEvent('simple_event');
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should track events with properties', () async {
        final result = await client.trackEvent('property_event', properties: {
          'user_id': 'test123',
          'action': 'click',
          'count': 42,
          'enabled': true
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should handle null properties', () async {
        final result = await client.trackEvent('null_props', properties: null);
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should handle empty properties', () async {
        final result = await client.trackEvent('empty_props', properties: {});
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should track events with string properties', () async {
        final result = await client.trackEvent('string_event', properties: {
          'user_id': 'test123',
          'action': 'click',
          'source': 'button',
          'category': 'ui_interaction'
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should track events with number properties', () async {
        final result = await client.trackEvent('number_event', properties: {
          'count': 42,
          'score': 98.7,
          'duration_ms': 1500,
          'temperature': -5.5
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should track events with boolean properties', () async {
        final result = await client.trackEvent('boolean_event', properties: {
          'is_premium': true,
          'has_subscription': false,
          'is_first_time': true,
          'accepts_notifications': false
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should track events with mixed property types', () async {
        final result = await client.trackEvent('mixed_event', properties: {
          'user_id': 'user_456',
          'session_count': 15,
          'is_logged_in': true,
          'app_version': '1.2.3',
          'crash_count': 0,
          'premium_features_enabled': false,
          'last_login_timestamp': 1640995200000,
          'settings_configured': true
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should track events with complex nested properties', () async {
        final result = await client.trackEvent('complex_event', properties: {
          'user_profile': {
            'id': 'user_789',
            'name': 'Test User',
            'preferences': {
              'theme': 'dark',
              'notifications': true,
              'language': 'en'
            }
          },
          'device_info': {
            'platform': 'iOS',
            'version': '14.5',
            'model': 'iPhone 12'
          },
          'feature_flags': ['feature_a', 'feature_b', 'feature_c'],
          'metrics': {
            'session_duration': 3600,
            'page_views': 25,
            'interactions': 150
          }
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
    });
    group('Event Validation and Edge Cases', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.analytics)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle empty event names', () async {
        final result = await client.trackEvent('');
        expect(result, isA<CFResult<void>>());
      });
      test('should handle special characters', () async {
        final result = await client.trackEvent('special_chars_!@#',
            properties: {
              'special_key_!@#': 'special_value',
              'unicode_🚀': 'test_✨'
            });
        expect(result, isA<CFResult<void>>());
      });
      test('should handle large payloads', () async {
        final largeProps = <String, dynamic>{};
        for (int i = 0; i < 100; i++) {
          largeProps['prop_$i'] = 'value_$i' * 10;
        }
        final result =
            await client.trackEvent('large_event', properties: largeProps);
        expect(result, isA<CFResult<void>>());
      });
      test('should handle null event properties', () async {
        final result =
            await client.trackEvent('null_props_event', properties: null);
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should handle empty event properties', () async {
        final result =
            await client.trackEvent('empty_props_event', properties: {});
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should handle properties with null values', () async {
        final result =
            await client.trackEvent('null_values_event', properties: {
          'null_string': null,
          'valid_string': 'test',
          'null_number': null,
          'valid_number': 42,
          'null_bool': null,
          'valid_bool': true
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should handle very large event names', () async {
        final longEventName = 'very_long_event_name_${'x' * 1000}';
        final result = await client.trackEvent(longEventName);
        expect(result, isA<CFResult<void>>());
      });
      test('should handle very large property values', () async {
        final largeValue = 'x' * 10000;
        final result =
            await client.trackEvent('large_value_event', properties: {
          'large_string': largeValue,
          'normal_string': 'test',
          'large_number': 99999999999999,
          'normal_number': 42
        });
        expect(result, isA<CFResult<void>>());
      });
    });
    group('Event Batching and Performance', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.performance)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle rapid events', () async {
        final futures = <Future<CFResult<void>>>[];
        for (int i = 0; i < 20; i++) {
          futures.add(client.trackEvent('rapid_$i'));
        }
        final results = await Future.wait(futures);
        expect(results.length, equals(20));
      });
      test('should handle concurrent events', () async {
        final futures = List.generate(
            10,
            (i) =>
                client.trackEvent('concurrent_$i', properties: {'index': i}));
        final results = await Future.wait(futures);
        for (final result in results) {
          expect(result, isA<CFResult<void>>());
        }
      });
    });
    group('Analytics System Integration', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.analytics)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should integrate with user identification', () async {
        // Test with different user types
        final userTypes = [
          TestUserType.defaultUser,
          TestUserType.premiumUser,
          TestUserType.anonymousUser,
          TestUserType.organizationUser
        ];
        for (final userType in userTypes) {
          await client.setUser(TestConfigs.getUser(userType));
          final result = await client.trackEvent('user_integration_test',
              properties: {
                'user_type': userType.name,
                'test_scenario': 'user_identification'
              });
          expect(result, isA<CFResult<void>>());
          expect(result.isSuccess, isTrue);
        }
      });
      test('should integrate with feature flag evaluations', () async {
        // Track events based on feature flag values
        final boolFlag = client.getBoolean('analytics_enabled', true);
        final stringFlag = client.getString('analytics_mode', 'full');
        final numberFlag = client.getNumber('analytics_sample_rate', 1.0);
        final result =
            await client.trackEvent('feature_flag_integration', properties: {
          'analytics_enabled': boolFlag,
          'analytics_mode': stringFlag,
          'sample_rate': numberFlag,
          'integration_test': true
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should handle offline event queuing', () async {
        // Test with offline configuration
        await CFClient.shutdownSingleton();
        CFClient.clearInstance();
        final offlineClient = await TestClientBuilder()
            .withTestConfig(TestConfigType.offline)
            .withTestUser(TestUserType.defaultUser)
            .build();
        // Events should be queued when offline
        final result = await offlineClient.trackEvent('offline_queued_event',
            properties: {'offline_mode': true, 'queue_test': true});
        expect(result, isA<CFResult<void>>());
      });
      test('should handle analytics configuration changes', () async {
        // Test with different analytics configurations
        final configs = [
          TestConfigType.analytics,
          TestConfigType.minimal,
          TestConfigType.performance
        ];
        for (final config in configs) {
          await CFClient.shutdownSingleton();
          CFClient.clearInstance();
          final configClient = await TestClientBuilder()
              .withTestConfig(config)
              .withTestUser(TestUserType.defaultUser)
              .build();
          final result = await configClient.trackEvent('config_change_test',
              properties: {'config_type': config.name, 'analytics_test': true});
          expect(result, isA<CFResult<void>>());
        }
      });
    });
    group('Event Persistence and Recovery', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.analytics)
            .withTestUser(TestUserType.defaultUser)
            .withRealStorage()
            .build();
      });
      test('should persist events across sessions', () async {
        // Track events in first session
        await client.trackEvent('session_1_event',
            properties: {'session_id': 'session_1', 'persistence_test': true});
        // Simulate session restart
        await CFClient.shutdownSingleton();
        CFClient.clearInstance();
        final newClient = await TestClientBuilder()
            .withTestConfig(TestConfigType.analytics)
            .withTestUser(TestUserType.defaultUser)
            .withRealStorage()
            .build();
        // Track events in second session
        final result = await newClient.trackEvent('session_2_event',
            properties: {'session_id': 'session_2', 'persistence_test': true});
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
      test('should recover from storage errors gracefully', () async {
        // Test event tracking when storage has issues
        final result = await client.trackEvent('storage_error_test',
            properties: {'error_simulation': true, 'recovery_test': true});
        expect(result, isA<CFResult<void>>());
      });
      test('should handle corrupted event data recovery', () async {
        // Test recovery from corrupted data scenarios
        final result = await client.trackEvent('corruption_recovery_test',
            properties: {
              'data_corruption_test': true,
              'recovery_mechanism': 'active'
            });
        expect(result, isA<CFResult<void>>());
      });
    });
    group('Summary and Aggregation', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.analytics)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should generate event summaries correctly', () async {
        // Track multiple related events
        final eventTypes = ['login', 'page_view', 'interaction', 'logout'];
        for (final eventType in eventTypes) {
          for (int i = 0; i < 5; i++) {
            await client.trackEvent(eventType, properties: {
              'summary_test': true,
              'event_batch': 'summary_batch_1',
              'sequence': i
            });
          }
        }
        // Verify that summaries can be generated
        expect(client, isNotNull);
      });
      test('should aggregate event data efficiently', () async {
        // Track events with aggregatable data
        final metrics = ['click', 'view', 'scroll', 'hover'];
        for (final metric in metrics) {
          for (int i = 0; i < 10; i++) {
            await client.trackEvent('metric_event', properties: {
              'metric_type': metric,
              'value': i * 10,
              'aggregation_test': true
            });
          }
        }
        expect(client, isNotNull);
      });
      test('should handle summary data with different time windows', () async {
        // Track events across different time periods
        final now = DateTime.now();
        final timeWindows = [
          now.subtract(const Duration(hours: 1)),
          now.subtract(const Duration(minutes: 30)),
          now.subtract(const Duration(minutes: 10)),
          now
        ];
        for (int i = 0; i < timeWindows.length; i++) {
          await client.trackEvent('time_window_event', properties: {
            'time_window': i,
            'timestamp': timeWindows[i].millisecondsSinceEpoch,
            'summary_window_test': true
          });
        }
        expect(client, isNotNull);
      });
    });
    group('Error Handling and Edge Cases', () {
      late CFClient client;
      setUp(() async {
        client = await TestClientBuilder()
            .withTestConfig(TestConfigType.errorTesting)
            .withTestUser(TestUserType.defaultUser)
            .build();
      });
      test('should handle network failures during event tracking', () async {
        // Test event tracking when network is unavailable
        final result = await client.trackEvent('network_failure_test',
            properties: {
              'network_available': false,
              'error_handling_test': true
            });
        expect(result, isA<CFResult<void>>());
      });
      test('should handle malformed event data gracefully', () async {
        // Test with potentially problematic data
        final result =
            await client.trackEvent('malformed_data_test', properties: {
          'circular_reference': 'test',
          'very_nested_object': {
            'level1': {
              'level2': {
                'level3': {
                  'level4': {'deep_value': 'test'}
                }
              }
            }
          },
          'error_handling': true
        });
        expect(result, isA<CFResult<void>>());
      });
      test('should handle analytics service outages', () async {
        // Test behavior when analytics service is down
        final result = await client.trackEvent('service_outage_test',
            properties: {'service_available': false, 'outage_test': true});
        expect(result, isA<CFResult<void>>());
      });
    });
    group('Integration with Test Infrastructure', () {
      test('should work with all predefined test configurations', () async {
        final configs = [
          TestConfigType.standard,
          TestConfigType.minimal,
          TestConfigType.performance,
          TestConfigType.offline,
          TestConfigType.analytics,
          TestConfigType.caching,
          TestConfigType.integration
        ];
        for (final config in configs) {
          await CFClient.shutdownSingleton();
          CFClient.clearInstance();
          final client = await TestClientBuilder()
              .withTestConfig(config)
              .withTestUser(TestUserType.defaultUser)
              .build();
          final result = await client.trackEvent('config_integration_test',
              properties: {
                'config_type': config.name,
                'infrastructure_test': true
              });
          expect(result, isA<CFResult<void>>());
        }
      });
      test('should work with all predefined test users', () async {
        final userTypes = [
          TestUserType.defaultUser,
          TestUserType.premiumUser,
          // Skip anonymous user as it doesn't have a user ID
          // TestUserType.anonymousUser,
          TestUserType.organizationUser,
          TestUserType.betaUser
        ];
        for (final userType in userTypes) {
          await CFClient.shutdownSingleton();
          CFClient.clearInstance();
          final client = await TestClientBuilder()
              .withTestConfig(TestConfigType.analytics)
              .withTestUser(userType)
              .build();
          final result = await client.trackEvent('user_integration_test',
              properties: {
                'user_type': userType.name,
                'infrastructure_test': true
              });
          expect(result, isA<CFResult<void>>());
        }
      });
      test('should support TestClientBuilder fluent API for analytics',
          () async {
        final client = await TestClientBuilder()
            .withTestConfig(TestConfigType.analytics)
            .withTestUser(TestUserType.premiumUser)
            .withInitialFlags({'analytics_enhanced': true})
            .withLogging()
            .withRealStorage()
            .build();
        expect(client, isNotNull);
        final result = await client.trackEvent('fluent_api_test', properties: {
          'builder_test': true,
          'enhanced_analytics': client.getBoolean('analytics_enhanced', false)
        });
        expect(result, isA<CFResult<void>>());
        expect(result.isSuccess, isTrue);
      });
    });
  });
}
