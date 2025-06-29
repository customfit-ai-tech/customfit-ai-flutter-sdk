// test/unit/core/memory/memory_aware_test.dart
//
// Comprehensive unit tests for MemoryAware interface and related classes
// to achieve 100% coverage (7/7 lines)
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/memory_aware.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/memory_pressure_level.dart';
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    PreferencesService.reset();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MemoryAware Interface', () {
    test('should define required getters and methods', () {
      final component = TestMemoryAwareComponent();
      // Test all interface methods and getters
      expect(component.componentName, equals('TestComponent'));
      expect(component.memoryPriority, equals(50));
      expect(component.estimatedMemoryUsage, equals(-1)); // Default value
      expect(component.canCleanup, isTrue);
      // Test onMemoryPressure
      expect(() => component.onMemoryPressure(MemoryPressureLevel.low), returnsNormally);
    });
    test('should handle all memory pressure levels', () async {
      final component = TestMemoryAwareComponent();
      // Test all pressure levels
      await component.onMemoryPressure(MemoryPressureLevel.low);
      expect(component.lastPressureLevel, equals(MemoryPressureLevel.low));
      await component.onMemoryPressure(MemoryPressureLevel.medium);
      expect(component.lastPressureLevel, equals(MemoryPressureLevel.medium));
      await component.onMemoryPressure(MemoryPressureLevel.high);
      expect(component.lastPressureLevel, equals(MemoryPressureLevel.high));
      await component.onMemoryPressure(MemoryPressureLevel.critical);
      expect(component.lastPressureLevel, equals(MemoryPressureLevel.critical));
    });
  });
  group('MemoryPriority Constants', () {
    test('should have correct priority values', () {
      expect(MemoryPriority.critical, equals(100));
      expect(MemoryPriority.high, equals(80));
      expect(MemoryPriority.normal, equals(50));
      expect(MemoryPriority.low, equals(20));
      expect(MemoryPriority.background, equals(10));
    });
    test('should maintain priority order', () {
      expect(MemoryPriority.critical, greaterThan(MemoryPriority.high));
      expect(MemoryPriority.high, greaterThan(MemoryPriority.normal));
      expect(MemoryPriority.normal, greaterThan(MemoryPriority.low));
      expect(MemoryPriority.low, greaterThan(MemoryPriority.background));
    });
    test('should be used correctly by components', () {
      final criticalComponent = TestMemoryAwareComponent(priority: MemoryPriority.critical);
      final normalComponent = TestMemoryAwareComponent(priority: MemoryPriority.normal);
      final backgroundComponent = TestMemoryAwareComponent(priority: MemoryPriority.background);
      expect(criticalComponent.memoryPriority, equals(100));
      expect(normalComponent.memoryPriority, equals(50));
      expect(backgroundComponent.memoryPriority, equals(10));
    });
  });
  group('MemoryCleanupResult', () {
    test('should create with required parameters', () {
      final result = MemoryCleanupResult(
        componentName: 'TestComponent',
        bytesFreed: 1024 * 1024,
        success: true,
        duration: const Duration(milliseconds: 100),
      );
      expect(result.componentName, equals('TestComponent'));
      expect(result.bytesFreed, equals(1024 * 1024));
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.duration, equals(const Duration(milliseconds: 100)));
    });
    test('should create with error', () {
      final result = MemoryCleanupResult(
        componentName: 'TestComponent',
        bytesFreed: 0,
        success: false,
        error: 'Cleanup failed',
        duration: const Duration(milliseconds: 50),
      );
      expect(result.componentName, equals('TestComponent'));
      expect(result.bytesFreed, equals(0));
      expect(result.success, isFalse);
      expect(result.error, equals('Cleanup failed'));
      expect(result.duration, equals(const Duration(milliseconds: 50)));
    });
    test('should format toString correctly for success', () {
      final result = MemoryCleanupResult(
        componentName: 'TestComponent',
        bytesFreed: 5 * 1024 * 1024, // 5MB
        success: true,
        duration: const Duration(milliseconds: 150),
      );
      final str = result.toString();
      expect(str, contains('TestComponent'));
      expect(str, contains('Success'));
      expect(str, contains('5.00MB'));
      expect(str, contains('150ms'));
      expect(str, isNot(contains('error:')));
    });
    test('should format toString correctly for failure', () {
      final result = MemoryCleanupResult(
        componentName: 'TestComponent',
        bytesFreed: 0,
        success: false,
        error: 'Out of memory',
        duration: const Duration(milliseconds: 10),
      );
      final str = result.toString();
      expect(str, contains('TestComponent'));
      expect(str, contains('Failed'));
      expect(str, contains('0MB'));
      expect(str, contains('10ms'));
      expect(str, contains('error: Out of memory'));
    });
    test('should handle various byte sizes correctly', () {
      // Test 0 bytes
      var result = MemoryCleanupResult(
        componentName: 'Test1',
        bytesFreed: 0,
        success: true,
        duration: const Duration(milliseconds: 1),
      );
      expect(result.toString(), contains('0MB'));
      // Test < 1MB
      result = MemoryCleanupResult(
        componentName: 'Test2',
        bytesFreed: 512 * 1024, // 0.5MB
        success: true,
        duration: const Duration(milliseconds: 1),
      );
      expect(result.toString(), contains('0.50MB'));
      // Test exact MB
      result = MemoryCleanupResult(
        componentName: 'Test3',
        bytesFreed: 10 * 1024 * 1024, // 10MB
        success: true,
        duration: const Duration(milliseconds: 1),
      );
      expect(result.toString(), contains('10.00MB'));
      // Test large values
      result = MemoryCleanupResult(
        componentName: 'Test4',
        bytesFreed: 1024 * 1024 * 1024, // 1GB
        success: true,
        duration: const Duration(milliseconds: 1),
      );
      expect(result.toString(), contains('1024.00MB'));
    });
    test('should handle edge cases in toString', () {
      // Test very long component name
      final result = MemoryCleanupResult(
        componentName: 'VeryLongComponentNameThatShouldStillWorkCorrectly',
        bytesFreed: 123456,
        success: true,
        duration: const Duration(seconds: 1, milliseconds: 500),
      );
      final str = result.toString();
      expect(str, contains('VeryLongComponentNameThatShouldStillWorkCorrectly'));
      expect(str, contains('1500ms'));
    });
  });
  group('MemoryAware Implementation Examples', () {
    test('should support different component implementations', () {
      final cache = CacheComponent();
      final database = DatabaseComponent();
      final imageLoader = ImageLoaderComponent();
      // All should implement MemoryAware
      expect(cache, isA<MemoryAware>());
      expect(database, isA<MemoryAware>());
      expect(imageLoader, isA<MemoryAware>());
      // Different priorities
      expect(cache.memoryPriority, equals(MemoryPriority.normal));
      expect(database.memoryPriority, equals(MemoryPriority.high));
      expect(imageLoader.memoryPriority, equals(MemoryPriority.low));
      // Different cleanup abilities
      expect(cache.canCleanup, isTrue);
      expect(database.canCleanup, isFalse); // Critical data
      expect(imageLoader.canCleanup, isTrue);
    });
    test('should handle async cleanup operations', () async {
      final component = AsyncCleanupComponent();
      final future = component.onMemoryPressure(MemoryPressureLevel.high);
      expect(future, isA<Future<void>>());
      await future;
      expect(component.cleanupCompleted, isTrue);
    });
  });
}
// Test implementations
class TestMemoryAwareComponent implements MemoryAware {
  final int priority;
  MemoryPressureLevel? lastPressureLevel;
  TestMemoryAwareComponent({this.priority = 50});
  @override
  String get componentName => 'TestComponent';
  @override
  int get memoryPriority => priority;
  @override
  int get estimatedMemoryUsage => -1; // Unknown
  @override
  bool get canCleanup => true;
  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    lastPressureLevel = level;
  }
}
// Example implementations for testing
class CacheComponent implements MemoryAware {
  @override
  String get componentName => 'CacheComponent';
  @override
  int get memoryPriority => MemoryPriority.normal;
  @override
  int get estimatedMemoryUsage => 10 * 1024 * 1024; // 10MB
  @override
  bool get canCleanup => true;
  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    // Simulate cache cleanup
  }
}
class DatabaseComponent implements MemoryAware {
  @override
  String get componentName => 'DatabaseComponent';
  @override
  int get memoryPriority => MemoryPriority.high;
  @override
  int get estimatedMemoryUsage => 50 * 1024 * 1024; // 50MB
  @override
  bool get canCleanup => false; // Critical component
  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    // Database might compact but not clear data
  }
}
class ImageLoaderComponent implements MemoryAware {
  @override
  String get componentName => 'ImageLoaderComponent';
  @override
  int get memoryPriority => MemoryPriority.low;
  @override
  int get estimatedMemoryUsage => 100 * 1024 * 1024; // 100MB
  @override
  bool get canCleanup => true;
  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    // Clear image cache based on pressure level
  }
}
class AsyncCleanupComponent implements MemoryAware {
  bool cleanupCompleted = false;
  @override
  String get componentName => 'AsyncCleanupComponent';
  @override
  int get memoryPriority => MemoryPriority.normal;
  @override
  int get estimatedMemoryUsage => -1;
  @override
  bool get canCleanup => true;
  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    // Simulate async work
    await Future.delayed(const Duration(milliseconds: 50));
    cleanupCompleted = true;
  }
}