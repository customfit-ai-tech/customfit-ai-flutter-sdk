// test/shared/helpers/test_helpers.dart
//
// Common test helper utilities for the CustomFit SDK test suite.
// Provides utilities for async testing, test data generation, and
// common test patterns.
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';

/// Helper class for async test operations
class AsyncTestHelper {
  /// Wait for a condition to become true with timeout
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 50),
    String? timeoutMessage,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (!condition()) {
      if (stopwatch.elapsed > timeout) {
        throw TimeoutException(
          timeoutMessage ?? 'Condition not met within timeout',
          timeout,
        );
      }
      await Future.delayed(pollInterval);
    }
  }

  /// Run an async operation with timeout
  static Future<T> runWithTimeout<T>(
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 10),
    String? timeoutMessage,
  }) async {
    return operation().timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        timeoutMessage ?? 'Operation timed out',
        timeout,
      ),
    );
  }

  /// Wait for all futures to complete with individual timeouts
  static Future<List<T>> waitForAll<T>(
    List<Future<T>> futures, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return Future.wait(
      futures.map((f) => f.timeout(timeout)),
    );
  }

  /// Retry an operation until it succeeds
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(milliseconds: 100),
    bool Function(dynamic)? retryIf,
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          rethrow;
        }
        if (retryIf != null && !retryIf(e)) {
          rethrow;
        }
        await Future.delayed(delay * attempts);
      }
    }
    throw Exception('Retry failed after $maxAttempts attempts');
  }

  /// Create a completer that completes after a delay
  static Completer<T> delayedCompleter<T>(T value, Duration delay) {
    final completer = Completer<T>();
    Timer(delay, () => completer.complete(value));
    return completer;
  }

  /// Create a completer that errors after a delay
  static Completer<T> errorCompleter<T>(dynamic error, Duration delay) {
    final completer = Completer<T>();
    Timer(delay, () => completer.completeError(error));
    return completer;
  }
}

/// Helper for generating test data
class TestDataGenerator {
  static int _counter = 0;

