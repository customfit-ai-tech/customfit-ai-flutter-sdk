import 'dart:convert';
import 'dart:io';

/// Test result data classes
class TestResult {
  final String name;
  final String suite;
  final bool passed;
  final bool skipped;
  final String? error;
  final String? stackTrace;
  final int duration; // milliseconds
  final String module;
  
  TestResult({
    required this.name,
    required this.suite,
    required this.passed,
    required this.skipped,
    this.error,
    this.stackTrace,
    required this.duration,
    required this.module,
  });
  
  bool get failed => !passed && !skipped;
}

class ModuleResult {
  final String name;
  final List<TestResult> tests;
  final int totalDuration;
  
  ModuleResult({
    required this.name,
    required this.tests,
  }) : totalDuration = tests.fold(0, (sum, test) => sum + test.duration);
  
  int get total => tests.length;
  int get passed => tests.where((t) => t.passed).length;
  int get failed => tests.where((t) => t.failed).length;
  int get skipped => tests.where((t) => t.skipped).length;
  
  double get passRate => total > 0 ? (passed / total * 100) : 0;
}

class TestRunSummary {
  final Map<String, ModuleResult> modules;
  final int totalDuration;
  final DateTime startTime;
  final DateTime endTime;
  
  TestRunSummary({
    required this.modules,
    required this.totalDuration,
    required this.startTime,
    required this.endTime,
  });
  
  int get totalTests => modules.values.fold(0, (sum, m) => sum + m.total);
  int get totalPassed => modules.values.fold(0, (sum, m) => sum + m.passed);
  int get totalFailed => modules.values.fold(0, (sum, m) => sum + m.failed);
  int get totalSkipped => modules.values.fold(0, (sum, m) => sum + m.skipped);
  
  double get overallPassRate => totalTests > 0 ? (totalPassed / totalTests * 100) : 0;
  
  List<TestResult> get failedTests {
    return modules.values
        .expand((m) => m.tests)
        .where((t) => t.failed)
        .toList();
  }
}

/// Parser for Flutter test JSON output
class TestParser {
  static const String _testStartEvent = 'testStart';
  static const String _testDoneEvent = 'testDone';
  static const String _errorEvent = 'error';
  static const String _printEvent = 'print';
  static const String _doneEvent = 'done';
  static const String _groupEvent = 'group';
  
  final Map<int, TestInfo> _activeTests = {};
  final Map<String, List<TestResult>> _moduleTests = {};
  final List<String> _testOutput = [];
  DateTime? _startTime;
  DateTime? _endTime;
  
  /// Parse Flutter test JSON output stream
  Future<TestRunSummary> parseJsonOutput(Stream<String> output) async {
    _startTime = DateTime.now();
    
    await for (final line in output) {
      if (line.trim().isEmpty) continue;
      
      try {
        final event = jsonDecode(line) as Map<String, dynamic>;
        await _handleEvent(event);
      } catch (e) {
        // Not JSON, might be regular output
        _testOutput.add(line);
      }
    }
    
    _endTime = DateTime.now();
    
    return _createSummary();
  }
  
  Future<void> _handleEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    if (type == null) return;
    
