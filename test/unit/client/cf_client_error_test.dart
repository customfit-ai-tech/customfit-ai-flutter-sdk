// test/unit/client/cf_client_error_test.dart
//
// Tests for error paths and edge cases in CFClient to improve coverage
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import '../../test_config.dart';
import '../../shared/test_shared.dart';
import '../../helpers/test_storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CFClient Error Path Tests', () {
    setUp(() {
      TestConfig.setupTestLogger(); // Enable logger for coverage
      SharedPreferences.setMockInitialValues({});
      TestStorageHelper.setupTestStorage();
      PreferencesService.reset();
      CFClient.clearInstance();
    });

    tearDown(() async {
      if (CFClient.isInitialized()) {
        await CFClient.shutdownSingleton();
      }
      PreferencesService.reset();
      TestStorageHelper.clearTestStorage();
    });

    group('Configuration Validation Errors', () {
      test('should handle missing client key', () async {
        // Builder throws immediately for empty client key
        expect(
          () => CFConfig.builder('') // Empty client key
              .setOfflineMode(true)
              .build(),
          throwsA(isA<CFException>().having(
            (e) => e.error.message,
            'message',
            contains('Client key cannot be empty'),
          )),
        );
      });

      test('should handle missing user ID for non-anonymous user', () async {
        // Arrange
        TestConfigurations.standard();

        // CFUser.builder('') throws immediately due to validation
        expect(
          () => CFUser.builder('').build(),
          throwsA(
            allOf(
              isA<CFException>(),
              predicate((e) => e
                  .toString()
                  .contains('User ID cannot be empty for non-anonymous users')),
            ),
          ),
        );

        // Since we can't create a user with empty ID, we can't test CFClient.initialize with it
        // The validation happens at the CFUser level, not at the CFClient level
      });
    });

    group('Detached Instance Tests', () {
      test('should create detached instance and trigger warning log', () {
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        // This will trigger Logger.w() at line 316
        final detached = CFClient.createDetached(config, user);
        expect(detached, isNotNull);

        // Detached instance should not affect singleton
        expect(CFClient.isInitialized(), false);
      });
    });

    group('Singleton Instance Tests', () {
      test('should return existing instance when already initialized',
          () async {
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        // First initialization
        final result1 = await CFClient.initialize(config, user);
        expect(result1.isSuccess, isTrue);
        final instance1 = result1;

        // Second initialization attempt should return same instance
        // This will trigger Logger.i() at line 213
        final result2 = await CFClient.initialize(config, user);
        expect(result2.isSuccess, isTrue);
        final instance2 = result2;

        expect(identical(instance1, instance2), true);
        expect(CFClient.isInitialized(), true);
      });

      test('should handle concurrent initialization attempts', () async {
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        // Start multiple concurrent initializations
        // This will trigger Logger.i() at line 220
        final future1 = CFClient.initialize(config, user);
        final future2 = CFClient.initialize(config, user);
        final future3 = CFClient.initialize(config, user);

        final results = await Future.wait([future1, future2, future3]);

        // All should succeed and return the same instance
        expect(results[0].isSuccess, isTrue);
        expect(results[1].isSuccess, isTrue);
        expect(results[2].isSuccess, isTrue);

        final instance1 = results[0];
        final instance2 = results[1];
        final instance3 = results[2];

        expect(identical(instance1, instance2), true);
        expect(identical(instance2, instance3), true);
      });
    });

    group('Reinitialize Tests', () {
      test('should successfully reinitialize with new config', () async {
        final config1 = TestConfigurations.standard();
        final user1 = TestDataGenerator.generateUser();

        final result1 = await CFClient.initialize(config1, user1);
        expect(result1.isSuccess, isTrue);
        final instance1 = result1;
        expect(CFClient.isInitialized(), true);

        final config2 = TestConfigurations.standard();
        final user2 = TestDataGenerator.generateUser();

        // This will trigger Logger.i() at line 302
        final instance2 = await CFClient.reinitialize(config2, user2);
        expect(CFClient.isInitialized(), true);
        expect(identical(instance1, instance2), false);
      });
    });
  });
}