  /// Generate a unique ID
  static String uniqueId([String prefix = 'test']) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
  }

  /// Generate a test user
  static CFUser generateUser({
    String? userId,
    Map<String, dynamic>? properties,
    bool anonymous = false,
  }) {
    if (anonymous) {
      final builder = CFUser.anonymousBuilder();
      _addProperties(builder, properties ?? _defaultUserProperties());
      return builder.build();
    }
    final builder = CFUser.builder(userId ?? uniqueId('user'));
    _addProperties(builder, properties ?? _defaultUserProperties());
    return builder.build();
  }

  /// Generate multiple test users
  static List<CFUser> generateUsers(
    int count, {
    String Function(int)? userIdGenerator,
    Map<String, dynamic> Function(int)? propertiesGenerator,
  }) {
    return List.generate(count, (i) {
      final userId = userIdGenerator?.call(i) ?? 'user_$i';
      final properties = propertiesGenerator?.call(i) ??
          {
            'index': i,
            'group': 'group_${i % 5}',
            'premium': i % 3 == 0,
          };
      return generateUser(userId: userId, properties: properties);
    });
  }

  /// Generate test event properties
  static Map<String, dynamic> generateEventProperties({
    String? eventType,
    int? propertyCount,
  }) {
    final properties = <String, dynamic>{
      'event_id': uniqueId('event'),
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'test',
    };
    if (eventType != null) {
      properties['type'] = eventType;
    }
    // Add random properties
    final count = propertyCount ?? 5;
    for (int i = 0; i < count; i++) {
      final key = 'prop_$i';
      properties[key] = _randomValue(i);
    }
    return properties;
  }

  /// Generate a feature flag value
  static Map<String, dynamic> generateFeatureFlag({
    required String name,
    bool enabled = true,
    dynamic value,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'name': name,
      'enabled': enabled,
      'value': value ?? _randomValue(name.length),
      'metadata': metadata ??
          {
            'created_at': DateTime.now().toIso8601String(),
            'rollout_percentage': 100,
          },
    };
  }

  /// Generate multiple feature flags
  static Map<String, dynamic> generateFeatureFlags(int count) {
    final flags = <String, dynamic>{};
    for (int i = 0; i < count; i++) {
      final name = 'feature_$i';
      flags[name] = generateFeatureFlag(
        name: name,
        enabled: i % 2 == 0,
        value: _randomValue(i),
      );
    }
    return flags;
  }

  static Map<String, dynamic> _defaultUserProperties() {
    return {
      'email': 'test@example.com',
      'plan': 'free',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  static void _addProperties(dynamic builder, Map<String, dynamic> properties) {
    properties.forEach((key, value) {
      if (value is String) {
        builder.addStringProperty(key, value);
      } else if (value is bool) {
        builder.addBooleanProperty(key, value);
      } else if (value is num) {
        builder.addNumberProperty(key, value);
      } else if (value is List || value is Map) {
        // Convert complex types to JSON string
        builder.addStringProperty(key, value.toString());
      }
    });
  }

  static dynamic _randomValue(int seed) {
    switch (seed % 6) {
      case 0:
        return true;
      case 1:
        return false;
      case 2:
        return 'string_$seed';
      case 3:
        return seed * 10;
      case 4:
        return seed / 3.14;
      case 5:
        return ['item1', 'item2', 'item3'];
      default:
        return null;
    }
  }
}

/// Memory leak detector for tests
class MemoryLeakDetector {
  final Map<String, WeakReference<Object>> _references = {};
  final List<String> _leaks = [];

  /// Track an object for leak detection
  void track(String name, Object object) {
    _references[name] = WeakReference(object);
  }

  /// Check for memory leaks
  Future<List<String>> checkLeaks() async {
    // Force garbage collection by creating pressure
    for (int i = 0; i < 5; i++) {
      List.generate(1000000, (i) => Object());
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _leaks.clear();
    _references.forEach((name, ref) {
      if (ref.target != null) {
        _leaks.add(name);
      }
    });
    return _leaks;
  }

  /// Clear all tracked references
  void clear() {
    _references.clear();
    _leaks.clear();
  }

  /// Get a report of current tracking
  Map<String, bool> getReport() {
    final report = <String, bool>{};
    _references.forEach((name, ref) {
      report[name] = ref.target != null;
    });
    return report;
  }
}

/// Test coverage analyzer
class CoverageAnalyzer {
  final Set<String> _coveredMethods = {};
  final Set<String> _allMethods = {};

  /// Register a method as existing
  void registerMethod(String className, String methodName) {
    _allMethods.add('$className.$methodName');
  }

  /// Mark a method as covered
  void markCovered(String className, String methodName) {
    final key = '$className.$methodName';
    if (_allMethods.contains(key)) {
      _coveredMethods.add(key);
    }
  }

  /// Get coverage percentage
  double getCoveragePercentage() {
    if (_allMethods.isEmpty) return 0.0;
    return (_coveredMethods.length / _allMethods.length) * 100;
  }

  /// Get uncovered methods
  Set<String> getUncoveredMethods() {
    return _allMethods.difference(_coveredMethods);
  }

  /// Generate coverage report
  Map<String, dynamic> generateReport() {
    return {
      'total_methods': _allMethods.length,
      'covered_methods': _coveredMethods.length,
      'coverage_percentage': getCoveragePercentage(),
      'uncovered_methods': getUncoveredMethods().toList()..sort(),
    };
  }
}

/// Test assertion helpers
extension TestAssertions on Object? {
  /// Assert that a future completes successfully
  Future<void> shouldComplete() async {
    if (this is Future) {
      await expectLater(this as Future, completes);
    } else {
      fail('Object is not a Future');
    }
  }

  /// Assert that a future throws an exception
  Future<void> shouldThrow<T>() async {
    if (this is Future) {
      await expectLater(this as Future, throwsA(isA<T>()));
    } else {
      fail('Object is not a Future');
    }
  }

  /// Assert that a CFResult is successful
  void shouldBeSuccess() {
    if (this is CFResult) {
      final result = this as CFResult;
      expect(result.isSuccess, isTrue,
          reason:
              'Expected success but got error: ${result.getErrorMessage()}');
    } else {
      fail('Object is not a CFResult');
    }
  }

  /// Assert that a CFResult is an error
  void shouldBeError([String? expectedMessage]) {
    if (this is CFResult) {
      final result = this as CFResult;
      expect(result.isSuccess, isFalse,
          reason: 'Expected error but got success');
      if (expectedMessage != null) {
        expect(result.getErrorMessage(), contains(expectedMessage));
      }
    } else {
      fail('Object is not a CFResult');
    }
  }
}
