#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

import 'src/console_colors.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('min-coverage',
        help: 'Minimum coverage threshold (override config)',
        valueHelp: 'PERCENTAGE')
    ..addFlag('open',
        abbr: 'o',
        help: 'Open HTML report in browser',
        defaultsTo: false)
    ..addOption('format',
        abbr: 'f',
        help: 'Output format',
        allowed: ['summary', 'detailed', 'lcov'],
        defaultsTo: 'summary')
    ..addFlag('verbose',
        abbr: 'v',
        help: 'Show detailed output',
        defaultsTo: false)
    ..addFlag('no-color',
        help: 'Disable colored output',
        defaultsTo: false)
    ..addOption('output',
        help: 'Save report to file',
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
    print('Flutter SDK Coverage Analysis\n');
    print(parser.usage);
    exit(0);
  }

  final runner = CoverageRunner(
    minCoverage: results['min-coverage'] != null 
        ? double.parse(results['min-coverage'] as String)
        : null,
    openReport: results['open'] as bool,
    format: results['format'] as String,
    verbose: results['verbose'] as bool,
    useColors: !(results['no-color'] as bool),
    outputPath: results['output'] as String?,
  );

  final exitCode = await runner.run();
  exit(exitCode);
}

class CoverageRunner {
  final double? minCoverage;
  final bool openReport;
  final String format;
  final bool verbose;
  final bool useColors;
  final String? outputPath;

  late final Map<String, dynamic> config;
  late final Map<String, ModuleCoverage> moduleCoverage;

  CoverageRunner({
    this.minCoverage,
    required this.openReport,
    required this.format,
    required this.verbose,
    required this.useColors,
    this.outputPath,
  });

  Future<int> run() async {
    // Load configuration
    await _loadConfig();

    print('${ConsoleColors.highlight('📊 Running Coverage Analysis')}');
    print(ConsoleColors.tableSeparator(50));

    // Run tests with coverage
    print('Running tests with coverage...\n');
    
    final testProcess = await Process.start(
      'flutter',
      ['test', '--coverage'],
      workingDirectory: p.dirname(p.dirname(Platform.script.path)),
    );

    // Show test output in verbose mode
    if (verbose) {
      await Future.wait([
        testProcess.stdout.transform(utf8.decoder).forEach(print),
        testProcess.stderr.transform(utf8.decoder).forEach(stderr.write),
      ]);
    } else {
      // Just consume the output
      await Future.wait([
        testProcess.stdout.drain(),
        testProcess.stderr.drain(),
      ]);
    }

    final testExitCode = await testProcess.exitCode;
    if (testExitCode != 0) {
      print('❌ Tests failed with exit code $testExitCode'.red);
      return testExitCode;
    }

    print('✅ Tests completed successfully\n'.green);

    // Parse coverage data
    print('Analyzing coverage data...');
    await _parseCoverageData();

    // Generate reports based on format
    switch (format) {
      case 'summary':
        _printCoverageSummary();
        break;
      case 'detailed':
        _printDetailedCoverage();
        break;
      case 'lcov':
        _printLcovPath();
        break;
    }

    // Save report if requested
    if (outputPath != null) {
      await _saveReport();
    }

    // Generate HTML report
    final htmlPath = await _generateHtmlReport();
    print('\n📄 HTML report: file://$htmlPath'.dim);

    // Open report if requested
    if (openReport || config['coverage']?['html_report']?['auto_open'] == true) {
      await _openHtmlReport(htmlPath);
    }

    // Track coverage history
    await _trackCoverageHistory();

    // Check coverage threshold
    final threshold = minCoverage ?? 
        (config['coverage']?['min_threshold'] as num?)?.toDouble() ?? 
        80.0;
    
    final overallCoverage = _calculateOverallCoverage();
    
    if (overallCoverage < threshold) {
      print('\n❌ Coverage ${overallCoverage.toStringAsFixed(1)}% is below threshold of ${threshold}%'.red.bold);
      return 1;
    } else {
      print('\n✅ Coverage ${overallCoverage.toStringAsFixed(1)}% meets threshold of ${threshold}%'.green.bold);
    }

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

  Future<void> _parseCoverageData() async {
    final lcovPath = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      'coverage',
      'lcov.info',
    );

    final lcovFile = File(lcovPath);
    if (!await lcovFile.exists()) {
      throw Exception('Coverage data not found at $lcovPath');
    }

    final lcovContent = await lcovFile.readAsString();
    moduleCoverage = _parseLcov(lcovContent);
  }

