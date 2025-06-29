// lib/src/core/util/memory_manager.dart
//
// Memory management utilities for the CustomFit SDK.
// Provides memory optimization, leak detection, and cleanup functionality.
// Helps maintain efficient memory usage across the SDK components.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:collection';
import '../../logging/logger.dart';
import '../memory/memory_aware.dart';
import '../memory/memory_pressure_level.dart';

/// Memory management utility for the CustomFit SDK
class MemoryManager implements MemoryAware {
  static const _source = 'MemoryManager';

  // Weak references to track objects
  static final Set<WeakReference<Object>> _trackedObjects =
      <WeakReference<Object>>{};
  static final Map<String, int> _allocationCounts = <String, int>{};
  static final Map<String, DateTime> _lastCleanup = <String, DateTime>{};

  // Memory optimization settings
  static const int _maxCacheSize = 1000;
  static const int _cleanupIntervalMs = 300000; // 5 minutes
  static const int _maxIdleTimeMs = 600000; // 10 minutes

  static Timer? _cleanupTimer;
  static bool _initialized = false;

  // Adaptive cleanup settings
  static bool _adaptiveCleanupEnabled = false;
  static DateTime _lastAdaptiveCleanup = DateTime.now();
  static int _adaptiveCleanupCount = 0;

  /// Initialize the memory manager
  ///
  /// Sets up automatic cleanup and monitoring.
  /// Call this once during SDK initialization.
  ///
  /// ## Example
  ///
  /// ```dart
  /// MemoryManager.initialize();
  /// ```
  static void initialize() {
    if (_initialized) {
      Logger.w('$_source: Already initialized');
      return;
    }

    _initialized = true;
    _startPeriodicCleanup();
    Logger.i('$_source: Memory manager initialized');
  }

  /// Shutdown the memory manager
  ///
  /// Stops automatic cleanup and clears all tracked objects.
  /// Call this during SDK shutdown.
  ///
  /// ## Example
  ///
  /// ```dart
  /// MemoryManager.shutdown();
  /// ```
  static void shutdown() {
    if (!_initialized) return;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _trackedObjects.clear();
    _allocationCounts.clear();
    _lastCleanup.clear();
    _initialized = false;
    Logger.i('$_source: Memory manager shutdown');
  }

  /// Track an object for memory management
  ///
  /// Adds an object to the tracking system for automatic cleanup
  /// and memory leak detection.
  ///
  /// ## Parameters
  ///
  /// - [object]: The object to track
  /// - [category]: Optional category for grouping (default: object type)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final eventTracker = EventTracker();
  /// MemoryManager.trackObject(eventTracker, 'EventTracker');
  /// ```
  static void trackObject(Object object, [String? category]) {
    if (!_initialized) {
      Logger.w('$_source: Not initialized, skipping object tracking');
      return;
    }

    final weakRef = WeakReference(object);
    _trackedObjects.add(weakRef);

    final cat = category ?? object.runtimeType.toString();
    _allocationCounts[cat] = (_allocationCounts[cat] ?? 0) + 1;

    Logger.d(
        '$_source: Tracking object of type $cat (total: ${_allocationCounts[cat]})');
  }

  /// Force garbage collection and cleanup
  ///
  /// Triggers immediate cleanup of dead references and
  /// attempts to free unused memory.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Before memory-intensive operation
  /// MemoryManager.forceCleanup();
  /// ```
  static void forceCleanup() {
    Logger.d('$_source: Starting forced cleanup');

    // Clean up dead weak references
    _cleanupDeadReferences();

    // Clear old cache entries
    _cleanupOldCacheEntries();

    // Log memory statistics
    _logMemoryStats();

    Logger.d('$_source: Forced cleanup completed');
  }

  /// Get current memory statistics
  ///
  /// Returns detailed information about tracked objects
  /// and memory usage patterns.
  ///
  /// ## Returns
  ///
  /// Map containing memory statistics and allocation counts.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final stats = MemoryManager.getMemoryStats();
  /// print('Tracked objects: ${stats['tracked_objects']}');
  /// print('Allocations: ${stats['allocations']}');
  /// ```
  static Map<String, dynamic> getMemoryStats() {
    return {
      'tracked_objects': _trackedObjects.length,
      'allocation_counts': Map<String, int>.from(_allocationCounts),
      'initialized': _initialized,
      'cleanup_timer_active': _cleanupTimer?.isActive ?? false,
      'last_cleanup': _lastCleanup,
    };
  }

