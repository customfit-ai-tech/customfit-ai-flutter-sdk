# Flutter SDK Testing Scripts

This directory contains comprehensive testing scripts for the CustomFit Flutter SDK. These Dart-based scripts provide detailed reporting, coverage analysis, performance testing, and benchmarking capabilities.

## 🚀 Quick Start

All scripts are written in Dart and can be run directly:

```bash
# Run unit tests
dart run tool/run_unit_tests.dart

# Generate coverage report
dart run tool/run_coverage.dart

# Run performance tests
dart run tool/run_performance.dart

# Run benchmarks
dart run tool/run_benchmarks.dart
```

## 📋 Available Scripts

### 1. `run_unit_tests.dart` - Unit Test Runner

Runs unit tests with module-level reporting and detailed statistics.

**Features:**
- Module-level test reporting (analytics/, client/, core/, etc.)
- Pass/fail counts per module
- Colored console output
- JUnit XML report generation
- JSON report generation
- Test filtering by module or tags

**Usage:**
```bash
# Run all unit tests
dart run tool/run_unit_tests.dart

# Run tests for specific module
dart run tool/run_unit_tests.dart --module analytics

# Generate JUnit report
dart run tool/run_unit_tests.dart --junit=test_results.xml

# Run with coverage
dart run tool/run_unit_tests.dart --coverage

# Verbose output
dart run tool/run_unit_tests.dart --verbose
```

**Options:**
- `-m, --module`: Run tests for specific module only
- `-t, --tags`: Run tests with specific tags
- `-c, --coverage`: Generate coverage report
- `-v, --verbose`: Show detailed output
- `--no-color`: Disable colored output
- `--fail-fast`: Stop on first test failure
- `-r, --reporter`: Test reporter format (compact, expanded, json)
- `--junit`: Generate JUnit XML report at path
- `--json-report`: Generate JSON report at path

### 2. `run_coverage.dart` - Coverage Analysis

Generates detailed coverage reports with module-level breakdown.

**Features:**
- Module-level coverage percentages
- HTML report generation
- Coverage threshold enforcement
- Historical coverage tracking
- Uncovered files listing
- Auto-open HTML report in browser

**Usage:**
```bash
# Generate coverage report
dart run tool/run_coverage.dart

# Set minimum coverage threshold
dart run tool/run_coverage.dart --min-coverage=90

# Open HTML report automatically
dart run tool/run_coverage.dart --open

# Save report to file
dart run tool/run_coverage.dart --output=coverage_report.json
```

**Options:**
- `--min-coverage`: Minimum coverage threshold (override config)
- `-o, --open`: Open HTML report in browser
- `-f, --format`: Output format (summary, detailed, lcov)
- `-v, --verbose`: Show detailed output
- `--no-color`: Disable colored output
- `--output`: Save report to file

### 3. `run_performance.dart` - Performance Testing

Runs stress tests and monitors performance metrics.

**Features:**
- Performance baseline tracking
- Regression detection
- Statistical analysis (mean, median, std dev, percentiles)
- Warmup runs before measurement
- Performance trend analysis

**Usage:**
```bash
# Run performance tests
dart run tool/run_performance.dart

# Update performance baseline
dart run tool/run_performance.dart --update-baseline

# Set custom regression threshold
dart run tool/run_performance.dart --threshold=100

# Test specific module
dart run tool/run_performance.dart --module=analytics
```

**Options:**
- `--update-baseline`: Update performance baseline with current results
- `-t, --threshold`: Regression threshold in milliseconds
- `-m, --module`: Run performance tests for specific module only
- `-v, --verbose`: Show detailed output
- `--no-color`: Disable colored output
- `--output`: Save performance report to file

### 4. `run_benchmarks.dart` - Benchmark Suite

Measures performance of key SDK operations.

**Features:**
- Benchmarks for initialization, flag evaluation, event tracking, etc.
- Statistical analysis with standard deviation
- Throughput measurement (operations/second)
- Comparison with previous benchmarks
- Multiple output formats (JSON, CSV)

**Usage:**
```bash
# Run all benchmarks
dart run tool/run_benchmarks.dart

# Benchmark specific operation
dart run tool/run_benchmarks.dart --operation=flag_evaluation

# Custom iteration count
dart run tool/run_benchmarks.dart --iterations=50

# Export as CSV
dart run tool/run_benchmarks.dart --output=csv
```

**Options:**
- `-o, --operation`: Specific operation to benchmark
- `-i, --iterations`: Number of iterations
- `--compare`: Compare with previous benchmark results
- `-v, --verbose`: Show detailed output
- `--no-color`: Disable colored output
- `--output`: Output format (console, json, csv, all)

