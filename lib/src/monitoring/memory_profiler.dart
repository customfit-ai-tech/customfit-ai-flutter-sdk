// lib/src/monitoring/memory_profiler.dart
//
// Memory profiling utilities for CustomFit Flutter SDK.
// Provides memory usage tracking, leak detection, and optimization insights.

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import '../logging/logger.dart';

/// Memory profiler for the CustomFit Flutter SDK.
///
/// Provides utilities for:
/// - Memory usage tracking
/// - Memory leak detection
/// - Performance optimization insights
/// - Resource cleanup validation
class MemoryProfiler {
  static const String _source = 'MemoryProfiler';

  /// Memory tracking data
  static final Map<String, MemorySnapshot> _snapshots = {};
  static Timer? _monitoringTimer;
  static bool _isMonitoring = false;
  static int _snapshotCounter = 0;

  /// Memory thresholds for alerts (in MB)
  static const int _warningThresholdMb = 50;
  static const int _criticalThresholdMb = 100;

  /// Memory usage history for trend analysis
  static final List<MemoryDataPoint> _memoryHistory = [];
  static const int _maxHistorySize = 100;

  /// Start memory monitoring with specified interval
  static void startMonitoring(
      {Duration interval = const Duration(seconds: 30)}) {
    if (_isMonitoring) {
      Logger.w('Memory monitoring already started');
      return;
    }

    _isMonitoring = true;
    Logger.i('Starting memory monitoring with ${interval.inSeconds}s interval');

    // Take initial snapshot
    _takeSnapshot('initial');

    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(interval, (_) {
      _takePeriodicSnapshot();
    });
  }

  /// Stop memory monitoring
  static void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    // Take final snapshot
    _takeSnapshot('final');

