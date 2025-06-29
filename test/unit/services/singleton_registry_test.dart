import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/services/singleton_registry.dart';
// Test classes for registry testing
class TestService {
  final String id;
  TestService(this.id);
}
class AnotherTestService {
  final int value;
  AnotherTestService(this.value);
}
class ThirdTestService {
  final bool flag;
  ThirdTestService(this.flag);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SingletonRegistry registry;
  setUp(() {
    registry = SingletonRegistry.instance;
    registry.clear(); // Clear before each test
  });
  tearDown(() {
    registry.clear(); // Clean up after each test
  });
  group('SingletonRegistry', () {
    test('should be a singleton', () {
      // Arrange & Act
      final instance1 = SingletonRegistry.instance;
      final instance2 = SingletonRegistry.instance;
      // Assert
      expect(identical(instance1, instance2), isTrue);
    });
    test('should register and retrieve singleton by name', () {
      // Arrange
      final testService = TestService('test1');
      // Act
      registry.register<TestService>(
        name: 'test_service',
        instance: testService,
        description: 'A test service',
        isLazy: false,
      );
      final retrieved = registry.get<TestService>('test_service');
      // Assert
      expect(retrieved, equals(testService));
      expect(retrieved?.id, equals('test1'));
    });
    test('should return null for unregistered singleton', () {
      // Act
      final result = registry.get<TestService>('nonexistent');
      // Assert
      expect(result, isNull);
    });
    test('should return null for wrong type', () {
      // Arrange
      registry.register<TestService>(
        name: 'test_service',
        instance: TestService('test1'),
      );
      // Act
      final result = registry.get<AnotherTestService>('test_service');
      // Assert
      expect(result, isNull);
    });
    test('should register multiple singletons of different types', () {
      // Arrange
      final testService = TestService('test1');
      final anotherService = AnotherTestService(42);
      final thirdService = ThirdTestService(true);
      // Act
      registry.register<TestService>(
        name: 'test_service',
        instance: testService,
      );
      registry.register<AnotherTestService>(
        name: 'another_service',
        instance: anotherService,
      );
      registry.register<ThirdTestService>(
        name: 'third_service',
        instance: thirdService,
      );
      // Assert
      expect(registry.get<TestService>('test_service'), equals(testService));
      expect(registry.get<AnotherTestService>('another_service'), equals(anotherService));
      expect(registry.get<ThirdTestService>('third_service'), equals(thirdService));
    });
    test('should get all singletons of a specific type', () {
      // Arrange
      final service1 = TestService('test1');
      final service2 = TestService('test2');
      final anotherService = AnotherTestService(42);
      registry.register<TestService>(name: 'service1', instance: service1);
      registry.register<TestService>(name: 'service2', instance: service2);
      registry.register<AnotherTestService>(name: 'another', instance: anotherService);
      // Act
      final testServices = registry.getAllOfType<TestService>();
      final anotherServices = registry.getAllOfType<AnotherTestService>();
      final nonExistentServices = registry.getAllOfType<ThirdTestService>();
      // Assert
      expect(testServices.length, equals(2));
      expect(testServices, contains(service1));
      expect(testServices, contains(service2));
      expect(anotherServices.length, equals(1));
      expect(anotherServices, contains(anotherService));
      expect(nonExistentServices.length, equals(0));
    });
    test('should provide accurate registry statistics', () {
      // Arrange
      final service1 = TestService('test1');
      final service2 = TestService('test2');
      final anotherService = AnotherTestService(42);
      registry.register<TestService>(name: 'service1', instance: service1);
      registry.register<TestService>(name: 'service2', instance: service2);
      registry.register<AnotherTestService>(name: 'another', instance: anotherService);
      // Act
      final stats = registry.getStats();
      // Assert
      expect(stats['totalSingletons'], equals(3));
      expect(stats['byType'], isA<Map<Type, int>>());
      expect(stats['byType'][TestService], equals(2));
      expect(stats['byType'][AnotherTestService], equals(1));
      expect(stats['registrationTimes'], isA<Map<String, DateTime>>());
      expect(stats['registrationTimes']['service1'], isA<DateTime>());
      expect(stats['registrationTimes']['service2'], isA<DateTime>());
      expect(stats['registrationTimes']['another'], isA<DateTime>());
    });
    test('should track registration metadata correctly', () {
      // Arrange
      final testService = TestService('test1');
      const description = 'A test service for testing';
      // Act
      registry.register<TestService>(
        name: 'test_service',
        instance: testService,
        description: description,
        isLazy: true,
      );
      final stats = registry.getStats();
      // Assert
      expect(stats['totalSingletons'], equals(1));
      expect(stats['registrationTimes']['test_service'], isA<DateTime>());
      // Verify the registration happened recently (within last 5 seconds)
      final registrationTime = stats['registrationTimes']['test_service'] as DateTime;
      final timeDiff = DateTime.now().difference(registrationTime);
      expect(timeDiff.inSeconds, lessThan(5));
    });
    test('should clear all singletons and metadata', () {
      // Arrange
      registry.register<TestService>(name: 'service1', instance: TestService('test1'));
      registry.register<AnotherTestService>(name: 'service2', instance: AnotherTestService(42));
      // Verify they exist
      expect(registry.get<TestService>('service1'), isNotNull);
      expect(registry.getStats()['totalSingletons'], equals(2));
      // Act
      registry.clear();
      // Assert
      expect(registry.get<TestService>('service1'), isNull);
      expect(registry.get<AnotherTestService>('service2'), isNull);
      expect(registry.getStats()['totalSingletons'], equals(0));
      expect(registry.getAllOfType<TestService>(), isEmpty);
      expect(registry.getAllOfType<AnotherTestService>(), isEmpty);
    });
    test('should handle empty registry statistics', () {
      // Act
      final stats = registry.getStats();
      // Assert
      expect(stats['totalSingletons'], equals(0));
      expect(stats['byType'], isA<Map<Type, int>>());
      expect(stats['byType'], isEmpty);
      expect(stats['registrationTimes'], isA<Map<String, DateTime>>());
      expect(stats['registrationTimes'], isEmpty);
    });
    test('should allow registering with same name but different types', () {
      // Arrange
      final testService = TestService('test1');
      final anotherService = AnotherTestService(42);
      // Act
      registry.register<TestService>(name: 'service', instance: testService);
      registry.register<AnotherTestService>(name: 'service', instance: anotherService);
      // Assert
      expect(registry.get<TestService>('service'), isNull); // Overwritten
      expect(registry.get<AnotherTestService>('service'), equals(anotherService));
    });
    test('should handle null descriptions correctly', () {
      // Arrange
      final testService = TestService('test1');
      // Act
      registry.register<TestService>(
        name: 'test_service',
        instance: testService,
        description: null,
        isLazy: false,
      );
      // Assert
      expect(registry.get<TestService>('test_service'), equals(testService));
      expect(registry.getStats()['totalSingletons'], equals(1));
    });
  });
  group('SingletonMetadata', () {
    test('should create metadata with all required fields', () {
      // Arrange & Act
      final metadata = SingletonMetadata(
        type: TestService,
        name: 'test_service',
        description: 'A test service',
        isLazy: true,
        registeredAt: DateTime.now(),
      );
      // Assert
      expect(metadata.type, equals(TestService));
      expect(metadata.name, equals('test_service'));
      expect(metadata.description, equals('A test service'));
      expect(metadata.isLazy, isTrue);
      expect(metadata.registeredAt, isA<DateTime>());
    });
    test('should create metadata with null description', () {
      // Arrange & Act
      final metadata = SingletonMetadata(
        type: TestService,
        name: 'test_service',
        description: null,
        isLazy: false,
        registeredAt: DateTime.now(),
      );
      // Assert
      expect(metadata.type, equals(TestService));
      expect(metadata.name, equals('test_service'));
      expect(metadata.description, isNull);
      expect(metadata.isLazy, isFalse);
      expect(metadata.registeredAt, isA<DateTime>());
    });
  });
}