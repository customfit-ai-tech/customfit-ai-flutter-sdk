#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';

import 'src/console_colors.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('coverage',
        abbr: 'c',
        help: 'Include coverage analysis',
        defaultsTo: true)
    ..addFlag('performance',
        abbr: 'p',
        help: 'Include performance tests',
        defaultsTo: false)
    ..addFlag('benchmarks',
        abbr: 'b',
        help: 'Include benchmarks',
        defaultsTo: false)
    ..addFlag('stop-on-failure',
        help: 'Stop if any test suite fails',
        defaultsTo: false)
    ..addFlag('verbose',
        abbr: 'v',
        help: 'Show detailed output',
        defaultsTo: false)
    ..addFlag('help',
        abbr: 'h',
        help: 'Show this help message',
        negatable: false);

  final ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    print('Error: $e\n');
    print(parser.usage);
    exit(1);
  }

  if (results['help'] as bool) {
    print('Flutter SDK Test Suite Runner\n');
    print('Runs all test suites in sequence.\n');
    print(parser.usage);
    exit(0);
  }

  final runner = TestSuiteRunner(
    includeCoverage: results['coverage'] as bool,
    includePerformance: results['performance'] as bool,
    includeBenchmarks: results['benchmarks'] as bool,
    stopOnFailure: results['stop-on-failure'] as bool,
    verbose: results['verbose'] as bool,
  );

  final exitCode = await runner.run();
  exit(exitCode);
}

class TestSuiteRunner {
  final bool includeCoverage;
  final bool includePerformance;
  final bool includeBenchmarks;
  final bool stopOnFailure;
  final bool verbose;

  final Map<String, TestResult> results = {};
  final Stopwatch totalTime = Stopwatch();

  TestSuiteRunner({
    required this.includeCoverage,
    required this.includePerformance,
    required this.includeBenchmarks,
    required this.stopOnFailure,
    required this.verbose,
  });

  Future<int> run() async {
    totalTime.start();

    print('${ConsoleColors.highlight('🧪 CustomFit Flutter SDK Test Suite')}');
    print(ConsoleColors.tableSeparator(50));
    print('');

    // Run unit tests
    await _runSuite('Unit Tests', 'tool/run_unit_tests.dart', [
      if (verbose) '--verbose',
      '--junit=test_results.xml',
    ]);

    // Run coverage if requested
    if (includeCoverage) {
      await _runSuite('Coverage Analysis', 'tool/run_coverage.dart', [
        if (verbose) '--verbose',
      ]);
    }

    // Run performance tests if requested
    if (includePerformance) {
      await _runSuite('Performance Tests', 'tool/run_performance.dart', [
        if (verbose) '--verbose',
      ]);
    }

    // Run benchmarks if requested
    if (includeBenchmarks) {
      await _runSuite('Benchmarks', 'tool/run_benchmarks.dart', [
        if (verbose) '--verbose',
        '--output=json',
      ]);
    }

    totalTime.stop();

    // Print summary
    _printSummary();

    // Return overall exit code
    final hasFailures = results.values.any((r) => !r.success);
    return hasFailures ? 1 : 0;
  }

  Future<void> _runSuite(String name, String script, List<String> args) async {
    print('${ConsoleColors.info('▶ Running:')} $name');
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final process = await Process.start(
        'dart',
        ['run', script, ...args],
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;
      stopwatch.stop();

      final success = exitCode == 0;
      results[name] = TestResult(
        name: name,
        success: success,
        duration: stopwatch.elapsed,
        exitCode: exitCode,
      );

      if (success) {
        print('${ConsoleColors.passed()} $name completed successfully\n'.green);
      } else {
        print('${ConsoleColors.failed()} $name failed with exit code $exitCode\n'.red);
        
        if (stopOnFailure) {
          print('Stopping due to failure (--stop-on-failure enabled)'.yellow);
          return;
        }
      }
    } catch (e) {
      stopwatch.stop();
      results[name] = TestResult(
        name: name,
        success: false,
        duration: stopwatch.elapsed,
        exitCode: -1,
        error: e.toString(),
      );
      
      print('${ConsoleColors.failed()} $name failed with error: $e\n'.red);
      
      if (stopOnFailure) {
        print('Stopping due to failure (--stop-on-failure enabled)'.yellow);
        return;
      }
    }
  }

  void _printSummary() {
    print('\n${ConsoleColors.highlight('Test Suite Summary')}');
    print(ConsoleColors.tableSeparator(60));
    
    final header = _padRight('Suite', 25) +
        _padRight('Status', 10) +
        _padRight('Duration', 15) +
        'Exit Code';
    
    print(header.bold);
    print(ConsoleColors.tableSeparator(60));

    for (final entry in results.entries) {
      final result = entry.value;
      final status = result.success 
          ? ConsoleColors.passed().padRight(10) 
          : ConsoleColors.failed().padRight(10);
      final duration = _formatDuration(result.duration);
      final exitCode = result.exitCode.toString();
      
      final row = _padRight(entry.key, 25) +
          status +
          _padRight(duration, 15) +
          exitCode;
      
      print(row);
    }

    print(ConsoleColors.tableSeparator(60));
    
    final successCount = results.values.where((r) => r.success).length;
    final totalCount = results.length;
    final totalDuration = _formatDuration(totalTime.elapsed);
    
    print('Total: $successCount/$totalCount passed in $totalDuration'.bold);
    
    if (successCount == totalCount) {
      print('\n✅ All test suites passed!'.green.bold);
    } else {
      print('\n❌ Some test suites failed'.red.bold);
    }
  }

  String _padRight(String text, int width) {
    if (text.length >= width) {
      return text.substring(0, width - 1) + ' ';
    }
    return text.padRight(width);
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
  }
}

class TestResult {
  final String name;
  final bool success;
  final Duration duration;
  final int exitCode;
  final String? error;

  TestResult({
    required this.name,
    required this.success,
    required this.duration,
    required this.exitCode,
    this.error,
  });
}