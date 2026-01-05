// test/unit/features/graceful_degradation_test.dart
//
// Tests for graceful degradation feature flag system
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/features/graceful_degradation.dart';
import 'package:customfit_ai_flutter_sdk/src/core/error/cf_result.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    PreferencesService.reset();
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group('GracefulDegradationConfig', () {
    test('should create default configuration', () {
      const config = GracefulDegradationConfig();

      expect(config.defaultStrategy, FallbackStrategy.useCachedOrDefault);
      expect(config.networkTimeout, const Duration(seconds: 5));
      expect(config.enableCaching, isTrue);
      expect(config.trackMetrics, isTrue);
      expect(config.emitWarnings, isTrue);
      expect(config.cacheMaxAge, const Duration(hours: 24));
    });

    test('should create production configuration', () {
      final config = GracefulDegradationConfig.production();

      expect(config.defaultStrategy, FallbackStrategy.useCachedOrDefault);
      expect(config.networkTimeout, const Duration(seconds: 3));
      expect(config.enableCaching, isTrue);
      expect(config.trackMetrics, isTrue);
      expect(config.emitWarnings, isFalse);
      expect(config.cacheMaxAge, const Duration(days: 7));
    });

    test('should create development configuration', () {
      final config = GracefulDegradationConfig.development();

      expect(config.defaultStrategy, FallbackStrategy.waitWithTimeout);
      expect(config.networkTimeout, const Duration(seconds: 10));
      expect(config.enableCaching, isTrue);
      expect(config.trackMetrics, isTrue);
      expect(config.emitWarnings, isTrue);
      expect(config.cacheMaxAge, const Duration(hours: 1));
    });
  });

  group('FallbackMetrics', () {
    test('should track metrics correctly', () {
      final metrics = FallbackMetrics();

      expect(metrics.totalEvaluations, 0);
      expect(metrics.successfulEvaluations, 0);
      expect(metrics.fallbacksUsed, 0);
      expect(metrics.cacheHits, 0);
      expect(metrics.networkFailures, 0);
      expect(metrics.successRate, 1.0);
      expect(metrics.fallbackRate, 0.0);
      expect(metrics.cacheHitRate, 0.0);
    });

    test('should calculate rates correctly', () {
      final metrics = FallbackMetrics();

      metrics.totalEvaluations = 100;
      metrics.successfulEvaluations = 80;
      metrics.fallbacksUsed = 15;
      metrics.cacheHits = 30;

      expect(metrics.successRate, 0.8);
      expect(metrics.fallbackRate, 0.15);
      expect(metrics.cacheHitRate, 0.3);
    });

    test('should convert to JSON correctly', () {
      final metrics = FallbackMetrics();

      metrics.totalEvaluations = 10;
      metrics.successfulEvaluations = 8;
      metrics.fallbacksUsed = 2;
      metrics.cacheHits = 3;
      metrics.networkFailures = 1;
      metrics.fallbacksByFlag['test_flag'] = 2;

      final json = metrics.toJson();

      expect(json['totalEvaluations'], 10);
      expect(json['successfulEvaluations'], 8);
      expect(json['fallbacksUsed'], 2);
      expect(json['cacheHits'], 3);
      expect(json['networkFailures'], 1);
      expect(json['successRate'], 0.8);
      expect(json['fallbackRate'], 0.2);
      expect(json['cacheHitRate'], 0.3);
      expect(json['topFallbackFlags'], isA<List>());
    });
  });

  group('GracefulDegradation', () {
    late GracefulDegradation degradation;

    setUp(() {
      degradation = GracefulDegradation(
        config: const GracefulDegradationConfig(
          networkTimeout: Duration(milliseconds: 100),
          enableCaching: true,
          emitWarnings: false,
        ),
      );
    });

    group('evaluateWithFallback', () {
      test('should return successful evaluation', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'test_flag',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('success_value'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 'success_value');
        expect(degradation.metrics.totalEvaluations, 1);
        expect(degradation.metrics.successfulEvaluations, 1);
        expect(degradation.metrics.fallbacksUsed, 0);
      });

      test('should use default strategy on failure', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'test_flag',
          defaultValue: 'default',
          evaluator: () async => CFResult.error('evaluation failed'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 'default');
        expect(degradation.metrics.totalEvaluations, 1);
        expect(degradation.metrics.successfulEvaluations, 0);
        expect(degradation.metrics.fallbacksUsed, 1);
      });

      test('should use specified strategy', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'test_flag',
          defaultValue: 'default',
          evaluator: () async => CFResult.error('evaluation failed'),
          strategy: FallbackStrategy.useDefault,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 'default');
      });

      test('should handle timeout strategy', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'test_flag',
          defaultValue: 'default',
          evaluator: () async {
            await Future.delayed(const Duration(milliseconds: 200));
            return CFResult.success('slow_value');
          },
          strategy: FallbackStrategy.waitWithTimeout,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 'default');
        expect(degradation.metrics.networkFailures, 1);
      });

      test('should handle exception in evaluator', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'test_flag',
          defaultValue: 'default',
          evaluator: () async => throw Exception('test exception'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 'default');
        expect(degradation.metrics.fallbacksUsed, 1);
      });
    });

    group('caching', () {
      test('should cache successful evaluations', () async {
        // First evaluation - should cache
        await degradation.evaluateWithFallback<String>(
          key: 'cached_flag',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('cached_value'),
          strategy: FallbackStrategy.useCachedOrDefault,
        );

        // Second evaluation - should use cache when evaluator fails
        final result = await degradation.evaluateWithFallback<String>(
          key: 'cached_flag',
          defaultValue: 'default',
          evaluator: () async => CFResult.error('network error'),
          strategy: FallbackStrategy.useCachedOrDefault,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 'cached_value');
        expect(degradation.metrics.cacheHits, 1);
      });

      test('should clear cache correctly', () async {
        // Cache a value
        await degradation.evaluateWithFallback<String>(
          key: 'test_flag',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('cached_value'),
        );

        // Clear cache
        await degradation.clearCache();

        // Verify cache is cleared
        final stats = await degradation.getCacheStats();
        expect(stats['totalKeys'], 0);
      });

      test('should clear specific flag cache', () async {
        // Cache multiple flags
        await degradation.evaluateWithFallback<String>(
          key: 'flag1',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('value1'),
        );

        await degradation.evaluateWithFallback<String>(
          key: 'flag2',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('value2'),
        );

        // Clear specific flag
        await degradation.clearFlagCache('flag1');

        // Verify only one flag is cleared
        final stats = await degradation.getCacheStats();
        expect(stats['totalKeys'], 1);
      });

      test('should get cache statistics', () async {
        // Cache some values
        await degradation.evaluateWithFallback<String>(
          key: 'flag1',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('value1'),
        );

        final stats = await degradation.getCacheStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['totalKeys'], isA<int>());
        expect(stats['validCacheCount'], isA<int>());
        expect(stats['staleCacheCount'], isA<int>());
        expect(stats['cacheHitRate'], isA<double>());
      });
    });

    group('last known good strategy', () {
      test('should use last known good value', () async {
        // First successful evaluation
        await degradation.evaluateWithFallback<String>(
          key: 'lkg_flag',
          defaultValue: 'default',
          evaluator: () async => CFResult.success('good_value'),
          strategy: FallbackStrategy.useLastKnownGood,
        );

        // Second evaluation fails - should use last known good
        final result = await degradation.evaluateWithFallback<String>(
          key: 'lkg_flag',
          defaultValue: 'default',
          evaluator: () async => CFResult.error('network error'),
          strategy: FallbackStrategy.useLastKnownGood,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 'good_value');
      });

      test('should fall back to default when no last known good', () async {
        final result = await degradation.evaluateWithFallback<String>(
          key: 'new_flag',
          defaultValue: 'default',
          evaluator: () async => CFResult.error('network error'),
          strategy: FallbackStrategy.useLastKnownGood,
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 'default');
        expect(degradation.metrics.fallbacksUsed, 1);
      });
    });

    group('type support', () {
      test('should handle boolean values', () async {
        final result = await degradation.evaluateWithFallback<bool>(
          key: 'bool_flag',
          defaultValue: false,
          evaluator: () async => CFResult.success(true),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), isTrue);
      });

      test('should handle number values', () async {
        final result = await degradation.evaluateWithFallback<double>(
          key: 'number_flag',
          defaultValue: 0.0,
          evaluator: () async => CFResult.success(42.5),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 42.5);
      });

      test('should handle JSON values', () async {
        final testData = {'key': 'value', 'number': 42};
        final result =
            await degradation.evaluateWithFallback<Map<String, dynamic>>(
          key: 'json_flag',
          defaultValue: {},
          evaluator: () async => CFResult.success(testData),
        );

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), testData);
      });
    });

    test('should get degradation summary', () {
      final summary = degradation.getDegradationSummary();

      expect(summary, isA<Map<String, dynamic>>());
      expect(summary['metrics'], isA<Map<String, dynamic>>());
      expect(summary['config'], isA<Map<String, dynamic>>());
      expect(summary['config']['strategy'], isA<String>());
      expect(summary['config']['networkTimeout'], isA<int>());
      expect(summary['config']['caching'], isA<bool>());
    });
  });

  group('FallbackStrategy enum', () {
    test('should have all expected strategies', () {
      expect(FallbackStrategy.values.length, 4);
      expect(FallbackStrategy.values, contains(FallbackStrategy.useDefault));
      expect(FallbackStrategy.values,
          contains(FallbackStrategy.useCachedOrDefault));
      expect(
          FallbackStrategy.values, contains(FallbackStrategy.waitWithTimeout));
      expect(
          FallbackStrategy.values, contains(FallbackStrategy.useLastKnownGood));
    });
  });
}
