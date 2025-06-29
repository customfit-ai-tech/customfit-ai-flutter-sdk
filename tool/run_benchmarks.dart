#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

import 'src/console_colors.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('operation',
        abbr: 'o',
        help: 'Specific operation to benchmark',
        allowed: [
          'client_initialization',
          'flag_evaluation', 
          'event_tracking',
          'cache_operations',
          'network_requests',
          'all'
        ],
        defaultsTo: 'all')
    ..addOption('iterations',
        abbr: 'i',
        help: 'Number of iterations (override config)',
        valueHelp: 'COUNT')
    ..addFlag('compare',
        help: 'Compare with previous benchmark results',
        defaultsTo: true)
    ..addFlag('verbose',
        abbr: 'v',
        help: 'Show detailed output',
        defaultsTo: false)
    ..addFlag('no-color',
        help: 'Disable colored output',
        defaultsTo: false)
    ..addOption('output',
        help: 'Output format',
        allowed: ['console', 'json', 'csv', 'all'],
        defaultsTo: 'console')
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
    print('Flutter SDK Benchmark Runner\n');
    print(parser.usage);
    exit(0);
  }

  final runner = BenchmarkRunner(
    operation: results['operation'] as String,
    iterations: results['iterations'] != null 
        ? int.parse(results['iterations'] as String)
        : null,
    compare: results['compare'] as bool,
    verbose: results['verbose'] as bool,
    useColors: !(results['no-color'] as bool),
    outputFormat: results['output'] as String,
  );

  final exitCode = await runner.run();
  exit(exitCode);
}

class BenchmarkRunner {
  final String operation;
  final int? iterations;
  final bool compare;
  final bool verbose;
  final bool useColors;
  final String outputFormat;

  late final Map<String, dynamic> config;
  final Map<String, BenchmarkResult> results = {};
  Map<String, BenchmarkResult>? previousResults;

  BenchmarkRunner({
    required this.operation,
    this.iterations,
    required this.compare,
    required this.verbose,
    required this.useColors,
    required this.outputFormat,
  });

  Future<int> run() async {
    // Load configuration
    await _loadConfig();

    print('${ConsoleColors.highlight('📈 Running Benchmarks')}');
    print(ConsoleColors.tableSeparator(50));

    // Load previous results for comparison
    if (compare) {
      await _loadPreviousResults();
    }

    // Get operations to benchmark
    final operations = _getOperations();
    
    print('Operations: ${operations.join(', ')}');
    print('Iterations: ${_getIterations()} (${_getWarmupRuns()} warmup)\n');

    // Run benchmarks
    for (final op in operations) {
      await _runBenchmark(op);
    }

    // Print results
    _printResults();

    // Save results
    await _saveResults();

    return 0;
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

  Future<void> _loadPreviousResults() async {
    final resultsPath = config['benchmarks']?['results_file'] ?? 
        'tool/benchmark_results.json';
    
    final fullPath = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      resultsPath,
    );

    final resultsFile = File(fullPath);
    if (!await resultsFile.exists()) {
      return;
    }

    try {
      final content = await resultsFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      previousResults = {};
      for (final entry in (data['benchmarks'] as Map<String, dynamic>).entries) {
        previousResults![entry.key] = BenchmarkResult.fromJson(entry.value);
      }
      
      print('Loaded previous results from ${data['timestamp']}'.dim);
    } catch (e) {
      print('Warning: Failed to load previous results: $e'.yellow);
    }
  }

  List<String> _getOperations() {
    if (operation == 'all') {
      return config['benchmarks']?['operations'] ?? [
        'client_initialization',
        'flag_evaluation',
        'event_tracking',
        'cache_operations',
        'network_requests',
      ];
    }
    return [operation];
  }

  int _getIterations() {
    return iterations ?? 
        config['benchmarks']?['measurement_runs'] ?? 
        20;
  }

  int _getWarmupRuns() {
    return config['benchmarks']?['warmup_runs'] ?? 5;
  }

  Future<void> _runBenchmark(String operation) async {
    print('Benchmarking: $operation...');
    
    // Create benchmark test file
    final benchmarkCode = _generateBenchmarkCode(operation);
    final tempFile = await _createTempBenchmarkFile(benchmarkCode);
    
    try {
      // Run warmup
      if (verbose) print('  Running warmup...'.dim);
      for (int i = 0; i < _getWarmupRuns(); i++) {
        await _runBenchmarkTest(tempFile.path);
      }
      
      // Run measurements
      if (verbose) print('  Running measurements...'.dim);
      final measurements = <int>[];
      
      for (int i = 0; i < _getIterations(); i++) {
        final duration = await _runBenchmarkTest(tempFile.path);
        measurements.add(duration);
        
        if (verbose && i % 5 == 0) {
          print('    Progress: ${i + 1}/${_getIterations()}'.dim);
        }
      }
      
      // Calculate results
      results[operation] = _calculateResults(operation, measurements);
      
      print('  ✓ Complete'.green);
    } finally {
      // Clean up temp file
      await tempFile.delete();
    }
  }

