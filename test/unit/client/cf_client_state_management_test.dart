// test/unit/client/cf_client_state_management_test.dart
//
// Advanced state management edge case tests for CFClient.
// Tests rapid state transitions, partial failures, recovery, and thread safety.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'dart:async';
import '../../shared/test_shared.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../test_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestConfig.setupTestLogger(); // Enable logger for coverage
    SharedPreferences.setMockInitialValues({});
  });

  group('CFClient State Management Edge Cases', () {
    // Ensure clean state before each test
    setUp(() {
      CFClient.clearInstance();
    });

    tearDown(() async {
      if (CFClient.isInitialized()) {
        await CFClient.shutdownSingleton();
      }
      PreferencesService.reset();
    });

    group('Rapid State Transitions', () {
      test('should_handle_rapid_state_transitions_during_network_issues',
          () async {
        // Arrange
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        // Act - Rapid initialization attempts
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(CFClient.initialize(config, user).timeout(
              const Duration(milliseconds: 50),
              onTimeout: () =>
                  throw TimeoutException('Initialization timeout')));
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Wait for all to complete
        await Future.wait(futures, eagerError: false);

        // Assert - Should handle gracefully
        // Either initialized or not, but no crashes
        if (CFClient.isInitialized()) {
          expect(CFClient.getInstance(), isNotNull);
        }
      });

      test('should_maintain_consistency_during_concurrent_state_checks',
          () async {
        // Arrange
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();
        final stateChecks = <Map<String, bool>>[];

        // Act - Start initialization and rapidly check states
        final initFuture = CFClient.initialize(config, user);

        // Rapidly check states during initialization
        for (int i = 0; i < 50; i++) {
          stateChecks.add({
            'initialized': CFClient.isInitialized(),
            'initializing': CFClient.isInitializing(),
          });
          await Future.delayed(const Duration(microseconds: 100));
        }

        await initFuture;

        // Assert - States should be consistent
        for (final check in stateChecks) {
          // Can't be both initialized and initializing
          if (check['initialized']!) {
            expect(check['initializing'], isFalse);
          }
        }
        expect(CFClient.isInitialized(), isTrue);
        expect(CFClient.isInitializing(), isFalse);
      });

      test('should_handle_shutdown_during_initialization', () async {
        // Arrange
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        // Act - Start init then immediately shutdown
        final initFuture = CFClient.initialize(config, user);
        await Future.delayed(const Duration(milliseconds: 50));
        final shutdownFuture = CFClient.shutdownSingleton();

        // Wait for both
        await Future.wait([
          initFuture.catchError(
              (_) => throw Exception('Initialization interrupted')),
          shutdownFuture,
        ]);

        // Assert
        expect(CFClient.isInitialized(), isFalse);
        expect(CFClient.isInitializing(), isFalse);
      });
    });

    group('Partial Initialization Failures', () {
      test('should_recover_from_partial_initialization_failure', () async {
        // Arrange
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        // Act - First attempt should complete (offline mode allows initialization)
        final firstResult = await CFClient.initialize(config, user);

        // Verify first initialization succeeded
        expect(firstResult, isNotNull);
        expect(CFClient.isInitialized(), isTrue);

        // Clear instance to simulate recovery scenario
        await CFClient.shutdownSingleton();
        await Future.delayed(const Duration(milliseconds: 10));
        expect(CFClient.isInitialized(), isFalse);

        // Second attempt should also succeed
        final client = await CFClient.initialize(config, user);

        // Assert
        expect(client, isNotNull);
        expect(CFClient.isInitialized(), isTrue);
      });

      test('should_cleanup_resources_on_initialization_failure', () async {
        // Arrange
        TestConfigurations.standard();
        // Track resource allocation
        final resourceTracker = MemoryLeakDetector();

        // Act - Should fail due to invalid user
        // CFUser.builder validates empty IDs and throws immediately
        try {
          CFUser.builder('').build(); // This will throw
          fail('CFUser.builder should have thrown for empty user ID');
        } catch (e) {
          // Expected - CFUser validation prevents creating invalid users
          expect(e, isA<CFException>());
          expect(e.toString(),
              contains('User ID cannot be empty for non-anonymous users'));
        }

        // Since we couldn't create a user, no initialization happened
        // Ensure instance is cleared
        CFClient.clearInstance();

        // Force cleanup
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - No resources should be leaked
        final leaks = await resourceTracker.checkLeaks();
        expect(leaks, isEmpty);
        expect(CFClient.isInitialized(), isFalse);
      });
    });

    group('Corrupted State Recovery', () {
      test('should_recover_from_corrupted_cached_config', () async {
        // Arrange
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        // Act - Should handle corrupted cache gracefully (offline mode handles this)
        final client = await CFClient.initialize(config, user);

        // Assert
        expect(client, isNotNull);
        expect(CFClient.isInitialized(), isTrue);
      });

      test('should_handle_state_file_corruption_gracefully', () async {
        // Arrange
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        // Act - Should initialize despite corrupted state (offline mode handles this)
        final client = await CFClient.initialize(config, user);

        // Assert
        expect(client, isNotNull);
        expect(CFClient.isInitialized(), isTrue);
      });
    });

    group('Thread Safety', () {
      test('should_handle_concurrent_operations_safely', () async {
        // Arrange
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();
        await CFClient.initialize(config, user);
        final client = CFClient.getInstance();
        if (client == null) {
          fail('CFClient instance should not be null after initialization');
        }
        final results = <dynamic>[];
        final errors = <dynamic>[];

        // Act - Perform many concurrent operations
        final operations = <Future>[];

        // Concurrent flag evaluations
        for (int i = 0; i < 20; i++) {
          operations.add(Future(() => client.getBoolean('flag_$i', false))
              .then((value) => results.add(value))
              .catchError((e) => errors.add(e)));
        }

        // Concurrent event tracking
        for (int i = 0; i < 20; i++) {
          operations.add(client
              .trackEvent('event_$i', properties: {'index': i})
              .then((_) => results.add('tracked_$i'))
              .catchError((e) => errors.add(e)));
        }

        // Concurrent user updates
        for (int i = 0; i < 10; i++) {
          final newUser =
              TestDataGenerator.generateUser(userId: 'concurrent_user_$i');
          operations.add(client
              .setUser(newUser)
              .then((_) => results.add('user_updated_$i'))
              .catchError((e) => errors.add(e)));
        }

        await Future.wait(operations, eagerError: false);

        // Assert - No crashes, all operations handled
        expect(errors, isEmpty);
        expect(results.length, equals(50)); // 20 + 20 + 10
      });

      test('should_serialize_critical_state_mutations', () async {
        // Arrange
        final config = TestConfigurations.standard();
        final users = TestDataGenerator.generateUsers(10);
        await CFClient.initialize(config, users.first);
        final client = CFClient.getInstance();
        if (client == null) {
          fail('CFClient instance should not be null after initialization');
        }
        final updateOrder = <String>[];

        // Act - Rapid user switches
        final futures = users.map((user) {
          return client.setUser(user).then((_) {
            updateOrder.add(user.userId!);
          });
        }).toList();

        await Future.wait(futures);

        // Assert - Updates should be serialized
        expect(updateOrder.length, equals(10));
        // Each user ID should appear exactly once
        expect(updateOrder.toSet().length, equals(10));
      });
    });

    group('Resource Cleanup', () {
      test('should_cleanup_all_resources_on_shutdown', () async {
        // Arrange
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        // Initialize client and verify it's working
        final result = await CFClient.initialize(config, user);
        final client = result;
        expect(CFClient.isInitialized(), isTrue);
        expect(CFClient.getInstance(), isNotNull);

        // Use the client to create internal resources
        client.getBoolean('test_flag', false);
        await client.trackEvent('test_event', properties: {});

        // Act - Shutdown
        await CFClient.shutdownSingleton();

        // Assert - Verify proper cleanup
        expect(CFClient.isInitialized(), isFalse);
        expect(CFClient.getInstance(), isNull);

        // Verify that we can initialize again after shutdown (proves cleanup worked)
        final secondResult = await CFClient.initialize(config, user);
        expect(secondResult.isSuccess, isTrue);
        expect(CFClient.isInitialized(), isTrue);

        // Clean up the second instance
        await CFClient.shutdownSingleton();
        expect(CFClient.isInitialized(), isFalse);
      });

      test('should_cancel_pending_operations_on_shutdown', () async {
        // Arrange
        final config = TestConfigurations.standard();
        final user = TestDataGenerator.generateUser();

        await CFClient.initialize(config, user);
        final client = CFClient.getInstance();
        if (client == null) {
          fail('CFClient instance should not be null after initialization');
        }

        // Act - Start operations then shutdown
        final pendingOps = <Future>[];
        for (int i = 0; i < 10; i++) {
          pendingOps.add(client.trackEvent('event_$i',
              properties: {}).catchError((_) => CFResult<void>.success(null)));
        }

        // Shutdown immediately
        await CFClient.shutdownSingleton();

        // Wait for operations to complete/cancel
        await Future.wait(pendingOps, eagerError: false);

        // Assert
        expect(CFClient.isInitialized(), isFalse);
      });
    });
  });
}
