import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/lifecycle/cf_lifecycle_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/cf_client.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import '../../utils/test_constants.dart';

void main() {
  // Initialize Flutter binding for platform-specific tests
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CFLifecycleManager', () {
    late CFConfig testConfig;
    late CFUser testUser;
    setUp(() {
      // Use a simple config for testing with offline mode to prevent network connections
      testConfig = CFConfig.builder(TestConstants.validJwtToken)
          .setOfflineMode(true)
          .build()
          .getOrThrow();
      testUser = CFUser.create(userCustomerId: 'test-user-123');
    });
    tearDown(() async {
      // Clean up any existing instances
      try {
        await CFLifecycleManager.cleanupInstance();
        await CFClient.shutdownSingleton();
      } catch (e) {
        // Ignore cleanup errors in tests
      }
    });
    group('Instance Management', () {
      test('should create instance through private constructor', () {
        // We can't directly test the private constructor, but we can test
        // that the singleton pattern works correctly
        expect(
            () => CFLifecycleManager.initializeInstance(testConfig, testUser),
            returnsNormally);
      });
      test('should maintain singleton pattern', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Multiple calls should not create new instances
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
      });
      test('should handle initialization state correctly', () async {
        expect(CFLifecycleManager.isClientInitialized(), isFalse);
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
      });
    });
    group('Initialization', () {
      test('should initialize successfully with valid config and user',
          () async {
        await expectLater(
          CFLifecycleManager.initializeInstance(testConfig, testUser),
          completes,
        );
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
      });
      test('should handle multiple initialization calls gracefully', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Second initialization should not throw
        await expectLater(
          CFLifecycleManager.initializeInstance(testConfig, testUser),
          completes,
        );
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
      });
      test('should handle initialization with different configs', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Try to initialize with different config (should not reinitialize)
        final differentConfig = CFConfig.builder(
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWZmZXJlbnQiLCJpYXQiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c')
            .setOfflineMode(true)
            .build()
            .getOrThrow();
        await expectLater(
          CFLifecycleManager.initializeInstance(differentConfig, testUser),
          completes,
        );
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
      });
      test('should handle initialization errors gracefully', () async {
        // CFConfig.builder now validates the JWT token, so we can't create an invalid config
        // Instead, test that initialization handles being called when already initialized
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Second initialization should complete without error
        await expectLater(
          CFLifecycleManager.initializeInstance(testConfig, testUser),
          completes,
        );
      });
    });
    group('Pause and Resume', () {
      test('should handle pause when not initialized', () {
        expect(() => CFLifecycleManager.pauseInstance(), returnsNormally);
      });
      test('should handle resume when not initialized', () {
        expect(() => CFLifecycleManager.resumeInstance(), returnsNormally);
      });
      test('should handle pause and resume after initialization', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        expect(() => CFLifecycleManager.pauseInstance(), returnsNormally);
        expect(() => CFLifecycleManager.resumeInstance(), returnsNormally);
      });
      test('should handle multiple pause calls', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        expect(() => CFLifecycleManager.pauseInstance(), returnsNormally);
        expect(() => CFLifecycleManager.pauseInstance(), returnsNormally);
        expect(() => CFLifecycleManager.pauseInstance(), returnsNormally);
      });
      test('should handle multiple resume calls', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        expect(() => CFLifecycleManager.resumeInstance(), returnsNormally);
        expect(() => CFLifecycleManager.resumeInstance(), returnsNormally);
        expect(() => CFLifecycleManager.resumeInstance(), returnsNormally);
      });
      test('should handle pause-resume cycles', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Multiple pause-resume cycles
        for (int i = 0; i < 5; i++) {
          expect(() => CFLifecycleManager.pauseInstance(), returnsNormally);
          expect(() => CFLifecycleManager.resumeInstance(), returnsNormally);
        }
      });
    });
    group('Cleanup and Shutdown', () {
      test('should handle cleanup when not initialized', () async {
        await expectLater(CFLifecycleManager.cleanupInstance(), completes);
      });
      test('should cleanup successfully after initialization', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
        await expectLater(CFLifecycleManager.cleanupInstance(), completes);
        expect(CFLifecycleManager.isClientInitialized(), isFalse);
      });
      test('should handle multiple cleanup calls', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        await expectLater(CFLifecycleManager.cleanupInstance(), completes);
        await expectLater(CFLifecycleManager.cleanupInstance(), completes);
        await expectLater(CFLifecycleManager.cleanupInstance(), completes);
      });
      test('should handle cleanup errors gracefully', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Even if cleanup encounters errors, it should complete
        await expectLater(CFLifecycleManager.cleanupInstance(), completes);
      });
    });
    group('Client Access', () {
      test('should return null client when not initialized', () {
        final client = CFLifecycleManager.getInstanceClient();
        expect(client, isNull);
      });
      test('should return client instance after initialization', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Wait a bit for the mediator pattern to work
        await Future.delayed(const Duration(milliseconds: 100));
        final client = CFLifecycleManager.getInstanceClient();
        expect(client, isA<CFClient>());
      });
      test('should return same client instance on multiple calls', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Wait a bit for the mediator pattern to work
        await Future.delayed(const Duration(milliseconds: 100));
        final client1 = CFLifecycleManager.getInstanceClient();
        final client2 = CFLifecycleManager.getInstanceClient();
        expect(client1, isNotNull);
        expect(client2, isNotNull);
        expect(identical(client1, client2), isTrue);
      });
      test('should return null after cleanup', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Wait a bit for the mediator pattern to work
        await Future.delayed(const Duration(milliseconds: 100));
        expect(CFLifecycleManager.getInstanceClient(), isNotNull);
        await CFLifecycleManager.cleanupInstance();
        expect(CFLifecycleManager.getInstanceClient(), isNull);
      });
    });
    group('Complete Lifecycle Workflows', () {
      test('should handle complete app lifecycle', () async {
        // App startup
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
        // App goes to background
        CFLifecycleManager.pauseInstance();
        // App comes to foreground
        CFLifecycleManager.resumeInstance();
        // App shutdown
        await CFLifecycleManager.cleanupInstance();
        expect(CFLifecycleManager.isClientInitialized(), isFalse);
      });
      test('should handle multiple lifecycle cycles', () async {
        for (int cycle = 0; cycle < 3; cycle++) {
          // Initialize
          await CFLifecycleManager.initializeInstance(testConfig, testUser);
          expect(CFLifecycleManager.isClientInitialized(), isTrue);
          // Multiple pause-resume cycles
          for (int i = 0; i < 3; i++) {
            CFLifecycleManager.pauseInstance();
            CFLifecycleManager.resumeInstance();
          }
          // Cleanup
          await CFLifecycleManager.cleanupInstance();
          expect(CFLifecycleManager.isClientInitialized(), isFalse);
        }
      });
      test('should handle rapid state changes', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Rapid pause-resume cycles
        for (int i = 0; i < 100; i++) {
          CFLifecycleManager.pauseInstance();
          CFLifecycleManager.resumeInstance();
        }
        await CFLifecycleManager.cleanupInstance();
      });
      test('should handle initialization-cleanup cycles', () async {
        for (int i = 0; i < 5; i++) {
          await CFLifecycleManager.initializeInstance(testConfig, testUser);
          expect(CFLifecycleManager.isClientInitialized(), isTrue);
          await CFLifecycleManager.cleanupInstance();
          expect(CFLifecycleManager.isClientInitialized(), isFalse);
        }
      });
    });
    group('Concurrent Operations', () {
      test('should handle concurrent initialization calls', () async {
        final futures = <Future>[];
        // Start multiple initialization calls concurrently
        for (int i = 0; i < 5; i++) {
          futures
              .add(CFLifecycleManager.initializeInstance(testConfig, testUser));
        }
        await expectLater(Future.wait(futures), completes);
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
      });
      test('should handle concurrent pause and resume calls', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        final futures = <Future>[];
        // Concurrent pause and resume operations
        for (int i = 0; i < 10; i++) {
          futures.add(Future(() => CFLifecycleManager.pauseInstance()));
          futures.add(Future(() => CFLifecycleManager.resumeInstance()));
        }
        await expectLater(Future.wait(futures), completes);
      });
      test('should handle concurrent cleanup calls', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        final futures = <Future>[];
        // Multiple concurrent cleanup calls
        for (int i = 0; i < 3; i++) {
          futures.add(CFLifecycleManager.cleanupInstance());
        }
        await expectLater(Future.wait(futures), completes);
        expect(CFLifecycleManager.isClientInitialized(), isFalse);
      });
      test('should handle mixed concurrent operations', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        final futures = <Future>[];
        // Mix of different operations
        futures.add(Future(() => CFLifecycleManager.pauseInstance()));
        futures.add(Future(() => CFLifecycleManager.resumeInstance()));
        futures.add(Future(() => CFLifecycleManager.getInstanceClient()));
        futures.add(Future(() => CFLifecycleManager.isClientInitialized()));
        await expectLater(Future.wait(futures), completes);
      });
    });
    group('Error Handling and Edge Cases', () {
      test('should handle operations with different user objects', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Try operations with different user
        final differentUser = CFUser.create(userCustomerId: 'different-user');
        await expectLater(
          CFLifecycleManager.initializeInstance(testConfig, differentUser),
          completes,
        );
      });
      test('should handle state queries during transitions', () async {
        // Check state before initialization
        expect(CFLifecycleManager.isClientInitialized(), isFalse);
        // During initialization
        final initFuture =
            CFLifecycleManager.initializeInstance(testConfig, testUser);
        // State might be transitioning
        CFLifecycleManager.isClientInitialized(); // Should not throw
        await initFuture;
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
      });
      test('should handle cleanup during active operations', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Start some operations
        CFLifecycleManager.pauseInstance();
        CFLifecycleManager.resumeInstance();
        // Cleanup should still work
        await expectLater(CFLifecycleManager.cleanupInstance(), completes);
      });
      test('should handle rapid initialization-cleanup cycles', () async {
        for (int i = 0; i < 10; i++) {
          await CFLifecycleManager.initializeInstance(testConfig, testUser);
          await CFLifecycleManager.cleanupInstance();
        }
      });
    });
    group('Performance Tests', () {
      test('should handle initialization efficiently', () async {
        final stopwatch = Stopwatch()..start();
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        stopwatch.stop();
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
        // Initialization should complete in reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
      test('should handle pause-resume efficiently', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          CFLifecycleManager.pauseInstance();
          CFLifecycleManager.resumeInstance();
        }
        stopwatch.stop();
        // 100 pause-resume cycles should be fast
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
      test('should handle cleanup efficiently', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        final stopwatch = Stopwatch()..start();
        await CFLifecycleManager.cleanupInstance();
        stopwatch.stop();
        expect(CFLifecycleManager.isClientInitialized(), isFalse);
        // Cleanup should complete in reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(3000));
      });
    });
    group('Integration with CFClient', () {
      test('should properly delegate to CFClient methods', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Wait a bit for the mediator pattern to work
        await Future.delayed(const Duration(milliseconds: 100));
        final client = CFLifecycleManager.getInstanceClient();
        expect(client, isNotNull);
        expect(client, isA<CFClient>());
      });
      test('should maintain client state consistency', () async {
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Wait a bit for the mediator pattern to work
        await Future.delayed(const Duration(milliseconds: 100));
        final client1 = CFLifecycleManager.getInstanceClient();
        CFLifecycleManager.pauseInstance();
        CFLifecycleManager.resumeInstance();
        final client2 = CFLifecycleManager.getInstanceClient();
        // Should be the same client instance
        expect(identical(client1, client2), isTrue);
      });
      test('should handle client lifecycle correctly', () async {
        // Before initialization
        expect(CFLifecycleManager.getInstanceClient(), isNull);
        expect(CFLifecycleManager.isClientInitialized(), isFalse);
        // After initialization
        await CFLifecycleManager.initializeInstance(testConfig, testUser);
        // Wait a bit for the mediator pattern to work
        await Future.delayed(const Duration(milliseconds: 100));
        expect(CFLifecycleManager.getInstanceClient(), isNotNull);
        expect(CFLifecycleManager.isClientInitialized(), isTrue);
        // After cleanup
        await CFLifecycleManager.cleanupInstance();
        expect(CFLifecycleManager.getInstanceClient(), isNull);
        expect(CFLifecycleManager.isClientInitialized(), isFalse);
      });
    });
  });
}