    switch (type) {
      case _testStartEvent:
        _handleTestStart(event);
        break;
      case _testDoneEvent:
        _handleTestDone(event);
        break;
      case _errorEvent:
        _handleError(event);
        break;
      case _printEvent:
        _handlePrint(event);
        break;
      case _groupEvent:
        _handleGroup(event);
        break;
      case _doneEvent:
        _handleDone(event);
        break;
    }
  }
  
  void _handleTestStart(Map<String, dynamic> event) {
    final test = event['test'] as Map<String, dynamic>;
    final id = test['id'] as int;
    final name = test['name'] as String;
    final suitePath = test['root_url'] as String?;
    final groupIds = test['group_ids'] as List<dynamic>?;
    
    _activeTests[id] = TestInfo(
      id: id,
      name: name,
      suitePath: suitePath ?? '',
      groupIds: groupIds?.cast<int>() ?? [],
      startTime: DateTime.now(),
    );
  }
  
  void _handleTestDone(Map<String, dynamic> event) {
    final testId = event['testID'] as int;
    final hidden = event['hidden'] as bool? ?? false;
    final skipped = event['skipped'] as bool? ?? false;
    final result = event['result'] as String;
    
    final testInfo = _activeTests[testId];
    if (testInfo == null || hidden) return;
    
    final duration = DateTime.now().difference(testInfo.startTime).inMilliseconds;
    final module = _extractModule(testInfo.suitePath);
    
    final testResult = TestResult(
      name: testInfo.name,
      suite: testInfo.suitePath,
      passed: result == 'success',
      skipped: skipped,
      error: testInfo.error,
      stackTrace: testInfo.stackTrace,
      duration: duration,
      module: module,
    );
    
    _moduleTests.putIfAbsent(module, () => []).add(testResult);
    _activeTests.remove(testId);
  }
  
  void _handleError(Map<String, dynamic> event) {
    final testId = event['testID'] as int?;
    final error = event['error'] as String;
    final stackTrace = event['stackTrace'] as String?;
    
    if (testId != null && _activeTests.containsKey(testId)) {
      _activeTests[testId]!
        ..error = error
        ..stackTrace = stackTrace;
    }
  }
  
  void _handlePrint(Map<String, dynamic> event) {
    final message = event['message'] as String;
    _testOutput.add(message);
  }
  
  void _handleGroup(Map<String, dynamic> event) {
    // Groups help organize tests but we handle them via the test path
  }
  
  void _handleDone(Map<String, dynamic> event) {
    final success = event['success'] as bool?;
    // Final event, parsing complete
  }
  
  String _extractModule(String path) {
    // Extract module from test path with improved pattern matching
    // Handle various test path structures
    final parts = path.split('/');
    
    // Standard test/unit/module structure
    if (parts.length >= 3 && parts[0] == 'test' && parts[1] == 'unit') {
      return parts[2];
    } 
    // Standard test/stress/module structure
    else if (parts.length >= 3 && parts[0] == 'test' && parts[1] == 'stress') {
      return 'stress/${parts[2]}';
    }
    // Direct test/module structure (e.g., test/analytics/...)
    else if (parts.length >= 2 && parts[0] == 'test') {
      // Skip common test subdirectories that aren't modules
      final nonModuleDirs = ['fixtures', 'helpers', 'utils', 'mocks', 'data'];
      if (!nonModuleDirs.contains(parts[1])) {
        return parts[1];
      }
    }
    // Handle integration tests
    else if (parts.contains('integration_test')) {
      final integrationIndex = parts.indexOf('integration_test');
      if (integrationIndex >= 0 && parts.length > integrationIndex + 1) {
        return 'integration/${parts[integrationIndex + 1]}';
      }
    }
    // Handle e2e tests
    else if (parts.contains('e2e')) {
      final e2eIndex = parts.indexOf('e2e');
      if (e2eIndex >= 0 && parts.length > e2eIndex + 1) {
        return 'e2e/${parts[e2eIndex + 1]}';
      }
    }
    // Extract module name from test file name if in root test directory
    else if (parts.length >= 2 && parts[0] == 'test') {
      final fileName = parts.last;
      // Try to extract module from file name pattern
      // e.g., event_tracker_test.dart -> event_tracker
      final filePattern = RegExp(r'^(\w+)_test\.dart$');
      final match = filePattern.firstMatch(fileName);
      if (match != null) {
        final moduleName = match.group(1)!;
        // Group by feature if we can identify it
        if (moduleName.contains('analytics') || moduleName.contains('event')) {
          return 'analytics';
        } else if (moduleName.contains('session')) {
          return 'session';
        } else if (moduleName.contains('network') || moduleName.contains('http')) {
          return 'network';
        } else if (moduleName.contains('config')) {
          return 'config';
        } else if (moduleName.contains('user')) {
          return 'user';
        }
      }
    }
    
    // If we can't determine module, use the first meaningful directory
    for (int i = 0; i < parts.length - 1; i++) {
      if (parts[i] == 'test' && i + 1 < parts.length) {
        return parts[i + 1];
      }
    }
    
    return 'other';
  }
  
  TestRunSummary _createSummary() {
    final modules = <String, ModuleResult>{};
    
    for (final entry in _moduleTests.entries) {
      modules[entry.key] = ModuleResult(
        name: entry.key,
        tests: entry.value,
      );
    }
    
    final totalDuration = _endTime?.difference(_startTime!).inMilliseconds ?? 0;
    
    return TestRunSummary(
      modules: modules,
      totalDuration: totalDuration,
      startTime: _startTime!,
      endTime: _endTime ?? DateTime.now(),
    );
  }
  
  /// Parse simple flutter test output (non-JSON)
  static TestRunSummary parseSimpleOutput(String output) {
    // Enhanced parsing for when JSON reporter is not available
    final lines = output.split('\n');
    final modules = <String, ModuleResult>{};
    final startTime = DateTime.now();
    
    // Enhanced regex patterns
    final passPattern = RegExp(r'✓\s+(.+?)(?:\s+\((\d+)ms\))?$');
    final failPattern = RegExp(r'✗\s+(.+?)(?:\s+\((\d+)ms\))?$');
    final skipPattern = RegExp(r'○\s+(.+?)(?:\s+\(skipped\))?$');
    final suitePattern = RegExp(r'^(?:\s+)?(.+?)(?::|$)');
    final errorPattern = RegExp(r'^\s+(.+)$');
    final filePattern = RegExp(r'^\s*(?:package:)?(?:.+?/)?test/(.+?):\d+:\d+');
    final summaryPattern = RegExp(r'(\d+) tests? passed(?:, (\d+) failed)?(?:, (\d+) skipped)?');
    final durationPattern = RegExp(r'(?:Tests? )?(?:ran in |took )(\d+(?:\.\d+)?)\s*(?:seconds?|s)');
    
    String? currentSuite;
    String? currentModule = 'unknown';
    final testsByModule = <String, List<TestResult>>{};
    TestResult? lastFailedTest;
    final errorLines = <String>[];
    int totalDuration = 0;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Skip empty lines
      if (line.trim().isEmpty) {
        if (lastFailedTest != null && errorLines.isNotEmpty) {
          // Save accumulated error for failed test
          final error = errorLines.join('\n').trim();
          testsByModule[currentModule]!.remove(lastFailedTest);
          testsByModule[currentModule]!.add(TestResult(
            name: lastFailedTest.name,
            suite: lastFailedTest.suite,
            passed: false,
            skipped: false,
            error: error,
            stackTrace: _extractStackTrace(errorLines),
            duration: lastFailedTest.duration,
            module: lastFailedTest.module,
          ));
          lastFailedTest = null;
          errorLines.clear();
        }
        continue;
      }
      
      // Detect test file/suite
      if (line.contains('test/') && !line.startsWith(' ')) {
        final fileMatch = filePattern.firstMatch(line);
        if (fileMatch != null) {
          final testPath = fileMatch.group(1)!;
          currentModule = TestParser()._extractModule('test/$testPath');
          currentSuite = testPath;
        }
      }
      
      // Detect group/describe blocks
      else if (!line.startsWith(' ') && line.endsWith(':')) {
        currentSuite = line.replaceAll(':', '').trim();
      }
      
      // Parse passed test
      else if (passPattern.hasMatch(line)) {
        final match = passPattern.firstMatch(line)!;
        final testName = match.group(1)!.trim();
        final duration = match.group(2) != null ? int.parse(match.group(2)!) : 0;
        
        final test = TestResult(
          name: testName,
          suite: currentSuite ?? 'unknown',
          passed: true,
          skipped: false,
          duration: duration,
          module: currentModule,
        );
        
        testsByModule.putIfAbsent(currentModule, () => []).add(test);
        lastFailedTest = null;
        errorLines.clear();
      }
      
      // Parse failed test
      else if (failPattern.hasMatch(line)) {
        final match = failPattern.firstMatch(line)!;
        final testName = match.group(1)!.trim();
        final duration = match.group(2) != null ? int.parse(match.group(2)!) : 0;
        
        final test = TestResult(
          name: testName,
          suite: currentSuite ?? 'unknown',
          passed: false,
          skipped: false,
          duration: duration,
          module: currentModule,
        );
        
        testsByModule.putIfAbsent(currentModule, () => []).add(test);
        lastFailedTest = test;
        errorLines.clear();
      }
      
      // Parse skipped test
      else if (skipPattern.hasMatch(line)) {
        final match = skipPattern.firstMatch(line)!;
        final testName = match.group(1)!.trim();
        
        final test = TestResult(
          name: testName,
          suite: currentSuite ?? 'unknown',
          passed: false,
          skipped: true,
          duration: 0,
          module: currentModule,
        );
        
        testsByModule.putIfAbsent(currentModule, () => []).add(test);
        lastFailedTest = null;
        errorLines.clear();
      }
      
      // Collect error details
      else if (lastFailedTest != null && line.startsWith(' ')) {
        errorLines.add(line);
      }
      
      // Parse summary
      else if (summaryPattern.hasMatch(line)) {
        // Summary line gives us overall test counts
      }
      
      // Parse duration
      else if (durationPattern.hasMatch(line)) {
        final match = durationPattern.firstMatch(line)!;
        final seconds = double.parse(match.group(1)!);
        totalDuration = (seconds * 1000).round();
      }
    }
    
    // Handle any remaining error
    if (lastFailedTest != null && errorLines.isNotEmpty) {
      final error = errorLines.join('\n').trim();
      testsByModule[currentModule]!.remove(lastFailedTest);
      testsByModule[currentModule]!.add(TestResult(
        name: lastFailedTest.name,
        suite: lastFailedTest.suite,
        passed: false,
        skipped: false,
        error: error,
        stackTrace: _extractStackTrace(errorLines),
        duration: lastFailedTest.duration,
        module: lastFailedTest.module,
      ));
    }
    
    // Create module results
    for (final entry in testsByModule.entries) {
      modules[entry.key] = ModuleResult(
        name: entry.key,
        tests: entry.value,
      );
    }
    
    // If no tests found, create a minimal summary
    if (modules.isEmpty) {
      modules['all'] = ModuleResult(name: 'all', tests: []);
    }
    
    final endTime = DateTime.now();
    
    return TestRunSummary(
      modules: modules,
      totalDuration: totalDuration > 0 ? totalDuration : endTime.difference(startTime).inMilliseconds,
      startTime: startTime,
      endTime: endTime,
    );
  }
  
  static String? _extractStackTrace(List<String> errorLines) {
    // Extract stack trace from error lines
    final stackLines = <String>[];
    bool inStackTrace = false;
    
    for (final line in errorLines) {
      if (line.contains('package:') || line.contains('.dart:') || line.contains('#')) {
        inStackTrace = true;
      }
      if (inStackTrace) {
        stackLines.add(line);
      }
    }
    
    return stackLines.isNotEmpty ? stackLines.join('\n') : null;
  }
}

/// Helper class to track test info during parsing
class TestInfo {
  final int id;
  final String name;
  final String suitePath;
  final List<int> groupIds;
  final DateTime startTime;
  String? error;
  String? stackTrace;
  
  TestInfo({
    required this.id,
    required this.name,
    required this.suitePath,
    required this.groupIds,
    required this.startTime,
  });
}