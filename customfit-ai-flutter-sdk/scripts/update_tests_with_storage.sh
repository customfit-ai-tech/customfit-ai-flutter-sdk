#!/bin/bash

# Script to update test files with TestStorageHelper

# List of test files that need updating
test_files=(
  "test/unit/analytics/event/persistent_event_queue_comprehensive_test.dart"
  "test/unit/analytics/event/persistent_event_queue_coverage_test.dart"
  "test/unit/client/cf_client_initializer_test.dart"
  "test/unit/client/cf_client_initializer_coverage_test.dart"
  "test/unit/client/cf_client_recovery_test.dart"
  "test/unit/client/cf_client_recovery_comprehensive_test.dart"
  "test/unit/client/cf_client_recovery_coverage_test.dart"
  "test/unit/client/cf_client_wrappers_test.dart"
  "test/unit/core/session/session_manager_comprehensive_test.dart"
  "test/unit/core/session/session_manager_coverage_test.dart"
  "test/unit/platform/default_background_state_monitor_comprehensive_test.dart"
)

for file in "${test_files[@]}"; do
  if [ -f "$file" ]; then
    echo "Updating $file..."
    
    # Check if already has TestStorageHelper
    if grep -q "TestStorageHelper" "$file"; then
      echo "  Already updated, skipping..."
      continue
    fi
    
    # Add import if not present
    if ! grep -q "test_storage_helper.dart" "$file"; then
      # Find the last import line and add after it
      last_import=$(grep -n "^import" "$file" | tail -1 | cut -d: -f1)
      if [ -n "$last_import" ]; then
        sed -i '' "${last_import}a\\
import '../../../helpers/test_storage_helper.dart';
" "$file"
      fi
    fi
    
    # Update setUp to include TestStorageHelper.setupTestStorage()
    # Find setUp method
    setup_line=$(grep -n "setUp(" "$file" | head -1 | cut -d: -f1)
    if [ -n "$setup_line" ]; then
      # Find the opening brace after setUp
      next_line=$((setup_line + 1))
      # Insert TestStorageHelper.setupTestStorage(); after SharedPreferences setup if present
      if grep -q "SharedPreferences.setMockInitialValues" "$file"; then
        sed -i '' "/SharedPreferences.setMockInitialValues/a\\
\\    // Setup test storage with secure storage\\
\\    TestStorageHelper.setupTestStorage();
" "$file"
      else
        # Add at the beginning of setUp
        sed -i '' "${next_line}a\\
\\    // Setup test storage with secure storage\\
\\    TestStorageHelper.setupTestStorage();
" "$file"
      fi
    fi
    
    # Update tearDown to include TestStorageHelper.clearTestStorage()
    teardown_line=$(grep -n "tearDown(" "$file" | head -1 | cut -d: -f1)
    if [ -n "$teardown_line" ]; then
      # Find the closing brace of tearDown
      # Add before the closing brace
      if grep -q "PreferencesService.reset()" "$file"; then
        sed -i '' "/PreferencesService.reset()/a\\
\\    TestStorageHelper.clearTestStorage();
" "$file"
      else
        # Find the next line after tearDown
        next_line=$((teardown_line + 1))
        sed -i '' "${next_line}a\\
\\    TestStorageHelper.clearTestStorage();
" "$file"
      fi
    fi
    
    echo "  Updated!"
  else
    echo "File not found: $file"
  fi
done

echo "Done updating test files!"