    Logger.i('Memory monitoring stopped');
    _logSummary();
  }

  /// Take a manual memory snapshot with custom tag
  static MemorySnapshot takeSnapshot(String tag) {
    return _takeSnapshot(tag);
  }

  /// Get current memory usage information
  static MemoryInfo getCurrentMemoryInfo() {
    final vmInfo = _getVmMemoryInfo();
    return MemoryInfo(
      timestamp: DateTime.now(),
      rssBytes: vmInfo['rss'] ?? 0,
      heapUsedBytes: vmInfo['heapUsed'] ?? 0,
      heapCapacityBytes: vmInfo['heapCapacity'] ?? 0,
      externalBytes: vmInfo['external'] ?? 0,
    );
  }

  /// Analyze memory usage patterns and detect potential leaks
  static MemoryAnalysis analyzeMemoryUsage() {
    if (_memoryHistory.length < 2) {
      return MemoryAnalysis(
        hasMemoryLeak: false,
        trend: MemoryTrend.stable,
        insights: ['Insufficient data for analysis'],
        peakUsageMb: 0,
        averageUsageMb: 0,
      );
    }

    final insights = <String>[];
    final usageMb =
        _memoryHistory.map((h) => h.rssBytes / (1024 * 1024)).toList();
    final averageUsage = usageMb.reduce((a, b) => a + b) / usageMb.length;
    final peakUsage = usageMb.reduce((a, b) => a > b ? a : b);

    // Trend analysis
    final trend = _analyzeTrend();

    // Memory leak detection
    final hasLeak = _detectMemoryLeak();

    // Generate insights
    if (peakUsage > _criticalThresholdMb) {
      insights.add(
          'CRITICAL: Peak memory usage exceeded ${_criticalThresholdMb}MB (${peakUsage.toStringAsFixed(1)}MB)');
    } else if (peakUsage > _warningThresholdMb) {
      insights.add(
          'WARNING: Peak memory usage exceeded ${_warningThresholdMb}MB (${peakUsage.toStringAsFixed(1)}MB)');
    }

    if (hasLeak) {
      insights.add('POTENTIAL MEMORY LEAK: Sustained memory growth detected');
    }

    if (trend == MemoryTrend.increasing) {
      insights.add('Memory usage is trending upward - monitor for leaks');
    } else if (trend == MemoryTrend.stable) {
      insights.add('Memory usage is stable');
    } else {
      insights.add('Memory usage is decreasing - good resource management');
    }

    return MemoryAnalysis(
      hasMemoryLeak: hasLeak,
      trend: trend,
      insights: insights,
      peakUsageMb: peakUsage,
      averageUsageMb: averageUsage,
    );
  }

  /// Get memory snapshots for a specific time range
  static List<MemorySnapshot> getSnapshotsInRange(
      DateTime start, DateTime end) {
    return _snapshots.values
        .where((s) => s.timestamp.isAfter(start) && s.timestamp.isBefore(end))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Generate memory optimization recommendations
  static List<MemoryOptimization> getOptimizationRecommendations() {
    final recommendations = <MemoryOptimization>[];
    final analysis = analyzeMemoryUsage();

    if (analysis.hasMemoryLeak) {
      recommendations.add(MemoryOptimization(
        type: OptimizationType.leakFix,
        priority: OptimizationPriority.critical,
        description: 'Investigate and fix memory leak',
        estimatedSavingsMb:
            analysis.peakUsageMb * 0.3, // Estimate 30% reduction
      ));
    }

    if (analysis.peakUsageMb > _warningThresholdMb) {
      recommendations.add(MemoryOptimization(
        type: OptimizationType.cacheOptimization,
        priority: OptimizationPriority.high,
        description: 'Optimize cache sizes and retention policies',
        estimatedSavingsMb: 10,
      ));
    }

    if (_snapshots.length > 10) {
      recommendations.add(MemoryOptimization(
        type: OptimizationType.resourceCleanup,
        priority: OptimizationPriority.medium,
        description: 'Implement better resource cleanup patterns',
        estimatedSavingsMb: 5,
      ));
    }

    return recommendations;
  }

  /// Clean up profiler data and reset tracking
  static void cleanup() {
    stopMonitoring();
    _snapshots.clear();
    _memoryHistory.clear();
    _snapshotCounter = 0;
    Logger.i('Memory profiler cleaned up');
  }

  // Private helper methods

  static MemorySnapshot _takeSnapshot(String tag) {
    final memInfo = getCurrentMemoryInfo();
    final snapshot = MemorySnapshot(
      id: 'snapshot_${++_snapshotCounter}',
      tag: tag,
      timestamp: memInfo.timestamp,
      rssBytes: memInfo.rssBytes,
      heapUsedBytes: memInfo.heapUsedBytes,
      heapCapacityBytes: memInfo.heapCapacityBytes,
      externalBytes: memInfo.externalBytes,
    );

    _snapshots[snapshot.id] = snapshot;

    // Add to history with size limit
    _memoryHistory.add(MemoryDataPoint(
      timestamp: snapshot.timestamp,
      rssBytes: snapshot.rssBytes,
      heapUsedBytes: snapshot.heapUsedBytes,
    ));

    if (_memoryHistory.length > _maxHistorySize) {
      _memoryHistory.removeAt(0);
    }

    // Log significant memory usage
    final rssMb = snapshot.rssBytes / (1024 * 1024);
    if (rssMb > _warningThresholdMb) {
      Logger.w(
          'High memory usage detected: ${rssMb.toStringAsFixed(1)}MB (tag: $tag)');
    } else {
      Logger.d('Memory snapshot "$tag": ${rssMb.toStringAsFixed(1)}MB RSS');
    }

    return snapshot;
  }

  static void _takePeriodicSnapshot() {
    _takeSnapshot('periodic_${DateTime.now().millisecondsSinceEpoch}');
  }

  static Map<String, int> _getVmMemoryInfo() {
    try {
      // Get VM service info if available
      developer.Service.getIsolateId(Isolate.current);

      // For now, return process memory info
      // In a real implementation, you'd use VM service APIs
      return {
        'rss': ProcessInfo.currentRss,
        'heapUsed': 0, // Would need VM service
        'heapCapacity': 0, // Would need VM service
        'external': 0, // Would need VM service
      };
    } catch (e) {
      Logger.w('Failed to get VM memory info: $e');
      return {
        'rss': 0,
        'heapUsed': 0,
        'heapCapacity': 0,
        'external': 0,
      };
    }
  }

  static MemoryTrend _analyzeTrend() {
    if (_memoryHistory.length < 5) return MemoryTrend.stable;

    final recent = _memoryHistory.takeLast(5).toList();
    final oldAvg =
        recent.take(2).map((h) => h.rssBytes).reduce((a, b) => a + b) / 2;
    final newAvg =
        recent.skip(3).map((h) => h.rssBytes).reduce((a, b) => a + b) / 2;

    final changePercent = (newAvg - oldAvg) / oldAvg * 100;

    if (changePercent > 10) return MemoryTrend.increasing;
    if (changePercent < -10) return MemoryTrend.decreasing;
    return MemoryTrend.stable;
  }

  static bool _detectMemoryLeak() {
    if (_memoryHistory.length < 10) return false;

    // Simple leak detection: sustained growth over time
    final recent = _memoryHistory.takeLast(10).toList();
    int increasingCount = 0;

    for (int i = 1; i < recent.length; i++) {
      if (recent[i].rssBytes > recent[i - 1].rssBytes) {
        increasingCount++;
      }
    }

    // If memory increased in 70% of recent samples, consider it a leak
    return increasingCount >= (recent.length * 0.7);
  }

  static void _logSummary() {
    if (_snapshots.isEmpty) return;

    final analysis = analyzeMemoryUsage();
    Logger.i('Memory Profiling Summary:');
    Logger.i('  Peak Usage: ${analysis.peakUsageMb.toStringAsFixed(1)}MB');
    Logger.i(
        '  Average Usage: ${analysis.averageUsageMb.toStringAsFixed(1)}MB');
    Logger.i('  Trend: ${analysis.trend}');
    Logger.i('  Memory Leak Detected: ${analysis.hasMemoryLeak}');
    Logger.i('  Total Snapshots: ${_snapshots.length}');

    for (final insight in analysis.insights) {
      Logger.i('  - $insight');
    }
  }
}

