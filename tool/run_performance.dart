#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

import 'src/console_colors.dart';
import 'src/test_parser.dart';
import 'src/test_reporter.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('update-baseline',
        help: 'Update performance baseline with current results',
        defaultsTo: false)
    ..addOption('threshold',
        abbr: 't',
        help: 'Regression threshold in milliseconds (override config)',
        valueHelp: 'MS')
    ..addOption('module',
        abbr: 'm',
        help: 'Run performance tests for specific module only',
        valueHelp: 'MODULE_NAME')
    ..addFlag('verbose',
        abbr: 'v',
        help: 'Show detailed output',
        defaultsTo: false)
    ..addFlag('no-color',
        help: 'Disable colored output',
        defaultsTo: false)
    ..addOption('output',
        help: 'Save performance report to file',
        valueHelp: 'PATH')
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
    print('Flutter SDK Performance Test Runner\n');
    print(parser.usage);
    exit(0);
  }

  final runner = PerformanceRunner(
    updateBaseline: results['update-baseline'] as bool,
    threshold: results['threshold'] != null 
        ? int.parse(results['threshold'] as String)
        : null,
    module: results['module'] as String?,
    verbose: results['verbose'] as bool,
    useColors: !(results['no-color'] as bool),
    outputPath: results['output'] as String?,
  );

  final exitCode = await runner.run();
  exit(exitCode);
}

class PerformanceRunner {
  final bool updateBaseline;
  final int? threshold;
  final String? module;
  final bool verbose;
  final bool useColors;
  final String? outputPath;

  late final Map<String, dynamic> config;
  late final Map<String, TestPerformance> performanceResults;
  Map<String, TestPerformance>? baseline;

  PerformanceRunner({
    required this.updateBaseline,
    this.threshold,
    this.module,
    required this.verbose,
    required this.useColors,
    this.outputPath,
  });

  Future<int> run() async {
    // Load configuration
    await _loadConfig();

    print('${ConsoleColors.highlight('⚡ Running Performance Tests')}');
    print(ConsoleColors.tableSeparator(50));

    // Load baseline if not updating
    if (!updateBaseline) {
      await _loadBaseline();
    }

    // Run performance tests
    print('Running stress tests...\n');
    
    final testDir = config['performance']?['directory'] ?? 'test/stress';
    final warmupRuns = config['performance']?['warmup_runs'] ?? 3;
    final measurementRuns = config['performance']?['measurement_runs'] ?? 10;
    
    // Build test command
    final command = _buildTestCommand(testDir);
    
    if (verbose) {
      print('Command: ${command.join(' ')}'.dim);
      print('Warmup runs: $warmupRuns');
      print('Measurement runs: $measurementRuns\n');
    }

    // Warmup runs
    print('Performing warmup runs...');
    for (int i = 0; i < warmupRuns; i++) {
      await _runTests(command, isWarmup: true);
      print('  Warmup ${i + 1}/$warmupRuns complete'.dim);
    }

    // Measurement runs
    print('\nPerforming measurement runs...');
    final measurements = <String, List<int>>{};
    
    for (int i = 0; i < measurementRuns; i++) {
      final results = await _runTests(command, isWarmup: false);
      
      for (final entry in results.entries) {
        measurements.putIfAbsent(entry.key, () => []).add(entry.value);
      }
      
      print('  Measurement ${i + 1}/$measurementRuns complete'.dim);
    }

    // Calculate statistics
    performanceResults = _calculateStatistics(measurements);

    // Print results
    _printPerformanceResults();

    // Check for regressions
    final hasRegressions = _checkRegressions();

    // Save report if requested
    if (outputPath != null) {
      await _saveReport();
    }

    // Update baseline if requested
    if (updateBaseline) {
      await _updateBaseline();
      print('\n✅ Performance baseline updated'.green);
      return 0;
    }

    if (hasRegressions) {
      print('\n❌ Performance regressions detected!'.red.bold);
      return 1;
    } else {
      print('\n✅ All performance tests passed'.green.bold);
      return 0;
    }
  }

  Future<void> _loadConfig() async {
    final configPath = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      'tool',
      'test_config.yaml',
    );

    final configFile = File(configPath);
    if (!await configFile.exists()) {
      config = {};
      return;
    }

