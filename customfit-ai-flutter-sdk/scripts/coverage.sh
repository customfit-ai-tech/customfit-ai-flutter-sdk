#!/bin/bash

# Flutter SDK Coverage Script
# Generates test coverage reports in multiple formats

set -e

echo "🧪 Running Flutter tests with coverage..."

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COVERAGE_DIR="coverage"
MIN_COVERAGE=85

# Clean previous coverage
rm -rf $COVERAGE_DIR
mkdir -p $COVERAGE_DIR

# Run tests with coverage (unit tests only)
# Continue even if tests fail to generate report
flutter test test/unit --coverage || true

# Check if lcov is installed
if ! command -v lcov &> /dev/null; then
    echo -e "${YELLOW}⚠️  lcov not found. Installing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install lcov
    else
        sudo apt-get update && sudo apt-get install -y lcov
    fi
fi

# Check if genhtml is installed
if ! command -v genhtml &> /dev/null; then
    echo -e "${YELLOW}⚠️  genhtml not found. Installing lcov...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install lcov
    else
        sudo apt-get update && sudo apt-get install -y lcov
    fi
fi

# Check if lcov.info was generated
if [ ! -f "$COVERAGE_DIR/lcov.info" ]; then
    echo -e "${RED}❌ No lcov.info file found. Cannot generate HTML report.${NC}"
    exit 1
fi

# Generate HTML report
echo "📊 Generating HTML coverage report..."
genhtml $COVERAGE_DIR/lcov.info -o $COVERAGE_DIR/html --quiet

# Generate coverage summary
lcov --summary $COVERAGE_DIR/lcov.info > $COVERAGE_DIR/summary.txt 2>&1

# Extract coverage percentage
COVERAGE_PCT=$(lcov --summary $COVERAGE_DIR/lcov.info 2>&1 | grep -E "lines.*:" | grep -oE "[0-9]+\.[0-9]+" | head -1)
COVERAGE_INT=${COVERAGE_PCT%.*}

# Generate badge
echo "🏷️  Generating coverage badge..."
if [ "$COVERAGE_INT" -ge 90 ]; then
    COLOR="brightgreen"
elif [ "$COVERAGE_INT" -ge 80 ]; then
    COLOR="green"
elif [ "$COVERAGE_INT" -ge 70 ]; then
    COLOR="yellow"
elif [ "$COVERAGE_INT" -ge 60 ]; then
    COLOR="orange"
else
    COLOR="red"
fi

# Create badge SVG
cat > $COVERAGE_DIR/badge.svg << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="114" height="20">
  <linearGradient id="b" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="a">
    <rect width="114" height="20" rx="3" fill="#fff"/>
  </clipPath>
  <g clip-path="url(#a)">
    <path fill="#555" d="M0 0h63v20H0z"/>
    <path fill="$COLOR" d="M63 0h51v20H63z"/>
    <path fill="url(#b)" d="M0 0h114v20H0z"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="110">
    <text x="325" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="530">coverage</text>
    <text x="325" y="140" transform="scale(.1)" textLength="530">coverage</text>
    <text x="875" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="410">${COVERAGE_PCT}%</text>
    <text x="875" y="140" transform="scale(.1)" textLength="410">${COVERAGE_PCT}%</text>
  </g>
</svg>
EOF

# Print summary
echo ""
echo "📈 Coverage Summary:"
echo "==================="
cat $COVERAGE_DIR/summary.txt | grep -E "(Total:|lines\.+:)" || true
echo ""

# Check coverage threshold
if [ "$COVERAGE_INT" -lt "$MIN_COVERAGE" ]; then
    echo -e "${RED}❌ Coverage ${COVERAGE_PCT}% is below minimum threshold of ${MIN_COVERAGE}%${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Coverage ${COVERAGE_PCT}% meets minimum threshold of ${MIN_COVERAGE}%${NC}"
fi

echo ""
echo "📁 Coverage reports generated:"
echo "  - HTML Report: $COVERAGE_DIR/html/index.html"
echo "  - Summary: $COVERAGE_DIR/summary.txt"
echo "  - Badge: $COVERAGE_DIR/badge.svg"
echo ""

# Open HTML report if not in CI
if [ -z "$CI" ]; then
    echo "Opening coverage report in browser..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open $COVERAGE_DIR/html/index.html
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open $COVERAGE_DIR/html/index.html 2>/dev/null || true
    fi
fi