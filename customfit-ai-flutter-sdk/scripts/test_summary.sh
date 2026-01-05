#!/bin/bash

# Flutter SDK Test Summary Script
# Quickly shows test status across all modules

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Navigate to Flutter SDK directory
cd "$(dirname "$0")/.."

echo -e "${BLUE}Flutter SDK Test Summary${NC}"
echo "========================"

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
    "platform"
    "services"
    "storage"
    "utils"
)

# Results tracking
declare -A MODULE_RESULTS
declare -A MODULE_COUNTS

# Function to run tests for a specific module and capture results
test_module_summary() {
    local module_path="$1"
    local module_name="$2"
    
    if [ ! -d "$module_path" ]; then
        MODULE_RESULTS["$module_name"]="SKIPPED"
        MODULE_COUNTS["$module_name"]="0/0"
        return
    fi
    
    # Count test files
    local test_count=$(find "$module_path" -name "*_test.dart" | wc -l)
    if [ "$test_count" -eq 0 ]; then
        MODULE_RESULTS["$module_name"]="SKIPPED"
        MODULE_COUNTS["$module_name"]="0/0"
        return
    fi
    
    echo -e "${YELLOW}Testing $module_name...${NC}"
    
    # Run tests and capture output
    if flutter test "$module_path" --reporter=compact 2>&1 | grep -E "(\+[0-9]+.*-[0-9]+|All tests passed)" > /tmp/test_result_$module_name.txt; then
        local result=$(cat /tmp/test_result_$module_name.txt | tail -1)
        
        if echo "$result" | grep -q "All tests passed"; then
            # Extract passed count from previous lines
            local passed=$(cat /tmp/test_result_$module_name.txt | grep -o "+[0-9]*" | tail -1 | sed 's/+//')
            MODULE_RESULTS["$module_name"]="PASSED"
            MODULE_COUNTS["$module_name"]="${passed}/${passed}"
        else
            # Extract passed and failed counts
            local passed=$(echo "$result" | grep -o "+[0-9]*" | sed 's/+//')
            local failed=$(echo "$result" | grep -o "\-[0-9]*" | sed 's/-//')
            local total=$((passed + failed))
            MODULE_RESULTS["$module_name"]="FAILED"
            MODULE_COUNTS["$module_name"]="${passed}/${total}"
        fi
    else
        # If we can't parse the output, run a simple test to see if it passes
        if flutter test "$module_path" --reporter=compact > /dev/null 2>&1; then
            MODULE_RESULTS["$module_name"]="PASSED"
            MODULE_COUNTS["$module_name"]="?/?"
        else
            MODULE_RESULTS["$module_name"]="FAILED"
            MODULE_COUNTS["$module_name"]="?/?"
        fi
    fi
    
    # Clean up temp file
    rm -f /tmp/test_result_$module_name.txt
}

# Test all modules
echo -e "\n${BLUE}Running tests on all modules...${NC}"
echo "This may take a few minutes..."
echo ""

for module in "${UNIT_MODULES[@]}"; do
    test_module_summary "test/unit/$module" "$module"
done

# Display summary
echo -e "\n${BLUE}📊 Test Results Summary${NC}"
echo "========================"
printf "%-15s %-10s %-15s\n" "Module" "Status" "Passed/Total"
echo "----------------------------------------"

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_MODULES=0

for module in "${UNIT_MODULES[@]}"; do
    local status="${MODULE_RESULTS[$module]}"
    local counts="${MODULE_COUNTS[$module]}"
    
    if [ "$status" = "PASSED" ]; then
        printf "%-15s ${GREEN}%-10s${NC} %-15s\n" "$module" "✅ PASSED" "$counts"
        ((TOTAL_PASSED++))
    elif [ "$status" = "FAILED" ]; then
        printf "%-15s ${RED}%-10s${NC} %-15s\n" "$module" "❌ FAILED" "$counts"
        ((TOTAL_FAILED++))
    else
        printf "%-15s ${YELLOW}%-10s${NC} %-15s\n" "$module" "⚠️  SKIPPED" "$counts"
    fi
    ((TOTAL_MODULES++))
done

echo "----------------------------------------"
echo -e "${GREEN}Passed modules: $TOTAL_PASSED${NC}"
echo -e "${RED}Failed modules: $TOTAL_FAILED${NC}"
echo -e "${YELLOW}Skipped modules: $((TOTAL_MODULES - TOTAL_PASSED - TOTAL_FAILED))${NC}"

# Recommendations
echo -e "\n${BLUE}📋 Recommendations${NC}"
echo "=================="

if [ $TOTAL_FAILED -gt 0 ]; then
    echo -e "${RED}Focus on these failing modules first:${NC}"
    for module in "${UNIT_MODULES[@]}"; do
        if [ "${MODULE_RESULTS[$module]}" = "FAILED" ]; then
            echo "  - $module (${MODULE_COUNTS[$module]})"
        fi
    done
    echo ""
    echo "To debug a specific module:"
    echo "  ./scripts/test_single_module.sh <module_name>"
    echo ""
    echo "To run all module tests systematically:"
    echo "  ./scripts/test_modules.sh"
else
    echo -e "${GREEN}🎉 All modules are passing! Great job!${NC}"
fi 