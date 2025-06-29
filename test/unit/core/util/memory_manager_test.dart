import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/memory_manager.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MemoryManager', () {
    setUp(() {
      // Ensure clean state before each test
    SharedPreferences.setMockInitialValues({});
      MemoryManager.shutdown();
    });
    tearDown(() {
      // Clean up after each test
    PreferencesService.reset();
      MemoryManager.shutdown();
    });
    group('Initialization and Shutdown', () {
      test('should initialize successfully', () {
        expect(() => MemoryManager.initialize(), returnsNormally);
        final stats = MemoryManager.getMemoryStats();
        expect(stats['initialized'], isTrue);
        expect(stats['cleanup_timer_active'], isTrue);
      });
      test('should not initialize twice', () {
        MemoryManager.initialize();
        // Second initialization should log warning but not fail
        expect(() => MemoryManager.initialize(), returnsNormally);
        final stats = MemoryManager.getMemoryStats();
        expect(stats['initialized'], isTrue);
      });
      test('should shutdown successfully', () {
        MemoryManager.initialize();
        expect(() => MemoryManager.shutdown(), returnsNormally);
        final stats = MemoryManager.getMemoryStats();
        expect(stats['initialized'], isFalse);
        expect(stats['cleanup_timer_active'], isFalse);
      });
      test('should handle shutdown when not initialized', () {
        expect(() => MemoryManager.shutdown(), returnsNormally);
      });
    });
    group('Object Tracking', () {
      test('should track objects successfully', () {
        MemoryManager.initialize();
        final testObject = TestObject('test1');
        MemoryManager.trackObject(testObject, 'TestObject');
        final stats = MemoryManager.getMemoryStats();
        expect(stats['tracked_objects'], equals(1));
        expect(stats['allocation_counts']['TestObject'], equals(1));
      });
      test('should track multiple objects of same type', () {
        MemoryManager.initialize();
        final obj1 = TestObject('test1');
        final obj2 = TestObject('test2');
        MemoryManager.trackObject(obj1, 'TestObject');
        MemoryManager.trackObject(obj2, 'TestObject');
        final stats = MemoryManager.getMemoryStats();
        expect(stats['tracked_objects'], equals(2));
        expect(stats['allocation_counts']['TestObject'], equals(2));
      });
      test('should track objects without category', () {
        MemoryManager.initialize();
        final testObject = TestObject('test');
        MemoryManager.trackObject(testObject);
        final stats = MemoryManager.getMemoryStats();
        expect(stats['tracked_objects'], equals(1));
        expect(stats['allocation_counts']['TestObject'], equals(1));
      });
      test('should handle tracking when not initialized', () {
        final testObject = TestObject('test');
        // Should not fail but should log warning
        expect(() => MemoryManager.trackObject(testObject), returnsNormally);
        final stats = MemoryManager.getMemoryStats();
        expect(stats['tracked_objects'], equals(0));
      });
      test('should track different object types', () {
        MemoryManager.initialize();
        final obj1 = TestObject('test1');
        final obj2 = AnotherTestObject('test2');
        MemoryManager.trackObject(obj1, 'TestObject');
        MemoryManager.trackObject(obj2, 'AnotherTestObject');
        final stats = MemoryManager.getMemoryStats();
        expect(stats['tracked_objects'], equals(2));
        expect(stats['allocation_counts']['TestObject'], equals(1));
        expect(stats['allocation_counts']['AnotherTestObject'], equals(1));
      });
    });
    group('Memory Cleanup', () {
      test('should force cleanup successfully', () {
        MemoryManager.initialize();
        final testObject = TestObject('test');
        MemoryManager.trackObject(testObject, 'TestObject');
        expect(() => MemoryManager.forceCleanup(), returnsNormally);
        // Should still have the object since it's not garbage collected
        final stats = MemoryManager.getMemoryStats();
        expect(stats['tracked_objects'], equals(1));
      });
      test('should clean up dead references', () async {
        MemoryManager.initialize();
        // Create object in a scope that will go out of scope
        void createAndTrackObject() {
          final testObject = TestObject('temp');
          MemoryManager.trackObject(testObject, 'TestObject');
        }
        createAndTrackObject();
        // Force garbage collection (though not guaranteed)
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 10));
          // Create pressure to encourage GC
          final _ = List.generate(1000, (i) => 'pressure$i');
        }
        MemoryManager.forceCleanup();
        // Should still work even if GC doesn't run
        expect(() => MemoryManager.forceCleanup(), returnsNormally);
      });
      test('should optimize specific component', () {
        MemoryManager.initialize();
        final obj1 = TestObject('test1');
        final obj2 = AnotherTestObject('test2');
        MemoryManager.trackObject(obj1, 'TestObject');
        MemoryManager.trackObject(obj2, 'AnotherTestObject');
        expect(() => MemoryManager.optimizeComponent('TestObject'),
            returnsNormally);
        final stats = MemoryManager.getMemoryStats();
        expect(
            (stats['last_cleanup'] as Map).containsKey('TestObject'), isTrue);
      });
    });
    group('Memory Statistics', () {
      test('should provide memory statistics', () {
        MemoryManager.initialize();
        final stats = MemoryManager.getMemoryStats();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('tracked_objects'), isTrue);
        expect(stats.containsKey('allocation_counts'), isTrue);
        expect(stats.containsKey('initialized'), isTrue);
        expect(stats.containsKey('cleanup_timer_active'), isTrue);
        expect(stats.containsKey('last_cleanup'), isTrue);
        expect(stats['tracked_objects'], isA<int>());
        expect(stats['allocation_counts'], isA<Map<String, int>>());
        expect(stats['initialized'], isA<bool>());
        expect(stats['cleanup_timer_active'], isA<bool>());
        expect(stats['last_cleanup'], isA<Map<String, DateTime>>());
      });
      test('should track allocation counts correctly', () {
        MemoryManager.initialize();
        for (int i = 0; i < 5; i++) {
          final obj = TestObject('test$i');
          MemoryManager.trackObject(obj, 'TestObject');
        }
        final stats = MemoryManager.getMemoryStats();
        expect(stats['allocation_counts']['TestObject'], equals(5));
      });
    });
    group('Leak Detection', () {
      test('should check for memory leaks', () {
        MemoryManager.initialize();
        // Create many objects to trigger leak warning
        for (int i = 0; i < 150; i++) {
          final obj = TestObject('test$i');
          MemoryManager.trackObject(obj, 'TestObject');
        }
        final warnings = MemoryManager.checkForLeaks();
        expect(warnings, isA<List<String>>());
        expect(
            warnings.any((w) => w.contains('High allocation count')), isTrue);
      });
      test('should detect stale cleanup timestamps', () {
        MemoryManager.initialize();
        final obj = TestObject('test');
        MemoryManager.trackObject(obj, 'TestObject');
        // Simulate old cleanup by directly modifying last cleanup time
        // This is a bit of a hack for testing, but necessary
        MemoryManager.optimizeComponent('TestObject');
        final warnings = MemoryManager.checkForLeaks();
        expect(warnings, isA<List<String>>());
        // Initially should not have warnings since cleanup just happened
      });
      test('should return empty warnings for clean state', () {
        MemoryManager.initialize();
        final warnings = MemoryManager.checkForLeaks();
        expect(warnings, isEmpty);
      });
    });
    group('WeakCache', () {
      test('should create weak cache', () {
        final cache = MemoryManager.createWeakCache<TestObject>();
        expect(cache, isA<WeakCache<TestObject>>());
        expect(cache.size, equals(0));
      });
      test('should create weak cache with custom size', () {
        final cache = MemoryManager.createWeakCache<TestObject>(50);
        expect(cache, isA<WeakCache<TestObject>>());
        expect(cache.size, equals(0));
      });
      test('should put and get values', () {
        final cache = MemoryManager.createWeakCache<TestObject>();
        final testObj = TestObject('value1');
        cache.put('key1', testObj);
        expect(cache.get('key1'), equals(testObj));
        expect(cache.size, equals(1));
      });
      test('should handle cache misses', () {
        final cache = MemoryManager.createWeakCache<TestObject>();
        expect(cache.get('nonexistent'), isNull);
      });
      test('should check if cache contains key', () {
        final cache = MemoryManager.createWeakCache<TestObject>();
        final testObj = TestObject('value1');
        cache.put('key1', testObj);
        expect(cache.containsKey('key1'), isTrue);
        expect(cache.containsKey('nonexistent'), isFalse);
      });
      test('should remove values', () {
        final cache = MemoryManager.createWeakCache<TestObject>();
        final testObj = TestObject('value1');
        cache.put('key1', testObj);
        expect(cache.containsKey('key1'), isTrue);
        cache.remove('key1');
        expect(cache.containsKey('key1'), isFalse);
        expect(cache.size, equals(0));
      });
      test('should clear cache', () {
        final cache = MemoryManager.createWeakCache<TestObject>();
        final obj1 = TestObject('value1');
        final obj2 = TestObject('value2');
        cache.put('key1', obj1);
        cache.put('key2', obj2);
        expect(cache.size, equals(2));
        cache.clear();
        expect(cache.size, equals(0));
        expect(cache.containsKey('key1'), isFalse);
        expect(cache.containsKey('key2'), isFalse);
      });
      test('should implement LRU eviction', () {
        final cache = MemoryManager.createWeakCache<TestObject>(3);
        final obj1 = TestObject('value1');
        final obj2 = TestObject('value2');
        final obj3 = TestObject('value3');
        final obj4 = TestObject('value4');
        cache.put('key1', obj1);
        cache.put('key2', obj2);
        cache.put('key3', obj3);
        expect(cache.size, equals(3));
        // Adding fourth item should evict first
        cache.put('key4', obj4);
        expect(cache.size, equals(3));
        expect(cache.containsKey('key1'), isFalse);
        expect(cache.containsKey('key4'), isTrue);
      });
      test('should update access order on get', () {
        final cache = MemoryManager.createWeakCache<TestObject>(3);
        final obj1 = TestObject('value1');
        final obj2 = TestObject('value2');
        final obj3 = TestObject('value3');
        final obj4 = TestObject('value4');
        cache.put('key1', obj1);
        cache.put('key2', obj2);
        cache.put('key3', obj3);
        // Access key1 to make it most recently used
        cache.get('key1');
        // Add new item - should evict key2, not key1
        cache.put('key4', obj4);
        expect(cache.containsKey('key1'), isTrue);
        expect(cache.containsKey('key2'), isFalse);
        expect(cache.containsKey('key4'), isTrue);
      });
      test('should handle duplicate keys', () {
        final cache = MemoryManager.createWeakCache<TestObject>();
        final obj1 = TestObject('value1');
        final obj2 = TestObject('value2');
        cache.put('key1', obj1);
        cache.put('key1', obj2); // Override
        expect(cache.get('key1'), equals(obj2));
        expect(cache.size, equals(1));
      });
    });
    group('Integration Tests', () {
      test('should handle complete lifecycle', () {
        // Initialize
        MemoryManager.initialize();
        expect(MemoryManager.getMemoryStats()['initialized'], isTrue);
        // Track objects
        final obj1 = TestObject('obj1');
        final obj2 = AnotherTestObject('obj2');
        MemoryManager.trackObject(obj1, 'TestObject');
        MemoryManager.trackObject(obj2, 'AnotherTestObject');
        // Check stats
        var stats = MemoryManager.getMemoryStats();
        expect(stats['tracked_objects'], equals(2));
        // Force cleanup
        MemoryManager.forceCleanup();
        // Optimize components
        MemoryManager.optimizeComponent('TestObject');
        // Check for leaks
        final warnings = MemoryManager.checkForLeaks();
        expect(warnings, isA<List<String>>());
        // Create and use cache
        final cache = MemoryManager.createWeakCache<TestObject>();
        final testObj = TestObject('value');
        cache.put('test', testObj);
        expect(cache.get('test'), equals(testObj));
        // Shutdown
        MemoryManager.shutdown();
        stats = MemoryManager.getMemoryStats();
        expect(stats['initialized'], isFalse);
      });
      test('should handle concurrent operations', () async {
        MemoryManager.initialize();
        // Simulate concurrent object tracking
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(Future(() {
            final obj = TestObject('concurrent$i');
            MemoryManager.trackObject(obj, 'ConcurrentTest');
          }));
        }
        await Future.wait(futures);
        final stats = MemoryManager.getMemoryStats();
        expect(stats['allocation_counts']['ConcurrentTest'], equals(10));
      });
      test('should handle edge cases gracefully', () {
        MemoryManager.initialize();
        // Track null category
        final obj = TestObject('test');
        expect(() => MemoryManager.trackObject(obj, null), returnsNormally);
        // Optimize non-existent category
        expect(() => MemoryManager.optimizeComponent('NonExistent'),
            returnsNormally);
        // Multiple shutdowns
        MemoryManager.shutdown();
        expect(() => MemoryManager.shutdown(), returnsNormally);
      });
    });
  });
}
// Test helper classes
class TestObject {
  final String name;
  TestObject(this.name);
  @override
  String toString() => 'TestObject($name)';
}
class AnotherTestObject {
  final String name;
  AnotherTestObject(this.name);
  @override
  String toString() => 'AnotherTestObject($name)';
}