  Map<String, ModuleCoverage> _parseLcov(String lcovContent) {
    final modules = <String, ModuleCoverage>{};
    
    String? currentFile;
    final fileData = <String, FileData>{};
    
    for (final line in lcovContent.split('\n')) {
      if (line.startsWith('SF:')) {
        currentFile = line.substring(3);
      } else if (line.startsWith('DA:')) {
        if (currentFile != null) {
          final parts = line.substring(3).split(',');
          final lineNum = int.parse(parts[0]);
          final hitCount = int.parse(parts[1]);
          
          fileData.putIfAbsent(currentFile, () => FileData(currentFile!));
          fileData[currentFile]!.addLine(lineNum, hitCount);
        }
      } else if (line == 'end_of_record') {
        currentFile = null;
      }
    }

    // Group files by module
    for (final entry in fileData.entries) {
      final module = _extractModule(entry.key);
      modules.putIfAbsent(module, () => ModuleCoverage(module));
      modules[module]!.addFile(entry.value);
    }

    return modules;
  }

  String _extractModule(String filePath) {
    // Extract module from file path
    // e.g., "lib/src/analytics/event_tracker.dart" -> "analytics"
    
    final relativePath = filePath.replaceFirst(RegExp(r'^.*lib/src/'), '');
    final parts = relativePath.split('/');
    
    if (parts.isEmpty) return 'other';
    
    // Map to config modules if available
    final moduleConfig = config['modules'] as Map<String, dynamic>?;
    if (moduleConfig != null && moduleConfig.containsKey(parts[0])) {
      return parts[0];
    }
    
    return parts[0];
  }

  void _printCoverageSummary() {
    print('\n${ConsoleColors.highlight('Coverage Summary by Module')}');
    print(ConsoleColors.tableSeparator(70));
    
    final header = _padRight('Module', 20) +
        _padRight('Files', 10) +
        _padRight('Lines', 10) +
        _padRight('Covered', 10) +
        _padRight('Coverage', 12) +
        'Status';
    
    print(header.bold);
    print(ConsoleColors.tableSeparator(70));

    // Sort modules by name
    final sortedModules = moduleCoverage.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedModules) {
      _printModuleRow(entry.key, entry.value);
    }