## ⚙️ Configuration

All scripts use `test_config.yaml` for configuration. Key settings include:

```yaml
# Test directories
test_directories:
  - "test/unit"
  - "test/stress"

# Coverage settings
coverage:
  min_threshold: 85.0
  exclude_files:
    - "**/*.g.dart"
    - "**/*.mocks.dart"

# Performance settings
performance:
  regression_threshold_ms: 50
  warmup_runs: 3
  measurement_runs: 10

# Benchmark settings
benchmarks:
  warmup_runs: 5
  measurement_runs: 20
  operations:
    - "client_initialization"
    - "flag_evaluation"
    - "event_tracking"
```

## 📊 Output Examples

### Unit Test Summary
```
Module Test Summary
────────────────────────────────────────────────────────────────────────────────
Module              Total     Passed    Failed    Skipped   Pass Rate   Time
────────────────────────────────────────────────────────────────────────────────
analytics           25        24        1         0         96.0%       2.3s
client              18        18        0         0         100.0%      1.5s
core                32        30        0         2         93.8%       3.1s
network             15        15        0         0         100.0%      1.2s
────────────────────────────────────────────────────────────────────────────────
TOTAL               90        87        1         2         96.7%       8.1s
```

### Coverage Summary
```
Coverage Summary by Module
──────────────────────────────────────────────────────────────────────
Module              Files     Lines     Covered   Coverage    Status
──────────────────────────────────────────────────────────────────────
analytics           8         420       395       94.0%       ✓
client              5         280       271       96.8%       ✓
core                12        650       585       90.0%       ✓
network             6         320       272       85.0%       ✓
──────────────────────────────────────────────────────────────────────
TOTAL               31        1670      1523      91.2%       ✓
```

### Performance Results
```
Performance Test Results
────────────────────────────────────────────────────────────────────────────────────────────────────
Test Name                               Mean    Median  StdDev  Min     Max     P95     P99     Status
────────────────────────────────────────────────────────────────────────────────────────────────────
event_tracking_stress_test              125ms   120ms   15ms    105ms   180ms   165ms   175ms   → ±5ms
cache_performance_stress_test           45ms    42ms    8ms     35ms    75ms    68ms    72ms    ↓ -10ms (-18.2%)
network_health_monitor_stress_test      230ms   225ms   25ms    195ms   295ms   285ms   290ms   ↑ +15ms (+7.0%)
```

## 🔧 Advanced Usage

### Continuous Integration

Add to your CI pipeline:

```yaml
# GitHub Actions example
- name: Run Unit Tests
  run: dart run tool/run_unit_tests.dart --junit=results.xml

- name: Generate Coverage
  run: dart run tool/run_coverage.dart --min-coverage=85

- name: Check Performance
  run: dart run tool/run_performance.dart

- name: Upload Reports
  uses: actions/upload-artifact@v2
  with:
    name: test-reports
    path: |
      results.xml
      coverage/html/
      tool/performance_report.json
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
dart run tool/run_unit_tests.dart --fail-fast
if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

### Custom Test Categories

Add custom test categories in `test_config.yaml`:

```yaml
test_categories:
  integration:
    path_pattern: "test/integration/**/*_test.dart"
    tags: ["integration"]
  
  e2e:
    path_pattern: "test/e2e/**/*_test.dart"
    tags: ["e2e", "slow"]
```

## 🎯 Best Practices

1. **Regular Baseline Updates**: Update performance baselines after significant changes
2. **Coverage Goals**: Set module-specific coverage thresholds
3. **Performance Monitoring**: Track performance trends over time
4. **Parallel Testing**: Use parallel execution for faster test runs
5. **Test Organization**: Keep tests organized by module for better reporting

## 🐛 Troubleshooting

### Common Issues

1. **"test_config.yaml not found"**
   - Ensure you're running scripts from the SDK root directory
   - Check that `tool/test_config.yaml` exists

2. **"genhtml not found" (Coverage)**
   - Install lcov: `brew install lcov` (macOS) or `apt-get install lcov` (Linux)

3. **Performance test variations**
   - Increase warmup runs and measurement runs in config
   - Run tests on a quiet system without other processes

4. **Benchmark failures**
   - Ensure test dependencies are properly mocked
   - Check that benchmark operations are isolated

## 📝 Contributing

When adding new test scripts:

1. Follow the existing pattern for argument parsing
2. Use the shared utilities in `src/`
3. Support both colored and plain output
4. Include proper error handling
5. Update this README with usage information

## 📄 License

These testing scripts are part of the CustomFit Flutter SDK and follow the same license terms.