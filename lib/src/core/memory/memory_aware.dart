import 'memory_pressure_level.dart';

/// Interface for components that can respond to memory pressure
abstract class MemoryAware {
  /// Called when memory pressure changes
  /// Components should implement cleanup strategies based on the pressure level
  Future<void> onMemoryPressure(MemoryPressureLevel level);
  
  /// Priority of this component (higher values = higher priority)
  /// Higher priority components are cleaned up last
  /// Range: 0-100, where 100 is critical system component
  int get memoryPriority;
  
  /// Human-readable name for logging and debugging
  String get componentName;
  
  /// Estimated memory usage in bytes
  /// Return -1 if unknown
  int get estimatedMemoryUsage => -1;
  
  /// Whether this component can be safely cleaned up
  /// Critical components might return false
  bool get canCleanup => true;
}

/// Memory priority constants for common component types
class MemoryPriority {
  static const int critical = 100;    // Core SDK functionality
  static const int high = 80;         // Active user features
  static const int normal = 50;       // Standard caching
  static const int low = 20;          // Optional features
  static const int background = 10;   // Background tasks
}

/// Result of a memory cleanup operation
class MemoryCleanupResult {
  final String componentName;
  final int bytesFreed;
  final bool success;
  final String? error;
  final Duration duration;
  
  MemoryCleanupResult({
    required this.componentName,
    required this.bytesFreed,
    required this.success,
    this.error,
    required this.duration,
  });
  
  @override
  String toString() {
    final status = success ? 'Success' : 'Failed';
    final freed = bytesFreed > 0 ? '${(bytesFreed / 1024 / 1024).toStringAsFixed(2)}MB' : '0MB';
    return '$componentName: $status, freed $freed in ${duration.inMilliseconds}ms${error != null ? ', error: $error' : ''}';
  }
}