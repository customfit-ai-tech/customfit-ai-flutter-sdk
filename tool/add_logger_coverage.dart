#!/usr/bin/env dart

import 'dart:io';

/// Script to add TestConfig.setupTestLogger() to all test files for better logger coverage
void main() async {
  print('Adding TestConfig.setupTestLogger() to test files...\n');

  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    print('Error: test directory not found');
    exit(1);
  }

  int filesUpdated = 0;
  int filesSkipped = 0;

  await for (final file in testDir.list(recursive: true).where(
      (entity) => entity is File && entity.path.endsWith('_test.dart'))) {
    final testFile = file as File;
    final relativePath = testFile.path.replaceFirst('test/', '');

    try {
      final content = await testFile.readAsString();

      // Skip if already has TestConfig.setupTestLogger
      if (content.contains('TestConfig.setupTestLogger')) {
        print('✓ Already updated: $relativePath');
        filesSkipped++;
        continue;
      }

      // Skip if it doesn't have setUp method
      if (!content.contains('setUp(')) {
        print('○ No setUp method: $relativePath');
        filesSkipped++;
        continue;
      }

      // Calculate the relative import path
      final depth = relativePath.split('/').length - 1;
      final importPath = '../' * depth + 'test_config.dart';

      var updatedContent = content;

      // Add import if not present
      if (!content.contains('test_config.dart')) {
        // Find the last import statement
        final importRegex = RegExp(r'import\s+.+;');
        final matches = importRegex.allMatches(content).toList();

        if (matches.isNotEmpty) {
          final lastImport = matches.last;
          final insertPosition = lastImport.end;

          updatedContent = content.substring(0, insertPosition) +
              '\nimport \'$importPath\';' +
              content.substring(insertPosition);
        }
      }

      // Add TestConfig.setupTestLogger() to setUp methods
      final setUpRegex = RegExp(r'setUp\s*\(\s*\)\s*\{');
      final setUpMatches = setUpRegex.allMatches(updatedContent).toList();

      // Process from last to first to maintain string positions
      for (var i = setUpMatches.length - 1; i >= 0; i--) {
        final match = setUpMatches[i];
        final insertPosition = match.end;

        // Check if the next non-whitespace content is already TestConfig.setupTestLogger
        final afterSetUp = updatedContent.substring(insertPosition).trim();
        if (!afterSetUp.startsWith('TestConfig.setupTestLogger')) {
          updatedContent = updatedContent.substring(0, insertPosition) +
              '\n      TestConfig.setupTestLogger(); // Enable logger for coverage\n' +
              updatedContent.substring(insertPosition);
        }
      }

      // Also handle async setUp
      final asyncSetUpRegex = RegExp(r'setUp\s*\(\s*\)\s*async\s*\{');
      final asyncSetUpMatches =
          asyncSetUpRegex.allMatches(updatedContent).toList();

      for (var i = asyncSetUpMatches.length - 1; i >= 0; i--) {
        final match = asyncSetUpMatches[i];
        final insertPosition = match.end;

        final afterSetUp = updatedContent.substring(insertPosition).trim();
        if (!afterSetUp.startsWith('TestConfig.setupTestLogger')) {
          updatedContent = updatedContent.substring(0, insertPosition) +
              '\n      TestConfig.setupTestLogger(); // Enable logger for coverage\n' +
              updatedContent.substring(insertPosition);
        }
      }

      // Write back if changed
      if (updatedContent != content) {
        await testFile.writeAsString(updatedContent);
        print('✅ Updated: $relativePath');
        filesUpdated++;
      } else {
        print('○ No changes needed: $relativePath');
        filesSkipped++;
      }
    } catch (e) {
      print('❌ Error processing $relativePath: $e');
    }
  }

  print('\n📊 Summary:');
  print('  Files updated: $filesUpdated');
  print('  Files skipped: $filesSkipped');
  print('  Total files processed: ${filesUpdated + filesSkipped}');

  if (filesUpdated > 0) {
    print('\n⚠️  Note: You may need to run build_runner after these changes:');
    print('  flutter pub run build_runner build --delete-conflicting-outputs');
  }
}