/// Memory information at a specific point in time
class MemoryInfo {
  final DateTime timestamp;
  final int rssBytes;
  final int heapUsedBytes;
  final int heapCapacityBytes;
  final int externalBytes;

  MemoryInfo({
    required this.timestamp,
    required this.rssBytes,
    required this.heapUsedBytes,
    required this.heapCapacityBytes,
    required this.externalBytes,
  });
}

/// Memory snapshot with metadata
class MemorySnapshot extends MemoryInfo {
  final String id;
  final String tag;

  MemorySnapshot({
    required this.id,
    required this.tag,
    required super.timestamp,
    required super.rssBytes,
    required super.heapUsedBytes,
    required super.heapCapacityBytes,
    required super.externalBytes,
  });
}

/// Simple data point for trend analysis
class MemoryDataPoint {
  final DateTime timestamp;
  final int rssBytes;
  final int heapUsedBytes;

  MemoryDataPoint({
    required this.timestamp,
    required this.rssBytes,
    required this.heapUsedBytes,
  });
}

/// Memory usage analysis results
class MemoryAnalysis {
  final bool hasMemoryLeak;
  final MemoryTrend trend;
  final List<String> insights;
  final double peakUsageMb;
  final double averageUsageMb;

  MemoryAnalysis({
    required this.hasMemoryLeak,
    required this.trend,
    required this.insights,
    required this.peakUsageMb,
    required this.averageUsageMb,
  });
}

/// Memory optimization recommendation
class MemoryOptimization {
  final OptimizationType type;
  final OptimizationPriority priority;
  final String description;
  final double estimatedSavingsMb;

  MemoryOptimization({
    required this.type,
    required this.priority,
    required this.description,
    required this.estimatedSavingsMb,
  });
}

enum MemoryTrend {
  increasing,
  decreasing,
  stable,
}

enum OptimizationType {
  leakFix,
  cacheOptimization,
  resourceCleanup,
  objectPooling,
}

enum OptimizationPriority {
  low,
  medium,
  high,
  critical,
}

/// Extension to get Iterable.takeLast() functionality
extension IterableExtension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    if (count >= length) return this;
    return skip(length - count);
  }
}
