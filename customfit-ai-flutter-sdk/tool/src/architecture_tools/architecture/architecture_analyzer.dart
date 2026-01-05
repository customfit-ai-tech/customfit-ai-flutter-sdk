import 'dart:io';
import 'package:path/path.dart' as path;

/// Represents a singleton instance found in the codebase
class SingletonInstance {
  final String filePath;
  final int lineNumber;
  final String className;
  final SingletonPattern pattern;
  final String codeSnippet;

  SingletonInstance({
    required this.filePath,
    required this.lineNumber,
    required this.className,
    required this.pattern,
    required this.codeSnippet,
  });

  String get relativePath => path.relative(filePath);
}

/// Types of singleton patterns
enum SingletonPattern {
  staticInstance('Static _instance field'),
  getInstance('getInstance() method'),
  getterInstance('get instance => pattern'),
  factoryConstructor('Factory constructor'),
  serviceLocator('ServiceLocator.get<T>()'),
  sharedPreferences('SharedPreferences.getInstance()'),
  staticField('Static field access'),
  other('Other pattern');

  final String description;
  const SingletonPattern(this.description);
}

/// Analysis report for architecture issues
class ArchitectureReport {
  final List<SingletonInstance> singletons;
  final Map<String, List<SingletonInstance>> singletonsByClass;
  final Map<SingletonPattern, int> patternCounts;
  final List<String> suggestions;
  final DateTime generatedAt;

  ArchitectureReport({
    required this.singletons,
    required this.singletonsByClass,
    required this.patternCounts,
    required this.suggestions,
  }) : generatedAt = DateTime.now();

  int get totalSingletons => singletons.length;

  void printSummary() {
    print('\n═══════════════════════════════════════════════════════════');
    print('              Architecture Analysis Report                  ');
    print('═══════════════════════════════════════════════════════════');
    print('Generated: $generatedAt\n');

    print('📊 Summary:');
    print('  Total singleton instances found: $totalSingletons');
    print('  Unique classes with singletons: ${singletonsByClass.length}');
    print('');

    print('📈 Pattern Distribution:');
    for (final entry in patternCounts.entries) {
      final pattern = entry.key;
      final count = entry.value;
      final percentage = ((count / totalSingletons) * 100).toStringAsFixed(1);
      print('  ${pattern.description}: $count ($percentage%)');
    }
    print('');

    print('🔝 Top Offenders (Classes with most instances):');
    final sortedClasses = singletonsByClass.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final entry in sortedClasses.take(10)) {
      print('  ${entry.key}: ${entry.value.length} instances');
    }
    print('');

    print('💡 Suggestions:');
    for (final suggestion in suggestions) {
      print('  • $suggestion');
    }
    print('');
  }

  void saveToFile(String outputPath) {
    final file = File(outputPath);
    final buffer = StringBuffer();

    buffer.writeln('# Architecture Analysis Report');
    buffer.writeln('Generated: $generatedAt\n');

    buffer.writeln('## Summary');
    buffer.writeln('- Total singleton instances: $totalSingletons');
    buffer.writeln('- Unique classes: ${singletonsByClass.length}');
    buffer.writeln('');

    buffer.writeln('## Pattern Distribution');
    for (final entry in patternCounts.entries) {
      buffer.writeln('- ${entry.key.description}: ${entry.value}');
    }
    buffer.writeln('');

    buffer.writeln('## Detailed Findings');
    for (final entry in singletonsByClass.entries) {
      final className = entry.key;
      final instances = entry.value;
      buffer.writeln('\n### $className (${instances.length} instances)');
      for (final instance in instances) {
        buffer.writeln(
            '- **${instance.relativePath}:${instance.lineNumber}** - ${instance.pattern.description}');
        buffer.writeln('  ```dart');
        buffer.writeln('  ${instance.codeSnippet.trim()}');
        buffer.writeln('  ```');
      }
    }

    buffer.writeln('\n## Recommendations');
    for (final suggestion in suggestions) {
      buffer.writeln('- $suggestion');
    }

    file.writeAsStringSync(buffer.toString());
  }
}

/// Main analyzer class for architecture patterns
class ArchitectureAnalyzer {
  final String projectRoot;
  final List<String> excludePaths;

