#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

import 'src/test_parser.dart';
import 'src/test_reporter.dart';
import 'src/console_colors.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('module',
        abbr: 'm',
        help: 'Run tests for specific module only',
        valueHelp: 'MODULE_NAME')
    ..addOption('tags',
        abbr: 't', 
        help: 'Run tests with specific tags',
        valueHelp: 'TAG_EXPRESSION')
    ..addFlag('coverage',
        abbr: 'c',
        help: 'Generate coverage report',
        defaultsTo: false)
    ..addFlag('verbose',
        abbr: 'v',
        help: 'Show detailed output',
        defaultsTo: false)
    ..addFlag('no-color',
        help: 'Disable colored output',
        defaultsTo: false)
    ..addFlag('fail-fast',
        help: 'Stop on first test failure',
        defaultsTo: false)
    ..addOption('reporter',
        abbr: 'r',
        help: 'Test reporter format',
        allowed: ['compact', 'expanded', 'json'],
        defaultsTo: 'expanded')
    ..addOption('junit',
        help: 'Generate JUnit XML report at path',
        valueHelp: 'PATH')
    ..addOption('json-report',
        help: 'Generate JSON report at path',
        valueHelp: 'PATH')
    ..addOption('shard',
        help: 'Run a subset of tests (e.g., 1/3 runs first third)',
        valueHelp: 'INDEX/TOTAL')
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
    print('Flutter SDK Unit Test Runner\n');
    print(parser.usage);
    exit(0);
  }

  final runner = UnitTestRunner(
    module: results['module'] as String?,
    tags: results['tags'] as String?,
    coverage: results['coverage'] as bool,
    verbose: results['verbose'] as bool,
    useColors: !(results['no-color'] as bool),
    failFast: results['fail-fast'] as bool,
    reporter: results['reporter'] as String,
    junitPath: results['junit'] as String?,
    jsonReportPath: results['json-report'] as String?,
    shard: results['shard'] as String?,
  );

  final exitCode = await runner.run();
  exit(exitCode);
}

class UnitTestRunner {
  final String? module;
  final String? tags;
  final bool coverage;
  final bool verbose;
  final bool useColors;
  final bool failFast;
  final String reporter;
  final String? junitPath;
  final String? jsonReportPath;
  final String? shard;

  late final Map<String, dynamic> config;
  late final TestReporter testReporter;

  UnitTestRunner({
    this.module,
    this.tags,
    required this.coverage,
    required this.verbose,
    required this.useColors,
    required this.failFast,
    required this.reporter,
    this.junitPath,
    this.jsonReportPath,
    this.shard,
  });

  Future<int> run() async {
    // Load configuration
    await _loadConfig();

    // Create reporter
    testReporter = TestReporter(
      useColors: useColors && ConsoleColors.supportsColor,
      verbose: verbose,
      showStackTraces: config['reporting']?['show_stack_traces'] ?? true,
      showModuleSummary: config['reporting']?['show_module_summary'] ?? true,
      showTestTiming: config['reporting']?['show_test_timing'] ?? true,
    );

    print('${ConsoleColors.highlight('🧪 Running Flutter SDK Unit Tests')}');
    print(ConsoleColors.tableSeparator(50));

    // Build flutter test command
    final command = _buildTestCommand();
    
    if (verbose) {
      print('Command: ${command.join(' ')}'.dim);
      print('');
    }

    // Run tests
    final process = await Process.start(
      'flutter',
      command,
      workingDirectory: p.dirname(p.dirname(Platform.script.path)),
    );

    // Parse test output with streaming for performance
    final parser = TestParser();
    TestRunSummary? summary;

    if (reporter == 'json') {
      // Stream JSON output for better performance with large test suites
      final outputLines = <String>[];
      final completer = Completer<TestRunSummary>();
      
      // Process output in chunks for better performance
      final jsonStream = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      
      // Start parsing immediately in background
      parser.parseJsonOutput(jsonStream).then(completer.complete);
      
      // Also display output in real-time if verbose
      if (verbose) {
        jsonStream.listen((line) {
          if (line.trim().isNotEmpty && !line.startsWith('{')) {
            print(line.dim);
          }
        });
      }
      
      // Handle stderr
      process.stderr.transform(utf8.decoder).forEach((line) {
        stderr.write(line);
      });
      
      summary = await completer.future;
    } else {
      // For compact/expanded, stream output for real-time display
      final output = StringBuffer();
      final outputController = StreamController<String>();
      
      // Process in parallel for better performance
      await Future.wait([
        process.stdout.transform(utf8.decoder).forEach((line) {
          print(line); // Real-time output
          outputController.add(line);
          output.writeln(line);
        }),
        process.stderr.transform(utf8.decoder).forEach((line) {
          stderr.write(line);
        }),
      ]);
      
      outputController.close();
      summary = TestParser.parseSimpleOutput(output.toString());
    }

    final exitCode = await process.exitCode;

    // Print results
    if (summary.totalTests > 0) {
      testReporter.printModuleSummary(summary);
      testReporter.printFailedTests(summary);
      testReporter.printExecutionSummary(summary);

      // Generate reports
      if (junitPath != null) {
        await testReporter.generateJUnitReport(summary, junitPath!);
      }

      if (jsonReportPath != null) {
        await testReporter.generateJsonReport(summary, jsonReportPath!);
      }
    }

    // Check if we met the pass rate threshold
    if (exitCode == 0 && config['unit_tests']?['min_pass_rate'] != null) {
      final minPassRate = config['unit_tests']['min_pass_rate'] as num;
      if (summary.overallPassRate < minPassRate) {
        print('\n❌ Pass rate ${summary.overallPassRate.toStringAsFixed(1)}% is below threshold of $minPassRate%'.red);
        return 1;
      }
    }

    return exitCode;
  }

