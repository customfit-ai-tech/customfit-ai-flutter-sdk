// test/stress/logging/remote_logger_stress_test.dart
// Stress tests for remote logging performance under high load.
// Tests high-frequency logging and large metadata handling.
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/logging/remote_logger.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import '../../test_config.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Remote Logger Stress Tests', () {
    late RemoteLogger remoteLogger;
    late CFConfig baseConfig;
    setUp(() {
      TestConfig.setupTestLogger(); // Enable logger for coverage
      remoteLogger = RemoteLogger.instance;
      baseConfig = CFConfig.builder('test_key')
          .setRemoteLoggingEnabled(true)
          .setRemoteLogProvider('console_only')
          .build()
          .getOrThrow();
    });
    tearDown(() async {
      await remoteLogger.shutdown();
    });
    group('High-Frequency Logging Stress', () {
      test('should handle high-frequency logging under stress', () {
        final config = CFConfig.builder(baseConfig.clientKey)
            .setRemoteLoggingEnabled(true)
            .setRemoteLogProvider('logtail')
            .setRemoteLogBatchSize(1000)
            .build()
            .getOrThrow();
        remoteLogger.configure(config);
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          remoteLogger.log(RemoteLogLevel.info, 'stress_test_$i');
        }
        stopwatch.stop();
        // Should complete reasonably quickly (less than 1 second for 1000 logs)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
      test('should handle large metadata efficiently under stress', () {
        final config = CFConfig.builder(baseConfig.clientKey)
            .setRemoteLoggingEnabled(true)
            .setRemoteLogProvider('console_only')
            .build()
            .getOrThrow();
        remoteLogger.configure(config);
        final largeMetadata = <String, dynamic>{};
        for (int i = 0; i < 100; i++) {
          largeMetadata['key_$i'] = 'value_$i' * 100; // Large string values
        }
        final stopwatch = Stopwatch()..start();
        remoteLogger.log(
            RemoteLogLevel.info, 'large_metadata_stress_test', largeMetadata);
        stopwatch.stop();
        // Should handle large metadata reasonably quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });
  });
}
