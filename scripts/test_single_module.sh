#!/bin/bash

# Flutter SDK Single Module Test Runner
# Usage: ./test_single_module.sh <module_name>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Navigate to Flutter SDK directory
cd "$(dirname "$0")/.."

if [ $# -eq 0 ]; then
    echo -e "${RED}Usage: $0 <module_name>${NC}"
    echo -e "${YELLOW}Available modules:${NC}"
    echo "  Unit test modules:"
    ls -1 test/unit/ 2>/dev/null | sed 's/^/    /'
    echo "  Other test directories:"
    ls -1 test/ | grep -v unit | grep -v "\.dart$" | sed 's/^/    /'
    exit 1
fi

MODULE_NAME="$1"

# Check if it's a unit test module
if [ -d "test/unit/$MODULE_NAME" ]; then
    MODULE_PATH="test/unit/$MODULE_NAME"
elif [ -d "test/$MODULE_NAME" ]; then
    MODULE_PATH="test/$MODULE_NAME"
else
    echo -e "${RED}❌ Module '$MODULE_NAME' not found${NC}"
    echo -e "${YELLOW}Available modules:${NC}"
    echo "  Unit test modules:"
    ls -1 test/unit/ 2>/dev/null | sed 's/^/    /'
    echo "  Other test directories:"
    ls -1 test/ | grep -v unit | grep -v "\.dart$" | sed 's/^/    /'
    exit 1
fi

# Count test files
TEST_COUNT=$(find "$MODULE_PATH" -name "*_test.dart" | wc -l)

echo -e "${BLUE}🧪 Testing module: $MODULE_NAME${NC}"
echo "Module path: $MODULE_PATH"
echo "Test files: $TEST_COUNT"
echo "========================================"

if [ "$TEST_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No test files found in $MODULE_NAME${NC}"
    exit 0
fi

# List test files
echo -e "${BLUE}Test files in this module:${NC}"
find "$MODULE_PATH" -name "*_test.dart" | sort | sed 's/^/  /'
echo ""

# Run tests with detailed output
echo -e "${BLUE}Running tests...${NC}"
if flutter test "$MODULE_PATH" --reporter=expanded; then
    echo -e "\n${GREEN}✅ Module $MODULE_NAME: ALL TESTS PASSED${NC}"
else
    echo -e "\n${RED}❌ Module $MODULE_NAME: SOME TESTS FAILED${NC}"
    echo -e "${YELLOW}To debug specific test files, run:${NC}"
    find "$MODULE_PATH" -name "*_test.dart" | sort | while read -r test_file; do
        echo "  flutter test $test_file --reporter=expanded"
    done
    exit 1
fi 