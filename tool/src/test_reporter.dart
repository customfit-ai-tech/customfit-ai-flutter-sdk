import 'dart:io';
import 'dart:convert';
import 'console_colors.dart';
import 'test_parser.dart';

/// Test reporter for formatting and displaying test results
class TestReporter {
  final bool useColors;
  final bool verbose;
  final bool showStackTraces;
  final bool showModuleSummary;
  final bool showTestTiming;
  
  TestReporter({
    this.useColors = true,
    this.verbose = false,
    this.showStackTraces = true,
    this.showModuleSummary = true,
    this.showTestTiming = true,
  });
  
  /// Print module-level summary table
  void printModuleSummary(TestRunSummary summary) {
    if (!showModuleSummary) return;
    
    print('\n${_header('Module Test Summary')}');
    print(_tableSeparator(80));
    
    // Table header
    final header = '${_padRight('Module', 20)}${_padRight('Total', 10)}${_padRight('Passed', 10)}${_padRight('Failed', 10)}${_padRight('Skipped', 10)}${_padRight('Pass Rate', 12)}Time';
    
    print(header.bold);
    print(_tableSeparator(80));
    
    // Sort modules by name
    final sortedModules = summary.modules.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    // Print each module
    for (final entry in sortedModules) {
      final module = entry.value;
      _printModuleRow(entry.key, module);
    }
    
    print(_tableSeparator(80));
    
    // Print totals
    _printTotalRow(summary);
  }
  
  void _printModuleRow(String name, ModuleResult module) {
    final passRate = '${module.passRate.toStringAsFixed(1)}%';
    final passRateColor = _getPassRateColor(module.passRate);
    final time = _formatDuration(module.totalDuration);
    
    final row = _padRight(name, 20) +
        _padRight(module.total.toString(), 10) +
        _padRight(module.passed.toString(), 10).green +
        _padRight(module.failed.toString(), 10).red +
        _padRight(module.skipped.toString(), 10).yellow +
        _padRight(passRate, 12).color(passRateColor) +
        time;
    
    print(row);
  }
  
  void _printTotalRow(TestRunSummary summary) {
    final passRate = '${summary.overallPassRate.toStringAsFixed(1)}%';
    final passRateColor = _getPassRateColor(summary.overallPassRate);
    final time = _formatDuration(summary.totalDuration);
    
    final row = _padRight('TOTAL', 20).bold +
        _padRight(summary.totalTests.toString(), 10).bold +
        _padRight(summary.totalPassed.toString(), 10).green.bold +
        _padRight(summary.totalFailed.toString(), 10).red.bold +
        _padRight(summary.totalSkipped.toString(), 10).yellow.bold +
        _padRight(passRate, 12).color(passRateColor).bold +
        time.bold;
    
    print(row);
  }
  
  /// Print failed tests details
  void printFailedTests(TestRunSummary summary) {
    final failedTests = summary.failedTests;
    if (failedTests.isEmpty) return;
    
    print('\n${_header('Failed Tests')}');
    print(_tableSeparator(80));
    
    for (final test in failedTests) {
      print('\n${ConsoleColors.failed()} ${test.module}/${test.name}'.red);
      
      if (test.error != null) {
        print('  Error: ${test.error}'.dim);
      }
      
      if (showStackTraces && test.stackTrace != null) {
        print('  Stack trace:'.dim);
        final stackLines = test.stackTrace!.split('\n').take(10);
        for (final line in stackLines) {
          print('    $line'.dim);
        }
        if (test.stackTrace!.split('\n').length > 10) {
          print('    ... (truncated)'.dim);
        }
      }
    }
  }
  
  /// Print test execution summary
  void printExecutionSummary(TestRunSummary summary) {
    print('\n${_header('Execution Summary')}');
    
    final duration = summary.endTime.difference(summary.startTime);
    print('Total time: ${_formatDuration(duration.inMilliseconds)}');
    print('Test suites: ${summary.modules.length}');
    print('Total tests: ${summary.totalTests}');
    
    if (summary.totalFailed > 0) {
      print('\n${ConsoleColors.failed()} ${summary.totalFailed} tests failed'.red.bold);
    } else if (summary.totalSkipped > 0) {
      print('\n${ConsoleColors.passed()} All tests passed! (${summary.totalSkipped} skipped)'.green.bold);
    } else {
      print('\n${ConsoleColors.passed()} All ${summary.totalTests} tests passed!'.green.bold);
    }
  }
  