  /// Create a weak cache for temporary storage
  ///
  /// Creates a cache that automatically removes entries
  /// when objects are garbage collected.
  ///
  /// ## Parameters
  ///
  /// - [maxSize]: Maximum number of entries (default: 100)
  ///
  /// ## Returns
  ///
  /// A [WeakCache] instance for temporary storage.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final cache = MemoryManager.createWeakCache<String>(50);
  /// cache.put('key', 'value');
  /// final value = cache.get('key');
  /// ```
  static WeakCache<T> createWeakCache<T extends Object>([int maxSize = 100]) {
    return WeakCache<T>(maxSize);
  }

  /// Optimize memory usage for a specific component
  ///
  /// Performs targeted cleanup and optimization for a
  /// specific component or category of objects.
  ///
  /// ## Parameters
  ///
  /// - [category]: The component category to optimize
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Optimize event tracker memory usage
  /// MemoryManager.optimizeComponent('EventTracker');
  /// ```
  static void optimizeComponent(String category) {
    Logger.d('$_source: Optimizing component: $category');

    // Remove dead references for this category
    int removedCount = 0;
    _trackedObjects.removeWhere((weakRef) {
      final obj = weakRef.target;
      if (obj == null || obj.runtimeType.toString() == category) {
        if (obj == null) removedCount++;
        return true;
      }
      return false;
    });

    // Update allocation count
    if (removedCount > 0) {
      _allocationCounts[category] =
          (_allocationCounts[category] ?? 0) - removedCount;
      if (_allocationCounts[category]! <= 0) {
        _allocationCounts.remove(category);
      }
    }

    _lastCleanup[category] = DateTime.now();
    Logger.d(
        '$_source: Component optimization completed for $category (removed: $removedCount)');
  }

  /// Check for potential memory leaks
  ///
  /// Analyzes allocation patterns to detect potential
  /// memory leaks or excessive object creation.
  ///
  /// ## Returns
  ///
  /// List of warnings about potential memory issues.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final warnings = MemoryManager.checkForLeaks();
  /// for (final warning in warnings) {
  ///   print('Memory warning: $warning');
  /// }
  /// ```
  static List<String> checkForLeaks() {
    final warnings = <String>[];

    // Check for excessive allocations
    _allocationCounts.forEach((category, count) {
      if (count > 100) {
        warnings.add('High allocation count for $category: $count objects');
      }
    });

    // Check for objects that haven't been cleaned up
    final now = DateTime.now();
    _lastCleanup.forEach((category, lastCleanup) {
      final timeSinceCleanup = now.difference(lastCleanup).inMilliseconds;
      if (timeSinceCleanup > _maxIdleTimeMs) {
        warnings.add(
            'Category $category has not been cleaned up for ${timeSinceCleanup ~/ 60000} minutes');
      }
    });

    return warnings;
  }

  // Private methods