  // Patterns to detect
  final _staticInstancePattern = RegExp(r'static\s+\w+\??\s+_instance\s*[;=]');
  final _getInstancePattern = RegExp(r'static\s+\w+\??\s+getInstance\s*\(');
  final _getterInstancePattern = RegExp(r'static\s+\w+\s+get\s+instance\s*=>');
  final _factoryPattern =
      RegExp(r'factory\s+\w+.*\{[\s\S]*?return\s+_?\w*[Ii]nstance');
  final _serviceLocatorPattern = RegExp(r'ServiceLocator\.get<(\w+)>');
  final _sharedPrefsPattern = RegExp(r'SharedPreferences\.getInstance\(\)');
  final _staticFieldPattern =
      RegExp(r'static\s+final\s+\w+\s+\w+\s*=\s*\w+\._');

  ArchitectureAnalyzer({
    required this.projectRoot,
    this.excludePaths = const [
      'test/',
      'build/',
      '.dart_tool/',
      'example/',
      'benchmark/',
    ],
  });

  /// Analyze the project for architectural issues
  Future<ArchitectureReport> analyze() async {
    print('🔍 Scanning project for singleton patterns...\n');

    final singletons = <SingletonInstance>[];
    final dartFiles = await _findDartFiles();

    print('Found ${dartFiles.length} Dart files to analyze\n');

    var processed = 0;
    for (final file in dartFiles) {
      final instances = await _analyzeFile(file);
      singletons.addAll(instances);

      processed++;
      if (processed % 10 == 0) {
        stdout.write('\rProcessed $processed/${dartFiles.length} files...');
      }
    }

    print('\rProcessed $processed/${dartFiles.length} files... Done!\n');

    // Group by class name
    final singletonsByClass = <String, List<SingletonInstance>>{};
    for (final singleton in singletons) {
      singletonsByClass
          .putIfAbsent(singleton.className, () => [])
          .add(singleton);
    }

    // Count patterns
    final patternCounts = <SingletonPattern, int>{};
    for (final singleton in singletons) {
      patternCounts[singleton.pattern] =
          (patternCounts[singleton.pattern] ?? 0) + 1;
    }

    // Generate suggestions
    final suggestions =
        _generateSuggestions(singletons, singletonsByClass, patternCounts);

    return ArchitectureReport(
      singletons: singletons,
      singletonsByClass: singletonsByClass,
      patternCounts: patternCounts,
      suggestions: suggestions,
    );
  }

