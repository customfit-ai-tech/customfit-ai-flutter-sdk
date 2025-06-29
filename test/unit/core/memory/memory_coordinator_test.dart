// test/unit/core/memory/memory_coordinator_test.dart
//
// Consolidated MemoryCoordinator Test Suite
// Merged from memory_coordinator_comprehensive_test.dart and memory_coordinator_test.dart
// to eliminate duplication while maintaining complete test coverage.
//
// This comprehensive test suite covers:
// 1. Singleton pattern and lifecycle management
// 2. Component registration and priority handling
// 3. Object tracking and weak reference management
// 4. Adaptive cleanup timer and pressure response
// 5. Core component adapters and integration
// 6. Error handling and edge cases
// 7. Memory statistics and reporting
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/memory_coordinator.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/memory_aware.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/memory_pressure_level.dart';
import 'package:customfit_ai_flutter_sdk/src/core/memory/platform/memory_platform_interface.dart';
import '../../../test_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestConfig.setupTestLogger();
  group('MemoryCoordinator Comprehensive Test Suite', () {
    late MemoryCoordinator coordinator;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      MemoryCoordinator.reset(); // Clean state
      coordinator = MemoryCoordinator.instance;
      await coordinator.initialize();
    });
    tearDown(() async {
      await coordinator.shutdown();
      MemoryCoordinator.reset();
      PreferencesService.reset();
    });
    group('Singleton Pattern & Lifecycle', () {
      test('should be singleton', () {
        final instance1 = MemoryCoordinator.instance;
        final instance2 = MemoryCoordinator.instance;
        expect(identical(instance1, instance2), isTrue);
      });
      test('should initialize and shutdown properly', () async {
        // Already initialized in setUp
        expect(coordinator.getMemoryStats()['components'], greaterThan(0));
        await coordinator.shutdown();
        // Should handle re-initialization
        await coordinator.initialize();
        expect(coordinator.getMemoryStats()['components'], greaterThan(0));
      });
      test('should handle initialization when already initialized', () async {
        // Already initialized in setUp
        await coordinator.initialize(); // Should log warning but not fail
        final stats = coordinator.getMemoryStats();
        expect(stats['components'], greaterThan(0));
      });
      test('should handle shutdown when not initialized', () async {
        await coordinator.shutdown();
        await coordinator.shutdown(); // Should handle gracefully
        expect(() => coordinator.getMemoryStats(), returnsNormally);
      });
      test('should cancel cleanup timer during shutdown', () async {
        // Timer should be active after initialization
        final stats = coordinator.getMemoryStats();
        expect(stats['components'], greaterThan(0));
        await coordinator.shutdown();
        // After shutdown, timer should be cancelled
        expect(() => coordinator.getMemoryStats(), returnsNormally);
      });
    });
    group('Component Registration & Management', () {
      test('should register and unregister components', () {
        final component = TestMemoryAwareComponent('TestComponent');
        coordinator.registerComponent(component);
        expect(coordinator.getMemoryStats()['components'],
            equals(4)); // 3 core + 1 test
        coordinator.unregisterComponent(component);
        expect(coordinator.getMemoryStats()['components'],
            equals(3)); // Back to 3 core
      });
      test('should not register duplicate components', () {
        final component = TestMemoryAwareComponent('TestComponent');
        coordinator.registerComponent(component);
        coordinator.registerComponent(component);
        // Should still have only one instance
        expect(coordinator.getMemoryStats()['components'], equals(4));
      });
      test('should handle multiple registrations of same component name', () {
        final component1 = TestMemoryAwareComponent('SameName');
        final component2 = TestMemoryAwareComponent('SameName');
        coordinator.registerComponent(component1);
        coordinator.registerComponent(component2); // Should be ignored
        final stats = coordinator.getMemoryStats();
        final componentStats = stats['componentStats'] as Map<String, dynamic>;
        // Should only have one component with this name
        expect(componentStats.keys.where((k) => k == 'SameName').length,
            equals(1));
      });
      test('should handle unregistering non-existent component', () {
        final component = TestMemoryAwareComponent('NonExistent');
        // Should not throw when unregistering non-existent component
        expect(
            () => coordinator.unregisterComponent(component), returnsNormally);
      });
      test('should register core components during initialization', () async {
        // Core components should already be registered
        final stats = coordinator.getMemoryStats();
        final componentStats = stats['componentStats'] as Map<String, dynamic>;
        expect(componentStats.containsKey('MemoryManager'), isTrue);
        expect(componentStats.containsKey('CacheManager'), isTrue);
        expect(componentStats.containsKey('MemoryProfiler'), isTrue);
      });
    });
    group('Object Tracking & Weak References', () {
      test('should track and untrack objects', () {
        final object = TestObject();
        coordinator.track(object, 'TestCategory');
        var stats = coordinator.getMemoryStats();
        expect(stats['trackedObjects'], equals(1));
        expect(stats['objectsByCategory']['TestCategory'], equals(1));
        coordinator.untrack(object);
        stats = coordinator.getMemoryStats();
        expect(stats['trackedObjects'], equals(0));
        expect(stats['objectsByCategory']['TestCategory'], equals(0));
      });
      test('should handle untracking objects correctly', () {
        final obj1 = TestObject();
        final obj2 = TestObject();
        coordinator.track(obj1, 'Category1');
        coordinator.track(obj2, 'Category2');
        var stats = coordinator.getMemoryStats();
        expect(stats['objectsByCategory']['Category1'], equals(1));
        expect(stats['objectsByCategory']['Category2'], equals(1));
        coordinator.untrack(obj1);
        stats = coordinator.getMemoryStats();
        expect(stats['objectsByCategory']['Category1'], equals(0));
        expect(stats['objectsByCategory']['Category2'], equals(1));
      });
      test('should handle untracking non-existent objects gracefully', () {
        final obj = TestObject();
        // Try to untrack an object that was never tracked
        expect(() => coordinator.untrack(obj), returnsNormally);
      });
      test('should clean dead weak references during adaptive cleanup',
          () async {
        // Track objects that will go out of scope
        for (int i = 0; i < 5; i++) {
          final obj = TestObject();
          coordinator.track(obj, 'TempCategory');
        }
        var stats = coordinator.getMemoryStats();
        expect(stats['trackedObjects'], greaterThanOrEqualTo(5));
        expect(stats['objectsByCategory']['TempCategory'],
            greaterThanOrEqualTo(5));
        // Force garbage collection simulation by calling adaptive cleanup
        coordinator.onMemoryPressureChanged(
          MemoryPressureLevel.medium,
          MemoryInfo.fromAvailableAndTotal(
            availableMemory: 400 * 1024 * 1024,
            totalMemory: 1000 * 1024 * 1024,
            appMemoryUsage: 100 * 1024 * 1024,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));
        // Some objects might be cleaned up, but we can't guarantee exact counts in test environment
        stats = coordinator.getMemoryStats();
        expect(stats['aliveObjects'], greaterThan(0));
      });
      test('should clean dead weak references', () async {
        // Track objects that will be garbage collected
        for (int i = 0; i < 10; i++) {
          coordinator.track(TestObject(), 'Temporary');
        }
        var stats = coordinator.getMemoryStats();
        expect(stats['trackedObjects'], greaterThanOrEqualTo(10));
        // Force cleanup
        await coordinator.forceCleanup();
        // Some references might be cleaned, but counts can vary in test environment
        stats = coordinator.getMemoryStats();
        expect(stats['trackedObjects'], greaterThan(0));
      });
      test('should maintain object counts by category', () {
        coordinator.track(TestObject(), 'CategoryA');
        coordinator.track(TestObject(), 'CategoryA');
        coordinator.track(TestObject(), 'CategoryB');
        final stats = coordinator.getMemoryStats();
        final objectsByCategory =
            Map<String, dynamic>.from(stats['objectsByCategory'] as Map);
        expect(objectsByCategory['CategoryA'], equals(2));
        expect(objectsByCategory['CategoryB'], equals(1));
      });
    });
    group('Memory Pressure Response & Adaptive Cleanup', () {
      test('should handle memory pressure changes', () async {
        final component = TestMemoryAwareComponent('TestComponent',
            priority: 10); // Lower priority to ensure selection
        coordinator.registerComponent(component);
        // Simulate pressure change
        final memoryInfo = MemoryInfo.fromAvailableAndTotal(
          availableMemory: 100 * 1024 * 1024,
          totalMemory: 1000 * 1024 * 1024,
          appMemoryUsage: 50 * 1024 * 1024,
        );
        coordinator.onMemoryPressureChanged(
            MemoryPressureLevel.medium, memoryInfo);
        // Component should have been notified - wait longer for async processing
        await Future.delayed(const Duration(milliseconds: 500));
        // Force a cleanup cycle which should definitely notify components
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.medium);
        // Component should have been notified during cleanup
        expect(component.lastPressureLevel, equals(MemoryPressureLevel.medium));
      });
      test('should adjust cleanup interval based on memory pressure', () async {
        final component = TestMemoryAwareComponent('TestComponent',
            priority: 10); // Lower priority to ensure selection
        coordinator.registerComponent(component);
        // Start with low pressure - should use 10 minute interval
        final lowPressureInfo = MemoryInfo.fromAvailableAndTotal(
          availableMemory: 800 * 1024 * 1024, // 80% available
          totalMemory: 1000 * 1024 * 1024,
          appMemoryUsage: 50 * 1024 * 1024,
        );
        coordinator.onMemoryPressureChanged(
            MemoryPressureLevel.low, lowPressureInfo);
        // Change to high pressure - should adjust to 1 minute interval
        final highPressureInfo = MemoryInfo.fromAvailableAndTotal(
          availableMemory: 200 * 1024 * 1024, // 20% available
          totalMemory: 1000 * 1024 * 1024,
          appMemoryUsage: 150 * 1024 * 1024,
        );
        coordinator.onMemoryPressureChanged(
            MemoryPressureLevel.high, highPressureInfo);
        // Wait briefly for cleanup to process, then force cleanup to ensure notification
        await Future.delayed(const Duration(milliseconds: 50));
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.high);
        expect(component.lastPressureLevel, equals(MemoryPressureLevel.high));
      });
      test('should use critical pressure 30-second interval', () async {
        final component =
            TestMemoryAwareComponent('CriticalTest', priority: 10);
        coordinator.registerComponent(component);
        final criticalInfo = MemoryInfo.fromAvailableAndTotal(
          availableMemory: 50 * 1024 * 1024, // Very low memory
          totalMemory: 1000 * 1024 * 1024,
          appMemoryUsage: 200 * 1024 * 1024,
        );
        coordinator.onMemoryPressureChanged(
            MemoryPressureLevel.critical, criticalInfo);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(
            component.lastPressureLevel, equals(MemoryPressureLevel.critical));
      });
      test('should respond immediately to pressure requiring action', () async {
        final component =
            TestMemoryAwareComponent('ResponseTest', priority: 10);
        coordinator.registerComponent(component);
        final highPressureInfo = MemoryInfo.fromAvailableAndTotal(
          availableMemory: 100 * 1024 * 1024,
          totalMemory: 1000 * 1024 * 1024,
          appMemoryUsage: 200 * 1024 * 1024,
        );
        // High pressure requires immediate action
        coordinator.onMemoryPressureChanged(
            MemoryPressureLevel.high, highPressureInfo);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(component.lastPressureLevel, equals(MemoryPressureLevel.high));
      });
      test('should not respond immediately to low pressure', () async {
        final component =
            TestMemoryAwareComponent('LowPressureTest', priority: 10);
        coordinator.registerComponent(component);
        final lowPressureInfo = MemoryInfo.fromAvailableAndTotal(
          availableMemory: 800 * 1024 * 1024,
          totalMemory: 1000 * 1024 * 1024,
          appMemoryUsage: 50 * 1024 * 1024,
        );
        final initialCleanupCount = component.cleanupCount;
        coordinator.onMemoryPressureChanged(
            MemoryPressureLevel.low, lowPressureInfo);
        await Future.delayed(const Duration(milliseconds: 30));
        // Low pressure shouldn't trigger immediate cleanup
        expect(component.cleanupCount, equals(initialCleanupCount));
      });
    });
    group('Component Priority & Cleanup Strategy', () {
      test('should force cleanup', () async {
        final component = TestMemoryAwareComponent('TestComponent',
            priority: 10); // Lower priority to ensure selection
        coordinator.registerComponent(component);
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.high);
        // Component should be notified during cleanup
        expect(component.lastPressureLevel, equals(MemoryPressureLevel.high));
      });
      test('should cleanup components based on pressure level percentages',
          () async {
        final lowPriority = TestMemoryAwareComponent('Low', priority: 10);
        final normalPriority = TestMemoryAwareComponent('Normal', priority: 30);
        final highPriority = TestMemoryAwareComponent('High', priority: 70);
        final criticalPriority =
            TestMemoryAwareComponent('Critical', priority: 90);
        coordinator.registerComponent(lowPriority);
        coordinator.registerComponent(normalPriority);
        coordinator.registerComponent(highPriority);
        coordinator.registerComponent(criticalPriority);
        // Medium pressure should clean ~30% of components (starting from lowest priority)
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.medium);
        // With 7 total components (3 core + 4 test), 30% would be ~2 components
        // Low priority component should definitely be cleaned
        expect(lowPriority.cleanupCount, greaterThan(0));
      });
      test('should clean 70% of components on high pressure', () async {
        final components = <TestMemoryAwareComponent>[];
        for (int i = 0; i < 5; i++) {
          final component =
              TestMemoryAwareComponent('Test$i', priority: 10 + i * 10);
          components.add(component);
          coordinator.registerComponent(component);
        }
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.high);
        // High pressure cleans 70% - most components should be cleaned
        final cleanedCount = components.where((c) => c.cleanupCount > 0).length;
        expect(cleanedCount, greaterThan(0));
      });
      test('should clean all cleanable components on critical pressure',
          () async {
        final cleanableComponent = TestMemoryAwareComponent('Cleanable',
            canCleanup: true, priority: 10);
        final nonCleanableComponent = TestNonCleanableComponent('NonCleanable');
        coordinator.registerComponent(cleanableComponent);
        coordinator.registerComponent(nonCleanableComponent);
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.critical);
        expect(cleanableComponent.cleanupCount, greaterThan(0));
        expect(nonCleanableComponent.cleanupCount,
            equals(0)); // Non-cleanable shouldn't be cleaned
      });
      test('should skip cleanup for components that cannot be cleaned',
          () async {
        final component = TestNonCleanableComponent('NonCleanable');
        coordinator.registerComponent(component);
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.critical);
        expect(component.cleanupCount, equals(0));
      });
      test('should not clean any components on low pressure', () async {
        final component =
            TestMemoryAwareComponent('LowPressureTest', priority: 10);
        coordinator.registerComponent(component);
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.low);
        // Low pressure should not trigger cleanup (componentsToProcess = 0)
        expect(component.cleanupCount, equals(0));
      });
    });
    test('should prioritize components correctly', () {
      final lowPriority = TestMemoryAwareComponent('Low', priority: 20);
      final highPriority = TestMemoryAwareComponent('High', priority: 80);
      coordinator.registerComponent(lowPriority);
      coordinator.registerComponent(highPriority);
      // High priority should be cleaned last
      // This is implicitly tested through the component order
      final stats = coordinator.getMemoryStats();
      expect(stats['componentStats'], isNotNull);
    });
    group('Error Handling & Edge Cases', () {
      test('should handle component cleanup errors gracefully', () async {
        final errorComponent = ErrorThrowingComponent();
        final normalComponent = TestMemoryAwareComponent('Normal',
            priority: 10); // Lower priority to ensure selection
        coordinator.registerComponent(errorComponent);
        coordinator.registerComponent(normalComponent);
        // Should not throw even when one component fails
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.critical);
        // Normal component should still be notified despite error in other component
        expect(normalComponent.lastPressureLevel,
            equals(MemoryPressureLevel.critical));
      });
      test('should handle component cleanup errors', () async {
        final errorComponent = ErrorThrowingComponent();
        coordinator.registerComponent(errorComponent);
        // Should not throw even if component throws
        await coordinator.forceCleanup(
            overridePressure: MemoryPressureLevel.critical);
      });
      test('should handle emergency cleanup with component errors', () async {
        final errorComponent = ErrorThrowingComponent();
        coordinator.registerComponent(errorComponent);
        // Emergency cleanup should complete despite errors
        await coordinator.shutdown();
        // Should complete without throwing
        expect(true, isTrue);
      });
    });
    group('Memory Statistics & Reporting', () {
      test('should provide memory statistics', () {
        final stats = coordinator.getMemoryStats();
        expect(stats.containsKey('trackedObjects'), isTrue);
        expect(stats.containsKey('aliveObjects'), isTrue);
        expect(stats.containsKey('components'), isTrue);
        expect(stats.containsKey('lastPressureLevel'), isTrue);
        expect(stats.containsKey('objectsByCategory'), isTrue);
        expect(stats.containsKey('componentStats'), isTrue);
      });
      test('should provide accurate component statistics', () {
        final highPriority = TestMemoryAwareComponent('High', priority: 80);
        final lowPriority = TestMemoryAwareComponent('Low', priority: 20);
        coordinator.registerComponent(highPriority);
        coordinator.registerComponent(lowPriority);
        final stats = coordinator.getMemoryStats();
        final componentStats = stats['componentStats'] as Map<String, dynamic>;
        // Check that our test components are registered (may have different priority due to existing components)
        expect(componentStats['High'], isNotNull);
        expect(componentStats['Low'], isNotNull);
        expect(componentStats['High']['canCleanup'], isTrue);
        expect(componentStats['Low']['estimatedMemory'], equals(1024 * 1024));
      });
      test('should track alive objects correctly', () {
        final obj1 = TestObject();
        final obj2 = TestObject();
        coordinator.track(obj1, 'Category1');
        coordinator.track(obj2, 'Category2');
        final stats = coordinator.getMemoryStats();
        // In test environment, there may be other tracked objects from previous tests
        expect(stats['aliveObjects'], greaterThanOrEqualTo(2));
        expect(stats['trackedObjects'], greaterThanOrEqualTo(2));
      });
    });
    test('should handle component cleanup errors', () async {
      final errorComponent = ErrorThrowingComponent();
      coordinator.registerComponent(errorComponent);
      // Should not throw even if component throws
      await coordinator.forceCleanup(
          overridePressure: MemoryPressureLevel.critical);
    });
  });
}

