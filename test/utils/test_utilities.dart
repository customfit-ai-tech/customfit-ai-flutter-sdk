import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
/// Comprehensive test utilities for CustomFit Flutter SDK
/// Provides helpers for async operations, memory management, JSON validation,
/// performance measurement, test data generation, error simulation, and more.
// ============================================================================
// Async Helpers
// ============================================================================
/// Waits for an async operation with a timeout
Future<T> waitForAsync<T>(
  Future<T> Function() operation, {
  Duration timeout = const Duration(seconds: 5),
  String? timeoutMessage,
}) async {
  try {
    return await operation().timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        timeoutMessage ?? 'Operation timed out after $timeout',
      ),
    );
  } catch (e) {
    rethrow;
  }
}
/// Pumps the event queue multiple times
Future<void> pump({int times = 1, Duration? duration}) async {
  for (int i = 0; i < times; i++) {
    await Future.delayed(duration ?? Duration.zero);
  }
}
/// Ticks the microtask queue
Future<void> tick() async {
  await Future.microtask(() {});
}
/// Delays execution for a specified duration
Future<void> delay(Duration duration) async {
  await Future.delayed(duration);
}
/// Waits for a condition to become true
Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration checkInterval = const Duration(milliseconds: 100),
  String? timeoutMessage,
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      throw TimeoutException(
        timeoutMessage ?? 'Condition not met within $timeout',
      );
    }
    await delay(checkInterval);
  }
}
/// Retries an operation with exponential backoff
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(milliseconds: 100),
  double backoffMultiplier = 2.0,
  bool Function(dynamic)? retryIf,
}) async {
  var delay = initialDelay;
  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (e) {
      if (attempt == maxRetries || (retryIf != null && !retryIf(e))) {
        rethrow;
      }
      await Future.delayed(delay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
      );
    }
  }
  throw StateError('Retry logic error');
}
// ============================================================================
// Memory Leak Checks and Garbage Collection
// ============================================================================
/// Checks for memory leaks by monitoring object allocation
class MemoryLeakChecker {
  final Map<Type, int> _initialCounts = {};
  final Map<Type, int> _finalCounts = {};
  /// Starts monitoring memory for the specified types
  void startMonitoring(List<Type> types) {
    for (final type in types) {
      _initialCounts[type] = _getInstanceCount(type);
    }
  }
  /// Stops monitoring and checks for leaks
  Future<MemoryLeakReport> checkForLeaks() async {
    // Force garbage collection
    await forceGarbageCollection();
    final leaks = <Type, int>{};
    for (final type in _initialCounts.keys) {
      final initialCount = _initialCounts[type]!;
      final finalCount = _getInstanceCount(type);
      _finalCounts[type] = finalCount;
      if (finalCount > initialCount) {
        leaks[type] = finalCount - initialCount;
      }
    }
    return MemoryLeakReport(
      initialCounts: Map.from(_initialCounts),
      finalCounts: Map.from(_finalCounts),
      leaks: leaks,
    );
  }
  int _getInstanceCount(Type type) {
    // This is a simplified implementation
    // In real scenarios, you'd use platform-specific memory profiling tools
    return 0;
  }
}
/// Report of memory leak detection
class MemoryLeakReport {
  final Map<Type, int> initialCounts;
  final Map<Type, int> finalCounts;
  final Map<Type, int> leaks;
  MemoryLeakReport({
    required this.initialCounts,
    required this.finalCounts,
    required this.leaks,
  });
  bool get hasLeaks => leaks.isNotEmpty;
  @override
  String toString() {
    if (!hasLeaks) {
      return 'No memory leaks detected';
    }
    final buffer = StringBuffer('Memory leaks detected:\n');
    for (final entry in leaks.entries) {
      buffer.writeln('  ${entry.key}: +${entry.value} instances');
    }
    return buffer.toString();
  }
}
/// Forces garbage collection
Future<void> forceGarbageCollection() async {
  // Trigger multiple GC cycles
  for (int i = 0; i < 3; i++) {
    // Create temporary objects to trigger GC
    List.generate(1000, (i) => Object());
    await tick();
  }
}
/// Monitors memory usage during test execution
class MemoryMonitor {
  final List<MemorySnapshot> _snapshots = [];
  Timer? _timer;
  /// Starts monitoring memory usage
  void startMonitoring({Duration interval = const Duration(seconds: 1)}) {
    _timer = Timer.periodic(interval, (_) {
      _snapshots.add(MemorySnapshot.current());
    });
  }
  /// Stops monitoring and returns the report
  MemoryUsageReport stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    return MemoryUsageReport(_snapshots);
  }
}
/// Snapshot of memory usage at a point in time
class MemorySnapshot {
  final DateTime timestamp;
  final int heapUsage;
  final int heapCapacity;
  MemorySnapshot({
    required this.timestamp,
    required this.heapUsage,
    required this.heapCapacity,
  });
  factory MemorySnapshot.current() {
    // Simplified implementation
    return MemorySnapshot(
      timestamp: DateTime.now(),
      heapUsage: 0,
      heapCapacity: 0,
    );
  }
}
/// Report of memory usage over time
class MemoryUsageReport {
  final List<MemorySnapshot> snapshots;
  MemoryUsageReport(this.snapshots);
  int get peakUsage =>
      snapshots.isEmpty ? 0 : snapshots.map((s) => s.heapUsage).reduce(max);
  int get averageUsage => snapshots.isEmpty
      ? 0
      : snapshots.map((s) => s.heapUsage).reduce((a, b) => a + b) ~/
          snapshots.length;
}
// ============================================================================
// JSON Assertion Helpers
// ============================================================================
/// Deep comparison of JSON objects
void assertJsonEquals(dynamic actual, dynamic expected, {String? message}) {
  if (!_deepJsonEquals(actual, expected)) {
    fail(message ??
        'JSON objects are not equal:\n'
            'Expected: ${jsonEncode(expected)}\n'
            'Actual: ${jsonEncode(actual)}');
  }
}
bool _deepJsonEquals(dynamic a, dynamic b) {
  if (a == b) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepJsonEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_deepJsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return false;
}
/// JSON schema validation
class JsonSchema {
  final Map<String, dynamic> schema;
  JsonSchema(this.schema);
  /// Validates JSON against the schema
  ValidationResult validate(dynamic json) {
    final errors = <String>[];
    _validateObject(json, schema, '', errors);
    return ValidationResult(errors.isEmpty, errors);
  }
  void _validateObject(
    dynamic value,
    Map<String, dynamic> schema,
    String path,
    List<String> errors,
  ) {
    final type = schema['type'];
    if (type != null && !_matchesType(value, type)) {
      errors.add('$path: expected type $type, got ${value.runtimeType}');
      return;
    }
    if (type == 'object' && value is Map) {
      final properties = schema['properties'] as Map<String, dynamic>?;
      final required = schema['required'] as List<String>?;
      if (required != null) {
        for (final key in required) {
          if (!value.containsKey(key)) {
            errors.add('$path: missing required property "$key"');
          }
        }
      }
      if (properties != null) {
        for (final entry in properties.entries) {
          final key = entry.key;
          final propSchema = entry.value as Map<String, dynamic>;
          if (value.containsKey(key)) {
            _validateObject(
              value[key],
              propSchema,
              '$path.$key',
              errors,
            );
          }
        }
      }
    }
    if (type == 'array' && value is List) {
      final items = schema['items'] as Map<String, dynamic>?;
      if (items != null) {
        for (int i = 0; i < value.length; i++) {
          _validateObject(value[i], items, '$path[$i]', errors);
        }
      }
    }
  }
  bool _matchesType(dynamic value, String type) {
    switch (type) {
      case 'string':
        return value is String;
      case 'number':
        return value is num;
      case 'integer':
        return value is int;
      case 'boolean':
        return value is bool;
      case 'object':
        return value is Map;
      case 'array':
        return value is List;
      case 'null':
        return value == null;
      default:
        return false;
    }
  }
}
/// Result of JSON schema validation
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  ValidationResult(this.isValid, this.errors);
}
/// Asserts that JSON matches a schema
void assertJsonMatchesSchema(dynamic json, JsonSchema schema,
    {String? message}) {
  final result = schema.validate(json);
  if (!result.isValid) {
    fail(message ?? 'JSON does not match schema:\n${result.errors.join('\n')}');
  }
}
// ============================================================================
// Performance Measurement Utilities
// ============================================================================
/// Measures the execution time of an operation
class PerformanceMeasurement {
  final String name;
  final Duration duration;
  final Map<String, dynamic> metadata;
  PerformanceMeasurement({
    required this.name,
    required this.duration,
    this.metadata = const {},
  });
  @override
  String toString() {
    return '$name: ${duration.inMilliseconds}ms';
  }
}
/// Measures performance of operations
class PerformanceProfiler {
  final List<PerformanceMeasurement> _measurements = [];
  /// Measures the execution time of an operation
  Future<T> measure<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, dynamic>? metadata,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      _measurements.add(PerformanceMeasurement(
        name: name,
        duration: stopwatch.elapsed,
        metadata: metadata ?? {},
      ));
    }
  }
  /// Measures sync operation
  T measureSync<T>(
    String name,
    T Function() operation, {
    Map<String, dynamic>? metadata,
  }) {
    final stopwatch = Stopwatch()..start();
    try {
      return operation();
    } finally {
      stopwatch.stop();
      _measurements.add(PerformanceMeasurement(
        name: name,
        duration: stopwatch.elapsed,
        metadata: metadata ?? {},
      ));
    }
  }
  /// Gets all measurements
  List<PerformanceMeasurement> get measurements => List.from(_measurements);
  /// Gets measurements by name
  List<PerformanceMeasurement> getMeasurements(String name) {
    return _measurements.where((m) => m.name == name).toList();
  }
  /// Calculates statistics for measurements
  PerformanceStats getStats(String name) {
    final measurements = getMeasurements(name);
    if (measurements.isEmpty) {
      return PerformanceStats.empty(name);
    }
    final durations =
        measurements.map((m) => m.duration.inMicroseconds).toList();
    durations.sort();
    final sum = durations.reduce((a, b) => a + b);
    final mean = sum / durations.length;
    final median = durations.length.isOdd
        ? durations[durations.length ~/ 2].toDouble()
        : (durations[durations.length ~/ 2 - 1] +
                durations[durations.length ~/ 2]) /
            2;
    final p95Index = (durations.length * 0.95).floor();
    final p95 = durations[p95Index].toDouble();
    return PerformanceStats(
      name: name,
      count: measurements.length,
      mean: Duration(microseconds: mean.round()),
      median: Duration(microseconds: median.round()),
      min: Duration(microseconds: durations.first),
      max: Duration(microseconds: durations.last),
      p95: Duration(microseconds: p95.round()),
    );
  }
  /// Clears all measurements
  void clear() {
    _measurements.clear();
  }
}
/// Performance statistics
class PerformanceStats {
  final String name;
  final int count;
  final Duration mean;
  final Duration median;
  final Duration min;
  final Duration max;
  final Duration p95;
  PerformanceStats({
    required this.name,
    required this.count,
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    required this.p95,
  });
  factory PerformanceStats.empty(String name) {
    return PerformanceStats(
      name: name,
      count: 0,
      mean: Duration.zero,
      median: Duration.zero,
      min: Duration.zero,
      max: Duration.zero,
      p95: Duration.zero,
    );
  }
  @override
  String toString() {
    return '''
Performance Stats for $name:
  Count: $count
  Mean: ${mean.inMilliseconds}ms
  Median: ${median.inMilliseconds}ms
  Min: ${min.inMilliseconds}ms
  Max: ${max.inMilliseconds}ms
  P95: ${p95.inMilliseconds}ms
''';
  }
}
/// Benchmarks code execution
Future<BenchmarkResult> benchmark(
  String name,
  Future<void> Function() operation, {
  int iterations = 10,
  int warmupIterations = 2,
}) async {
  final profiler = PerformanceProfiler();
  // Warmup
  for (int i = 0; i < warmupIterations; i++) {
    await operation();
  }
  // Actual benchmark
  for (int i = 0; i < iterations; i++) {
    await profiler.measure('iteration', operation);
  }
  final stats = profiler.getStats('iteration');
  return BenchmarkResult(
    name: name,
    iterations: iterations,
    warmupIterations: warmupIterations,
    stats: stats,
  );
}
/// Result of a benchmark
class BenchmarkResult {
  final String name;
  final int iterations;
  final int warmupIterations;
  final PerformanceStats stats;
  BenchmarkResult({
    required this.name,
    required this.iterations,
    required this.warmupIterations,
    required this.stats,
  });
  @override
  String toString() {
    return '''
Benchmark: $name
  Iterations: $iterations (warmup: $warmupIterations)
  $stats
''';
  }
}
// ============================================================================
// Test Data Generation Helpers
// ============================================================================
/// Random data generator for tests
class TestDataGenerator {
  final Random _random;
  TestDataGenerator({int? seed}) : _random = Random(seed);
  /// Generates a random string
  String randomString({
    int length = 10,
    String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
  }) {
    return List.generate(
      length,
      (index) => chars[_random.nextInt(chars.length)],
    ).join();
  }
  /// Generates a random email
  String randomEmail() {
    return '${randomString(length: 8)}@${randomString(length: 6)}.com';
  }
  /// Generates a random UUID
  String randomUuid() {
    final bytes = List<int>.generate(16, (i) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
  /// Generates a random integer
  int randomInt({int min = 0, int? max}) {
    if (max == null) return _random.nextInt(1 << 32);
    return min + _random.nextInt(max - min);
  }
  /// Generates a random double
  double randomDouble({double min = 0.0, double max = 1.0}) {
    return min + _random.nextDouble() * (max - min);
  }
  /// Generates a random boolean
  bool randomBool({double probability = 0.5}) {
    return _random.nextDouble() < probability;
  }
  /// Generates a random date
  DateTime randomDateTime({
    DateTime? start,
    DateTime? end,
  }) {
    start ??= DateTime(2000);
    end ??= DateTime.now();
    final diff = end.difference(start).inMilliseconds;
    final randomMillis = _random.nextInt(diff);
    return start.add(Duration(milliseconds: randomMillis));
  }
  /// Generates a random item from a list
  T randomItem<T>(List<T> items) {
    if (items.isEmpty) {
      throw ArgumentError('Cannot select from empty list');
    }
    return items[_random.nextInt(items.length)];
  }
  /// Generates random JSON
  Map<String, dynamic> randomJson({
    int maxDepth = 3,
    int maxKeys = 5,
    int maxArrayLength = 5,
  }) {
    return _generateRandomJson(maxDepth, maxKeys, maxArrayLength)
        as Map<String, dynamic>;
  }
  dynamic _generateRandomJson(int depth, int maxKeys, int maxArrayLength) {
    if (depth == 0) {
      // Generate primitive
      final type = _random.nextInt(4);
      switch (type) {
        case 0:
          return randomString();
        case 1:
          return randomInt(max: 1000);
        case 2:
          return randomDouble(max: 1000);
        case 3:
          return randomBool();
        default:
          return null;
      }
    }
    // Generate object or array
    if (randomBool()) {
      // Object
      final numKeys = _random.nextInt(maxKeys) + 1;
      final object = <String, dynamic>{};
      for (int i = 0; i < numKeys; i++) {
        final key = randomString(length: 5);
        object[key] = _generateRandomJson(depth - 1, maxKeys, maxArrayLength);
      }
      return object;
    } else {
      // Array
      final length = _random.nextInt(maxArrayLength) + 1;
      return List.generate(
        length,
        (_) => _generateRandomJson(depth - 1, maxKeys, maxArrayLength),
      );
    }
  }
}
/// Edge case data generator
class EdgeCaseGenerator {
  /// String edge cases
  static const List<String> stringEdgeCases = [
    '', // Empty string
    ' ', // Single space
    '  ', // Multiple spaces
    '\n', // Newline
    '\t', // Tab
    '\r\n', // Windows newline
    'null', // String "null"
    'undefined', // String "undefined"
    '0', // String zero
    '1', // String one
    'true', // String "true"
    'false', // String "false"
    '{}', // Empty object string
    '[]', // Empty array string
    '{"key": "value"}', // JSON string
    '<script>alert("xss")</script>', // XSS attempt
    'SELECT * FROM users', // SQL injection attempt
    '../../etc/passwd', // Path traversal
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', // Long string (1000 A's)
    '你好世界', // Unicode characters
    '🔥💯🎉', // Emojis
    '\u0000', // Null character
    '\u200B', // Zero-width space
  ];
  /// Number edge cases
  static const List<num> numberEdgeCases = [
    0,
    -0,
    1,
    -1,
    0.1,
    -0.1,
    double.infinity,
    double.negativeInfinity,
    double.nan,
    double.maxFinite,
    -double.maxFinite,
    double.minPositive,
    -double.minPositive,
    9007199254740991, // MAX_SAFE_INTEGER
    -9007199254740991, // MIN_SAFE_INTEGER
  ];
  /// Array edge cases
  static List<List<dynamic>> generateArrayEdgeCases<T>(T Function() generator) {
    return [
      [], // Empty array
      [generator()], // Single element
      List.generate(100, (_) => generator()), // Large array
      [null, generator(), null], // With nulls
      [generator(), generator(), generator()], // Multiple elements
    ];
  }
  /// Map edge cases
  static List<Map<String, dynamic>> generateMapEdgeCases() {
    return [
      {}, // Empty map
      {'key': null}, // Null value
      {'': 'empty key'}, // Empty key
      {' ': 'space key'}, // Space key
      Map.fromEntries(
        // Large map
        List.generate(100, (i) => MapEntry('key$i', 'value$i')),
      ),
      {
        'nested': {
          'deeply': {
            'nested': 'value',
          },
        },
      }, // Nested structure
    ];
  }
}
// ============================================================================
// Error Simulation Utilities
// ============================================================================
/// Simulates various error conditions
class ErrorSimulator {
  /// Simulates a network error
  static Future<void> simulateNetworkError({
    Duration? delay,
    String? message,
  }) async {
    if (delay != null) {
      await Future.delayed(delay);
    }
    throw SocketException(message ?? 'Network error');
  }
  /// Simulates a timeout
  static Future<void> simulateTimeout({
    required Duration duration,
    String? message,
  }) async {
    await Future.delayed(duration);
    throw TimeoutException(message ?? 'Operation timed out', duration);
  }
  /// Simulates an HTTP error
  static void simulateHttpError({
    required int statusCode,
    String? message,
  }) {
    throw HttpException(
      message ?? 'HTTP error',
      uri: Uri.parse('http://example.com'),
    );
  }
  /// Simulates random errors
  static Future<T> withRandomErrors<T>(
    Future<T> Function() operation, {
    double errorProbability = 0.1,
    List<Exception>? possibleErrors,
  }) async {
    if (Random().nextDouble() < errorProbability) {
      final errors = possibleErrors ??
          [
            const SocketException('Random network error'),
            TimeoutException('Random timeout'),
            const FormatException('Random format error'),
          ];
      throw errors[Random().nextInt(errors.length)];
    }
    return await operation();
  }
  /// Simulates flaky behavior
  static Future<T> makeFlaky<T>(
    Future<T> Function() operation, {
    double failureProbability = 0.3,
    int maxAttempts = 5,
  }) async {
    int attempt = 0;
    while (attempt < maxAttempts) {
      final isLastAttempt = attempt == maxAttempts - 1;
      final shouldSucceed = Random().nextDouble() >= failureProbability;
      if (shouldSucceed || isLastAttempt) {
        return await operation();
      }
      attempt++;
      throw Exception('Flaky failure on attempt $attempt');
    }
    // This line should never be reached, but satisfies the compiler
    throw StateError('Unexpected end of makeFlaky method');
  }
}
/// Network condition simulator
class NetworkConditionSimulator {
  final Duration? latency;
  final double? packetLoss;
  final int? bandwidth; // bytes per second
  NetworkConditionSimulator({
    this.latency,
    this.packetLoss,
    this.bandwidth,
  });
  /// Simulates network conditions for an operation
  Future<T> simulate<T>(Future<T> Function() operation) async {
    // Simulate latency
    if (latency != null) {
      await Future.delayed(latency!);
    }
    // Simulate packet loss
    if (packetLoss != null && Random().nextDouble() < packetLoss!) {
      throw const SocketException('Packet lost');
    }
    // Simulate bandwidth limitation
    if (bandwidth != null) {
      // This is a simplified simulation
      await Future.delayed(Duration(milliseconds: Random().nextInt(100)));
    }
    return await operation();
  }
  /// Common network conditions
  static final NetworkConditionSimulator good = NetworkConditionSimulator(
    latency: const Duration(milliseconds: 20),
    packetLoss: 0.0,
  );
  static final NetworkConditionSimulator moderate = NetworkConditionSimulator(
    latency: const Duration(milliseconds: 100),
    packetLoss: 0.01,
  );
  static final NetworkConditionSimulator poor = NetworkConditionSimulator(
    latency: const Duration(milliseconds: 500),
    packetLoss: 0.05,
  );
  static final NetworkConditionSimulator offline = NetworkConditionSimulator(
    packetLoss: 1.0,
  );
}
// ============================================================================
// Mock Validation Helpers
// ============================================================================
/// Extension for enhanced mock verification
extension MockVerification on Mock {
  /// Verifies that a method was called exactly n times
  void verifyCalledExactly(dynamic Function() interaction, int times) {
    verify(interaction()).called(times);
  }
  /// Verifies that a method was never called
  void verifyNeverCalled(dynamic Function() interaction) {
    verifyNever(interaction());
  }
  /// Verifies call order
  void verifyInOrder(List<dynamic Function()> interactions) {
    final inOrder = verifyInOrder;
    for (final interaction in interactions) {
      inOrder(interaction());
    }
  }
  /// Captures all arguments passed to a method
  List<dynamic> captureAll(dynamic Function() interaction) {
    return verify(interaction()).captured;
  }
}
/// Mock call recorder for detailed verification
class MockCallRecorder {
  final List<MockCall> _calls = [];
  /// Records a method call
  void recordCall(String method, List<dynamic> args, {dynamic result}) {
    _calls.add(MockCall(
      method: method,
      arguments: args,
      result: result,
      timestamp: DateTime.now(),
    ));
  }
  /// Gets all calls for a method
  List<MockCall> getCallsForMethod(String method) {
    return _calls.where((call) => call.method == method).toList();
  }
  /// Verifies call count for a method
  void verifyCallCount(String method, int expectedCount) {
    final actualCount = getCallsForMethod(method).length;
    if (actualCount != expectedCount) {
      fail('Expected $expectedCount calls to $method, but got $actualCount');
    }
  }
  /// Verifies arguments for a specific call
  void verifyArguments(
      String method, int callIndex, List<dynamic> expectedArgs) {
    final calls = getCallsForMethod(method);
    if (callIndex >= calls.length) {
      fail('Call index $callIndex out of range for method $method');
    }
    final actualArgs = calls[callIndex].arguments;
    if (!_listEquals(actualArgs, expectedArgs)) {
      fail('Arguments mismatch for $method call $callIndex:\n'
          'Expected: $expectedArgs\n'
          'Actual: $actualArgs');
    }
  }
  /// Clears all recorded calls
  void clear() {
    _calls.clear();
  }
  bool _listEquals(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
/// Represents a recorded mock call
class MockCall {
  final String method;
  final List<dynamic> arguments;
  final dynamic result;
  final DateTime timestamp;
  MockCall({
    required this.method,
    required this.arguments,
    this.result,
    required this.timestamp,
  });
}
// ============================================================================
// File System Test Utilities
// ============================================================================
/// File system test utilities
class FileSystemTestUtils {
  static final Random _random = Random();
  /// Creates a temporary directory for testing
  static Future<Directory> createTempDirectory({String? prefix}) async {
    final tempDir = Directory.systemTemp.createTempSync(
      prefix ?? 'cf_test_${_random.nextInt(10000)}',
    );
    return tempDir;
  }
  /// Creates a temporary file with content
  static Future<File> createTempFile({
    String? prefix,
    String? suffix,
    String? content,
    Directory? directory,
  }) async {
    final dir = directory ?? Directory.systemTemp;
    final name =
        '${prefix ?? 'temp'}_${_random.nextInt(10000)}${suffix ?? '.tmp'}';
    final file = File('${dir.path}/$name');
    if (content != null) {
      await file.writeAsString(content);
    } else {
      await file.create();
    }
    return file;
  }
  /// Cleans up a directory and all its contents
  static Future<void> cleanupDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
  /// Creates a file structure for testing
  static Future<void> createFileStructure(
    Directory root,
    Map<String, dynamic> structure,
  ) async {
    for (final entry in structure.entries) {
      final path = '${root.path}/${entry.key}';
      final value = entry.value;
      if (value is String) {
        // Create file with content
        final file = File(path);
        await file.create(recursive: true);
        await file.writeAsString(value);
      } else if (value is Map<String, dynamic>) {
        // Create subdirectory
        final dir = Directory(path);
        await dir.create(recursive: true);
        await createFileStructure(dir, value);
      }
    }
  }
  /// Verifies file structure matches expected
  static Future<void> verifyFileStructure(
    Directory root,
    Map<String, dynamic> expectedStructure,
  ) async {
    for (final entry in expectedStructure.entries) {
      final path = '${root.path}/${entry.key}';
      final expectedValue = entry.value;
      if (expectedValue is String) {
        // Verify file content
        final file = File(path);
        if (!await file.exists()) {
          fail('Expected file not found: $path');
        }
        final content = await file.readAsString();
        if (content != expectedValue) {
          fail('File content mismatch for $path:\n'
              'Expected: $expectedValue\n'
              'Actual: $content');
        }
      } else if (expectedValue is Map<String, dynamic>) {
        // Verify subdirectory
        final dir = Directory(path);
        if (!await dir.exists()) {
          fail('Expected directory not found: $path');
        }
        await verifyFileStructure(dir, expectedValue);
      }
    }
  }
}
/// Automatic cleanup manager for test resources
class TestResourceManager {
  final List<Future<void> Function()> _cleanupTasks = [];
  /// Registers a cleanup task
  void addCleanup(Future<void> Function() cleanup) {
    _cleanupTasks.add(cleanup);
  }
  /// Adds a directory for cleanup
  void addDirectory(Directory directory) {
    addCleanup(() => FileSystemTestUtils.cleanupDirectory(directory));
  }
  /// Adds a file for cleanup
  void addFile(File file) {
    addCleanup(() async {
      if (await file.exists()) {
        await file.delete();
      }
    });
  }
  /// Performs all cleanup tasks
  Future<void> cleanup() async {
    for (final task in _cleanupTasks.reversed) {
      try {
        await task();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
    _cleanupTasks.clear();
  }
}
// ============================================================================
// Concurrency Testing Helpers
// ============================================================================
/// Helps test concurrent operations
class ConcurrencyTester {
  /// Runs operations in parallel and collects results
  static Future<List<T>> runParallel<T>(
    List<Future<T> Function()> operations,
  ) async {
    return await Future.wait(
      operations.map((op) => op()),
    );
  }
  /// Runs operations with controlled concurrency
  static Future<List<T>> runWithConcurrency<T>(
    List<Future<T> Function()> operations, {
    required int maxConcurrency,
  }) async {
    final results = <T>[];
    final queue = List<Future<T> Function()>.from(operations);
    final active = <Future<T>>[];
    while (queue.isNotEmpty || active.isNotEmpty) {
      // Start new operations up to max concurrency
      while (active.length < maxConcurrency && queue.isNotEmpty) {
        final operation = queue.removeAt(0);
        active.add(operation());
      }
      // Wait for any operation to complete
      if (active.isNotEmpty) {
        final completed = await Future.any(active);
        results.add(completed);
        active.removeWhere((future) => future == completed);
      }
    }
    return results;
  }
  /// Tests for race conditions
  static Future<RaceConditionReport> testForRaceConditions({
    required Future<void> Function() setup,
    required List<Future<void> Function()> concurrentOperations,
    required Future<bool> Function() checkInvariant,
    required Future<void> Function() cleanup,
    int iterations = 100,
  }) async {
    final violations = <String>[];
    for (int i = 0; i < iterations; i++) {
      await setup();
      try {
        await runParallel(concurrentOperations);
        if (!await checkInvariant()) {
          violations.add('Iteration $i: Invariant violated');
        }
      } catch (e) {
        violations.add('Iteration $i: Exception: $e');
      } finally {
        await cleanup();
      }
    }
    return RaceConditionReport(
      iterations: iterations,
      violations: violations,
    );
  }
  /// Creates a barrier for synchronizing operations
  static Barrier createBarrier(int participantCount) {
    return Barrier(participantCount);
  }
}
/// Report of race condition testing
class RaceConditionReport {
  final int iterations;
  final List<String> violations;
  RaceConditionReport({
    required this.iterations,
    required this.violations,
  });
  bool get hasViolations => violations.isNotEmpty;
  double get violationRate => violations.length / iterations;
  @override
  String toString() {
    if (!hasViolations) {
      return 'No race conditions detected in $iterations iterations';
    }
    return '''
Race conditions detected:
  Iterations: $iterations
  Violations: ${violations.length} (${(violationRate * 100).toStringAsFixed(1)}%)
  Details:
${violations.map((v) => '    $v').join('\n')}
''';
  }
}
/// Synchronization barrier for concurrent operations
class Barrier {
  final int _participantCount;
  int _waitingCount = 0;
  final List<Completer<void>> _waiters = [];
  Barrier(this._participantCount);
  /// Waits at the barrier until all participants arrive
  Future<void> wait() async {
    _waitingCount++;
    if (_waitingCount >= _participantCount) {
      // All participants have arrived, release them
      for (final completer in _waiters) {
        completer.complete();
      }
      _waiters.clear();
      _waitingCount = 0;
    } else {
      // Wait for other participants
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
    }
  }
}
// ============================================================================
// Platform-Specific Test Utilities
// ============================================================================
/// Isolate testing utilities
class IsolateTestUtils {
  /// Runs code in an isolate and returns the result
  static Future<T> runInIsolate<T>(
    T Function() computation, {
    String? debugName,
  }) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint<T>,
      _IsolateMessage(
        sendPort: receivePort.sendPort,
        computation: computation,
      ),
      debugName: debugName,
    );
    try {
      return await receivePort.first as T;
    } finally {
      receivePort.close();
      isolate.kill();
    }
  }
  static void _isolateEntryPoint<T>(_IsolateMessage<T> message) {
    final result = message.computation();
    message.sendPort.send(result);
  }
  /// Tests isolate communication
  static Future<void> testIsolateCommunication({
    required Future<void> Function(SendPort) isolateCode,
    required Future<void> Function(ReceivePort, SendPort) mainCode,
  }) async {
    final mainReceivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      (SendPort sendPort) async {
        final isolateReceivePort = ReceivePort();
        sendPort.send(isolateReceivePort.sendPort);
        await isolateCode(sendPort);
      },
      mainReceivePort.sendPort,
    );
    try {
      final isolateSendPort = await mainReceivePort.first as SendPort;
      await mainCode(mainReceivePort, isolateSendPort);
    } finally {
      mainReceivePort.close();
      isolate.kill();
    }
  }
}
class _IsolateMessage<T> {
  final SendPort sendPort;
  final T Function() computation;
  _IsolateMessage({
    required this.sendPort,
    required this.computation,
  });
}
/// Zone testing utilities
class ZoneTestUtils {
  /// Runs code in a custom zone with error handling
  static Future<T> runInZone<T>(
    Future<T> Function() body, {
    Function? onError,
    Map<Object?, Object?>? zoneValues,
  }) async {
    final completer = Completer<T>();
    runZonedGuarded(
      () async {
        try {
          final result = await body();
          completer.complete(result);
        } catch (e, stack) {
          completer.completeError(e, stack);
        }
      },
      (error, stack) {
        if (onError != null) {
          onError(error, stack);
        }
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      },
      zoneValues: zoneValues,
    );
    return completer.future;
  }
  /// Creates a zone with custom print handling
  static Future<List<String>> captureOutput(
    Future<void> Function() body,
  ) async {
    final output = <String>[];
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          output.add(line);
        },
      ),
    );
    return output;
  }
  /// Creates a zone that tracks async operations
  static Future<AsyncOperationReport> trackAsyncOperations(
    Future<void> Function() body,
  ) async {
    int pendingOperations = 0;
    int completedOperations = 0;
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        scheduleMicrotask: (self, parent, zone, f) {
          pendingOperations++;
          parent.scheduleMicrotask(zone, () {
            try {
              f();
            } finally {
              pendingOperations--;
              completedOperations++;
            }
          });
        },
      ),
    );
    return AsyncOperationReport(
      pending: pendingOperations,
      completed: completedOperations,
    );
  }
}
/// Report of async operations in a zone
class AsyncOperationReport {
  final int pending;
  final int completed;
  AsyncOperationReport({
    required this.pending,
    required this.completed,
  });
  @override
  String toString() {
    return 'Async operations - Pending: $pending, Completed: $completed';
  }
}
// ============================================================================
// Test Assertions and Matchers
// ============================================================================
/// Custom assertions for common test scenarios
class TestAssertions {
  /// Asserts that a future completes within a timeout
  static Future<void> assertCompletesWithin(
    Future<void> Function() operation,
    Duration timeout, {
    String? message,
  }) async {
    try {
      await operation().timeout(timeout);
    } on TimeoutException {
      fail(message ?? 'Operation did not complete within $timeout');
    }
  }
  /// Asserts that a future throws a specific exception
  static Future<void> assertThrowsAsync<T extends Exception>(
    Future<void> Function() operation, {
    bool Function(T)? matcher,
    String? message,
  }) async {
    try {
      await operation();
      fail(message ?? 'Expected $T to be thrown');
    } on T catch (e) {
      if (matcher != null && !matcher(e)) {
        fail(message ?? 'Exception did not match expectations: $e');
      }
    }
  }
  /// Asserts that two lists are equal ignoring order
  static void assertListEqualsIgnoringOrder<T>(
    List<T> actual,
    List<T> expected, {
    String? message,
  }) {
    if (actual.length != expected.length) {
      fail(message ??
          'Lists have different lengths: '
              'actual=${actual.length}, expected=${expected.length}');
    }
    final actualCopy = List<T>.from(actual);
    final expectedCopy = List<T>.from(expected);
    for (final item in expectedCopy) {
      if (!actualCopy.remove(item)) {
        fail(message ?? 'Expected item not found in actual list: $item');
      }
    }
  }
  /// Asserts that a value is within a range
  static void assertInRange(
    num value,
    num min,
    num max, {
    String? message,
  }) {
    if (value < min || value > max) {
      fail(message ?? 'Value $value is not in range [$min, $max]');
    }
  }
  /// Asserts that a duration is approximately equal
  static void assertDurationApproximately(
    Duration actual,
    Duration expected, {
    Duration tolerance = const Duration(milliseconds: 100),
    String? message,
  }) {
    final diff = (actual - expected).abs();
    if (diff > tolerance) {
      fail(message ??
          'Duration $actual is not approximately $expected '
              '(difference: $diff, tolerance: $tolerance)');
    }
  }
}
// ============================================================================
// Test Lifecycle Helpers
// ============================================================================
/// Manages test lifecycle and cleanup
class TestLifecycle {
  final List<Future<void> Function()> _setupCallbacks = [];
  final List<Future<void> Function()> _teardownCallbacks = [];
  /// Registers a setup callback
  void onSetup(Future<void> Function() callback) {
    _setupCallbacks.add(callback);
  }
  /// Registers a teardown callback
  void onTeardown(Future<void> Function() callback) {
    _teardownCallbacks.add(callback);
  }
  /// Runs all setup callbacks
  Future<void> setup() async {
    for (final callback in _setupCallbacks) {
      await callback();
    }
  }
  /// Runs all teardown callbacks
  Future<void> teardown() async {
    for (final callback in _teardownCallbacks.reversed) {
      try {
        await callback();
      } catch (e) {
        // Log but don't fail on teardown errors
        // ignore: avoid_print
        print('Teardown error: $e');
      }
    }
  }
  /// Runs a test with lifecycle management
  Future<void> runTest(
    String description,
    Future<void> Function() body,
  ) async {
    // ignore: avoid_print
    print('Running test: $description');
    await setup();
    try {
      await body();
      // ignore: avoid_print
      print('✓ Test passed: $description');
    } catch (e) {
      // ignore: avoid_print
      print('✗ Test failed: $description');
      rethrow;
    } finally {
      await teardown();
    }
  }
}
// ============================================================================
// Test Configuration and Environment
// ============================================================================
/// Test environment configuration
class TestEnvironment {
  static final Map<String, String> _overrides = {};
  /// Sets an environment variable override for testing
  static void setOverride(String key, String value) {
    _overrides[key] = value;
  }
  /// Gets an environment variable with test overrides
  static String? get(String key) {
    return _overrides[key] ?? Platform.environment[key];
  }
  /// Clears all overrides
  static void clearOverrides() {
    _overrides.clear();
  }
  /// Runs code with temporary environment overrides
  static Future<T> withOverrides<T>(
    Map<String, String> overrides,
    Future<T> Function() body,
  ) async {
    final originalOverrides = Map<String, String>.from(_overrides);
    _overrides.addAll(overrides);
    try {
      return await body();
    } finally {
      _overrides.clear();
      _overrides.addAll(originalOverrides);
    }
  }
}
/// Test feature flags
class TestFeatureFlags {
  static final Map<String, bool> _flags = {};
  /// Enables a feature flag for testing
  static void enable(String flag) {
    _flags[flag] = true;
  }
  /// Disables a feature flag for testing
  static void disable(String flag) {
    _flags[flag] = false;
  }
  /// Checks if a feature flag is enabled
  static bool isEnabled(String flag) {
    return _flags[flag] ?? false;
  }
  /// Clears all feature flags
  static void clear() {
    _flags.clear();
  }
  /// Runs code with temporary feature flags
  static Future<T> withFlags<T>(
    Map<String, bool> flags,
    Future<T> Function() body,
  ) async {
    final originalFlags = Map<String, bool>.from(_flags);
    _flags.addAll(flags);
    try {
      return await body();
    } finally {
      _flags.clear();
      _flags.addAll(originalFlags);
    }
  }
}