  Future<void> _loadConfig() async {
    final configPath = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      'tool',
      'test_config.yaml',
    );

    final configFile = File(configPath);
    if (!await configFile.exists()) {
      print('Warning: test_config.yaml not found, using defaults'.yellow);
      config = {};
      return;
    }

    final configContent = await configFile.readAsString();
    final yamlMap = loadYaml(configContent);
    config = yamlMap != null ? Map<String, dynamic>.from(yamlMap) : {};
  }

  List<String> _buildTestCommand() {
    final command = ['test'];

    // Add reporter
    if (reporter == 'json') {
      command.add('--reporter=json');
    } else {
      command.add('--reporter=$reporter');
    }

    // Add coverage
    if (coverage) {
      command.add('--coverage');
    }

    // Add fail fast
    if (failFast) {
      command.add('--fail-fast');
    }

    // Add test timeout
    final timeout = config['unit_tests']?['timeout'] ?? 30;
    command.add('--timeout=${timeout}s');

    // Add concurrency with smart defaults based on CPU cores
    if (config['unit_tests']?['parallel'] == true) {
      final cores = Platform.numberOfProcessors;
      final concurrency = config['unit_tests']?['concurrency'] ?? (cores > 4 ? cores - 1 : cores);
      command.add('--concurrency=$concurrency');
    }

    // Add randomization
    if (config['unit_tests']?['randomize'] == true) {
      final seed = DateTime.now().millisecondsSinceEpoch;
      command.add('--test-randomize-ordering-seed=$seed');
    }

    // Add tags
    if (tags != null) {
      command.add('--tags=$tags');
    } else if (config['exclude_tags'] != null) {
      command.add('--exclude-tags=${config['exclude_tags']}');
    }
    
    // Add shard
    if (shard != null) {
      // Validate shard format
      final shardParts = shard.split('/');
      if (shardParts.length == 2) {
        final shardIndex = int.tryParse(shardParts[0]);
        final totalShards = int.tryParse(shardParts[1]);
        if (shardIndex != null && totalShards != null && 
            shardIndex > 0 && shardIndex <= totalShards) {
          command.add('--shard-index=${shardIndex - 1}'); // Flutter uses 0-based index
          command.add('--total-shards=$totalShards');
        }
      }
    }

    // Add module filter or test directories
    if (module != null) {
      // Run tests for specific module
      command.add('test/unit/$module');
    } else {
      // Add all test directories from config
      final testDirs = config['test_directories'] as YamlList?;
      if (testDirs != null) {
        for (final dir in testDirs) {
          if (dir.toString().contains('unit')) {
            command.add(dir.toString());
          }
        }
      } else {
        command.add('test/unit');
      }
    }

    // Add any remaining arguments
    command.addAll(Platform.executableArguments);

    return command;
  }
}