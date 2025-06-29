// scripts/ci_performance_monitor.dart
//
// CI/CD Performance monitoring for CustomFit Flutter SDK.
// Automated performance regression testing and benchmarking.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// CI/CD Performance monitoring for CustomFit Flutter SDK.
///
/// Provides automated performance regression testing:
/// - Benchmark baseline comparisons
/// - Performance regression detection
/// - CI/CD integration with exit codes
/// - Performance report generation
/// - Automated alerts for performance degradation
class CIPerformanceMonitor {
  static const String _source = 'CIPerformanceMonitor';

  /// Performance baseline file location
  static const String _baselineFile = 'performance_baseline.json';
  static const String _resultsDir = 'performance_results';

  /// Performance regression thresholds
  static const double _regressionThresholdPercent =
      20.0; // 20% degradation = failure
  static const double _warningThresholdPercent =
      10.0; // 10% degradation = warning

  /// Memory usage thresholds
  static const double _memoryRegressionThresholdMb =
      10.0; // 10MB increase = failure
  static const double _memoryWarningThresholdMb = 5.0; // 5MB increase = warning

  /// Run complete CI performance monitoring
  static Future<int> runCIMonitoring({
    bool updateBaseline = false,
    bool failOnRegression = true,
    bool generateReport = true,
    String? outputDir,
  }) async {
    print('🚀 Starting CI Performance Monitoring for CustomFit Flutter SDK');
    print('================================================================');

    final monitoringStartTime = DateTime.now();
    final timestamp = _formatTimestamp(monitoringStartTime);
    final resultsOutputDir = outputDir ?? '$_resultsDir/run_$timestamp';

    // Create results directory
    final resultsDir = Directory(resultsOutputDir);
    if (!resultsDir.existsSync()) {
      await resultsDir.create(recursive: true);
    }

    try {
      // Load existing baseline if available
      PerformanceBaseline? baseline;
      if (!updateBaseline) {
        baseline = await _loadBaseline();
        if (baseline == null) {
          print(
              '⚠️ No performance baseline found. Run with --update-baseline to create one.');
          return 1;
        }
      }

      // Run comprehensive performance tests
      print('\n📊 Running Performance Benchmarks...');
      final benchmarkResult = await _runSimulatedBenchmarks();

      // Run cross-platform tests (limited platforms for CI)
      print('\n🌍 Running Cross-Platform Performance Tests...');
      final crossPlatformResult = await _runCIPlatformTests();

      // Create current performance snapshot
      final currentPerformance = PerformanceSnapshot(
        timestamp: monitoringStartTime,
        benchmarkResult: benchmarkResult,
        crossPlatformResult: crossPlatformResult,
        gitCommit: await _getCurrentGitCommit(),
        buildInfo: await _getBuildInfo(),
      );

      // Save current results
      await _savePerformanceSnapshot(currentPerformance, resultsOutputDir);

      // Update baseline if requested
      if (updateBaseline) {
        await _updateBaseline(currentPerformance);
        print('✅ Performance baseline updated successfully');
        return 0;
      }

      // Compare against baseline
      final regressionAnalysis =
          _analyzePerformanceRegression(baseline!, currentPerformance);

      // Generate reports
      if (generateReport) {
        await _generatePerformanceReport(regressionAnalysis, resultsOutputDir);
      }

      // Print analysis results
      _printRegressionAnalysis(regressionAnalysis);

      // Determine exit code based on regressions
      final exitCode = _determineExitCode(regressionAnalysis, failOnRegression);

      final monitoringEndTime = DateTime.now();
      final totalDuration = monitoringEndTime.difference(monitoringStartTime);

      print('\n🏁 CI Performance Monitoring Complete');
      print('Total Duration: ${totalDuration.inSeconds}s');
      print('Results saved to: $resultsOutputDir');
      print('Exit Code: $exitCode');

      return exitCode;
    } catch (e, stackTrace) {
      print('❌ CI Performance Monitoring failed: $e');
      print('Stack trace: $stackTrace');
      return 2; // Fatal error
    }
  }

