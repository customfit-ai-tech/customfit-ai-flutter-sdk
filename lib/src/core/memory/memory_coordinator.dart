import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../logging/logger.dart';
import '../util/memory_manager.dart';
import '../util/cache_manager.dart';
import '../../monitoring/memory_profiler.dart';
import '../resource_registry.dart';
import 'memory_pressure_level.dart';
import 'memory_pressure_monitor.dart';
import 'memory_aware.dart';
import 'platform/memory_platform_interface.dart' as platform;

/// Coordinates memory management across all SDK components
class MemoryCoordinator implements MemoryPressureListener {
  static MemoryCoordinator? _instance;
  static MemoryCoordinator get instance => _instance ??= MemoryCoordinator._();

  final List<MemoryAware> _components = [];
  final Map<String, WeakReference<Object>> _trackedObjects = {};
  final Map<String, int> _objectCounts = {};
  final Map<Object, String> _objectToId = {};
  final _uuid = const Uuid();

  bool _isInitialized = false;
  MemoryPressureLevel _lastPressureLevel = MemoryPressureLevel.low;
  ManagedTimer? _cleanupTimer;
  bool _isShutdown = false;

  // Configuration
  Duration _adaptiveCleanupInterval = const Duration(minutes: 5);
  final bool _aggressiveCleanupEnabled = true;
  final bool _autoTrackingEnabled = true;

  MemoryCoordinator._();