  /// Generate JUnit XML report
  Future<void> generateJUnitReport(TestRunSummary summary, String outputPath) async {
    final buffer = StringBuffer();
    
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<testsuites tests="${summary.totalTests}" '
        'failures="${summary.totalFailed}" '
        'skipped="${summary.totalSkipped}" '
        'time="${summary.totalDuration / 1000}">');
    
    for (final entry in summary.modules.entries) {
      final module = entry.value;
      buffer.writeln('  <testsuite name="${entry.key}" '
          'tests="${module.total}" '
          'failures="${module.failed}" '
          'skipped="${module.skipped}" '
          'time="${module.totalDuration / 1000}">');
      
      for (final test in module.tests) {
        buffer.writeln('    <testcase name="${_escapeXml(test.name)}" '
            'classname="${_escapeXml(test.module)}" '
            'time="${test.duration / 1000}">');
        
        if (test.failed) {
          buffer.writeln('      <failure message="${_escapeXml(test.error ?? 'Test failed')}">');
          if (test.stackTrace != null) {
            buffer.writeln(_escapeXml(test.stackTrace!));
          }
          buffer.writeln('      </failure>');
        } else if (test.skipped) {
          buffer.writeln('      <skipped/>');
        }
        
        buffer.writeln('    </testcase>');
      }
      
      buffer.writeln('  </testsuite>');
    }
    
    buffer.writeln('</testsuites>');
    
    final file = File(outputPath);
    await file.writeAsString(buffer.toString());
    print('\nJUnit report generated: $outputPath'.dim);
  }
  
  /// Generate JSON report
  Future<void> generateJsonReport(TestRunSummary summary, String outputPath) async {
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'duration': summary.totalDuration,
      'summary': {
        'total': summary.totalTests,
        'passed': summary.totalPassed,
        'failed': summary.totalFailed,
        'skipped': summary.totalSkipped,
        'passRate': summary.overallPassRate,
      },
      'modules': summary.modules.map((name, module) => MapEntry(name, {
        'total': module.total,
        'passed': module.passed,
        'failed': module.failed,
        'skipped': module.skipped,
        'passRate': module.passRate,
        'duration': module.totalDuration,
      })),
      'failedTests': summary.failedTests.map((test) => {
        'name': test.name,
        'module': test.module,
        'error': test.error,
        'stackTrace': test.stackTrace,
        'duration': test.duration,
      }).toList(),
    };
    
    final file = File(outputPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    print('JSON report generated: $outputPath'.dim);
  }
  
  // Helper methods
  String _header(String title) {
    if (useColors) {
      return title.cyan.bold;
    }
    return title;
  }
  
  String _tableSeparator(int width) {
    return ConsoleColors.tableSeparator(width);
  }
  
  String _padRight(String text, int width) {
    if (text.length >= width) {
      return text.substring(0, width - 1) + ' ';
    }
    return text.padRight(width);
  }
  
  String _formatDuration(int milliseconds) {
    if (milliseconds < 1000) {
      return '${milliseconds}ms';
    } else if (milliseconds < 60000) {
      return '${(milliseconds / 1000).toStringAsFixed(1)}s';
    } else {
      final minutes = milliseconds ~/ 60000;
      final seconds = (milliseconds % 60000) / 1000;
      return '${minutes}m ${seconds.toStringAsFixed(1)}s';
    }
  }
  
  String _getPassRateColor(double rate) {
    if (rate >= 90) return ConsoleColors.green;
    if (rate >= 80) return ConsoleColors.yellow;
    return ConsoleColors.red;
  }
  
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

// Extension for colored strings
extension ColoredStringReporter on String {
  String color(String colorCode) {
    return '$colorCode$this${ConsoleColors.reset}';
  }
}