    print(ConsoleColors.tableSeparator(70));
    _printTotalRow();
  }

  void _printModuleRow(String name, ModuleCoverage module) {
    final coverage = module.coveragePercentage;
    final coverageStr = '${coverage.toStringAsFixed(1)}%';
    final coverageColor = _getCoverageColor(coverage);
    
    // Check module-specific threshold
    final moduleConfig = config['modules']?[name] as Map<String, dynamic>?;
    final moduleThreshold = moduleConfig?['min_coverage'] as num? ?? 
        config['coverage']?['min_threshold'] as num? ?? 
        80.0;
    
    final status = coverage >= moduleThreshold ? '✓'.green : '✗'.red;
    
    final row = _padRight(name, 20) +
        _padRight(module.fileCount.toString(), 10) +
        _padRight(module.totalLines.toString(), 10) +
        _padRight(module.coveredLines.toString(), 10) +
        _padRight(coverageStr, 12).color(coverageColor) +
        status;
    
    print(row);
  }

  void _printTotalRow() {
    final totalFiles = moduleCoverage.values.fold(0, (sum, m) => sum + m.fileCount);
    final totalLines = moduleCoverage.values.fold(0, (sum, m) => sum + m.totalLines);
    final coveredLines = moduleCoverage.values.fold(0, (sum, m) => sum + m.coveredLines);
    final coverage = totalLines > 0 ? (coveredLines / totalLines * 100) : 0.0;
    
    final row = _padRight('TOTAL', 20).bold +
        _padRight(totalFiles.toString(), 10).bold +
        _padRight(totalLines.toString(), 10).bold +
        _padRight(coveredLines.toString(), 10).bold +
        _padRight('${coverage.toStringAsFixed(1)}%', 12).bold.color(_getCoverageColor(coverage)) +
        (coverage >= (minCoverage ?? 80.0) ? '✓'.green.bold : '✗'.red.bold);
    
    print(row);
  }

  void _printDetailedCoverage() {
    _printCoverageSummary();
    
    print('\n${ConsoleColors.highlight('Uncovered Files')}');
    print(ConsoleColors.tableSeparator(80));
    
    for (final module in moduleCoverage.values) {
      for (final file in module.files) {
        if (file.coveragePercentage < 100) {
          final relativePath = file.path.replaceFirst(RegExp(r'^.*lib/'), 'lib/');
          print('${file.coveragePercentage.toStringAsFixed(1).padLeft(5)}% $relativePath'.dim);
          
          if (verbose && file.uncoveredLines.isNotEmpty) {
            final lines = file.uncoveredLines.take(10).join(', ');
            final more = file.uncoveredLines.length > 10 ? ' ...' : '';
            print('       Uncovered lines: $lines$more'.dim);
          }
        }
      }
    }
  }

  void _printLcovPath() {
    final lcovPath = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      'coverage',
      'lcov.info',
    );
    print('LCOV file: $lcovPath');
  }

  Future<String> _generateHtmlReport() async {
    final coverageDir = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      'coverage',
    );

    print('\nGenerating HTML report...');
    
    // Check if genhtml is available
    final genHtmlResult = await Process.run('which', ['genhtml']);
    if (genHtmlResult.exitCode != 0) {
      print('Warning: genhtml not found. Install lcov to generate HTML reports.'.yellow);
      return p.join(coverageDir, 'html', 'index.html');
    }

    // Generate HTML report
    final process = await Process.start(
      'genhtml',
      [
        'coverage/lcov.info',
        '-o', 'coverage/html',
        '--quiet',
      ],
      workingDirectory: p.dirname(p.dirname(Platform.script.path)),
    );

    await process.exitCode;
    
    return p.join(coverageDir, 'html', 'index.html');
  }

  Future<void> _openHtmlReport(String htmlPath) async {
    print('Opening coverage report...');
    
    String command;
    if (Platform.isMacOS) {
      command = 'open';
    } else if (Platform.isLinux) {
      command = 'xdg-open';
    } else if (Platform.isWindows) {
      command = 'start';
    } else {
      print('Cannot open browser on this platform'.yellow);
      return;
    }

    await Process.run(command, [htmlPath]);
  }

  Future<void> _trackCoverageHistory() async {
    final historyPath = p.join(
      p.dirname(p.dirname(Platform.script.path)),
      '.coverage_history.json',
    );

    final historyFile = File(historyPath);
    List<Map<String, dynamic>> history = [];
    
    if (await historyFile.exists()) {
      try {
        final content = await historyFile.readAsString();
        history = (jsonDecode(content) as List).cast<Map<String, dynamic>>();
      } catch (e) {
        // Invalid history file, start fresh
      }
    }

    // Add current coverage
    history.add({
      'timestamp': DateTime.now().toIso8601String(),
      'coverage': _calculateOverallCoverage(),
      'modules': moduleCoverage.map((name, module) => MapEntry(name, {
        'coverage': module.coveragePercentage,
        'lines': module.totalLines,
        'covered': module.coveredLines,
      })),
    });

    // Keep only last 30 entries
    if (history.length > 30) {
      history = history.sublist(history.length - 30);
    }

    await historyFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(history),
    );
  }

  Future<void> _saveReport() async {
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'overall_coverage': _calculateOverallCoverage(),
      'modules': moduleCoverage.map((name, module) => MapEntry(name, {
        'coverage': module.coveragePercentage,
        'files': module.fileCount,
        'total_lines': module.totalLines,
        'covered_lines': module.coveredLines,
        'uncovered_lines': module.uncoveredLines,
      })),
    };

    final file = File(outputPath!);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    
    print('Report saved to: $outputPath');
  }

  double _calculateOverallCoverage() {
    final totalLines = moduleCoverage.values.fold(0, (sum, m) => sum + m.totalLines);
    final coveredLines = moduleCoverage.values.fold(0, (sum, m) => sum + m.coveredLines);
    return totalLines > 0 ? (coveredLines / totalLines * 100) : 0.0;
  }

  String _getCoverageColor(double coverage) {
    if (coverage >= 90) return ConsoleColors.green;
    if (coverage >= 80) return ConsoleColors.yellow;
    return ConsoleColors.red;
  }

  String _padRight(String text, int width) {
    if (text.length >= width) {
      return text.substring(0, width - 1) + ' ';
    }
    return text.padRight(width);
  }
}

// Extension for colored strings
extension ColoredStringCoverage on String {
  String color(String colorCode) {
    return '$colorCode$this${ConsoleColors.reset}';
  }
}

class ModuleCoverage {
  final String name;
  final List<FileData> files = [];

  ModuleCoverage(this.name);

  void addFile(FileData file) {
    files.add(file);
  }

  int get fileCount => files.length;
  int get totalLines => files.fold(0, (sum, f) => sum + f.totalLines);
  int get coveredLines => files.fold(0, (sum, f) => sum + f.coveredLines);
  int get uncoveredLines => totalLines - coveredLines;
  
  double get coveragePercentage {
    return totalLines > 0 ? (coveredLines / totalLines * 100) : 0.0;
  }
}

class FileData {
  final String path;
  final Map<int, int> lineHits = {};

  FileData(this.path);

  void addLine(int lineNum, int hitCount) {
    lineHits[lineNum] = hitCount;
  }

  int get totalLines => lineHits.length;
  int get coveredLines => lineHits.values.where((hits) => hits > 0).length;
  
  List<int> get uncoveredLines {
    return lineHits.entries
        .where((e) => e.value == 0)
        .map((e) => e.key)
        .toList()
      ..sort();
  }
  
  double get coveragePercentage {
    return totalLines > 0 ? (coveredLines / totalLines * 100) : 0.0;
  }
}