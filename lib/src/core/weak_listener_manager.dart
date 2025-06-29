import 'dart:async';
import '../logging/logger.dart';

/// Manages listeners using WeakReferences to prevent memory leaks
class WeakListenerManager<T extends Object> {
  final String _name;
  final List<WeakReference<T>> _weakListeners = [];
  Timer? _cleanupTimer;
  final Duration _cleanupInterval;
  
  WeakListenerManager({
    required String name,
    Duration cleanupInterval = const Duration(minutes: 1),
  }) : _name = name,
       _cleanupInterval = cleanupInterval {
    _startCleanupTimer();
  }
  
  /// Add a listener
  void addListener(T listener) {
    _weakListeners.add(WeakReference(listener));
    Logger.d('[$_name] Added listener, total: ${_weakListeners.length}');
  }
  
  /// Remove a listener
  void removeListener(T listener) {
    _weakListeners.removeWhere((ref) {
      final target = ref.target;
      return target == null || target == listener;
    });
    Logger.d('[$_name] Removed listener, total: ${_weakListeners.length}');
  }
  
  /// Get all active listeners
  List<T> getActiveListeners() {
    _cleanupDeadReferences();
    return _weakListeners
        .map((ref) => ref.target)
        .whereType<T>()
        .toList();
  }
  
  /// Notify all active listeners
  void notifyListeners(void Function(T listener) callback) {
    final activeListeners = getActiveListeners();
    Logger.d('[$_name] Notifying ${activeListeners.length} listeners');
    
    for (final listener in activeListeners) {
      try {
        callback(listener);
      } catch (e) {
        Logger.e('[$_name] Error notifying listener: $e');
      }
    }
  }
  
  /// Notify listeners asynchronously
  Future<void> notifyListenersAsync(Future<void> Function(T listener) callback) async {
    final activeListeners = getActiveListeners();
    Logger.d('[$_name] Notifying ${activeListeners.length} listeners asynchronously');
    
    final futures = activeListeners.map((listener) async {
      try {
        await callback(listener);
      } catch (e) {
        Logger.e('[$_name] Error notifying listener: $e');
      }
    });
    
    await Future.wait(futures);
  }
  
  /// Clean up dead references
  void _cleanupDeadReferences() {
    final before = _weakListeners.length;
    _weakListeners.removeWhere((ref) => ref.target == null);
    final removed = before - _weakListeners.length;
    
    if (removed > 0) {
      Logger.d('[$_name] Cleaned up $removed dead references');
    }
  }
  
  /// Start periodic cleanup
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _cleanupDeadReferences();
    });
  }
  
  /// Clear all listeners
  void clear() {
    _weakListeners.clear();
    Logger.d('[$_name] Cleared all listeners');
  }
  
  /// Dispose of the manager
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _weakListeners.clear();
    Logger.d('[$_name] Disposed listener manager');
  }
  
  /// Get listener count (includes dead references)
  int get listenerCount => _weakListeners.length;
  
  /// Get active listener count
  int get activeListenerCount => getActiveListeners().length;
}

/// Extension to make any listener class work with weak references
extension WeakListenerExtension<T extends Object> on T {
  /// Create a weak reference to this object
  WeakReference<T> get weak => WeakReference(this);
}