    final configContent = await configFile.readAsString();
    final yamlMap = loadYaml(configContent);
    config = yamlMap != null ? Map<String, dynamic>.from(yamlMap) : {};
  }

  Future<void> _loadBaseline() async {
    final baselinePath = config['performance']?['baseline_file'] ?? 
        'tool/performance_baseline.json';
    
    final fullPath = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      baselinePath,
    );

    final baselineFile = File(fullPath);
    if (!await baselineFile.exists()) {
      print('Warning: No baseline found. First run will establish baseline.'.yellow);
      return;
    }

    try {
      final content = await baselineFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      baseline = {};
      for (final entry in data['tests'].entries) {
        baseline![entry.key] = TestPerformance.fromJson(entry.value);
      }
      
      print('Loaded baseline from ${data['timestamp']}'.dim);
    } catch (e) {
      print('Warning: Failed to load baseline: $e'.yellow);
    }
  }

  List<String> _buildTestCommand(String testDir) {
    final command = ['test'];
    
    // Add reporter
    command.add('--reporter=json');
    
    // Add timeout
    command.add('--timeout=300s');
    
    // Add test directory or specific module
    if (module != null) {
      command.add('$testDir/$module');
    } else {
      command.add(testDir);
    }
    
    return command;
  }

  Future<Map<String, int>> _runTests(List<String> command, {required bool isWarmup}) async {
    final process = await Process.start(
      'flutter',
      command,
      workingDirectory: p.dirname(p.dirname(Platform.script.path)),
    );

    final results = <String, int>{};
    final parser = TestParser();
    
    // Parse JSON output to get test durations
    await for (final line in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      
      try {
        final event = jsonDecode(line) as Map<String, dynamic>;
        
        if (event['type'] == 'testDone') {
          final test = event['test'] as Map<String, dynamic>?;
          if (test != null) {
            final name = test['name'] as String;
            final duration = event['time'] as int? ?? 0;
            
            if (!name.contains('group') && duration > 0) {
              results[name] = duration;
            }
          }
        }
      } catch (e) {
        // Not JSON, ignore
      }
    }

    await process.exitCode;
    return results;
  }

  Map<String, TestPerformance> _calculateStatistics(Map<String, List<int>> measurements) {
    final results = <String, TestPerformance>{};
    
    for (final entry in measurements.entries) {
      final values = entry.value..sort();
      
      if (values.isEmpty) continue;
      
      final mean = values.reduce((a, b) => a + b) / values.length;
      final median = values[values.length ~/ 2];
      final min = values.first;
      final max = values.last;
      
      // Calculate standard deviation
      final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
      final stdDev = (variance > 0) ? (variance).round() : 0;
      
      // Calculate percentiles
      final p95 = values[(values.length * 0.95).floor()];
      final p99 = values[(values.length * 0.99).floor()];
      
      results[entry.key] = TestPerformance(
        name: entry.key,
        mean: mean.round(),
        median: median,
        min: min,
        max: max,
        stdDev: stdDev,
        p95: p95,
        p99: p99,
        samples: values.length,
      );
    }
    
    return results;
  }

  void _printPerformanceResults() {
    print('\n${ConsoleColors.highlight('Performance Test Results')}');
    print(ConsoleColors.tableSeparator(100));
    
    final header = _padRight('Test Name', 40) +
        _padRight('Mean', 8) +
        _padRight('Median', 8) +
        _padRight('StdDev', 8) +
        _padRight('Min', 8) +
        _padRight('Max', 8) +
        _padRight('P95', 8) +
        _padRight('P99', 8) +
        'Status';
    
    print(header.bold);
    print(ConsoleColors.tableSeparator(100));

    // Sort by test name
    final sortedResults = performanceResults.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedResults) {
      _printPerformanceRow(entry.key, entry.value);
    }
  }

  void _printPerformanceRow(String name, TestPerformance perf) {
    final baselinePerf = baseline?[name];
    String status = '';
    String meanColor = '';
    
    if (baselinePerf != null) {
      final diff = perf.mean - baselinePerf.mean;
      final percentage = (diff / baselinePerf.mean * 100).abs();
      
      final regressionThreshold = threshold ?? 
          config['performance']?['regression_threshold_ms'] ?? 50;
      
      if (diff > regressionThreshold) {
        status = '↑ +${diff}ms (+${percentage.toStringAsFixed(1)}%)'.red;
        meanColor = ConsoleColors.red;
      } else if (diff < -regressionThreshold) {
        status = '↓ -${diff.abs()}ms (-${percentage.toStringAsFixed(1)}%)'.green;
        meanColor = ConsoleColors.green;
      } else {
        status = '→ ±${diff.abs()}ms'.dim;
        meanColor = '';
      }
    } else {
      status = 'NEW'.cyan;
    }
    
    final displayName = name.length > 39 ? name.substring(0, 36) + '...' : name;
    
    final row = _padRight(displayName, 40) +
        ColoredStringPerf(_padRight('${perf.mean}ms', 8)).color(meanColor) +
        _padRight('${perf.median}ms', 8) +
        _padRight('${perf.stdDev}ms', 8) +
        _padRight('${perf.min}ms', 8) +
        _padRight('${perf.max}ms', 8) +
        _padRight('${perf.p95}ms', 8) +
        _padRight('${perf.p99}ms', 8) +
        status;
    
    print(row);
  }

  bool _checkRegressions() {
    if (baseline == null) return false;
    
    final regressionThreshold = threshold ?? 
        config['performance']?['regression_threshold_ms'] ?? 50;
    
    bool hasRegressions = false;
    
    for (final entry in performanceResults.entries) {
      final baselinePerf = baseline![entry.key];
      if (baselinePerf == null) continue;
      
      final diff = entry.value.mean - baselinePerf.mean;
      if (diff > regressionThreshold) {
        hasRegressions = true;
        break;
      }
    }
    
    return hasRegressions;
  }

  Future<void> _updateBaseline() async {
    final baselinePath = config['performance']?['baseline_file'] ?? 
        'tool/performance_baseline.json';
    
    final fullPath = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      baselinePath,
    );

    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'flutter_version': await _getFlutterVersion(),
      'tests': performanceResults.map((name, perf) => MapEntry(name, perf.toJson())),
    };

    final file = File(fullPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<void> _saveReport() async {
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'flutter_version': await _getFlutterVersion(),
      'configuration': {
        'warmup_runs': config['performance']?['warmup_runs'] ?? 3,
        'measurement_runs': config['performance']?['measurement_runs'] ?? 10,
      },
      'results': performanceResults.map((name, perf) => MapEntry(name, {
        ...perf.toJson(),
        'baseline': baseline?[name]?.toJson(),
        'regression': baseline?[name] != null 
            ? perf.mean - baseline![name]!.mean 
            : null,
      })),
    };

    final file = File(outputPath!);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    
    print('\nPerformance report saved to: $outputPath'.dim);
  }

  Future<String> _getFlutterVersion() async {
    try {
      final result = await Process.run('flutter', ['--version']);
      final output = result.stdout as String;
      final match = RegExp(r'Flutter (\S+)').firstMatch(output);
      return match?.group(1) ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  String _padRight(String text, int width) {
    if (text.length >= width) {
      return text.substring(0, width - 1) + ' ';
    }
    return text.padRight(width);
  }
}

// Extension for colored strings
extension ColoredStringPerf on String {
  String color(String colorCode) {
    if (colorCode.isEmpty) return this;
    return '$colorCode$this${ConsoleColors.reset}';
  }
}

class TestPerformance {
  final String name;
  final int mean;
  final int median;
  final int min;
  final int max;
  final int stdDev;
  final int p95;
  final int p99;
  final int samples;

  TestPerformance({
    required this.name,
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    required this.stdDev,
    required this.p95,
    required this.p99,
    required this.samples,
  });

  factory TestPerformance.fromJson(Map<String, dynamic> json) {
    return TestPerformance(
      name: json['name'] as String,
      mean: json['mean'] as int,
      median: json['median'] as int,
      min: json['min'] as int,
      max: json['max'] as int,
      stdDev: json['stdDev'] as int,
      p95: json['p95'] as int,
      p99: json['p99'] as int,
      samples: json['samples'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mean': mean,
      'median': median,
      'min': min,
      'max': max,
      'stdDev': stdDev,
      'p95': p95,
      'p99': p99,
      'samples': samples,
    };
  }
}