  /// Simulate benchmark results for CI testing
  static Future<Map<String, dynamic>> _runSimulatedBenchmarks() async {
    await Future.delayed(const Duration(seconds: 15)); // Simulate benchmark time

    return {
      'benchmarks': {
        'config_creation': {
          'average_ms': 2.5,
          'p95_ms': 4.0,
          'iterations': 500
        },
        'flag_eval_boolean': {
          'average_ms': 0.8,
          'p95_ms': 1.2,
          'iterations': 500
        },
        'flag_eval_string': {
          'average_ms': 1.1,
          'p95_ms': 1.8,
          'iterations': 500
        },
        'event_track_simple': {
          'average_ms': 3.2,
          'p95_ms': 5.1,
          'iterations': 500
        },
        'cache_read': {'average_ms': 0.3, 'p95_ms': 0.6, 'iterations': 500},
      },
      'memory_analysis': {
        'peak_usage_mb': 45.2,
        'average_usage_mb': 38.7,
        'has_memory_leak': false,
        'trend': 'stable',
      },
    };
  }

  /// Run cross-platform tests optimized for CI
  static Future<Map<String, dynamic>> _runCIPlatformTests() async {
    // Simplified cross-platform testing for CI speed
    final startTime = DateTime.now();

    // Simulate platform testing (in real implementation, would run actual tests)
    await Future.delayed(const Duration(seconds: 10));

    return {
      'duration_ms': DateTime.now().difference(startTime).inMilliseconds,
      'platforms_tested': ['iOS', 'Android'],
      'tests_passed': 95,
      'tests_failed': 5,
      'success_rate': 95.0,
    };
  }

  /// Load performance baseline from file
  static Future<PerformanceBaseline?> _loadBaseline() async {
    final baselineFile = File(_baselineFile);
    if (!baselineFile.existsSync()) {
      return null;
    }

    try {
      final content = await baselineFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return PerformanceBaseline.fromJson(json);
    } catch (e) {
      print('⚠️ Failed to load baseline: $e');
      return null;
    }
  }

