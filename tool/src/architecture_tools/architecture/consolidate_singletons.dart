import 'dart:io';
import 'package:path/path.dart' as path;
import 'architecture_analyzer.dart';
import 'singleton_consolidator.dart';

/// Main entry point for singleton consolidation
Future<void> main(List<String> args) async {
  print('🔧 Singleton Consolidation Tool\n');

  // Run architecture analysis first
  final projectRoot = args.isNotEmpty ? args[0] : Directory.current.path;
  final analyzer = ArchitectureAnalyzer(projectRoot: projectRoot);

  print('📊 Analyzing architecture...\n');
  final report = await analyzer.analyze();

  // Show summary
  report.printSummary();

  // Create consolidator
  final consolidator = SingletonConsolidator(report);

  // Generate artifacts
  final outputDir = path.join(projectRoot, 'lib/src/services');
  print('\n💾 Generating consolidation artifacts...\n');
  await consolidator.saveArtifacts(outputDir);

  print('\n✨ Consolidation artifacts generated successfully!');
  print('\n📚 Next steps:');
  print('1. Review the generated files in $outputDir');
  print('2. Read the MIGRATION_GUIDE.md for detailed instructions');
  print('3. Run the refactor_singletons.sh script to automate changes');
  print('4. Test thoroughly after refactoring');
  print(
      '5. Consider using a dependency injection package like riverpod or provider');

  // Show statistics
  print('\n📈 Potential improvements:');
  print(
      '- Reduce singleton instances from ${report.totalSingletons} to ~10-15');
  print(
      '- Improve testability by ${((report.patternCounts[SingletonPattern.serviceLocator] ?? 0) / report.totalSingletons * 100).toStringAsFixed(0)}%');
  print(
      '- Eliminate ${report.patternCounts[SingletonPattern.sharedPreferences] ?? 0} direct SharedPreferences calls');
  print(
      '- Consolidate ${report.singletonsByClass.length} classes with singleton patterns');
}