  String _generateBenchmarkCode(String operation) {
    switch (operation) {
      case 'client_initialization':
        return '''
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';

void main() {
  test('benchmark', () async {
    final stopwatch = Stopwatch()..start();
    
    final config = CFConfig.builder('test-key')
        .setServerUrl('https://test.com')
        .build();
    
    await CFClient.initialize(config);
    await CFClient.shutdown();
    
    stopwatch.stop();
    print('BENCHMARK_RESULT: \${stopwatch.elapsedMicroseconds}');
  });
}
''';

      case 'flag_evaluation':
        return '''
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';

void main() {
  test('benchmark', () async {
    // Setup
    final config = CFConfig.builder('test-key').build();
    await CFClient.initialize(config);
    await CFClient.setUser(CFUser.builder('test-user').build());
    
    // Benchmark
    final stopwatch = Stopwatch()..start();
    
    for (int i = 0; i < 1000; i++) {
      CFClient.getBooleanFlag('test-flag', false);
    }
    
    stopwatch.stop();
    print('BENCHMARK_RESULT: \${stopwatch.elapsedMicroseconds ~/ 1000}'); // Per operation
    
    await CFClient.shutdown();
  });
}
''';

      case 'event_tracking':
        return '''
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';

void main() {
  test('benchmark', () async {
    // Setup
    final config = CFConfig.builder('test-key')
        .setEventsFlushIntervalMs(60000) // Don't auto-flush
        .build();
    await CFClient.initialize(config);
    await CFClient.setUser(CFUser.builder('test-user').build());
    
    // Benchmark
    final stopwatch = Stopwatch()..start();
    
    for (int i = 0; i < 100; i++) {
      await CFClient.trackEvent('test-event', {'index': i});
    }
    
    stopwatch.stop();
    print('BENCHMARK_RESULT: \${stopwatch.elapsedMicroseconds ~/ 100}'); // Per operation
    
    await CFClient.shutdown();
  });
}
''';

      case 'cache_operations':
        return '''
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/storage/implementations/shared_prefs_storage.dart';

void main() {
  test('benchmark', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    final storage = SharedPrefsStorage();
    await storage.initialize();
    
    // Benchmark write operations
    final stopwatch = Stopwatch()..start();
    
    for (int i = 0; i < 100; i++) {
      await storage.setString('test-key-\$i', 'test-value-\$i');
    }
    
    // Benchmark read operations
    for (int i = 0; i < 100; i++) {
      await storage.getString('test-key-\$i');
    }
    
    stopwatch.stop();
    print('BENCHMARK_RESULT: \${stopwatch.elapsedMicroseconds ~/ 200}'); // Per operation
    
    // Cleanup
    await storage.clear();
  });
}
''';

      case 'network_requests':
        return '''
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  test('benchmark', () async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    
    // Mock interceptor to avoid real network calls
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'status': 'ok'},
        ));
      },
    ));
    
    // Benchmark
    final stopwatch = Stopwatch()..start();
    
    for (int i = 0; i < 50; i++) {
      await dio.get('https://test.com/api/test');
    }
    
    stopwatch.stop();
    print('BENCHMARK_RESULT: \${stopwatch.elapsedMicroseconds ~/ 50}'); // Per operation
  });
}
''';

      default:
        throw Exception('Unknown operation: $operation');
    }
  }

  Future<File> _createTempBenchmarkFile(String code) async {
    final tempDir = await Directory.systemTemp.createTemp('benchmark_');
    final tempFile = File(p.join(tempDir.path, 'benchmark_test.dart'));
    await tempFile.writeAsString(code);
    return tempFile;
  }

  Future<int> _runBenchmarkTest(String testPath) async {
    final process = await Process.start(
      'flutter',
      ['test', testPath, '--reporter=json'],
      workingDirectory: p.dirname(p.dirname(Platform.script.path)),
    );

    int? duration;
    
    await for (final line in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.contains('BENCHMARK_RESULT:')) {
        final match = RegExp(r'BENCHMARK_RESULT: (\d+)').firstMatch(line);
        if (match != null) {
          duration = int.parse(match.group(1)!);
        }
      }
    }

    await process.exitCode;
    
    if (duration == null) {
      throw Exception('Failed to get benchmark result');
    }
    