  /// Initialize the memory coordinator
  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.w('MemoryCoordinator already initialized');
      return;
    }

    _isInitialized = true;
    Logger.i('Initializing MemoryCoordinator');

    // Register with memory pressure monitor
    MemoryPressureMonitor.instance.addListener(this);

    // Register core components
    _registerCoreComponents();

    // Start monitoring
    MemoryPressureMonitor.instance.startMonitoring();

    // Start adaptive cleanup timer
    _startAdaptiveCleanup();

    Logger.i(
        'MemoryCoordinator initialized with ${_components.length} components');
  }

  /// Shutdown the coordinator
  Future<void> shutdown() async {
    if (!_isInitialized || _isShutdown) return;

    _isShutdown = true;
    Logger.i('Shutting down MemoryCoordinator');

    _cleanupTimer?.dispose();
    _cleanupTimer = null;

    MemoryPressureMonitor.instance.removeListener(this);
    MemoryPressureMonitor.instance.stopMonitoring();

    // Cleanup all tracked objects
    await _performEmergencyCleanup();

    _components.clear();
    _trackedObjects.clear();
    _objectCounts.clear();
    _objectToId.clear();
    _isInitialized = false;
  }

  /// Reset the singleton instance (for testing)
  static void reset() {
    _instance?.shutdown();
    _instance = null;
  }

  /// Register a memory-aware component
  void registerComponent(MemoryAware component) {
    if (_components.any((c) => c.componentName == component.componentName)) {
      Logger.w('Component ${component.componentName} already registered');
      return;
    }

    _components.add(component);

    // Sort by priority (higher priority = less likely to be cleaned)
    _components.sort((a, b) => b.memoryPriority.compareTo(a.memoryPriority));

    Logger.d(
        'Registered component: ${component.componentName} (priority: ${component.memoryPriority})');
  }

  /// Unregister a component
  void unregisterComponent(MemoryAware component) {
    _components.removeWhere((c) => c.componentName == component.componentName);
    Logger.d('Unregistered component: ${component.componentName}');
  }

  /// Track an object for automatic lifecycle management
  void track<T>(T object, String category) {
    if (!_autoTrackingEnabled) return;

    final obj = object as Object;

    // Check if object is already tracked
    if (_objectToId.containsKey(obj)) {
      Logger.w('Object already tracked in category: $category');
      return;
    }

    // Generate unique ID for this object
    final id = _uuid.v4();
    final key = '${category}_$id';

    _trackedObjects[key] = WeakReference(obj);
    _objectToId[obj] = key;

    // Update count
    _objectCounts[category] = (_objectCounts[category] ?? 0) + 1;

    Logger.d(
        'Tracking object in category: $category (total: ${_objectCounts[category]})');
  }

  /// Untrack an object
  void untrack(Object object) {
    final foundKey = _objectToId[object];

    if (foundKey != null) {
      _trackedObjects.remove(foundKey);
      _objectToId.remove(object);

      // Extract category by removing the UUID part
      final parts = foundKey.split('_');
      final category = parts.sublist(0, parts.length - 1).join('_');
      _objectCounts[category] = (_objectCounts[category] ?? 1) - 1;
      Logger.d('Untracked object from category: $category');
    }
  }

  /// Get memory statistics
  Map<String, dynamic> getMemoryStats() {
    final stats = <String, dynamic>{
      'trackedObjects': _trackedObjects.length,
      'aliveObjects': _countAliveObjects(),
      'components': _components.length,
      'lastPressureLevel': _lastPressureLevel.name,
      'objectsByCategory': Map.from(_objectCounts),
    };

    // Add component stats
    final componentStats = <String, dynamic>{};
    for (final component in _components) {
      componentStats[component.componentName] = {
        'priority': component.memoryPriority,
        'estimatedMemory': component.estimatedMemoryUsage,
        'canCleanup': component.canCleanup,
      };
    }
    stats['componentStats'] = componentStats;

    return stats;
  }

  /// Force a memory cleanup based on current pressure
  Future<void> forceCleanup({MemoryPressureLevel? overridePressure}) async {
    // Clean dead references first
    _performAdaptiveCleanup();

    final pressure = overridePressure ?? _lastPressureLevel;
    await _respondToPressure(pressure);
  }

  @override
  void onMemoryPressureChanged(
      MemoryPressureLevel level, platform.MemoryInfo memoryInfo) {
    Logger.i(
        'Memory pressure changed to: ${level.name} (${(memoryInfo.usageRatio * 100).toStringAsFixed(1)}% usage)');
    _lastPressureLevel = level;

    // Clean dead references immediately
    _performAdaptiveCleanup();

    // Respond immediately to high/critical pressure
    if (level.requiresAction) {
      // Use Future.microtask to ensure cleanup happens soon but doesn't block
      Future.microtask(() => _respondToPressure(level));
    }

    // Adjust cleanup interval based on pressure
    _adjustCleanupInterval(level);
  }

  void _registerCoreComponents() {
    // Register MemoryManager directly
    registerComponent(MemoryManager.instance);

    // Register CacheManager directly
    registerComponent(CacheManager.instance);

    // Register MemoryProfiler adapter if available
    final profilerAdapter = _MemoryProfilerAdapter();
    registerComponent(profilerAdapter);
  }

  void _startAdaptiveCleanup() {
    if (_isShutdown) return;

    _cleanupTimer?.dispose();

    _cleanupTimer = ManagedTimer.periodic(
      owner: 'MemoryCoordinator',
      duration: _adaptiveCleanupInterval,
      callback: (_) {
        if (_isShutdown) return;
        _performAdaptiveCleanup();
      },
    );
  }

  void _adjustCleanupInterval(MemoryPressureLevel level) {
    Duration newInterval;

    switch (level) {
      case MemoryPressureLevel.low:
        newInterval = const Duration(minutes: 10);
        break;
      case MemoryPressureLevel.medium:
        newInterval = const Duration(minutes: 5);
        break;
      case MemoryPressureLevel.high:
        newInterval = const Duration(minutes: 1);
        break;
      case MemoryPressureLevel.critical:
        newInterval = const Duration(seconds: 30);
        break;
    }

    if (newInterval != _adaptiveCleanupInterval) {
      _adaptiveCleanupInterval = newInterval;
      _startAdaptiveCleanup();
      Logger.d('Adjusted cleanup interval to: ${newInterval.inSeconds}s');
    }
  }

  Future<void> _respondToPressure(MemoryPressureLevel level) async {
    Logger.i('Responding to memory pressure: ${level.name}');

    final stopwatch = Stopwatch()..start();
    final results = <MemoryCleanupResult>[];

    // Notify components in reverse priority order (lowest priority first)
    final componentsToClean = _components.where((c) => c.canCleanup).toList();

    // Determine how many components to clean based on pressure
    int componentsToProcess;
    switch (level) {
      case MemoryPressureLevel.low:
        componentsToProcess = 0; // No cleanup needed
        break;
      case MemoryPressureLevel.medium:
        componentsToProcess =
            (componentsToClean.length * 0.3).ceil(); // Clean 30%
        break;
      case MemoryPressureLevel.high:
        componentsToProcess =
            (componentsToClean.length * 0.7).ceil(); // Clean 70%
        break;
      case MemoryPressureLevel.critical:
        componentsToProcess = componentsToClean.length; // Clean all
        break;
    }

    // Clean components starting from lowest priority
    for (int i = componentsToClean.length - 1;
        i >= componentsToClean.length - componentsToProcess && i >= 0;
        i--) {
      final component = componentsToClean[i];

      try {
        final componentStopwatch = Stopwatch()..start();
        await component.onMemoryPressure(level);
        componentStopwatch.stop();

        results.add(MemoryCleanupResult(
          componentName: component.componentName,
          bytesFreed: 0, // Component should report this
          success: true,
          duration: componentStopwatch.elapsed,
        ));
      } catch (e) {
        Logger.e('Error cleaning component ${component.componentName}: $e');
        results.add(MemoryCleanupResult(
          componentName: component.componentName,
          bytesFreed: 0,
          success: false,
          error: e.toString(),
          duration: Duration.zero,
        ));
      }
    }

    // Clean tracked objects
    if (level == MemoryPressureLevel.critical) {
      _cleanupTrackedObjects();
    }

    stopwatch.stop();

    // Log results
    final totalFreed = results.fold<int>(0, (sum, r) => sum + r.bytesFreed);
    final successCount = results.where((r) => r.success).length;

    Logger.i(
        'Memory cleanup completed: $successCount/${results.length} components cleaned, '
        '~${(totalFreed / 1024 / 1024).toStringAsFixed(1)}MB freed in ${stopwatch.elapsedMilliseconds}ms');
  }

  void _performAdaptiveCleanup() {
    // Clean dead weak references
    final deadKeys = <String>[];
    for (final entry in _trackedObjects.entries) {
      if (entry.value.target == null) {
        deadKeys.add(entry.key);
      }
    }

    for (final key in deadKeys) {
      _trackedObjects.remove(key);
      // Extract category by removing the UUID part
      final parts = key.split('_');
      final category = parts.sublist(0, parts.length - 1).join('_');
      _objectCounts[category] = (_objectCounts[category] ?? 1) - 1;

      // Clean up the reverse mapping
      _objectToId.removeWhere((obj, id) => id == key);
    }

    if (deadKeys.isNotEmpty) {
      Logger.d('Cleaned ${deadKeys.length} dead references');
    }

    // Trigger component cleanup if needed
    if (_lastPressureLevel != MemoryPressureLevel.low) {
      // Fire and forget - don't await to avoid blocking
      Future.microtask(() => _respondToPressure(_lastPressureLevel));
    }
  }

  void _cleanupTrackedObjects() {
    Logger.d('Performing emergency cleanup of tracked objects');

    int cleaned = 0;
    final keysToRemove = <String>[];

    for (final entry in _trackedObjects.entries) {
      if (entry.value.target == null) {
        keysToRemove.add(entry.key);
        cleaned++;
      }
    }

    for (final key in keysToRemove) {
      _trackedObjects.remove(key);
    }

    Logger.i('Emergency cleanup removed $cleaned dead references');
  }

  Future<void> _performEmergencyCleanup() async {
    Logger.w('Performing emergency memory cleanup');

    // Clean all components
    for (final component in _components) {
      try {
        await component.onMemoryPressure(MemoryPressureLevel.critical);
      } catch (e) {
        Logger.e('Emergency cleanup failed for ${component.componentName}: $e');
      }
    }

    // Clear all tracked objects
    _trackedObjects.clear();
    _objectCounts.clear();
    _objectToId.clear();
  }

  int _countAliveObjects() {
    return _trackedObjects.values.where((ref) => ref.target != null).length;
  }
}

// Note: MemoryManagerAdapter and CacheManagerAdapter have been removed
// MemoryManager and CacheManager now implement MemoryAware directly

/// Adapter for MemoryProfiler
class _MemoryProfilerAdapter implements MemoryAware {
  @override
  String get componentName => 'MemoryProfiler';

  @override
  int get memoryPriority => MemoryPriority.low;

  @override
  bool get canCleanup => true;

  @override
  int get estimatedMemoryUsage => -1;

  @override
  Future<void> onMemoryPressure(MemoryPressureLevel level) async {
    if (level == MemoryPressureLevel.critical) {
      // Clear profiler data under critical pressure
      MemoryProfiler.cleanup();
    }
  }
}
