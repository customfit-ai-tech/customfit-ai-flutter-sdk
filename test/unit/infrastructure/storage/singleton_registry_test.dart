import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/infrastructure/storage/internal/singleton_registry.dart';
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
        'test_service',
        testService,
        description: 'A test service',
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
        'test_service',
        TestService('test1'),
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
        'test_service',
        testService,
      );
      registry.register<AnotherTestService>(
        'another_service',
        anotherService,
      );
      registry.register<ThirdTestService>(
        'third_service',
        thirdService,
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
      registry.register<TestService>('service1', service1);
      registry.register<TestService>('service2', service2);
      registry.register<AnotherTestService>('another', anotherService);
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
      registry.register<TestService>('service1', service1);
      registry.register<TestService>('service2', service2);
      registry.register<AnotherTestService>('another', anotherService);
      // Act
      final stats = registry.getStats();
      // Assert
      expect(stats['totalCount'], equals(3));
      expect(stats['typeDistribution'], isA<Map<String, int>>());
      expect(stats['typeDistribution']['TestService'], equals(2));
      expect(stats['typeDistribution']['AnotherTestService'], equals(1));
      expect(stats['registrationOrder'], isA<List<Map<String, dynamic>>>());
      expect(stats['registrationOrder'].length, equals(3));
      expect(stats['registrationOrder'][0]['name'], equals('service1'));
      expect(stats['registrationOrder'][1]['name'], equals('service2'));
      expect(stats['registrationOrder'][2]['name'], equals('another'));
    });
    test('should track registration metadata correctly', () {
      // Arrange
      final testService = TestService('test1');
      const description = 'A test service for testing';
      // Act
      registry.register<TestService>(
        'test_service',
        testService,
        description: description,
      );
      final stats = registry.getStats();
      // Assert
      expect(stats['totalCount'], equals(1));
      expect(stats['registrationOrder'], isA<List<Map<String, dynamic>>>());
      expect(stats['registrationOrder'].length, equals(1));
      expect(stats['registrationOrder'][0]['name'], equals('test_service'));
      // Verify the registration happened recently (within last 5 seconds)
      final registrationTime = DateTime.parse(stats['registrationOrder'][0]['registeredAt'] as String);
      final timeDiff = DateTime.now().difference(registrationTime);
      expect(timeDiff.inSeconds, lessThan(5));
    });
    test('should clear all singletons and metadata', () {
      // Arrange
      registry.register<TestService>('service1', TestService('test1'));
      registry.register<AnotherTestService>('service2', AnotherTestService(42));
      // Verify they exist
      expect(registry.get<TestService>('service1'), isNotNull);
      expect(registry.getStats()['totalCount'], equals(2));
      // Act
      registry.clear();
      // Assert
      expect(registry.get<TestService>('service1'), isNull);
      expect(registry.get<AnotherTestService>('service2'), isNull);
      expect(registry.getStats()['totalCount'], equals(0));
      expect(registry.getAllOfType<TestService>(), isEmpty);
      expect(registry.getAllOfType<AnotherTestService>(), isEmpty);
    });
    test('should handle empty registry statistics', () {
      // Act
      final stats = registry.getStats();
      // Assert
      expect(stats['totalCount'], equals(0));
      expect(stats['typeDistribution'], isA<Map<String, int>>());
      expect(stats['typeDistribution'], isEmpty);
      expect(stats['registrationOrder'], isA<List<Map<String, dynamic>>>());
      expect(stats['registrationOrder'], isEmpty);
    });
    test('should allow registering with same name but different types', () {
      // Arrange
      final testService = TestService('test1');
      final anotherService = AnotherTestService(42);
      // Act
      registry.register<TestService>('service', testService);
      registry.register<AnotherTestService>('service', anotherService);
      // Assert
      expect(registry.get<TestService>('service'), isNull); // Overwritten
      expect(registry.get<AnotherTestService>('service'), equals(anotherService));
    });
    test('should handle null descriptions correctly', () {
      // Arrange
      final testService = TestService('test1');
      // Act
      registry.register<TestService>(
        'test_service',
        testService,
        description: null,
      );
      // Assert
      expect(registry.get<TestService>('test_service'), equals(testService));
      expect(registry.getStats()['totalCount'], equals(1));
    });
  });
  group('SingletonMetadata', () {
    test('should create metadata with all required fields', () {
      // Arrange & Act
      final metadata = SingletonMetadata(
        type: TestService,
        name: 'test_service',
        description: 'A test service',
        registeredAt: DateTime.now(),
      );
      // Assert
      expect(metadata.type, equals(TestService));
      expect(metadata.name, equals('test_service'));
      expect(metadata.description, equals('A test service'));
      expect(metadata.registeredAt, isA<DateTime>());
    });
    test('should create metadata with null description', () {
      // Arrange & Act
      final metadata = SingletonMetadata(
        type: TestService,
        name: 'test_service',
        description: null,
        registeredAt: DateTime.now(),
      );
      // Assert
      expect(metadata.type, equals(TestService));
      expect(metadata.name, equals('test_service'));
      expect(metadata.description, isNull);
      expect(metadata.registeredAt, isA<DateTime>());
    });
  });
}