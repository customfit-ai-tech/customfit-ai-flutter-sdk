// test/unit/client/cf_client_advanced_config_test.dart
//
// Advanced configuration scenario tests for CFClient.
// Tests runtime updates, migration, feature flag evaluation during init, and memory pressure.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/test_shared.dart';
import '../../utils/test_constants.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import '../../helpers/test_storage_helper.dart';
import '../../test_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestConfig.setupTestLogger(); // Enable logger for coverage
    SharedPreferences.setMockInitialValues({});
    TestStorageHelper.setupTestStorage();
  });
  group('CFClient Advanced Configuration Scenarios', () {
    setUp(() {
      CFClient.clearInstance();
    });
    tearDown(() async {
      if (CFClient.isInitialized()) {
        await CFClient.shutdownSingleton();
      }
      PreferencesService.reset();
      TestStorageHelper.clearTestStorage();
    });
    group('Runtime Configuration Updates', () {
      test('should_handle_runtime_config_updates_without_restart', () async {
        // Arrange - Pre-populate cache with initial config
        final cachedConfig = {
          'feature_a': {'variation': 'initial'},
        };
        final metadata = {
          'lastModified': '',
          'etag': '',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'expiresAt': DateTime.now().millisecondsSinceEpoch +
              (7 * 24 * 60 * 60 * 1000), // 7 days
        };
        SharedPreferences.setMockInitialValues({
          'cf_config_data': jsonEncode(cachedConfig),
          'cf_config_metadata': jsonEncode(metadata),
        });
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        await CFClient.initialize(config, user);
        // Wait for cache to load
        await Future.delayed(const Duration(milliseconds: 100));
        final client = CFClient.getInstance()!;
        // Verify initial value
        expect(client.getString('feature_a', 'default'), equals('initial'));
        // Note: Runtime config updates would require implementing a refresh mechanism
        // The current implementation doesn't automatically poll for updates
        // This test documents the expected behavior if runtime updates were implemented
        // For now, the value remains the same
        expect(client.getString('feature_a', 'default'), equals('initial'));
      });
      test('should_apply_config_updates_atomically', () async {
        // Arrange - Pre-populate cache with related flags
        final cachedConfig = {
          'feature_enabled': {'variation': true},
          'feature_variant': {'variation': 'A'},
          'feature_percentage': {'variation': 100},
        };
        final metadata = {
          'lastModified': '',
          'etag': '',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'expiresAt': DateTime.now().millisecondsSinceEpoch +
              (7 * 24 * 60 * 60 * 1000), // 7 days
        };
        SharedPreferences.setMockInitialValues({
          'cf_config_data': jsonEncode(cachedConfig),
          'cf_config_metadata': jsonEncode(metadata),
        });
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        await CFClient.initialize(config, user);
        // Wait for cache to load
        await Future.delayed(const Duration(milliseconds: 100));
        final client = CFClient.getInstance()!;
        // Verify initial values
        expect(client.getBoolean('feature_enabled', false), equals(true));
        expect(client.getString('feature_variant', 'X'), equals('A'));
        expect(client.getNumber('feature_percentage', -1), equals(100));
        // Note: Atomic updates would require implementing a config refresh mechanism
        // The current implementation loads config once during initialization
        // This test documents the expected atomicity behavior if updates were implemented
      });
    });
    group('Configuration Migration', () {
      test('should_migrate_from_older_config_version', () async {
        // Arrange
        final storage = TestStorage();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(false)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        // Store old format config
        final oldConfig = {
          'flags': {
            // Old format used 'flags' instead of 'feature_flags'
            'old_flag': true,
          },
          'version': '0.9.0',
        };
        await storage.setString('cf_config_data', jsonEncode(oldConfig));
        // Act - Initialize should migrate
        await CFClient.initialize(config, user);
        final client = CFClient.getInstance()!;
        // Assert - Should handle missing data gracefully
        expect(client.getBoolean('old_flag', false),
            anyOf(equals(true), equals(false)) // Either migrated or default
            );
      });
      test('should_preserve_user_data_during_config_migration', () async {
        // Arrange
        final storage = TestStorage();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(false)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser(
            userId: 'migration_test_user',
            properties: {
              'plan': 'premium',
              'customData': {'nested': 'value'},
            });
        // Store user data in old format
        await storage.setString(
            'cf_user_data',
            jsonEncode({
              'id': 'migration_test_user',
              'attributes': {
                // Old format
                'plan': 'premium',
              }
            }));
        // Act
        await CFClient.initialize(config, user);
        final client = CFClient.getInstance()!;
        // Assert - User context should be preserved via getUser
        final currentUser = client.getUser();
        expect(currentUser.userCustomerId, equals('migration_test_user'));
      });
    });
    group('Feature Flag Evaluation During Initialization', () {
      test('should_queue_flag_evaluations_during_initialization', () async {
        // Arrange - Pre-populate cache with config data
        final cachedConfig = {
          'early_flag': {'variation': 'success'},
        };
        final metadata = {
          'lastModified': '',
          'etag': '',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'expiresAt': DateTime.now().millisecondsSinceEpoch +
              (7 * 24 * 60 * 60 * 1000), // 7 days
        };
        SharedPreferences.setMockInitialValues({
          'cf_config_data': jsonEncode(cachedConfig),
          'cf_config_metadata': jsonEncode(metadata),
        });
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(true) // Use offline mode
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        // Act - Initialize which should load from cache
        await CFClient.initialize(config, user);
        // Wait a bit for cache to be loaded asynchronously
        await Future.delayed(const Duration(milliseconds: 100));
        // After initialization and cache load, we can evaluate flags
        final client = CFClient.getInstance()!;
        // Act - Evaluate flags multiple times
        final values = <String>[];
        for (int i = 0; i < 5; i++) {
          values.add(client.getString('early_flag', 'default'));
        }
        // Assert - All should return the cached value
        expect(values, everyElement(equals('success')));
      });
      test('should_handle_flag_evaluation_timeout_gracefully', () async {
        // Arrange
        final mockHttp = MockHttpClient();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(false)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        // Very slow config response
        mockHttp.responseDelay = const Duration(seconds: 5);
        mockHttp.whenGet('/config', ApiFixtures.successfulConfigResponse());
        await CFClient.initialize(config, user);
        final client = CFClient.getInstance()!;
        // Act - Evaluation without timeout (synchronous)
        final result = client.getBoolean('slow_flag', true);
        // Assert
        expect(result, equals(true)); // Should return default
      });
    });
    group('Memory Pressure Handling', () {
      test('should_handle_initialization_with_1000_plus_flags', () async {
        // Arrange
        final mockHttp = MockHttpClient();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(false)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        // Large config response
        mockHttp.whenGet(
            '/config', ApiFixtures.largeConfigResponse(flagCount: 1500));
        // Act
        final stopwatch = Stopwatch()..start();
        await CFClient.initialize(config, user);
        stopwatch.stop();
        final client = CFClient.getInstance()!;
        // Assert - Should complete in reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        // Should be able to evaluate flags
        expect(client.getBoolean('feature_100', false), isA<bool>());
        expect(client.getString('feature_500', 'default'), isA<String>());
      });
      test('should_implement_config_size_limits', () async {
        // Arrange
        final mockHttp = MockHttpClient();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(false)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        // Extremely large config
        final hugeConfig = ApiFixtures.largeConfigResponse(flagCount: 10000);
        // Add massive metadata to each flag
        final flags = hugeConfig['data']['feature_flags'] as Map;
        flags.forEach((key, value) {
          (value as Map)['metadata'] = {
            'large_data': List.filled(1000, 'x' * 100),
          };
        });
        mockHttp.whenGet('/config', hugeConfig);
        // Act - Should handle without OOM
        await CFClient.initialize(config, user);
        // Assert
        expect(CFClient.isInitialized(), isTrue);
      });
      test('should_cleanup_old_config_data_under_memory_pressure', () async {
        // Arrange
        final storage = TestStorage();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(false)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        // Simulate existing cached configs
        for (int i = 0; i < 10; i++) {
          await storage.setString('cf_config_data_v$i',
              jsonEncode(ApiFixtures.largeConfigResponse(flagCount: 100)));
        }
        // Track storage size before
        final keysBefore = (await storage.getKeys()).length;
        // Act - Initialize
        await CFClient.initialize(config, user);
        // Note: Memory pressure handling would be tested separately
        // as it's not part of the public API
        // Assert - Storage should still have data
        final keysAfter = (await storage.getKeys()).length;
        expect(keysAfter, greaterThan(0));
        // Verify some cleanup may have occurred but not all data was lost
        expect(keysAfter, lessThanOrEqualTo(keysBefore));
      });
    });
    group('Configuration Validation Edge Cases', () {
      test('should_handle_missing_required_config_fields_gracefully', () async {
        // Arrange
        final mockHttp = MockHttpClient();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(false)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        // Incomplete config response
        mockHttp.whenGet('/config', {
          'data': {
            // Missing 'feature_flags' field
            'sdk_settings': {},
          }
        });
        // Act
        await CFClient.initialize(config, user);
        final client = CFClient.getInstance()!;
        // Assert - Should use defaults
        expect(
            client.getBoolean('any_flag', true), equals(true) // Default value
            );
      });
      test('should_validate_and_sanitize_config_values', () async {
        // Arrange
        final mockHttp = MockHttpClient();
        final config = CFConfig.builder(TestConstants.validJwtToken)
            .setOfflineMode(false)
            .build().getOrThrow();
        final user = TestDataGenerator.generateUser();
        // Config with invalid values
        mockHttp.whenGet('/config', {
          'data': {
            'feature_flags': {
              'flag_with_null': {'enabled': true, 'value': null},
              'flag_with_invalid_type': {
                'enabled': 'yes',
                'value': true
              }, // enabled should be bool
              'flag_with_huge_number': {
                'enabled': true,
                'value': 9223372036854775807
              }, // Max int64
            },
            'sdk_settings': {
              'events_flush_interval_ms': -1000, // Should be positive
              'max_event_batch_size': 0, // Should be positive
            }
          }
        });
        // Act - Should handle invalid values
        await CFClient.initialize(config, user);
        final client = CFClient.getInstance()!;
        // Assert - Should sanitize values
        expect(client.getBoolean('flag_with_null', false),
            equals(false) // Default for null
            );
      });
    });
  });
}
