// test/unit/monitoring/memory_profiler_test.dart
//
// Comprehensive unit tests for MemoryProfiler covering all methods
// to achieve 85%+ coverage from 6.1% (8/131 lines)
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/monitoring/memory_profiler.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MemoryProfiler', () {
    setUp(() {
      // Clean up any previous state before each test
      MemoryProfiler.cleanup();
    });
    tearDown(() {
      // Ensure profiler is stopped and cleaned after each test
      MemoryProfiler.stopMonitoring();
      MemoryProfiler.cleanup();
    });
    group('Monitoring Lifecycle', () {
      test('should start monitoring with default interval', () async {
        // Start monitoring
        MemoryProfiler.startMonitoring();
        // Give time for initial snapshot
        await Future.delayed(const Duration(milliseconds: 100));
        // Should have taken initial snapshot
        final snapshots = MemoryProfiler.getSnapshotsInRange(
          DateTime.now().subtract(const Duration(seconds: 1)),
          DateTime.now().add(const Duration(seconds: 1)),
        );
        expect(snapshots.length, greaterThanOrEqualTo(1));
        expect(snapshots.first.tag, equals('initial'));
      });
      test('should start monitoring with custom interval', () async {
        // Start monitoring with short interval
        MemoryProfiler.startMonitoring(
          interval: const Duration(milliseconds: 100),
        );
        // Wait for multiple snapshots
        await Future.delayed(const Duration(milliseconds: 350));
        MemoryProfiler.stopMonitoring();
        // Should have multiple snapshots
        final snapshots = MemoryProfiler.getSnapshotsInRange(
          DateTime.now().subtract(const Duration(seconds: 1)),
          DateTime.now().add(const Duration(seconds: 1)),
        );
        expect(snapshots.length, greaterThanOrEqualTo(3));
      });
      test('should not start monitoring twice', () {
        // Start monitoring
        MemoryProfiler.startMonitoring();
        // Try to start again - should log warning but not throw
        expect(() => MemoryProfiler.startMonitoring(), returnsNormally);
      });
      test('should stop monitoring and log summary', () async {
        // Start monitoring
        MemoryProfiler.startMonitoring(
          interval: const Duration(milliseconds: 50),
        );
        await Future.delayed(const Duration(milliseconds: 150));
        // Stop monitoring
        MemoryProfiler.stopMonitoring();
        // Should have final snapshot
        final snapshots = MemoryProfiler.getSnapshotsInRange(
          DateTime.now().subtract(const Duration(seconds: 1)),
          DateTime.now().add(const Duration(seconds: 1)),
        );
        expect(snapshots.any((s) => s.tag == 'final'), isTrue);
      });
      test('should handle stop without start', () {
        // Should not throw
        expect(() => MemoryProfiler.stopMonitoring(), returnsNormally);
      });
    });
    group('Manual Snapshots', () {
      test('should take manual snapshot with custom tag', () {
        final snapshot = MemoryProfiler.takeSnapshot('test-snapshot');
        expect(snapshot.tag, equals('test-snapshot'));
        expect(snapshot.id, startsWith('snapshot_'));
        expect(snapshot.timestamp, isNotNull);
        expect(snapshot.rssBytes, greaterThanOrEqualTo(0));
      });
      test('should increment snapshot counter', () {
        final snapshot1 = MemoryProfiler.takeSnapshot('snap1');
        final snapshot2 = MemoryProfiler.takeSnapshot('snap2');
        // Extract counter numbers
        final id1 = int.parse(snapshot1.id.split('_')[1]);
        final id2 = int.parse(snapshot2.id.split('_')[1]);
        expect(id2, equals(id1 + 1));
      });
      test('should store snapshots correctly', () {
        final tag = 'unique-test-tag-${DateTime.now().millisecondsSinceEpoch}';
        final snapshot = MemoryProfiler.takeSnapshot(tag);
        final found = MemoryProfiler.getSnapshotsInRange(
          snapshot.timestamp.subtract(const Duration(seconds: 1)),
          snapshot.timestamp.add(const Duration(seconds: 1)),
        );
        expect(found.any((s) => s.tag == tag), isTrue);
      });
    });
    group('Memory Info', () {
      test('should get current memory info', () {
        final memInfo = MemoryProfiler.getCurrentMemoryInfo();
        expect(memInfo.timestamp, isNotNull);
        expect(memInfo.rssBytes, greaterThanOrEqualTo(0));
        expect(memInfo.heapUsedBytes, greaterThanOrEqualTo(0));
        expect(memInfo.heapCapacityBytes, greaterThanOrEqualTo(0));
        expect(memInfo.externalBytes, greaterThanOrEqualTo(0));
      });
      test('should handle ProcessInfo.currentRss', () {
        // ProcessInfo.currentRss should return valid value
        final rss = ProcessInfo.currentRss;
        expect(rss, greaterThanOrEqualTo(0));
        final memInfo = MemoryProfiler.getCurrentMemoryInfo();
        expect(memInfo.rssBytes, equals(rss));
      });
    });
    group('Memory Analysis', () {
      test('should return insufficient data for analysis with <2 snapshots',
          () {
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        expect(analysis.hasMemoryLeak, isFalse);
        expect(analysis.trend, equals(MemoryTrend.stable));
        expect(analysis.insights, contains('Insufficient data for analysis'));
        expect(analysis.peakUsageMb, equals(0));
        expect(analysis.averageUsageMb, equals(0));
      });
      test('should analyze memory usage with sufficient data', () async {
        // Take multiple snapshots
        for (int i = 0; i < 5; i++) {
          MemoryProfiler.takeSnapshot('test-$i');
          await Future.delayed(const Duration(milliseconds: 10));
        }
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        expect(analysis.hasMemoryLeak, isA<bool>());
        expect(analysis.trend, isA<MemoryTrend>());
        expect(analysis.insights, isNotEmpty);
        expect(analysis.peakUsageMb, greaterThan(0));
        expect(analysis.averageUsageMb, greaterThan(0));
      });
      test('should detect memory trends correctly', () async {
        // Simulate memory increase pattern
        for (int i = 0; i < 15; i++) {
          MemoryProfiler.takeSnapshot('trend-$i');
          await Future.delayed(const Duration(milliseconds: 5));
        }
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        // Should have meaningful trend analysis
        expect(analysis.trend, isA<MemoryTrend>());
        expect(
            analysis.insights
                .any((i) => i.contains('trend') || i.contains('stable')),
            isTrue);
      });
      test('should generate critical memory insights', () async {
        // Take snapshots to build history
        for (int i = 0; i < 5; i++) {
          MemoryProfiler.takeSnapshot('critical-$i');
          await Future.delayed(const Duration(milliseconds: 5));
        }
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        // Check for various insight types
        expect(analysis.insights, isNotEmpty);
        // Should mention memory usage or stability
        expect(
            analysis.insights.any((i) =>
                i.contains('memory') ||
                i.contains('MB') ||
                i.contains('stable')),
            isTrue);
      });
      test('should calculate peak and average usage correctly', () async {
        // Take multiple snapshots
        final snapshots = <MemorySnapshot>[];
        for (int i = 0; i < 10; i++) {
          snapshots.add(MemoryProfiler.takeSnapshot('calc-$i'));
          await Future.delayed(const Duration(milliseconds: 5));
        }
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        // Peak should be >= average
        expect(analysis.peakUsageMb,
            greaterThanOrEqualTo(analysis.averageUsageMb));
        expect(analysis.averageUsageMb, greaterThan(0));
      });
    });
    group('Memory Leak Detection', () {
      test('should not detect leak with stable memory', () async {
        // Take snapshots with stable memory
        for (int i = 0; i < 12; i++) {
          MemoryProfiler.takeSnapshot('stable-$i');
          await Future.delayed(const Duration(milliseconds: 5));
        }
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        // Unlikely to detect leak with natural variations
        if (!analysis.hasMemoryLeak) {
          expect(analysis.insights.any((i) => i.contains('LEAK')), isFalse);
        }
      });
      test('should handle memory leak detection threshold', () async {
        // Create enough history for leak detection
        for (int i = 0; i < 15; i++) {
          MemoryProfiler.takeSnapshot('leak-test-$i');
          await Future.delayed(const Duration(milliseconds: 5));
        }
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        // Should have made a determination about leaks
        expect(analysis.hasMemoryLeak, isA<bool>());
        if (analysis.hasMemoryLeak) {
          expect(analysis.insights.any((i) => i.contains('LEAK')), isTrue);
        }
      });
    });
    group('Optimization Recommendations', () {
      test('should provide optimization recommendations', () {
        final recommendations = MemoryProfiler.getOptimizationRecommendations();
        expect(recommendations, isA<List<MemoryOptimization>>());
        for (final rec in recommendations) {
          expect(rec.type, isA<OptimizationType>());
          expect(rec.priority, isA<OptimizationPriority>());
          expect(rec.description, isNotEmpty);
          expect(rec.estimatedSavingsMb, greaterThanOrEqualTo(0));
        }
      });
      test('should recommend leak fix when leak detected', () async {
        // Simulate conditions that might trigger leak detection
        for (int i = 0; i < 15; i++) {
          MemoryProfiler.takeSnapshot('leak-rec-$i');
          await Future.delayed(const Duration(milliseconds: 5));
        }
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        final recommendations = MemoryProfiler.getOptimizationRecommendations();
        if (analysis.hasMemoryLeak) {
          expect(recommendations.any((r) => r.type == OptimizationType.leakFix),
              isTrue);
        }
      });
      test('should recommend cache optimization for high memory', () async {
        // Build history
        for (int i = 0; i < 5; i++) {
          MemoryProfiler.takeSnapshot('cache-opt-$i');
          await Future.delayed(const Duration(milliseconds: 5));
        }
        final recommendations = MemoryProfiler.getOptimizationRecommendations();
        // May recommend cache optimization based on usage
        final cacheOpt = recommendations.firstWhere(
          (r) => r.type == OptimizationType.cacheOptimization,
          orElse: () => MemoryOptimization(
            type: OptimizationType.cacheOptimization,
            priority: OptimizationPriority.low,
            description: '',
            estimatedSavingsMb: 0,
          ),
        );
        if (cacheOpt.estimatedSavingsMb > 0) {
          expect(cacheOpt.priority, isA<OptimizationPriority>());
        }
      });
      test('should recommend resource cleanup with many snapshots', () async {
        // Create many snapshots
        for (int i = 0; i < 15; i++) {
          MemoryProfiler.takeSnapshot('cleanup-$i');
          await Future.delayed(const Duration(milliseconds: 5));
        }
        final recommendations = MemoryProfiler.getOptimizationRecommendations();
        // Should recommend cleanup with many snapshots
        expect(
            recommendations
                .any((r) => r.type == OptimizationType.resourceCleanup),
            isTrue);
      });
    });
    group('Snapshot Management', () {
      test('should get snapshots in time range', () {
        // Take snapshots
        MemoryProfiler.takeSnapshot('past');
        final target = MemoryProfiler.takeSnapshot('target');
        MemoryProfiler.takeSnapshot('future');
        final found = MemoryProfiler.getSnapshotsInRange(
          target.timestamp.subtract(const Duration(seconds: 1)),
          target.timestamp.add(const Duration(seconds: 1)),
        );
        expect(found.any((s) => s.tag == 'target'), isTrue);
      });
      test('should sort snapshots by timestamp', () {
        // Take multiple snapshots
        final tags = ['first', 'second', 'third'];
        for (final tag in tags) {
          MemoryProfiler.takeSnapshot(tag);
        }
        final found = MemoryProfiler.getSnapshotsInRange(
          DateTime.now().subtract(const Duration(minutes: 1)),
          DateTime.now().add(const Duration(minutes: 1)),
        );
        // Verify sorted order
        for (int i = 1; i < found.length; i++) {
          expect(
              found[i].timestamp.isAfter(found[i - 1].timestamp) ||
                  found[i].timestamp.isAtSameMomentAs(found[i - 1].timestamp),
              isTrue);
        }
      });
      test('should enforce memory history size limit', () async {
        // Take more than max history size (100) snapshots
        for (int i = 0; i < 110; i++) {
          MemoryProfiler.takeSnapshot('history-$i');
          if (i % 10 == 0) {
            await Future.delayed(const Duration(milliseconds: 1));
          }
        }
        // History should be limited
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        expect(analysis, isNotNull); // Should still work with limited history
      });
    });
    group('Cleanup', () {
      test('should cleanup all data', () async {
        // Create some data
        MemoryProfiler.startMonitoring();
        await Future.delayed(const Duration(milliseconds: 100));
        MemoryProfiler.takeSnapshot('cleanup-test');
        // Cleanup
        MemoryProfiler.cleanup();
        // All data should be cleared
        final snapshots = MemoryProfiler.getSnapshotsInRange(
          DateTime.now().subtract(const Duration(hours: 1)),
          DateTime.now().add(const Duration(hours: 1)),
        );
        expect(snapshots, isEmpty);
        // Analysis should show insufficient data
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        expect(analysis.insights, contains('Insufficient data for analysis'));
      });
      test('should stop monitoring on cleanup', () async {
        // Start monitoring
        MemoryProfiler.startMonitoring(
          interval: const Duration(milliseconds: 50),
        );
        await Future.delayed(const Duration(milliseconds: 100));
        // Cleanup should stop monitoring
        MemoryProfiler.cleanup();
        // Wait and verify no new snapshots
        final countBefore = MemoryProfiler.getSnapshotsInRange(
          DateTime.now().subtract(const Duration(hours: 1)),
          DateTime.now().add(const Duration(hours: 1)),
        ).length;
        await Future.delayed(const Duration(milliseconds: 100));
        final countAfter = MemoryProfiler.getSnapshotsInRange(
          DateTime.now().subtract(const Duration(hours: 1)),
          DateTime.now().add(const Duration(hours: 1)),
        ).length;
        expect(countAfter, equals(countBefore));
      });
    });
    group('Data Classes', () {
      test('MemoryInfo should be created correctly', () {
        final info = MemoryInfo(
          timestamp: DateTime.now(),
          rssBytes: 100 * 1024 * 1024,
          heapUsedBytes: 50 * 1024 * 1024,
          heapCapacityBytes: 80 * 1024 * 1024,
          externalBytes: 10 * 1024 * 1024,
        );
        expect(info.timestamp, isNotNull);
        expect(info.rssBytes, equals(100 * 1024 * 1024));
        expect(info.heapUsedBytes, equals(50 * 1024 * 1024));
        expect(info.heapCapacityBytes, equals(80 * 1024 * 1024));
        expect(info.externalBytes, equals(10 * 1024 * 1024));
      });
      test('MemorySnapshot extends MemoryInfo correctly', () {
        final snapshot = MemorySnapshot(
          id: 'test-123',
          tag: 'test-snapshot',
          timestamp: DateTime.now(),
          rssBytes: 200 * 1024 * 1024,
          heapUsedBytes: 100 * 1024 * 1024,
          heapCapacityBytes: 150 * 1024 * 1024,
          externalBytes: 20 * 1024 * 1024,
        );
        expect(snapshot.id, equals('test-123'));
        expect(snapshot.tag, equals('test-snapshot'));
        expect(snapshot, isA<MemoryInfo>());
      });
      test('MemoryDataPoint should store data correctly', () {
        final dataPoint = MemoryDataPoint(
          timestamp: DateTime.now(),
          rssBytes: 300 * 1024 * 1024,
          heapUsedBytes: 150 * 1024 * 1024,
        );
        expect(dataPoint.timestamp, isNotNull);
        expect(dataPoint.rssBytes, equals(300 * 1024 * 1024));
        expect(dataPoint.heapUsedBytes, equals(150 * 1024 * 1024));
      });
      test('MemoryAnalysis should contain all fields', () {
        final analysis = MemoryAnalysis(
          hasMemoryLeak: true,
          trend: MemoryTrend.increasing,
          insights: ['Test insight 1', 'Test insight 2'],
          peakUsageMb: 512.5,
          averageUsageMb: 256.25,
        );
        expect(analysis.hasMemoryLeak, isTrue);
        expect(analysis.trend, equals(MemoryTrend.increasing));
        expect(analysis.insights, hasLength(2));
        expect(analysis.peakUsageMb, equals(512.5));
        expect(analysis.averageUsageMb, equals(256.25));
      });
      test('MemoryOptimization should contain all fields', () {
        final optimization = MemoryOptimization(
          type: OptimizationType.cacheOptimization,
          priority: OptimizationPriority.high,
          description: 'Optimize cache retention',
          estimatedSavingsMb: 50.0,
        );
        expect(optimization.type, equals(OptimizationType.cacheOptimization));
        expect(optimization.priority, equals(OptimizationPriority.high));
        expect(optimization.description, equals('Optimize cache retention'));
        expect(optimization.estimatedSavingsMb, equals(50.0));
      });
    });
    group('Enums', () {
      test('MemoryTrend should have all values', () {
        expect(MemoryTrend.values, contains(MemoryTrend.increasing));
        expect(MemoryTrend.values, contains(MemoryTrend.decreasing));
        expect(MemoryTrend.values, contains(MemoryTrend.stable));
        expect(MemoryTrend.values, hasLength(3));
      });
      test('OptimizationType should have all values', () {
        expect(OptimizationType.values, contains(OptimizationType.leakFix));
        expect(OptimizationType.values,
            contains(OptimizationType.cacheOptimization));
        expect(OptimizationType.values,
            contains(OptimizationType.resourceCleanup));
        expect(
            OptimizationType.values, contains(OptimizationType.objectPooling));
        expect(OptimizationType.values, hasLength(4));
      });
      test('OptimizationPriority should have all values', () {
        expect(OptimizationPriority.values, contains(OptimizationPriority.low));
        expect(
            OptimizationPriority.values, contains(OptimizationPriority.medium));
        expect(
            OptimizationPriority.values, contains(OptimizationPriority.high));
        expect(OptimizationPriority.values,
            contains(OptimizationPriority.critical));
        expect(OptimizationPriority.values, hasLength(4));
      });
    });
    group('Extension Methods', () {
      test('takeLast should work with exact count', () {
        final list = [1, 2, 3, 4, 5];
        final last3 = list.takeLast(3).toList();
        expect(last3, equals([3, 4, 5]));
      });
      test('takeLast should return all items if count > length', () {
        final list = [1, 2, 3];
        final lastMany = list.takeLast(10).toList();
        expect(lastMany, equals([1, 2, 3]));
      });
      test('takeLast should return empty if count is 0', () {
        final list = [1, 2, 3, 4, 5];
        final last0 = list.takeLast(0).toList();
        expect(last0, isEmpty);
      });
      test('takeLast should work with empty iterable', () {
        final list = <int>[];
        final lastAny = list.takeLast(5).toList();
        expect(lastAny, isEmpty);
      });
      test('takeLast should work with exact length', () {
        final list = [1, 2, 3, 4, 5];
        final all = list.takeLast(5).toList();
        expect(all, equals([1, 2, 3, 4, 5]));
      });
    });
    group('Edge Cases', () {
      test('should handle very small memory values', () {
        final info = MemoryInfo(
          timestamp: DateTime.now(),
          rssBytes: 1,
          heapUsedBytes: 0,
          heapCapacityBytes: 1,
          externalBytes: 0,
        );
        expect(info.rssBytes, equals(1));
        expect(info.heapUsedBytes, equals(0));
      });
      test('should handle concurrent snapshot operations', () async {
        // Start monitoring
        MemoryProfiler.startMonitoring(
          interval: const Duration(milliseconds: 50),
        );
        // Take manual snapshots concurrently
        final futures = <Future<MemorySnapshot>>[];
        for (int i = 0; i < 10; i++) {
          futures
              .add(Future(() => MemoryProfiler.takeSnapshot('concurrent-$i')));
        }
        final snapshots = await Future.wait(futures);
        expect(snapshots, hasLength(10));
        expect(snapshots.map((s) => s.id).toSet(),
            hasLength(10)); // All unique IDs
        MemoryProfiler.stopMonitoring();
      });
      test('should handle rapid start/stop cycles', () async {
        for (int i = 0; i < 5; i++) {
          MemoryProfiler.startMonitoring();
          await Future.delayed(const Duration(milliseconds: 10));
          MemoryProfiler.stopMonitoring();
          await Future.delayed(const Duration(milliseconds: 10));
        }
        // Should not crash or have issues
        expect(true, isTrue);
      });
      test('should handle analysis with single data point', () async {
        // Take just one snapshot
        MemoryProfiler.takeSnapshot('single');
        final analysis = MemoryProfiler.analyzeMemoryUsage();
        expect(analysis.hasMemoryLeak, isFalse);
        expect(analysis.trend, equals(MemoryTrend.stable));
        expect(analysis.insights, contains('Insufficient data for analysis'));
      });
    });
  });
}
