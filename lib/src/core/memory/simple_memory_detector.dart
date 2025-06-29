// lib/src/core/memory/simple_memory_detector.dart
//
// Simplified memory detection that replaces complex platform-specific implementations
// with a simple, fallback-based approach.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:io';
import '../../logging/logger.dart';

/// Simple memory information
class SimpleMemoryInfo {
  /// Total physical memory in bytes (estimated)
  final int totalMemory;

  /// Available memory in bytes (estimated)
  final int availableMemory;

  /// Used memory in bytes (calculated)
  final int usedMemory;

  /// Memory usage as a percentage (0.0 - 1.0)
  final double usageRatio;

  /// App's memory usage in bytes (estimated)
  final int appMemoryUsage;

  /// Timestamp of this measurement
  final DateTime timestamp;

  SimpleMemoryInfo({
    required this.totalMemory,
    required this.availableMemory,
    required this.usedMemory,
    required this.usageRatio,
    required this.appMemoryUsage,
    required this.timestamp,
  });

  /// Creates a SimpleMemoryInfo from available and total memory
  factory SimpleMemoryInfo.fromAvailableAndTotal({
    required int availableMemory,
    required int totalMemory,
    required int appMemoryUsage,
  }) {
    final usedMemory = totalMemory - availableMemory;
    final usageRatio = totalMemory > 0 ? usedMemory / totalMemory : 0.0;

    return SimpleMemoryInfo(
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
    return 'SimpleMemoryInfo(used: ${usedMB}MB/${totalMB}MB ($percentage%), app: ${appMB}MB)';
  }
}

/// Simplified memory detector that provides basic memory estimates
class SimpleMemoryDetector {
  static const String _source = 'SimpleMemoryDetector';

  Timer? _monitoringTimer;
  StreamController<SimpleMemoryInfo>? _memoryStreamController;
  int _appMemoryEstimate = 50 * 1024 * 1024; // Start with 50MB estimate

  /// Gets current memory information using simple estimates
  Future<SimpleMemoryInfo> getMemoryInfo() async {
    try {
      // Try to get basic info from platform if available
      if (Platform.isAndroid) {
        return await _getAndroidMemoryInfo();
      } else if (Platform.isIOS) {
        return _getIOSMemoryInfo();
      } else {
        return _getGenericMemoryInfo();
      }
    } catch (e) {
      Logger.w('$_source: Failed to get memory info, using fallback: $e');
      return _getFallbackMemoryInfo();
    }
  }

  /// Simple Android memory detection
  Future<SimpleMemoryInfo> _getAndroidMemoryInfo() async {
    try {
      // Try to read from /proc/meminfo if available
      final meminfoFile = File('/proc/meminfo');
      if (meminfoFile.existsSync()) {
        final lines = await meminfoFile.readAsLines();
        int? totalMemory;
        int? availableMemory;

        for (final line in lines) {
          if (line.startsWith('MemTotal:') && totalMemory == null) {
            totalMemory = _parseMemoryLine(line);
          } else if (line.startsWith('MemAvailable:') &&
              availableMemory == null) {
            availableMemory = _parseMemoryLine(line);
          }

          if (totalMemory != null && availableMemory != null) break;
        }

        if (totalMemory != null && availableMemory != null) {
          return SimpleMemoryInfo.fromAvailableAndTotal(
            availableMemory: availableMemory,
            totalMemory: totalMemory,
            appMemoryUsage: _getAppMemoryEstimate(),
          );
        }
      }
    } catch (e) {
      Logger.d('$_source: Could not read /proc/meminfo: $e');
    }

    // Fallback to Android estimates
    return SimpleMemoryInfo.fromAvailableAndTotal(
      availableMemory: 1 * 1024 * 1024 * 1024, // 1GB available
      totalMemory:
          4 * 1024 * 1024 * 1024, // 4GB total (common for modern Android)
      appMemoryUsage: _getAppMemoryEstimate(),
    );
  }

  /// Simple iOS memory detection
  SimpleMemoryInfo _getIOSMemoryInfo() {
    // iOS doesn't provide direct memory access, use conservative estimates
    return SimpleMemoryInfo.fromAvailableAndTotal(
      availableMemory: 512 * 1024 * 1024, // 512MB available (conservative)
      totalMemory: 3 * 1024 * 1024 * 1024, // 3GB total (common for modern iOS)
      appMemoryUsage: _getAppMemoryEstimate(),
    );
  }

  /// Generic memory detection for other platforms
  SimpleMemoryInfo _getGenericMemoryInfo() {
    return SimpleMemoryInfo.fromAvailableAndTotal(
      availableMemory: 1 * 1024 * 1024 * 1024, // 1GB available
      totalMemory: 2 * 1024 * 1024 * 1024, // 2GB total
      appMemoryUsage: _getAppMemoryEstimate(),
    );
  }

  /// Fallback memory info when all else fails
  SimpleMemoryInfo _getFallbackMemoryInfo() {
    return SimpleMemoryInfo.fromAvailableAndTotal(
      availableMemory: 512 * 1024 * 1024, // 512MB available
      totalMemory: 2 * 1024 * 1024 * 1024, // 2GB total
      appMemoryUsage: _getAppMemoryEstimate(),
    );
  }

  /// Parse memory line from /proc/meminfo
  int _parseMemoryLine(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final value = int.tryParse(parts[1]) ?? 0;
      // Convert from KB to bytes
      return value * 1024;
    }
    return 0;
  }

  /// Get app memory usage estimate
  int _getAppMemoryEstimate() {
    // Simple heuristic: gradually increase estimate over time
    // In a real implementation, this could use platform channels
    _appMemoryEstimate = (_appMemoryEstimate * 1.01).round(); // Slowly increase

    // Cap at reasonable maximum (500MB)
    if (_appMemoryEstimate > 500 * 1024 * 1024) {
      _appMemoryEstimate = 500 * 1024 * 1024;
    }

    return _appMemoryEstimate;
  }

  /// Start monitoring memory changes
  Stream<SimpleMemoryInfo> startMonitoring(
      {Duration interval = const Duration(seconds: 10)}) {
    stopMonitoring();

    _memoryStreamController = StreamController<SimpleMemoryInfo>.broadcast();

    // Emit initial value
    getMemoryInfo().then((info) {
      _memoryStreamController?.add(info);
    });

    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(interval, (_) async {
      try {
        final info = await getMemoryInfo();
        _memoryStreamController?.add(info);
      } catch (e) {
        Logger.w('$_source: Error during periodic monitoring: $e');
      }
    });

    return _memoryStreamController!.stream;
  }

  /// Stop monitoring memory changes
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _memoryStreamController?.close();
    _memoryStreamController = null;
  }

  /// Check if memory monitoring is supported on this platform
  bool get isSupported => true; // Always supported with fallbacks

  /// Get platform name for debugging
  String get platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    return 'Unknown';
  }
}
