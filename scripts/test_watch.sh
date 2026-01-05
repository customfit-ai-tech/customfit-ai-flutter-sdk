#!/bin/bash

# Test Watch Script for CustomFit Flutter SDK
# This script watches for file changes and runs tests automatically

# Note: We don't use 'set -e' here because we want to continue watching even when tests fail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
WATCH_PATH="lib test"
TEST_PATH="test/"
COVERAGE=false
UTIL_ONLY=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -c, --coverage   Run tests with coverage"
    echo "  -u, --util       Watch only core/util tests"
    echo "  -p, --path PATH  Specify custom test path (default: test/)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Watch all tests"
    echo "  $0 -c                 # Watch all tests with coverage"
    echo "  $0 -u                 # Watch only core/util tests"
    echo "  $0 -u -c              # Watch core/util tests with coverage"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -u|--util)
            UTIL_ONLY=true
            TEST_PATH="test/unit/core/util/"
            shift
            ;;
        -p|--path)
            TEST_PATH="$2"
            shift
            shift
            ;;
        *)
            echo "Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to run tests
run_tests() {
    echo -e "${BLUE}🧪 Running tests...${NC}"
    
    local exit_code=0
    
    if [ "$COVERAGE" = true ]; then
        echo -e "${YELLOW}📊 Running with coverage...${NC}"
        if [ "$UTIL_ONLY" = true ]; then
            flutter test --coverage --reporter=expanded "$TEST_PATH" || exit_code=$?
        else
            flutter test --coverage --reporter=expanded || exit_code=$?
        fi
        
        # Generate coverage report if coverage was run (even if tests failed)
        if [ -f "coverage/lcov.info" ]; then
            echo -e "${BLUE}📈 Generating coverage report...${NC}"
            genhtml coverage/lcov.info -o coverage/html 2>/dev/null || echo -e "${YELLOW}⚠️  genhtml not available, skipping HTML report${NC}"
        fi
    else
        if [ "$UTIL_ONLY" = true ]; then
            flutter test --reporter=expanded "$TEST_PATH" || exit_code=$?
        else
            flutter test --reporter=expanded || exit_code=$?
        fi
    fi
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Tests passed!${NC}"
    else
        echo -e "${RED}❌ Tests failed! (Exit code: $exit_code)${NC}"
        echo -e "${YELLOW}🔄 Continuing to watch for changes...${NC}"
    fi
    
    echo -e "${BLUE}⏰ $(date '+%Y-%m-%d %H:%M:%S') - Watching for changes...${NC}"
    echo ""
}

# Function to watch for file changes
watch_files() {
    echo -e "${BLUE}👀 Starting test watcher...${NC}"
    echo -e "${YELLOW}📁 Watching: $WATCH_PATH${NC}"
    echo -e "${YELLOW}🧪 Test path: $TEST_PATH${NC}"
    echo -e "${YELLOW}📊 Coverage: $COVERAGE${NC}"
    echo -e "${YELLOW}🔧 Util only: $UTIL_ONLY${NC}"
    echo ""
    
    # Run tests initially (continue even if they fail)
    run_tests || true
    
    # Check if fswatch is available
    if command -v fswatch >/dev/null 2>&1; then
        echo -e "${BLUE}Using fswatch for file monitoring${NC}"
        fswatch -o $WATCH_PATH | while read f; do
            echo -e "${YELLOW}🔄 File change detected, running tests...${NC}"
            run_tests || true
        done
    # Check if inotifywait is available (Linux)
    elif command -v inotifywait >/dev/null 2>&1; then
        echo -e "${BLUE}Using inotifywait for file monitoring${NC}"
        while inotifywait -r -e modify,create,delete $WATCH_PATH >/dev/null 2>&1; do
            echo -e "${YELLOW}🔄 File change detected, running tests...${NC}"
            run_tests || true
        done
    else
        echo -e "${RED}❌ No file watching tool found!${NC}"
        echo -e "${YELLOW}Please install fswatch (macOS) or inotify-tools (Linux):${NC}"
        echo "  macOS: brew install fswatch"
        echo "  Linux: sudo apt-get install inotify-tools"
        echo ""
        echo -e "${BLUE}Running tests once and exiting...${NC}"
        run_tests || true
        exit 1
    fi
}

# Main execution
echo -e "${GREEN}🚀 CustomFit Flutter SDK Test Watcher${NC}"
echo -e "${BLUE}======================================${NC}"

# Check if we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: Not in a Flutter project directory${NC}"
    exit 1
fi

# Start watching
watch_files 