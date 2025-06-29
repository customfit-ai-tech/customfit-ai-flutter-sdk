import 'dart:async';

/// Platform-specific memory information
class MemoryInfo {
  /// Total physical memory in bytes
  final int totalMemory;
  
  /// Available memory in bytes
  final int availableMemory;
  
  /// Used memory in bytes
  final int usedMemory;
  
  /// Memory usage as a percentage (0.0 - 1.0)
  final double usageRatio;
  
  /// App's memory usage in bytes
  final int appMemoryUsage;
  
  /// Timestamp of this measurement
  final DateTime timestamp;
  
  MemoryInfo({
    required this.totalMemory,
    required this.availableMemory,
    required this.usedMemory,
    required this.usageRatio,
    required this.appMemoryUsage,
    required this.timestamp,
  });
  
  /// Creates a MemoryInfo from available and total memory
  factory MemoryInfo.fromAvailableAndTotal({
    required int availableMemory,
    required int totalMemory,
    required int appMemoryUsage,
  }) {
    final usedMemory = totalMemory - availableMemory;
    final usageRatio = totalMemory > 0 ? usedMemory / totalMemory : 0.0;
    
    return MemoryInfo(
      totalMemory: totalMemory,
      availableMemory: availableMemory,
      usedMemory: usedMemory,
      usageRatio: usageRatio,
      appMemoryUsage: appMemoryUsage,
      timestamp: DateTime.now(),
    );
  }
  
  @override
  String toString() {
    final usedMB = (usedMemory / 1024 / 1024).toStringAsFixed(1);
    final totalMB = (totalMemory / 1024 / 1024).toStringAsFixed(1);
    final appMB = (appMemoryUsage / 1024 / 1024).toStringAsFixed(1);
    final percentage = (usageRatio * 100).toStringAsFixed(1);
    return 'MemoryInfo(used: ${usedMB}MB/${totalMB}MB ($percentage%), app: ${appMB}MB)';
  }
}

/// Abstract interface for platform-specific memory detection
abstract class MemoryPlatformInterface {
  /// Gets current memory information
  Future<MemoryInfo> getMemoryInfo();
  
  /// Starts monitoring memory changes
  /// Returns a stream of memory info updates
  Stream<MemoryInfo> startMonitoring({Duration interval = const Duration(seconds: 10)});
  
  /// Stops memory monitoring
  void stopMonitoring();
  
  /// Checks if memory monitoring is supported on this platform
  bool get isSupported;
  
  /// Gets platform name for debugging
  String get platformName;
}