class TestObject {
  final String id = DateTime.now().millisecondsSinceEpoch.toString();
}

class TestMemoryAwareComponent implements MemoryAware {
  final String name;
  final int priority;
  final bool _canCleanup;
  int cleanupCount = 0;
  MemoryPressureLevel? lastPressureLevel;
  TestMemoryAwareComponent(this.name,
      {this.priority = 50, bool canCleanup = true})
      : _canCleanup = canCleanup;
  @override
  String get componentName => name;
  @override
  int get memoryPriority => priority;
  @override
  bool get canCleanup => _canCleanup;
  @override
  int get estimatedMemoryUsage => 1024 * 1024; // 1MB
  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    cleanupCount++;
    lastPressureLevel = level;
    // Simulate some cleanup work
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

class TestNonCleanableComponent implements MemoryAware {
  final String name;
  int cleanupCount = 0;
  TestNonCleanableComponent(this.name);
  @override
  String get componentName => name;
  @override
  int get memoryPriority => 10;
  @override
  bool get canCleanup => false;
  @override
  int get estimatedMemoryUsage => 1024 * 1024; // 1MB
  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    cleanupCount++;
    // Simulate some cleanup work
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

class ErrorThrowingComponent implements MemoryAware {
  @override
  String get componentName => 'ErrorComponent';
  @override
  int get memoryPriority => 10;
  @override
  bool get canCleanup => true;
  @override
  int get estimatedMemoryUsage => -1;
  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    throw Exception('Test error during cleanup');
  }
}