  /// Find all Dart files in the project
  Future<List<File>> _findDartFiles() async {
    final files = <File>[];
    final dir = Directory(projectRoot);

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Check if path should be excluded
        bool shouldExclude = false;
        for (final excludePath in excludePaths) {
          if (entity.path.contains(excludePath)) {
            shouldExclude = true;
            break;
          }
        }

        if (!shouldExclude) {
          files.add(entity);
        }
      }
    }

    return files;
  }

  /// Analyze a single file for singleton patterns
  Future<List<SingletonInstance>> _analyzeFile(File file) async {
    final instances = <SingletonInstance>[];
    final lines = await file.readAsLines();
    final content = await file.readAsString();

    // Extract class name from file
    String? currentClass;
    final classPattern = RegExp(r'class\s+(\w+)');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;

      // Update current class context
      final classMatch = classPattern.firstMatch(line);
      if (classMatch != null) {
        currentClass = classMatch.group(1);
      }

      // Check for static instance pattern
      if (_staticInstancePattern.hasMatch(line)) {
        instances.add(SingletonInstance(
          filePath: file.path,
          lineNumber: lineNumber,
          className: currentClass ?? _extractClassFromLine(line),
          pattern: SingletonPattern.staticInstance,
          codeSnippet: line,
        ));
      }

      // Check for getInstance pattern
      if (_getInstancePattern.hasMatch(line)) {
        instances.add(SingletonInstance(
          filePath: file.path,
          lineNumber: lineNumber,
          className: currentClass ?? _extractClassFromLine(line),
          pattern: SingletonPattern.getInstance,
          codeSnippet: line,
        ));
      }

      // Check for getter instance pattern
      if (_getterInstancePattern.hasMatch(line)) {
        instances.add(SingletonInstance(
          filePath: file.path,
          lineNumber: lineNumber,
          className: currentClass ?? _extractClassFromLine(line),
          pattern: SingletonPattern.getterInstance,
          codeSnippet: line,
        ));
      }

      // Check for ServiceLocator pattern
      final serviceLocatorMatches = _serviceLocatorPattern.allMatches(line);
      for (final match in serviceLocatorMatches) {
        instances.add(SingletonInstance(
          filePath: file.path,
          lineNumber: lineNumber,
          className: match.group(1) ?? 'Unknown',
          pattern: SingletonPattern.serviceLocator,
          codeSnippet: line,
        ));
      }

      // Check for SharedPreferences pattern
      if (_sharedPrefsPattern.hasMatch(line)) {
        instances.add(SingletonInstance(
          filePath: file.path,
          lineNumber: lineNumber,
          className: 'SharedPreferences',
          pattern: SingletonPattern.sharedPreferences,
          codeSnippet: line,
        ));
      }

      // Check for static field pattern
      if (_staticFieldPattern.hasMatch(line)) {
        instances.add(SingletonInstance(
          filePath: file.path,
          lineNumber: lineNumber,
          className: currentClass ?? 'Unknown',
          pattern: SingletonPattern.staticField,
          codeSnippet: line,
        ));
      }
    }

    // Check for factory patterns (multi-line)
    final factoryMatches = _factoryPattern.allMatches(content);
    for (final match in factoryMatches) {
      final matchStart = content.substring(0, match.start).split('\n').length;
      instances.add(SingletonInstance(
        filePath: file.path,
        lineNumber: matchStart,
        className: currentClass ?? 'Unknown',
        pattern: SingletonPattern.factoryConstructor,
        codeSnippet: match.group(0) ?? '',
      ));
    }

    return instances;
  }

  /// Extract class name from a line of code
  String _extractClassFromLine(String line) {
    // Try to extract class name from the line
    final patterns = [
      RegExp(r'(\w+)\._'),
      RegExp(r'static\s+(\w+)'),
      RegExp(r'<(\w+)>'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        return match.group(1) ?? 'Unknown';
      }
    }

    return 'Unknown';
  }

  /// Generate suggestions based on findings
  List<String> _generateSuggestions(
    List<SingletonInstance> singletons,
    Map<String, List<SingletonInstance>> singletonsByClass,
    Map<SingletonPattern, int> patternCounts,
  ) {
    final suggestions = <String>[];

    // High-level suggestions
    if (singletons.length > 50) {
      suggestions.add(
          'Consider implementing a centralized dependency injection container to manage all instances');
    }

    // SharedPreferences specific
    final sharedPrefsCount =
        patternCounts[SingletonPattern.sharedPreferences] ?? 0;
    if (sharedPrefsCount > 10) {
      suggestions.add(
          'SharedPreferences.getInstance() called $sharedPrefsCount times. Create a single wrapper service');
    }

    // ServiceLocator pattern
    final serviceLocatorCount =
        patternCounts[SingletonPattern.serviceLocator] ?? 0;
    if (serviceLocatorCount > 20) {
      suggestions.add(
          'Heavy use of ServiceLocator ($serviceLocatorCount calls). Consider constructor injection for better testability');
    }

    // Multiple patterns in same class
    for (final entry in singletonsByClass.entries) {
      final className = entry.key;
      final instances = entry.value;
      if (instances.length > 5) {
        suggestions.add(
            '$className has ${instances.length} singleton references. Consider refactoring to reduce coupling');
      }
    }

    // Pattern-specific suggestions
    if ((patternCounts[SingletonPattern.staticInstance] ?? 0) > 20) {
      suggestions.add(
          'Many static _instance fields found. Standardize on a single singleton pattern across the codebase');
    }

    // General suggestions
    suggestions.add(
        'Create a SingletonRegistry to track and manage all singleton instances');
    suggestions.add(
        'Consider using provider or riverpod for dependency injection instead of manual singletons');
    suggestions.add(
        'Add @singleton annotations to clearly mark intentional singletons');

    return suggestions;
  }
}

/// Main entry point for running the analyzer
Future<void> main(List<String> args) async {
  final projectRoot = args.isNotEmpty ? args[0] : Directory.current.path;

  final analyzer = ArchitectureAnalyzer(projectRoot: projectRoot);
  final report = await analyzer.analyze();

  report.printSummary();

  // Save detailed report
  final outputPath = path.join(projectRoot, 'architecture_analysis_report.md');
  report.saveToFile(outputPath);

  print('📄 Detailed report saved to: $outputPath');
}
