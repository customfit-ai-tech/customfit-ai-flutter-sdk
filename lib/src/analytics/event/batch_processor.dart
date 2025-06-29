import 'dart:async';
import 'dart:math' as math;

import '../../core/error/cf_result.dart';
import '../../core/error/error_category.dart';
import '../../logging/logger.dart';
import 'event_data.dart';

/// Utility class for processing events in parallel batches for maximum throughput
class BatchProcessor {
  static const String _source = 'BatchProcessor';
  static const int _maxConcurrentBatches = 4;
  static const int _optimalBatchSize = 50;

  /// Process events in parallel batches for maximum throughput
  static Future<List<CFResult<T>>> processInParallel<T>(
    List<EventData> events,
    Future<CFResult<T>> Function(EventData) processor,
  ) async {
    if (events.isEmpty) return <CFResult<T>>[];

    Logger.d(
        '$_source: Processing ${events.length} events in parallel batches');

    // Split into optimal batch sizes
    final batches = _splitIntoBatches(events, _optimalBatchSize);
    final results = <CFResult<T>>[];

    Logger.d(
        '$_source: Split into ${batches.length} batches of ~$_optimalBatchSize events each');

    // Process batches in parallel with concurrency limit
    for (int i = 0; i < batches.length; i += _maxConcurrentBatches) {
      final batchSlice = batches.skip(i).take(_maxConcurrentBatches);

      Logger.d(
          '$_source: Processing batch slice ${i ~/ _maxConcurrentBatches + 1} with ${batchSlice.length} batches');

      // Process current batch slice in parallel
      final batchFutures = batchSlice.map((batch) async {
        final batchResults = <CFResult<T>>[];

        // Process events in this batch sequentially (within parallel batches)
        for (final event in batch) {
          try {
            final result = await processor(event);
            batchResults.add(result);
          } catch (e) {
            Logger.w('$_source: Error processing event ${event.eventId}: $e');
            batchResults.add(CFResult.error(
              'Failed to process event: $e',
              exception: e,
              category: ErrorCategory.internal,
            ));
          }
        }

        return batchResults;
      });

      // Wait for current batch slice to complete
      final batchResults = await Future.wait(batchFutures);

      // Flatten results
      for (final batchResult in batchResults) {
        results.addAll(batchResult);
      }
    }

    final successCount = results.where((r) => r.isSuccess).length;
    final errorCount = results.length - successCount;

    Logger.i(
        '$_source: Completed processing ${results.length} events - Success: $successCount, Errors: $errorCount');

    return results;
  }

  /// Process a list of items in parallel batches with generic type support
  static Future<List<CFResult<R>>> processItemsInParallel<T, R>(
    List<T> items,
    Future<CFResult<R>> Function(T) processor, {
    int? batchSize,
    int? maxConcurrentBatches,
  }) async {
    if (items.isEmpty) return <CFResult<R>>[];

    final effectiveBatchSize = batchSize ?? _optimalBatchSize;
    final effectiveMaxConcurrent =
        maxConcurrentBatches ?? _maxConcurrentBatches;

    Logger.d(
        '$_source: Processing ${items.length} items in parallel (batch size: $effectiveBatchSize, max concurrent: $effectiveMaxConcurrent)');

    // Split into batches
    final batches = _splitItemsIntoBatches(items, effectiveBatchSize);
    final results = <CFResult<R>>[];

    // Process batches in parallel with concurrency limit
    for (int i = 0; i < batches.length; i += effectiveMaxConcurrent) {
      final batchSlice = batches.skip(i).take(effectiveMaxConcurrent);

      // Process current batch slice in parallel
      final batchFutures = batchSlice.map((batch) async {
        final batchResults = <CFResult<R>>[];

        for (final item in batch) {
          try {
            final result = await processor(item);
            batchResults.add(result);
          } catch (e) {
            Logger.w('$_source: Error processing item: $e');
            batchResults.add(CFResult.error(
              'Failed to process item: $e',
              exception: e,
              category: ErrorCategory.internal,
            ));
          }
        }

        return batchResults;
      });

      // Wait for current batch slice to complete
      final batchResults = await Future.wait(batchFutures);

      // Flatten results
      for (final batchResult in batchResults) {
        results.addAll(batchResult);
      }
    }

    return results;
  }

  /// Split events into optimal batch sizes
  static List<List<EventData>> _splitIntoBatches(
    List<EventData> events,
    int batchSize,
  ) {
    final batches = <List<EventData>>[];

    for (int i = 0; i < events.length; i += batchSize) {
      final end = math.min(i + batchSize, events.length);
      batches.add(events.sublist(i, end));
    }

    return batches;
  }

  /// Split generic items into batches
  static List<List<T>> _splitItemsIntoBatches<T>(
    List<T> items,
    int batchSize,
  ) {
    final batches = <List<T>>[];

    for (int i = 0; i < items.length; i += batchSize) {
      final end = math.min(i + batchSize, items.length);
      batches.add(items.sublist(i, end));
    }

    return batches;
  }

  /// Calculate optimal batch size based on system conditions
  static int calculateOptimalBatchSize({
    int itemCount = 0,
    int maxBatchSize = 100,
    int minBatchSize = 10,
  }) {
    if (itemCount <= minBatchSize) return itemCount;
    if (itemCount <= maxBatchSize) return itemCount;

    // For large item counts, use square root heuristic for optimal batching
    final optimalSize = math.sqrt(itemCount).ceil();
    return math.max(minBatchSize, math.min(maxBatchSize, optimalSize));
  }

  /// Get processing statistics for monitoring
  static Map<String, dynamic> getProcessingStats() {
    return {
      'maxConcurrentBatches': _maxConcurrentBatches,
      'optimalBatchSize': _optimalBatchSize,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