    return duration;
  }

  BenchmarkResult _calculateResults(String operation, List<int> measurements) {
    measurements.sort();
    
    final mean = measurements.reduce((a, b) => a + b) / measurements.length;
    final median = measurements[measurements.length ~/ 2];
    final min = measurements.first;
    final max = measurements.last;
    
    // Calculate standard deviation
    final variance = measurements.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / measurements.length;
    final stdDev = (variance > 0) ? (variance).round() : 0;
    
    // Calculate throughput (operations per second)
    final throughput = mean > 0 ? (1000000 / mean).round() : 0;
    
    return BenchmarkResult(
      operation: operation,
      mean: mean.round(),
      median: median,
      min: min,
      max: max,
      stdDev: stdDev,
      throughput: throughput,
      samples: measurements.length,
    );
  }

  void _printResults() {
    print('\n${ConsoleColors.highlight('Benchmark Results')}');
    print(ConsoleColors.tableSeparator(90));
    
    final header = _padRight('Operation', 25) +
        _padRight('Mean', 10) +
        _padRight('Median', 10) +
        _padRight('StdDev', 10) +
        _padRight('Min-Max', 15) +
        _padRight('Ops/sec', 10) +
        'Change';
    
    print(header.bold);
    print(ConsoleColors.tableSeparator(90));

    for (final entry in results.entries) {
      _printResultRow(entry.key, entry.value);
    }
    
    print('');
    print('Times in microseconds (μs)'.dim);
  }

  void _printResultRow(String operation, BenchmarkResult result) {
    final prev = previousResults?[operation];
    String change = '';
    String meanColor = '';
    
    if (prev != null) {
      final diff = result.mean - prev.mean;
      final percentage = (diff / prev.mean * 100).abs();
      
      if (diff > 0) {
        change = '↑ +${percentage.toStringAsFixed(1)}%'.red;
        meanColor = ConsoleColors.red;
      } else if (diff < 0) {
        change = '↓ -${percentage.toStringAsFixed(1)}%'.green;
        meanColor = ConsoleColors.green;
      } else {
        change = '→ 0%'.dim;
      }
    } else {
      change = 'NEW'.cyan;
    }
    
    final row = _padRight(operation, 25) +
        _padRight('${result.mean}μs', 10).color(meanColor) +
        _padRight('${result.median}μs', 10) +
        _padRight('${result.stdDev}μs', 10) +
        _padRight('${result.min}-${result.max}μs', 15) +
        _padRight(result.throughput.toString(), 10) +
        change;
    
    print(row);
  }

  Future<void> _saveResults() async {
    final timestamp = DateTime.now();
    
    // Save JSON format
    if (outputFormat == 'json' || outputFormat == 'all') {
      await _saveJsonResults(timestamp);
    }
    
    // Save CSV format
    if (outputFormat == 'csv' || outputFormat == 'all') {
      await _saveCsvResults(timestamp);
    }
    
    // Always update the main results file for comparison
    await _updateMainResults(timestamp);
  }

  Future<void> _saveJsonResults(DateTime timestamp) async {
    final data = {
      'timestamp': timestamp.toIso8601String(),
      'flutter_version': await _getFlutterVersion(),
      'configuration': {
        'warmup_runs': _getWarmupRuns(),
        'measurement_runs': _getIterations(),
      },
      'benchmarks': results.map((name, result) => MapEntry(name, result.toJson())),
    };

    final path = 'tool/benchmark_${timestamp.millisecondsSinceEpoch}.json';
    final file = File(p.join(
      p.dirname(p.dirname(Platform.script.path)),
      path,
    ));
    
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    print('JSON results saved to: $path'.dim);
  }

  Future<void> _saveCsvResults(DateTime timestamp) async {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Operation,Mean(μs),Median(μs),StdDev(μs),Min(μs),Max(μs),Throughput(ops/s)');
    
    // Data
    for (final entry in results.entries) {
      final r = entry.value;
      buffer.writeln('${r.operation},${r.mean},${r.median},${r.stdDev},${r.min},${r.max},${r.throughput}');
    }
    
    final path = 'tool/benchmark_${timestamp.millisecondsSinceEpoch}.csv';
    final file = File(p.join(
      p.dirname(p.dirname(Platform.script.path)),
      path,
    ));
    
    await file.writeAsString(buffer.toString());
    print('CSV results saved to: $path'.dim);
  }

  Future<void> _updateMainResults(DateTime timestamp) async {
    final resultsPath = config['benchmarks']?['results_file'] ?? 
        'tool/benchmark_results.json';
    
    final fullPath = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      resultsPath,
    );

    final data = {
      'timestamp': timestamp.toIso8601String(),
      'flutter_version': await _getFlutterVersion(),
      'benchmarks': results.map((name, result) => MapEntry(name, result.toJson())),
    };

    final file = File(fullPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
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
extension ColoredStringBench on String {
  String color(String colorCode) {
    if (colorCode.isEmpty) return this;
    return '$colorCode$this${ConsoleColors.reset}';
  }
}

class BenchmarkResult {
  final String operation;
  final int mean;
  final int median;
  final int min;
  final int max;
  final int stdDev;
  final int throughput;
  final int samples;

  BenchmarkResult({
    required this.operation,
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    required this.stdDev,
    required this.throughput,
    required this.samples,
  });

  factory BenchmarkResult.fromJson(Map<String, dynamic> json) {
    return BenchmarkResult(
      operation: json['operation'] as String,
      mean: json['mean'] as int,
      median: json['median'] as int,
      min: json['min'] as int,
      max: json['max'] as int,
      stdDev: json['stdDev'] as int,
      throughput: json['throughput'] as int,
      samples: json['samples'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operation': operation,
      'mean': mean,
      'median': median,
      'min': min,
      'max': max,
      'stdDev': stdDev,
      'throughput': throughput,
      'samples': samples,
    };
  }
}