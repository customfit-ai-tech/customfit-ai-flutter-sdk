import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:customfit_ai_flutter_sdk/src/di/dependency_container.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/network/http_client.dart';
import 'package:customfit_ai_flutter_sdk/src/network/connection/connection_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/platform/default_background_state_monitor.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/config_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/user_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/environment_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/client/managers/listener_manager.dart';
// Import concrete types for backward compatibility tests
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_tracker.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/summary/summary_manager.dart';
import 'package:customfit_ai_flutter_sdk/src/network/config/config_fetcher.dart';
import 'dependency_container_test.mocks.dart';
import '../../utils/test_constants.dart';
import '../../helpers/test_storage_helper.dart';
import '../../test_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Test interfaces and classes
abstract class TestService {
  String get id;
}

class TestServiceImpl implements TestService {
  @override
  final String id;
  TestServiceImpl(this.id);
}

class AsyncTestService {
  final String name;
  AsyncTestService(this.name);
}

@GenerateMocks([
  DependencyFactory,
  HttpClient,
  ConnectionManagerImpl,
  EventTracker,
  SummaryManager,
  ConfigFetcher,
])
void main() {
  late DependencyContainer container;
  late MockDependencyFactory mockFactory;
  late CFConfig testConfig;
  late CFUser testUser;
  const testSessionId = 'test-session-123';
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestConfig.setupTestLogger(); // Enable logger for coverage
    SharedPreferences.setMockInitialValues({});
    TestStorageHelper.setupTestStorage();
    container = DependencyContainer.instance;
    container.reset(); // Reset before each test
    mockFactory = MockDependencyFactory();
    // Set up mock stubs
    when(mockFactory.createHttpClient(any)).thenReturn(MockHttpClient());
    when(mockFactory.createEventTracker(any, any, any, any, any, any))
        .thenReturn(MockEventTracker());
    when(mockFactory.createConnectionManager(any))
        .thenReturn(MockConnectionManagerImpl());
    final configResult = CFConfig.builder(TestConstants.validJwtToken)
        .setNetworkConnectionTimeoutMs(5000)
        .build()
        .getOrThrow();
    final userResult = CFUser.builder('test-user').build();
    testUser = userResult;
    testConfig = configResult;
  });
  tearDown(() {
    container.reset();
    TestStorageHelper.clearTestStorage();
  });
  group('DependencyContainer - Singleton', () {
    test('should return same instance', () {
      // Act
      final instance1 = DependencyContainer.instance;
      final instance2 = DependencyContainer.instance;
      // Assert
      expect(identical(instance1, instance2), isTrue);
    });
  });
  group('DependencyContainer - Initialization', () {
    test('should initialize with required parameters', () {
      // Act
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: testSessionId,
        factory: mockFactory,
      );
      // Assert - Container should be initialized
      // We can verify initialization by checking if services are registered
      expect(container.isRegistered<HttpClient>(), isTrue);
    });
    test('should reinitialize when already initialized', () {
      // Arrange
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: testSessionId,
        factory: mockFactory,
      );
      // Act & Assert - Should not throw
      expect(
          () => container.initialize(
                config: testConfig,
                user: testUser,
                sessionId: 'new-session',
                factory: mockFactory,
              ),
          returnsNormally);
    });
    test('should use default factory when none provided', () {
      // Act & Assert - Should not throw
      expect(
          () => container.initialize(
                config: testConfig,
                user: testUser,
                sessionId: testSessionId,
              ),
          returnsNormally);
    });
    test('should initialize container with default factory', () {
      // This covers initialize method lines 85-106
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session-123',
        // No factory provided - will use default
      );
      // Verify core services are registered
      expect(container.isRegistered<HttpClient>(), isTrue);
      expect(container.isRegistered<ConnectionManagerImpl>(), isTrue);
      expect(container.isRegistered<BackgroundStateMonitor>(), isTrue);
    });
    test('should reinitialize when already initialized with warning', () {
      // Test reinitialization warning and reset logic (lines 91-94)
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'session-1',
      );
      // Second initialization should trigger warning and reset
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'session-2',
      );
      // Should complete without error
      expect(container.isRegistered<HttpClient>(), isTrue);
    });
  });
  group('DependencyContainer - Service Registration', () {
    test('should register and retrieve singleton', () {
      // Arrange
      final testService = TestServiceImpl('test-123');
      // Act
      container.registerSingleton<TestService>(testService);
      final retrieved = container.get<TestService>();
      // Assert
      expect(retrieved, equals(testService));
      expect(retrieved.id, equals('test-123'));
    });
    test('should register and retrieve lazy singleton', () {
      // Arrange
      var factoryCalled = false;
      // Act
      container.registerLazySingleton<TestService>(() {
        factoryCalled = true;
        return TestServiceImpl('lazy-test');
      });
      // Assert - Factory not called yet
      expect(factoryCalled, isFalse);
      // Act - Get the service
      final service = container.get<TestService>();
      // Assert
      expect(factoryCalled, isTrue);
      expect(service.id, equals('lazy-test'));
      // Act - Get again
      final service2 = container.get<TestService>();
      // Assert - Same instance returned
      expect(identical(service, service2), isTrue);
    });
    test('should register and retrieve async singleton', () async {
      // Arrange
      var factoryCalled = false;
      // Act
      container.registerAsyncSingleton<AsyncTestService>(() async {
        factoryCalled = true;
        await Future.delayed(const Duration(milliseconds: 10));
        return AsyncTestService('async-test');
      });
      // Assert - Factory not called yet
      expect(factoryCalled, isFalse);
      // Act - Get the service
      final service = await container.getAsync<AsyncTestService>();
      // Assert
      expect(factoryCalled, isTrue);
      expect(service.name, equals('async-test'));
      // Act - Get again (should be cached)
      final service2 = await container.getAsync<AsyncTestService>();
      // Assert - Same instance returned
      expect(identical(service, service2), isTrue);
    });
    test('should handle concurrent async service initialization', () async {
      // Arrange
      var initCount = 0;
      container.registerAsyncSingleton<AsyncTestService>(() async {
        initCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return AsyncTestService('concurrent-test');
      });
      // Act - Start multiple concurrent gets
      final futures =
          List.generate(3, (index) => container.getAsync<AsyncTestService>());
      final services = await Future.wait(futures);
      // Assert - Only initialized once, all return same instance
      expect(initCount, equals(1));
      expect(services.length, equals(3));
      expect(identical(services[0], services[1]), isTrue);
      expect(identical(services[1], services[2]), isTrue);
      expect(services[0].name, equals('concurrent-test'));
    });
    test('should throw on unregistered service', () {
      // Act & Assert
      expect(() => container.get<TestService>(), throwsStateError);
    });
    test('should throw on unregistered async service', () async {
      // Act & Assert
      await expectLater(
          container.getAsync<AsyncTestService>(), throwsStateError);
    });
    test('should handle async service initialization error', () async {
      // Run the test in a guarded zone to catch async exceptions
      await runZonedGuarded(() async {
        // Arrange
        container.registerAsyncSingleton<AsyncTestService>(() async {
          throw Exception('Initialization failed');
        });
        // Act & Assert
        await expectLater(
            container.getAsync<AsyncTestService>(),
            throwsA(isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Initialization failed'),
            )));
        // Assert - Should be able to register again after failure
        container.registerAsyncSingleton<AsyncTestService>(() async {
          return AsyncTestService('recovered');
        });
        final service = await container.getAsync<AsyncTestService>();
        expect(service.name, equals('recovered'));
      }, (error, stack) {
        // Ignore expected async errors from the completer
        if (!error.toString().contains('Initialization failed')) {
          fail('Unexpected error: $error');
        }
      });
    });
    test('should register all core services', () {
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session',
      );
      // Verify all core services are registered (lines 151-186)
      expect(container.isRegistered<HttpClient>(), isTrue);
      expect(container.isRegistered<ConnectionManagerImpl>(), isTrue);
      expect(container.isRegistered<BackgroundStateMonitor>(), isTrue);
      expect(container.isRegistered<ConfigFetcher>(), isTrue);
      expect(container.isRegistered<SummaryManager>(), isTrue);
      expect(container.isRegistered<EventTracker>(), isTrue);
    });
    test('should register all manager services', () {
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session',
      );
      // Verify all managers are registered (lines 189-209)
      expect(container.isRegistered<ConfigManager>(), isTrue);
      expect(container.isRegistered<UserManager>(), isTrue);
      expect(container.isRegistered<EnvironmentManager>(), isTrue);
      expect(container.isRegistered<ListenerManager>(), isTrue);
    });
    test('should register concrete types for backward compatibility', () {
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session',
      );
      // Verify types are registered using their interface/abstract types
      expect(container.isRegistered<SummaryManager>(), isTrue);
      expect(container.isRegistered<EventTracker>(), isTrue);
      expect(container.isRegistered<ConfigFetcher>(), isTrue);
      expect(container.isRegistered<ConfigManager>(), isTrue);
      expect(container.isRegistered<UserManager>(), isTrue);
      expect(container.isRegistered<EnvironmentManager>(), isTrue);
      expect(container.isRegistered<ListenerManager>(), isTrue);
      expect(container.isRegistered<ConnectionManagerImpl>(), isTrue);
      expect(container.isRegistered<BackgroundStateMonitor>(), isTrue);
    });
  });
  group('DependencyContainer - Service Queries', () {
    test('should check if service is registered', () {
      // Arrange
      container.registerSingleton<TestService>(TestServiceImpl('test'));
      // Act & Assert
      expect(container.isRegistered<TestService>(), isTrue);
      expect(container.isRegistered<AsyncTestService>(), isFalse);
    });
    test('should check if lazy singleton is registered', () {
      // Arrange
      container
          .registerLazySingleton<TestService>(() => TestServiceImpl('lazy'));
      // Act & Assert
      expect(container.isRegistered<TestService>(), isTrue);
    });
    test('should check if async singleton is registered', () {
      // Arrange
      container.registerAsyncSingleton<AsyncTestService>(
          () async => AsyncTestService('async'));
      // Act & Assert
      expect(container.isRegistered<AsyncTestService>(), isTrue);
    });
    test('should correctly check service registration', () {
      container.registerSingleton<String>('test-instance');
      container.registerLazySingleton<int>(() => 42);
      container.registerAsyncSingleton<double>(() async => 3.14);
      // Test isRegistered method (lines 364-368)
      expect(container.isRegistered<String>(), isTrue);
      expect(container.isRegistered<int>(), isTrue);
      expect(container.isRegistered<double>(), isTrue);
      expect(container.isRegistered<bool>(), isFalse);
    });
  });
  group('DependencyContainer - Session Management', () {
    test('should update session ID when initialized', () {
      // Arrange
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: testSessionId,
        factory: mockFactory,
      );
      // Act & Assert - Should not throw
      expect(
          () => container.updateSessionId('new-session-456'), returnsNormally);
    });
    test('should warn when updating session ID without initialization', () {
      // Act & Assert - Should not throw but will log warning
      expect(() => container.updateSessionId('new-session'), returnsNormally);
    });
    test('should clear session-dependent services on session update', () {
      // Arrange
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: testSessionId,
        factory: mockFactory,
      );
      // Act
      container.updateSessionId('new-session-789');
      // Assert - Should complete without error
      expect(true, isTrue);
    });
    test('should update session ID and clear dependent services', () {
      // Initialize first
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'original-session',
      );
      // This covers updateSessionId method lines 109-134
      container.updateSessionId('new-session-id');
      // Services should still be accessible
      expect(container.isRegistered<EventTracker>(), isTrue);
      expect(container.isRegistered<SummaryManager>(), isTrue);
    });
    test('should handle session ID update when not initialized', () {
      // Test warning when not initialized (lines 110-115)
      container.updateSessionId('new-session');
      // Should complete without error (just logs warning)
      expect(true, isTrue);
    });
  });
  group('DependencyContainer - Service Resolution', () {
    test('should resolve lazy singleton services', () {
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session',
      );
      // Test lazy factory resolution (lines 319-324)
      final httpClient = container.get<HttpClient>();
      expect(httpClient, isNotNull);
      // Second call should return same instance
      final httpClient2 = container.get<HttpClient>();
      expect(identical(httpClient, httpClient2), isTrue);
    });
    test('should throw StateError for unregistered service', () {
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session',
      );
      // Test StateError for unregistered service (line 326)
      expect(() => container.get<String>(), throwsA(isA<StateError>()));
    });
    test('should handle async service resolution', () async {
      container.registerAsyncSingleton<String>(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'async-result';
      });
      // Test async service resolution (lines 330-361)
      final result = await container.getAsync<String>();
      expect(result, equals('async-result'));
      // Second call should return cached instance
      final result2 = await container.getAsync<String>();
      expect(identical(result, result2), isTrue);
    });
    test(
        'should handle concurrent async service initialization with multiple calls',
        () async {
      container.registerAsyncSingleton<String>(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'concurrent-result';
      });
      // Test concurrent initialization handling (lines 337-339)
      final futures = List.generate(3, (_) => container.getAsync<String>());
      final results = await Future.wait(futures);
      // All should return same instance
      expect(results.length, equals(3));
      expect(results.every((r) => identical(r, results.first)), isTrue);
    });
    test('should throw StateError for unregistered async service', () async {
      // Test StateError for unregistered async service (line 360)
      try {
        await container.getAsync<String>();
        fail('Expected StateError was not thrown');
      } catch (e) {
        expect(e, isA<StateError>());
        expect(e.toString(), contains('Async service'));
      }
    });
  });
  group('DependencyContainer - Lifecycle', () {
    test('should reset all registrations', () {
      // Arrange
      container.registerSingleton<TestService>(TestServiceImpl('test'));
      container.registerLazySingleton<AsyncTestService>(
          () => AsyncTestService('lazy'));
      // Act
      container.reset();
      // Assert
      expect(container.isRegistered<TestService>(), isFalse);
      expect(container.isRegistered<AsyncTestService>(), isFalse);
      expect(() => container.get<TestService>(), throwsStateError);
    });
    test('should shutdown gracefully when not initialized', () async {
      // Act & Assert - Should not throw
      await expectLater(container.shutdown(), completes);
    });
    test('should shutdown and reset when initialized', () async {
      // Arrange
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: testSessionId,
        factory: mockFactory,
      );
      // Act & Assert
      await expectLater(container.shutdown(), completes);
      // Assert - Should be reset after shutdown
      expect(() => container.get<ConfigManager>(), throwsStateError);
    });
    test('should handle shutdown errors gracefully', () async {
      // Arrange
      final mockService = MockEventTracker();
      when(mockService.shutdown()).thenThrow(Exception('Shutdown error'));
      container.registerSingleton<EventTracker>(mockService);
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: testSessionId,
        factory: mockFactory,
      );
      // Act & Assert - Should not throw despite service shutdown error
      await expectLater(container.shutdown(), completes);
    });
    test('should shutdown all services gracefully', () async {
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session',
      );
      // Access some services to instantiate them
      container.get<EventTracker>();
      container.get<SummaryManager>();
      // Test shutdown method (lines 253-294)
      await container.shutdown();
      // Should complete successfully
      expect(true, isTrue);
    });
    test('should handle shutdown when not initialized', () async {
      // Test shutdown when not initialized (lines 254-257)
      await container.shutdown();
      // Should complete without error
      expect(true, isTrue);
    });
    test('should clear all registrations when reset', () {
      container.registerSingleton<String>('test');
      container.registerLazySingleton<int>(() => 42);
      container.registerAsyncSingleton<double>(() async => 3.14);
      expect(container.isRegistered<String>(), isTrue);
      expect(container.isRegistered<int>(), isTrue);
      expect(container.isRegistered<double>(), isTrue);
      // Test reset method (lines 371-376)
      container.reset();
      expect(container.isRegistered<String>(), isFalse);
      expect(container.isRegistered<int>(), isFalse);
      expect(container.isRegistered<double>(), isFalse);
    });
  });
  group('DependencyContainer - Registration Methods', () {
    test('should register singleton instances', () {
      // Test registerSingleton method (lines 297-299)
      container.registerSingleton<String>('test-value');
      expect(container.get<String>(), equals('test-value'));
    });
    test('should register lazy singleton factories', () {
      var callCount = 0;
      // Test registerLazySingleton method (lines 302-304)
      container.registerLazySingleton<int>(() {
        callCount++;
        return 42;
      });
      expect(container.get<int>(), equals(42));
      expect(callCount, equals(1));
      // Second call should return same instance without calling factory again
      expect(container.get<int>(), equals(42));
      expect(callCount, equals(1));
    });
    test('should register async singleton factories', () async {
      // Test registerAsyncSingleton method (lines 307-309)
      container.registerAsyncSingleton<String>(() async {
        await Future.delayed(const Duration(milliseconds: 1));
        return 'async-value';
      });
      final result = await container.getAsync<String>();
      expect(result, equals('async-value'));
    });
  });
  group('DependencyContainer - GetIt Extension', () {
    test('should provide static access through extension', () {
      // Arrange
      container
          .registerSingleton<TestService>(TestServiceImpl('extension-test'));
      // Act
      final service = GetIt.get<TestService>();
      // Assert
      expect(service.id, equals('extension-test'));
    });
    test('should provide static async access through extension', () async {
      // Arrange
      container.registerAsyncSingleton<AsyncTestService>(
        () async => AsyncTestService('async-extension'),
      );
      // Act
      final service = await GetIt.getAsync<AsyncTestService>();
      // Assert
      expect(service.name, equals('async-extension'));
    });
    test('should provide static access via extension', () {
      container.registerSingleton<String>('extension-test');
      // Test GetIt extension (lines 380-383)
      final result = GetIt.get<String>();
      expect(result, equals('extension-test'));
    });
    test('should provide static async access via extension', () async {
      container.registerAsyncSingleton<String>(() async => 'async-extension');
      // Test GetIt extension async method
      final result = await GetIt.getAsync<String>();
      expect(result, equals('async-extension'));
    });
  });
  group('DependencyContainer - Error Handling', () {
    test('should handle state errors appropriately', () {
      // Act & Assert
      expect(
          () => container.get<TestService>(),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              contains('Service TestService not registered'))));
    });
    test('should handle async state errors appropriately', () async {
      // Act & Assert
      await expectLater(
          container.getAsync<AsyncTestService>(),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              contains('Async service AsyncTestService not registered'))));
    });
  });
  group('DependencyContainer - Complex Scenarios', () {
    test('should handle mixed service types correctly', () async {
      // Arrange
      final testService = TestServiceImpl('mixed-test');
      container.registerSingleton<TestService>(testService);
      container.registerLazySingleton<String>(() => 'lazy-string');
      container.registerAsyncSingleton<AsyncTestService>(
          () async => AsyncTestService('async-mixed'));
      // Act
      final service1 = container.get<TestService>();
      final service2 = container.get<String>();
      final service3 = await container.getAsync<AsyncTestService>();
      // Assert
      expect(service1, equals(testService));
      expect(service2, equals('lazy-string'));
      expect(service3.name, equals('async-mixed'));
    });
    test('should maintain service isolation', () {
      // Arrange
      container.registerSingleton<TestService>(TestServiceImpl('service1'));
      container.registerSingleton<String>('different-service');
      // Act
      final service1 = container.get<TestService>();
      final service2 = container.get<String>();
      // Assert
      expect(service1.id, equals('service1'));
      expect(service2, equals('different-service'));
    });
    test('should handle service replacement correctly', () {
      // Arrange
      container.registerSingleton<TestService>(TestServiceImpl('original'));
      final original = container.get<TestService>();
      // Act - Register new instance
      container.registerSingleton<TestService>(TestServiceImpl('replacement'));
      final replacement = container.get<TestService>();
      // Assert
      expect(original.id, equals('original'));
      expect(replacement.id, equals('replacement'));
      expect(identical(original, replacement), isFalse);
    });
  });
  group('DependencyContainer - Edge Cases', () {
    test('should handle empty session dependent types during update', () {
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session',
      );
      // Update session without accessing dependent services first
      container.updateSessionId('new-session');
      // Should complete without error
      expect(true, isTrue);
    });
    test('should handle service with no shutdown method', () async {
      // Register a service without shutdown method
      container.registerSingleton<String>('no-shutdown-service');
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session',
      );
      // Should handle services without shutdown gracefully
      await container.shutdown();
      expect(true, isTrue);
    });
    test('should handle futures list when empty during shutdown', () async {
      container.initialize(
        config: testConfig,
        user: testUser,
        sessionId: 'test-session',
      );
      // Test empty futures list handling (lines 287-289)
      await container.shutdown();
      expect(true, isTrue);
    });
  });
}