  static void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(
      const Duration(milliseconds: _cleanupIntervalMs),
      (_) => _performPeriodicCleanup(),
    );
  }

  static void _performPeriodicCleanup() {
    Logger.d('$_source: Starting periodic cleanup');

    _cleanupDeadReferences();
    _cleanupOldCacheEntries();

    // Check for memory warnings
    final warnings = checkForLeaks();
    if (warnings.isNotEmpty) {
      Logger.w('$_source: Memory warnings detected:');
      for (final warning in warnings) {
        Logger.w('  - $warning');
      }
    }

    Logger.d('$_source: Periodic cleanup completed');
  }

  static void _cleanupDeadReferences() {
    final initialCount = _trackedObjects.length;

    // Remove dead weak references
    _trackedObjects.removeWhere((weakRef) => weakRef.target == null);

    final removedCount = initialCount - _trackedObjects.length;
    if (removedCount > 0) {
      Logger.d('$_source: Cleaned up $removedCount dead references');
    }
  }

  static void _cleanupOldCacheEntries() {
    final now = DateTime.now();
    final cutoffTime =
        now.subtract(const Duration(milliseconds: _maxIdleTimeMs));

    // Clean up old cleanup timestamps
    _lastCleanup.removeWhere((category, lastCleanup) {
      return lastCleanup.isBefore(cutoffTime);
    });
  }

  static void _logMemoryStats() {
    Logger.d(
        '$_source: Memory stats - Tracked: ${_trackedObjects.length}, Allocations: $_allocationCounts');
  }

  /// Enable adaptive cleanup based on memory pressure
  static void enableAdaptiveCleanup() {
    _adaptiveCleanupEnabled = true;
    Logger.i('$_source: Adaptive cleanup enabled');
  }

  /// Disable adaptive cleanup
  static void disableAdaptiveCleanup() {
    _adaptiveCleanupEnabled = false;
    Logger.i('$_source: Adaptive cleanup disabled');
  }

  /// Perform adaptive cleanup based on pressure level
  /// Called by MemoryCoordinator
  static void performAdaptiveCleanup({bool aggressive = false}) {
    if (!_initialized) return;

    final now = DateTime.now();
    final timeSinceLastCleanup = now.difference(_lastAdaptiveCleanup).inSeconds;

    // Prevent too frequent cleanups
    if (!aggressive && timeSinceLastCleanup < 10) {
      return;
    }

    _lastAdaptiveCleanup = now;
    _adaptiveCleanupCount++;

    Logger.d(
        '$_source: Performing adaptive cleanup (aggressive: $aggressive, count: $_adaptiveCleanupCount)');

    if (aggressive) {
      // Aggressive cleanup for high/critical pressure
      clearWeakReferences();
      _allocationCounts.clear();
      _lastCleanup.clear();
    } else {
      // Standard cleanup for medium pressure
      _cleanupDeadReferences();

      // Clean up categories with high allocation counts
      final highAllocationCategories = _allocationCounts.entries
          .where((e) => e.value > 50)
          .map((e) => e.key)
          .toList();

      for (final category in highAllocationCategories) {
        optimizeComponent(category);
      }
    }

    _logMemoryStats();
  }

  /// Clear all weak references
  static void clearWeakReferences() {
    final count = _trackedObjects.length;
    _trackedObjects.clear();
    Logger.i('$_source: Cleared $count weak references');
  }

  // MemoryAware implementation
  @override
  String get componentName => 'MemoryManager';

  @override
  int get memoryPriority => MemoryPriority.critical;

  @override
  bool get canCleanup => true;

  @override
  int get estimatedMemoryUsage => -1;

  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    switch (level) {
      case MemoryPressureLevel.low:
        // No action needed
        break;
      case MemoryPressureLevel.medium:
        // Perform standard cleanup
        forceCleanup();
        break;
      case MemoryPressureLevel.high:
        // Aggressive cleanup
        performAdaptiveCleanup(aggressive: false);
        break;
      case MemoryPressureLevel.critical:
        // Emergency cleanup
        clearWeakReferences();
        performAdaptiveCleanup(aggressive: true);
        break;
    }
  }

  /// Get singleton instance for MemoryAware registration
  static final MemoryManager _instance = MemoryManager._internal();
  MemoryManager._internal();
  static MemoryManager get instance => _instance;
}

/// Weak cache implementation for temporary storage
class WeakCache<T extends Object> {
  final int _maxSize;
  final Map<String, WeakReference<T>> _cache = <String, WeakReference<T>>{};
  final Queue<String> _accessOrder = Queue<String>();

  WeakCache(this._maxSize);

  /// Get a value from the cache
  T? get(String key) {
    final weakRef = _cache[key];
    if (weakRef != null) {
      final value = weakRef.target;
      if (value != null) {
        // Update access order
        _accessOrder.remove(key);
        _accessOrder.addLast(key);
        return value;
      } else {
        // Dead reference, remove it
        _cache.remove(key);
        _accessOrder.remove(key);
      }
    }
    return null;
  }

  /// Put a value in the cache
  void put(String key, T value) {
    // Remove if already exists
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
    }

    // Add new entry
    _cache[key] = WeakReference(value);
    _accessOrder.addLast(key);

    // Evict if necessary
    while (_cache.length > _maxSize && _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.removeFirst();
      _cache.remove(oldestKey);
    }
  }

  /// Remove a value from the cache
  void remove(String key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  /// Clear the entire cache
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// Get cache size
  int get size => _cache.length;

  /// Check if cache contains key
  bool containsKey(String key) {
    final weakRef = _cache[key];
    if (weakRef != null) {
      final value = weakRef.target;
      if (value != null) {
        return true;
      } else {
        // Dead reference, clean it up
        _cache.remove(key);
        _accessOrder.remove(key);
      }
    }
    return false;
  }
}
