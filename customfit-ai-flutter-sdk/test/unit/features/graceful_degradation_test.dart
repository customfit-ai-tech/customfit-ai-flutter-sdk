// test/unit/features/graceful_degradation_test.dart
//
// Simplified tests for GracefulDegradation after SDK simplification
// Tests basic graceful degradation functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/features/graceful_degradation.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';

void main() {
  group('GracefulDegradation (Simplified)', () {
    late GracefulDegradation degradation;

    group('Configuration Tests', () {
      test('should create with production config', () {
        final config = GracefulDegradationConfig.production();
        
        expect(config.defaultStrategy, equals(FallbackStrategy.useCachedOrDefault));
        expect(config.networkTimeout, equals(const Duration(seconds: 30)));
        expect(config.enableCaching, isTrue);
      });

      test('should create with development config', () {
        final config = GracefulDegradationConfig.development();
        
        expect(config.defaultStrategy, equals(FallbackStrategy.useCachedOrDefault));
        expect(config.networkTimeout, equals(const Duration(seconds: 10)));
        expect(config.enableCaching, isTrue);
      });

      test('should create with custom config', () {
        final config = const GracefulDegradationConfig(
          defaultStrategy: FallbackStrategy.useDefault,
          networkTimeout: Duration(seconds: 5),
          enableCaching: false,
        );
        
        expect(config.defaultStrategy, equals(FallbackStrategy.useDefault));
        expect(config.networkTimeout, equals(const Duration(seconds: 5)));
        expect(config.enableCaching, isFalse);
      });
    });

    group('Basic Evaluation Tests', () {
      setUp(() {
        degradation = GracefulDegradation(
          config: GracefulDegradationConfig.development(),
        );
      });

      test('should evaluate successfully with working operation', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'test_key',
          defaultValue: 'default_value',
          evaluator: () async => CFResult.success('success_value'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('success_value'));
      });

      test('should return default value when operation fails', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'test_key',
          defaultValue: 'default_value',
          evaluator: () async => CFResult.error('Operation failed'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('default_value'));
      });

      test('should handle timeout gracefully', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'timeout_test',
          defaultValue: 'timeout_default',
          evaluator: () async {
            await Future.delayed(const Duration(seconds: 20)); // Longer than timeout
            return CFResult.success('should_not_reach');
          },
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('timeout_default'));
      });

      test('should use cached value when available', () async {
        // First call to populate cache
        await degradation.evaluateWithFallback<String>(
          key: 'cached_key',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('cached_value'),
        );

        // Second call should use cache
        final result = await degradation.evaluateWithFallback<String>(
          key: 'cached_key',
          defaultValue: 'default',
          evaluator: () async => CFResult.error('Should not be called'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('cached_value'));
      });
    });

    group('Caching Tests', () {
      test('should respect cache disabled setting', () async {
        degradation = GracefulDegradation(
          config: const GracefulDegradationConfig(
            defaultStrategy: FallbackStrategy.useCachedOrDefault,
            networkTimeout: Duration(seconds: 10),
            enableCaching: false,
          ),
        );

        // First call
        await degradation.evaluateWithFallback<String>(
          key: 'no_cache_key',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('first_value'),
        );

        // Second call should not use cache since caching is disabled
        final result = await degradation.evaluateWithFallback<String>(
          key: 'no_cache_key',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('second_value'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('second_value'));
      });
    });

    group('Fallback Strategy Tests', () {
      test('should respect useDefault strategy', () async {
        degradation = GracefulDegradation(
          config: const GracefulDegradationConfig(
            defaultStrategy: FallbackStrategy.useDefault,
            networkTimeout: Duration(seconds: 10),
            enableCaching: true,
          ),
        );

        final result = await degradation.evaluateWithFallback<String>(
          key: 'strategy_test',
          defaultValue: 'strategy_default',
          evaluator: () async => CFResult.error('Operation failed'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('strategy_default'));
      });

      test('should respect useCachedOrDefault strategy', () async {
        degradation = GracefulDegradation(
          config: const GracefulDegradationConfig(
            defaultStrategy: FallbackStrategy.useCachedOrDefault,
            networkTimeout: Duration(seconds: 10),
            enableCaching: true,
          ),
        );

        // First populate cache
        await degradation.evaluateWithFallback<String>(
          key: 'strategy_cached',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('cached_result'),
        );

        // Then test fallback to cache
        final result = await degradation.evaluateWithFallback<String>(
          key: 'strategy_cached',
          defaultValue: 'should_not_use',
          evaluator: () async => CFResult.error('Operation failed'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('cached_result'));
      });
    });

    group('Exception Handling Tests', () {
      test('should handle synchronous exceptions in evaluator', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'exception_test',
          defaultValue: 'exception_default',
          evaluator: () async => throw Exception('Synchronous exception'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('exception_default'));
      });

      test('should handle async exceptions in evaluator', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'async_exception_test',
          defaultValue: 'async_default',
          evaluator: () async {
            await Future.delayed(const Duration(milliseconds: 10));
            throw Exception('Async exception');
          },
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('async_default'));
      });
    });
  });
}