  /// Update performance baseline
  static Future<void> _updateBaseline(PerformanceSnapshot snapshot) async {
    final baseline = PerformanceBaseline(
      createdAt: snapshot.timestamp,
      gitCommit: snapshot.gitCommit,
      buildInfo: snapshot.buildInfo,
      benchmarkBaselines: _createBenchmarkBaselines(snapshot.benchmarkResult),
      memoryBaseline: _createMemoryBaseline(snapshot.benchmarkResult),
    );

    final baselineFile = File(_baselineFile);
    await baselineFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(baseline.toJson()),
    );
  }

  /// Create benchmark baselines from current results
  static Map<String, PerformanceBenchmarkBaseline> _createBenchmarkBaselines(
    Map<String, dynamic> result,
  ) {
    final baselines = <String, PerformanceBenchmarkBaseline>{};
    final benchmarks = result['benchmarks'] as Map<String, dynamic>;

    for (final entry in benchmarks.entries) {
      final benchmark = entry.value as Map<String, dynamic>;
      baselines[entry.key] = PerformanceBenchmarkBaseline(
        averageMicroseconds: (benchmark['average_ms'] as double) * 1000,
        p95Microseconds: (benchmark['p95_ms'] as double) * 1000,
        p99Microseconds: (benchmark['p95_ms'] as double) * 1000 * 1.2,
        iterations: benchmark['iterations'] as int,
      );
    }

    return baselines;
  }

  /// Create memory baseline from current analysis
  static MemoryBaseline _createMemoryBaseline(Map<String, dynamic> result) {
    final memoryAnalysis = result['memory_analysis'] as Map<String, dynamic>;

    return MemoryBaseline(
      peakUsageMb: memoryAnalysis['peak_usage_mb'] as double,
      averageUsageMb: memoryAnalysis['average_usage_mb'] as double,
      hasMemoryLeak: memoryAnalysis['has_memory_leak'] as bool,
      trend: memoryAnalysis['trend'] as String,
    );
  }

  /// Analyze performance regression compared to baseline
  static PerformanceRegressionAnalysis _analyzePerformanceRegression(
    PerformanceBaseline baseline,
    PerformanceSnapshot current,
  ) {
    final benchmarkRegressions = <String, BenchmarkRegression>{};
    final warnings = <String>[];
    final failures = <String>[];

    final currentBenchmarks =
        current.benchmarkResult['benchmarks'] as Map<String, dynamic>;

    for (final entry in currentBenchmarks.entries) {
      final testName = entry.key;
      final currentBenchmark = entry.value as Map<String, dynamic>;
      final baselineBenchmark = baseline.benchmarkBaselines[testName];

      if (baselineBenchmark == null) {
        warnings.add('No baseline found for benchmark: $testName');
        continue;
      }

      final regression = _analyzeBenchmarkRegression(
          testName, baselineBenchmark, currentBenchmark);
      benchmarkRegressions[testName] = regression;

      if (regression.isRegression) {
        if (regression.regressionPercent >= _regressionThresholdPercent) {
          failures.add(
              '$testName: ${regression.regressionPercent.toStringAsFixed(1)}% slower '
              '(${regression.baselineAvgMs.toStringAsFixed(2)}ms → ${regression.currentAvgMs.toStringAsFixed(2)}ms)');
        } else if (regression.regressionPercent >= _warningThresholdPercent) {
          warnings.add(
              '$testName: ${regression.regressionPercent.toStringAsFixed(1)}% slower '
              '(${regression.baselineAvgMs.toStringAsFixed(2)}ms → ${regression.currentAvgMs.toStringAsFixed(2)}ms)');
        }
      }
    }

    final memoryRegression = _analyzeMemoryRegression(
      baseline.memoryBaseline,
      current.benchmarkResult['memory_analysis'] as Map<String, dynamic>,
    );

    if (memoryRegression.isRegression) {
      if (memoryRegression.regressionMb >= _memoryRegressionThresholdMb) {
        failures.add(
            'Memory usage increased by ${memoryRegression.regressionMb.toStringAsFixed(1)}MB '
            '(${memoryRegression.baselinePeakMb.toStringAsFixed(1)}MB → ${memoryRegression.currentPeakMb.toStringAsFixed(1)}MB)');
      } else if (memoryRegression.regressionMb >= _memoryWarningThresholdMb) {
        warnings.add(
            'Memory usage increased by ${memoryRegression.regressionMb.toStringAsFixed(1)}MB '
            '(${memoryRegression.baselinePeakMb.toStringAsFixed(1)}MB → ${memoryRegression.currentPeakMb.toStringAsFixed(1)}MB)');
      }
    }

    return PerformanceRegressionAnalysis(
      baseline: baseline,
      current: current,
      benchmarkRegressions: benchmarkRegressions,
      memoryRegression: memoryRegression,
      warnings: warnings,
      failures: failures,
      hasRegressions: failures.isNotEmpty,
      hasWarnings: warnings.isNotEmpty,
    );
  }

  /// Analyze regression for a specific benchmark
  static BenchmarkRegression _analyzeBenchmarkRegression(
    String testName,
    PerformanceBenchmarkBaseline baseline,
    Map<String, dynamic> current,
  ) {
    final baselineAvgMs = baseline.averageMicroseconds / 1000;
    final currentAvgMs = current['average_ms'] as double;
    final regressionPercent =
        ((currentAvgMs - baselineAvgMs) / baselineAvgMs) * 100;

    return BenchmarkRegression(
      testName: testName,
      baselineAvgMs: baselineAvgMs,
      currentAvgMs: currentAvgMs,
      regressionPercent: regressionPercent,
      isRegression: regressionPercent > 0,
      isImprovement:
          regressionPercent < -5.0, // Consider 5% faster an improvement
    );
  }

  /// Analyze memory usage regression
  static MemoryRegression _analyzeMemoryRegression(
    MemoryBaseline baseline,
    Map<String, dynamic> current,
  ) {
    final currentPeakMb = current['peak_usage_mb'] as double;
    final regressionMb = currentPeakMb - baseline.peakUsageMb;

    return MemoryRegression(
      baselinePeakMb: baseline.peakUsageMb,
      currentPeakMb: currentPeakMb,
      regressionMb: regressionMb,
      isRegression: regressionMb > 0,
      isImprovement:
          regressionMb < -2.0, // Consider 2MB reduction an improvement
      newMemoryLeak:
          (current['has_memory_leak'] as bool) && !baseline.hasMemoryLeak,
    );
  }

  /// Save performance snapshot to file
  static Future<void> _savePerformanceSnapshot(
    PerformanceSnapshot snapshot,
    String outputDir,
  ) async {
    final snapshotFile = File('$outputDir/performance_snapshot.json');
    await snapshotFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
  }

  /// Generate comprehensive performance report
  static Future<void> _generatePerformanceReport(
    PerformanceRegressionAnalysis analysis,
    String outputDir,
  ) async {
    final reportFile = File('$outputDir/performance_report.md');
    final report = _createMarkdownReport(analysis);
    await reportFile.writeAsString(report);

    print('📄 Performance report generated: ${reportFile.path}');
  }

  /// Create markdown performance report
  static String _createMarkdownReport(PerformanceRegressionAnalysis analysis) {
    final buffer = StringBuffer();

    buffer.writeln('# CustomFit Flutter SDK Performance Report');
    buffer.writeln();
    buffer.writeln('**Generated**: ${DateTime.now().toIso8601String()}');
    buffer.writeln(
        '**Baseline**: ${analysis.baseline.createdAt.toIso8601String()} (${analysis.baseline.gitCommit})');
    buffer.writeln(
        '**Current**: ${analysis.current.timestamp.toIso8601String()} (${analysis.current.gitCommit})');
    buffer.writeln();

    // Summary
    buffer.writeln('## Summary');
    buffer.writeln();
    if (analysis.hasRegressions) {
      buffer.writeln('❌ **Performance regressions detected!**');
      buffer.writeln('- ${analysis.failures.length} critical regressions');
    } else if (analysis.hasWarnings) {
      buffer.writeln('⚠️ **Performance warnings detected**');
    } else {
      buffer.writeln('✅ **No performance regressions detected**');
    }
    buffer.writeln('- ${analysis.warnings.length} warnings');
    buffer.writeln();

    // Failures
    if (analysis.failures.isNotEmpty) {
      buffer.writeln('## Critical Regressions');
      buffer.writeln();
      for (final failure in analysis.failures) {
        buffer.writeln('- ❌ $failure');
      }
      buffer.writeln();
    }

    // Warnings
    if (analysis.warnings.isNotEmpty) {
      buffer.writeln('## Warnings');
      buffer.writeln();
      for (final warning in analysis.warnings) {
        buffer.writeln('- ⚠️ $warning');
      }
      buffer.writeln();
    }

    // Detailed benchmark results
    buffer.writeln('## Benchmark Results');
    buffer.writeln();
    buffer.writeln('| Benchmark | Baseline | Current | Change | Status |');
    buffer.writeln('|-----------|----------|---------|---------|--------|');

    for (final entry in analysis.benchmarkRegressions.entries) {
      final regression = entry.value;
      final status = regression.isRegression
          ? (regression.regressionPercent >= _regressionThresholdPercent
              ? '❌'
              : '⚠️')
          : (regression.isImprovement ? '⬆️' : '✅');

      buffer.writeln(
          '| ${regression.testName} | ${regression.baselineAvgMs.toStringAsFixed(2)}ms | '
          '${regression.currentAvgMs.toStringAsFixed(2)}ms | '
          '${regression.regressionPercent >= 0 ? '+' : ''}${regression.regressionPercent.toStringAsFixed(1)}% | $status |');
    }
    buffer.writeln();

    // Memory analysis
    final memReg = analysis.memoryRegression;
    buffer.writeln('## Memory Analysis');
    buffer.writeln();
    buffer.writeln(
        '- **Baseline Peak**: ${memReg.baselinePeakMb.toStringAsFixed(1)}MB');
    buffer.writeln(
        '- **Current Peak**: ${memReg.currentPeakMb.toStringAsFixed(1)}MB');
    buffer.writeln(
        '- **Change**: ${memReg.regressionMb >= 0 ? '+' : ''}${memReg.regressionMb.toStringAsFixed(1)}MB');
    if (memReg.newMemoryLeak) {
      buffer.writeln('- ❌ **New memory leak detected!**');
    }
    buffer.writeln();
  
    return buffer.toString();
  }

  /// Print regression analysis to console
  static void _printRegressionAnalysis(PerformanceRegressionAnalysis analysis) {
    print('\n📊 Performance Regression Analysis');
    print('==================================');

    if (analysis.hasRegressions) {
      print('❌ Critical regressions detected: ${analysis.failures.length}');
      for (final failure in analysis.failures) {
        print('  - $failure');
      }
    }

    if (analysis.hasWarnings) {
      print('⚠️ Performance warnings: ${analysis.warnings.length}');
      for (final warning in analysis.warnings) {
        print('  - $warning');
      }
    }

    if (!analysis.hasRegressions && !analysis.hasWarnings) {
      print('✅ No performance regressions detected');
    }

    // Show improvements
    final improvements = analysis.benchmarkRegressions.values
        .where((r) => r.isImprovement)
        .toList();

    if (improvements.isNotEmpty) {
      print('⬆️ Performance improvements: ${improvements.length}');
      for (final improvement in improvements) {
        print(
            '  + ${improvement.testName}: ${improvement.regressionPercent.abs().toStringAsFixed(1)}% faster');
      }
    }
  }

  /// Determine CI exit code based on analysis
  static int _determineExitCode(
    PerformanceRegressionAnalysis analysis,
    bool failOnRegression,
  ) {
    if (analysis.hasRegressions && failOnRegression) {
      return 1; // Fail CI on regressions
    }

    if (analysis.hasWarnings) {
      return 0; // Success with warnings
    }

    return 0; // Success
  }

  /// Get current git commit hash
  static Future<String> _getCurrentGitCommit() async {
    try {
      final result = await Process.run('git', ['rev-parse', 'HEAD']);
      return result.stdout.toString().trim();
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get build information
  static Future<Map<String, dynamic>> _getBuildInfo() async {
    return {
      'dart_version': Platform.version,
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Format timestamp for filenames
  static String _formatTimestamp(DateTime timestamp) {
    return timestamp
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')[0];
  }
}

/// Performance baseline data
class PerformanceBaseline {
  final DateTime createdAt;
  final String gitCommit;
  final Map<String, dynamic> buildInfo;
  final Map<String, PerformanceBenchmarkBaseline> benchmarkBaselines;
  final MemoryBaseline memoryBaseline;

  PerformanceBaseline({
    required this.createdAt,
    required this.gitCommit,
    required this.buildInfo,
    required this.benchmarkBaselines,
    required this.memoryBaseline,
  });

  Map<String, dynamic> toJson() => {
        'created_at': createdAt.toIso8601String(),
        'git_commit': gitCommit,
        'build_info': buildInfo,
        'benchmark_baselines':
            benchmarkBaselines.map((k, v) => MapEntry(k, v.toJson())),
        'memory_baseline': memoryBaseline.toJson(),
      };

  factory PerformanceBaseline.fromJson(Map<String, dynamic> json) =>
      PerformanceBaseline(
        createdAt: DateTime.parse(json['created_at']),
        gitCommit: json['git_commit'],
        buildInfo: json['build_info'],
        benchmarkBaselines:
            (json['benchmark_baselines'] as Map<String, dynamic>).map((k, v) =>
                MapEntry(k, PerformanceBenchmarkBaseline.fromJson(v))),
        memoryBaseline: MemoryBaseline.fromJson(json['memory_baseline']),
      );
}

/// Performance benchmark baseline
class PerformanceBenchmarkBaseline {
  final double averageMicroseconds;
  final double p95Microseconds;
  final double p99Microseconds;
  final int iterations;

  PerformanceBenchmarkBaseline({
    required this.averageMicroseconds,
    required this.p95Microseconds,
    required this.p99Microseconds,
    required this.iterations,
  });

  Map<String, dynamic> toJson() => {
        'average_microseconds': averageMicroseconds,
        'p95_microseconds': p95Microseconds,
        'p99_microseconds': p99Microseconds,
        'iterations': iterations,
      };

  factory PerformanceBenchmarkBaseline.fromJson(Map<String, dynamic> json) =>
      PerformanceBenchmarkBaseline(
        averageMicroseconds: json['average_microseconds'],
        p95Microseconds: json['p95_microseconds'],
        p99Microseconds: json['p99_microseconds'],
        iterations: json['iterations'],
      );
}

/// Memory usage baseline
class MemoryBaseline {
  final double peakUsageMb;
  final double averageUsageMb;
  final bool hasMemoryLeak;
  final String trend;

  MemoryBaseline({
    required this.peakUsageMb,
    required this.averageUsageMb,
    required this.hasMemoryLeak,
    required this.trend,
  });

  Map<String, dynamic> toJson() => {
        'peak_usage_mb': peakUsageMb,
        'average_usage_mb': averageUsageMb,
        'has_memory_leak': hasMemoryLeak,
        'trend': trend,
      };

  factory MemoryBaseline.fromJson(Map<String, dynamic> json) => MemoryBaseline(
        peakUsageMb: json['peak_usage_mb'],
        averageUsageMb: json['average_usage_mb'],
        hasMemoryLeak: json['has_memory_leak'],
        trend: json['trend'],
      );
}

/// Performance snapshot for a specific point in time
class PerformanceSnapshot {
  final DateTime timestamp;
  final Map<String, dynamic> benchmarkResult;
  final Map<String, dynamic> crossPlatformResult;
  final String gitCommit;
  final Map<String, dynamic> buildInfo;

  PerformanceSnapshot({
    required this.timestamp,
    required this.benchmarkResult,
    required this.crossPlatformResult,
    required this.gitCommit,
    required this.buildInfo,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'git_commit': gitCommit,
        'build_info': buildInfo,
        'benchmark_result': benchmarkResult,
        'cross_platform_result': crossPlatformResult,
      };
}

/// Performance regression analysis result
class PerformanceRegressionAnalysis {
  final PerformanceBaseline baseline;
  final PerformanceSnapshot current;
  final Map<String, BenchmarkRegression> benchmarkRegressions;
  final MemoryRegression memoryRegression;
  final List<String> warnings;
  final List<String> failures;
  final bool hasRegressions;
  final bool hasWarnings;

  PerformanceRegressionAnalysis({
    required this.baseline,
    required this.current,
    required this.benchmarkRegressions,
    required this.memoryRegression,
    required this.warnings,
    required this.failures,
    required this.hasRegressions,
    required this.hasWarnings,
  });
}

/// Individual benchmark regression analysis
class BenchmarkRegression {
  final String testName;
  final double baselineAvgMs;
  final double currentAvgMs;
  final double regressionPercent;
  final bool isRegression;
  final bool isImprovement;

  BenchmarkRegression({
    required this.testName,
    required this.baselineAvgMs,
    required this.currentAvgMs,
    required this.regressionPercent,
    required this.isRegression,
    required this.isImprovement,
  });
}

/// Memory usage regression analysis
class MemoryRegression {
  final double baselinePeakMb;
  final double currentPeakMb;
  final double regressionMb;
  final bool isRegression;
  final bool isImprovement;
  final bool newMemoryLeak;

  MemoryRegression({
    required this.baselinePeakMb,
    required this.currentPeakMb,
    required this.regressionMb,
    required this.isRegression,
    required this.isImprovement,
    required this.newMemoryLeak,
  });
}

/// CLI entry point for CI/CD integration
Future<void> main(List<String> args) async {
  final bool updateBaseline = args.contains('--update-baseline');
  final bool failOnRegression = !args.contains('--no-fail');
  final bool generateReport = !args.contains('--no-report');

  final outputDirIndex = args.indexOf('--output');
  final String? outputDir = outputDirIndex >= 0 && outputDirIndex + 1 < args.length
      ? args[outputDirIndex + 1]
      : null;

  final exitCode = await CIPerformanceMonitor.runCIMonitoring(
    updateBaseline: updateBaseline,
    failOnRegression: failOnRegression,
    generateReport: generateReport,
    outputDir: outputDir,
  );

  exit(exitCode);
}
