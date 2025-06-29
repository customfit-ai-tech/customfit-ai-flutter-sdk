import 'dart:async';
import 'package:meta/meta.dart';
import '../logging/logger.dart';

/// Interface for resources that can be disposed
abstract class DisposableResource {
  /// Unique identifier for this resource
  String get resourceId;
  
  /// Type of resource (e.g., 'StreamController', 'Timer', 'Listener')
  String get resourceType;
  
  /// Dispose of this resource
  Future<void> dispose();
  
  /// Check if resource is already disposed
  bool get isDisposed;
}

/// Registry for tracking all active resources in the SDK
class ResourceRegistry {
  static final ResourceRegistry _instance = ResourceRegistry._internal();
  factory ResourceRegistry() => _instance;
  ResourceRegistry._internal();
  
  static const String _logTag = 'ResourceRegistry';
  final Map<String, DisposableResource> _resources = {};
  final Map<String, int> _resourceCounts = {};
  bool _isShuttingDown = false;
  
  /// Register a resource for tracking
  void register(DisposableResource resource) {
    if (_isShuttingDown) {
      Logger.w('Cannot register resource during shutdown: ${resource.resourceId}');
      return;
    }
    
    _resources[resource.resourceId] = resource;
    _resourceCounts[resource.resourceType] = 
        (_resourceCounts[resource.resourceType] ?? 0) + 1;
    
    Logger.d('Registered ${resource.resourceType}: ${resource.resourceId}');
  }
  
  /// Unregister a resource
  void unregister(String resourceId) {
    final resource = _resources.remove(resourceId);
    if (resource != null) {
      final count = _resourceCounts[resource.resourceType] ?? 0;
      if (count > 0) {
        _resourceCounts[resource.resourceType] = count - 1;
      }
      Logger.d('Unregistered ${resource.resourceType}: $resourceId');
    }
  }
  
  /// Get current resource counts by type
  Map<String, int> getResourceCounts() => Map.from(_resourceCounts);
  
  /// Get all active resources
  List<DisposableResource> getActiveResources() => _resources.values.toList();
  
  /// Dispose all registered resources
  Future<void> disposeAll() async {
    _isShuttingDown = true;
    Logger.i('Disposing all resources: ${_resources.length} active');
    
    final resources = _resources.values.toList();
    final futures = <Future>[];
    
    for (final resource in resources) {
      if (!resource.isDisposed) {
        futures.add(
          resource.dispose().catchError((error) {
            Logger.e('Error disposing ${resource.resourceType} ${resource.resourceId}: $error');
          })
        );
      }
    }
    
    await Future.wait(futures);
    _resources.clear();
    _resourceCounts.clear();
    _isShuttingDown = false;
    
    Logger.i('All resources disposed');
  }
  
  /// Check for potential leaks (for debugging)
  void checkForLeaks() {
    if (_resources.isEmpty) return;
    
    Logger.w('Potential resource leaks detected:');
    _resourceCounts.forEach((type, count) {
      if (count > 0) {
        Logger.w('  $type: $count active');
      }
    });
    
    // In debug mode, log detailed resource info
    assert(() {
      _resources.forEach((id, resource) {
        Logger.d('  Active: ${resource.resourceType} - $id');
      });
      return true;
    }());
  }
  
  /// Reset the registry (for testing)
  @visibleForTesting
  void reset() {
    _resources.clear();
    _resourceCounts.clear();
    _isShuttingDown = false;
  }
}

/// Wrapper for StreamController that auto-registers with ResourceRegistry
class ManagedStreamController<T> implements DisposableResource {
  final StreamController<T> _controller;
  final String _id;
  final String _owner;
  bool _isDisposed = false;
  
  ManagedStreamController({
    required String owner,
    bool sync = false,
    bool broadcast = false,
  }) : _owner = owner,
       _id = '${owner}_${DateTime.now().microsecondsSinceEpoch}',
       _controller = broadcast 
           ? StreamController<T>.broadcast(sync: sync)
           : StreamController<T>(sync: sync) {
    ResourceRegistry().register(this);
  }
  
  @override
  String get resourceId => _id;
  
  @override
  String get resourceType => 'StreamController<$T>';
  
  @override
  bool get isDisposed => _isDisposed;
  
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    await _controller.close();
    ResourceRegistry().unregister(resourceId);
  }
  
  /// Get the underlying stream
  Stream<T> get stream => _controller.stream;
  
  /// Add data to the stream
  void add(T data) {
    if (!_isDisposed && !_controller.isClosed) {
      _controller.add(data);
    }
  }
  
  /// Add error to the stream
  void addError(Object error, [StackTrace? stackTrace]) {
    if (!_isDisposed && !_controller.isClosed) {
      _controller.addError(error, stackTrace);
    }
  }
  
  /// Get sink for the controller
  StreamSink<T> get sink => _controller.sink;
  
  /// Check if controller is closed
  bool get isClosed => _controller.isClosed;
}

/// Wrapper for Timer that auto-registers with ResourceRegistry
class ManagedTimer implements DisposableResource {
  Timer? _timer;
  final String _id;
  final String _owner;
  bool _isDisposed = false;
  
  ManagedTimer.periodic({
    required String owner,
    required Duration duration,
    required void Function(Timer) callback,
  }) : _owner = owner,
       _id = '${owner}_${DateTime.now().microsecondsSinceEpoch}' {
    _timer = Timer.periodic(duration, callback);
    ResourceRegistry().register(this);
  }
  
  ManagedTimer({
    required String owner,
    required Duration duration,
    required void Function() callback,
  }) : _owner = owner,
       _id = '${owner}_${DateTime.now().microsecondsSinceEpoch}' {
    _timer = Timer(duration, callback);
    ResourceRegistry().register(this);
  }
  
  @override
  String get resourceId => _id;
  
  @override
  String get resourceType => 'Timer';
  
  @override
  bool get isDisposed => _isDisposed;
  
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    ResourceRegistry().unregister(resourceId);
  }
  
  /// Cancel the timer
  void cancel() {
    dispose();
  }
  
  /// Check if timer is active
  bool get isActive => _timer?.isActive ?? false;
}

/// Base class for managing listeners with automatic cleanup
abstract class ManagedListener<T> implements DisposableResource {
  final String _id;
  final String _owner;
  bool _isDisposed = false;
  final Set<T> _listeners = {};
  
  ManagedListener({required String owner}) 
      : _owner = owner,
        _id = '${owner}_listeners_${DateTime.now().microsecondsSinceEpoch}' {
    ResourceRegistry().register(this);
  }
  
  @override
  String get resourceId => _id;
  
  @override
  String get resourceType => 'ListenerSet<$T>';
  
  @override
  bool get isDisposed => _isDisposed;
  
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _listeners.clear();
    ResourceRegistry().unregister(resourceId);
  }
  
  /// Add a listener
  void addListener(T listener) {
    if (!_isDisposed) {
      _listeners.add(listener);
    }
  }
  
  /// Remove a listener
  void removeListener(T listener) {
    if (!_isDisposed) {
      _listeners.remove(listener);
    }
  }
  
  /// Get all listeners
  List<T> get listeners => _listeners.toList();
  
  /// Clear all listeners
  void clear() {
    _listeners.clear();
  }
  
  /// Notify all listeners
  void notifyListeners(void Function(T listener) callback) {
    if (_isDisposed) return;
    
    // Create a copy to avoid concurrent modification
    final listenersCopy = _listeners.toList();
    for (final listener in listenersCopy) {
      try {
        callback(listener);
      } catch (e) {
        // Log error but continue notifying other listeners
        Logger.e('Error notifying listener: $e');
      }
    }
  }
}