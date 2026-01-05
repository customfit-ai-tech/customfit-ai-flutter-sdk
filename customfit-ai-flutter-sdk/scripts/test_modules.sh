#!/bin/bash

# Flutter SDK Module-wise Test Runner
# This script runs tests module by module to isolate failures

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Navigate to Flutter SDK directory
cd "$(dirname "$0")/.."

echo -e "${BLUE}Flutter SDK Module-wise Test Runner${NC}"
echo "========================================"

# Test modules in unit directory
UNIT_MODULES=(
    "analytics"
    "client" 
    "config"
    "constants"
    "core"
    "di"
    "features"
    "lifecycle"
    "logging"
    "monitoring"
    "network"
    "networking"
    "platform"
    "services"
    "storage"
    "utils"
)

# Other test directories
OTHER_TEST_DIRS=(
    "shared"
    "utils"
    "performance"
)

# Results tracking
declare -a PASSED_MODULES
declare -a FAILED_MODULES
declare -a SKIPPED_MODULES

# Function to run tests for a specific module
run_module_tests() {
    local module_path="$1"
    local module_name="$2"
    
    if [ ! -d "$module_path" ]; then
        echo -e "${YELLOW}⚠️  Module $module_name not found at $module_path - SKIPPING${NC}"
        SKIPPED_MODULES+=("$module_name")
        return
    fi
    
    # Count test files
    local test_count=$(find "$module_path" -name "*_test.dart" | wc -l)
    if [ "$test_count" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No test files found in $module_name - SKIPPING${NC}"
        SKIPPED_MODULES+=("$module_name")
        return
    fi
    
    echo -e "\n${BLUE}🧪 Testing module: $module_name ($test_count test files)${NC}"
    echo "Module path: $module_path"
    echo "----------------------------------------"
    
    # Run tests for this module
    if flutter test "$module_path" --reporter=expanded; then
        echo -e "${GREEN}✅ $module_name: PASSED${NC}"
        PASSED_MODULES+=("$module_name")
    else
        echo -e "${RED}❌ $module_name: FAILED${NC}"
        FAILED_MODULES+=("$module_name")
        
        # Ask if user wants to continue or stop for debugging
        echo -e "\n${YELLOW}Module $module_name failed. What would you like to do?${NC}"
        echo "1) Continue to next module"
        echo "2) Stop here for debugging"
        echo "3) Run this module again with verbose output"
        read -p "Enter choice (1-3): " choice
        
        case $choice in
            2)
                echo -e "${YELLOW}Stopping for debugging. You can re-run this module with:${NC}"
                echo "flutter test $module_path --reporter=expanded"
                exit 1
                ;;
            3)
                echo -e "${BLUE}Re-running $module_name with verbose output...${NC}"
                flutter test "$module_path" --reporter=expanded --verbose
                ;;
        esac
    fi
}

# Run unit tests module by module
echo -e "\n${BLUE}📁 Running Unit Tests by Module${NC}"
echo "================================="

for module in "${UNIT_MODULES[@]}"; do
    run_module_tests "test/unit/$module" "$module"
done

# Run other test directories
echo -e "\n${BLUE}📁 Running Other Test Directories${NC}"
echo "=================================="

for test_dir in "${OTHER_TEST_DIRS[@]}"; do
    run_module_tests "test/$test_dir" "$test_dir"
done

# Summary
echo -e "\n${BLUE}📊 Test Summary${NC}"
echo "==============="
echo -e "${GREEN}✅ Passed modules (${#PASSED_MODULES[@]}):${NC}"
for module in "${PASSED_MODULES[@]}"; do
    echo "  - $module"
done

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
    echo -e "\n${RED}❌ Failed modules (${#FAILED_MODULES[@]}):${NC}"
    for module in "${FAILED_MODULES[@]}"; do
        echo "  - $module"
    done
fi

if [ ${#SKIPPED_MODULES[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️  Skipped modules (${#SKIPPED_MODULES[@]}):${NC}"
    for module in "${SKIPPED_MODULES[@]}"; do
        echo "  - $module"
    done
fi

# Exit with error if any modules failed
if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
    echo -e "\n${RED}Some modules failed. Focus on fixing these modules first.${NC}"
    exit 1
else
    echo -e "\n${GREEN}All modules passed! 🎉${NC}"
fi 