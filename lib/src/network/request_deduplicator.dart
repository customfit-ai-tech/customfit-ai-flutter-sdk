import 'dart:async';
import '../logging/logger.dart';
import '../core/error/cf_result.dart';

/// Request deduplicator to prevent duplicate concurrent requests
/// When multiple components request the same resource, only one actual request is made
class RequestDeduplicator {
  /// In-flight requests by key
  final Map<String, Future<CFResult<dynamic>>> _inFlightRequests = {};

  /// Execute a request with deduplication
  /// If an identical request is already in progress, returns the same result
  ///
  /// [key] Unique key for the request (e.g., URL + params)
  /// [request] The actual request to execute
  /// Returns result of the request
  Future<CFResult<T>> execute<T>(
    String key,
    Future<CFResult<T>> Function() request,
  ) async {
    // Check if there's already an in-flight request
    final existingRequest = _inFlightRequests[key];
    if (existingRequest != null) {
      // Silent - request deduplication is working as expected
      try {
        final result = await existingRequest;
        return result as CFResult<T>;
      } catch (e) {
        Logger.e('Error waiting for deduplicated request: $key - $e');
        return CFResult.error(
          'Failed to get deduplicated result',
          exception: e,
        );
      }
    }

    // No in-flight request, create a new one
    // Silent - starting new request is normal behavior

    // Create a completer to handle the request
    final completer = Completer<CFResult<dynamic>>();
    _inFlightRequests[key] = completer.future;

    try {
      final result = await request();
      completer.complete(result);

      // Remove from in-flight map when done
      _inFlightRequests.remove(key);

      return result;
    } catch (e) {
      // Remove from in-flight map on error
      _inFlightRequests.remove(key);

      Logger.e('Error executing request: $key - $e');
      final errorResult = CFResult<T>.error(
        'Request failed: $e',
        exception: e,
      );
      completer.complete(errorResult);
      return errorResult;
    }
  }

  /// Cancel all in-flight requests
  void cancelAll() {
    _inFlightRequests.clear();
    // Silent - cancellation complete
  }

  /// Get count of in-flight requests
  int get inFlightCount => _inFlightRequests.length;
}

/// Request coalescer to batch multiple requests within a time window
class RequestCoalescer<T> {
  /// Time window for coalescing in milliseconds
  final int windowMs;

  /// Maximum batch size
  final int maxBatchSize;

  /// Pending requests
  final List<Completer<CFResult<T>>> _pendingRequests = [];

  /// Coalescing timer
  Timer? _coalescingTimer;

  /// Create a request coalescer
  /// [windowMs] Time window for coalescing in milliseconds (default: 100)
  /// [maxBatchSize] Maximum batch size (default: 10)
  RequestCoalescer({
    this.windowMs = 100,
    this.maxBatchSize = 10,
  });

  /// Add a request to be coalesced
  /// [executor] Function to execute the batch of requests
  /// Returns result of the request
  Future<CFResult<T>> coalesce(
    Future<CFResult<T>> Function(int batchSize) executor,
  ) async {
    final completer = Completer<CFResult<T>>();

    _pendingRequests.add(completer);

    // If we hit max batch size, execute immediately
    if (_pendingRequests.length >= maxBatchSize) {
      _executeAndClear(executor);
      return completer.future;
    }

    // Start coalescing timer if not already running
    if (_coalescingTimer == null || !_coalescingTimer!.isActive) {
      _coalescingTimer = Timer(Duration(milliseconds: windowMs), () {
        if (_pendingRequests.isNotEmpty) {
          _executeAndClear(executor);
        }
      });
    }

    return completer.future;
  }

  /// Execute pending requests and clear the batch
  void _executeAndClear(Future<CFResult<T>> Function(int batchSize) executor) {
    final batch = List<Completer<CFResult<T>>>.from(_pendingRequests);
    _pendingRequests.clear();
    _coalescingTimer?.cancel();
    _coalescingTimer = null;

    if (batch.isEmpty) return;

    // Only log if batch size is significant
    if (batch.length > 1) {
      Logger.d('Request coalescing: Batching ${batch.length} requests');
    }

    // Execute the batch
    executor(batch.length).then((result) {
      for (final completer in batch) {
        completer.complete(result);
      }
    }).catchError((error) {
      final errorResult = CFResult<T>.error(
        'Batch execution failed',
        exception: error,
      );
      for (final completer in batch) {
        completer.complete(errorResult);
      }
    });
  }

  /// Cancel all pending requests
  void cancelAll() {
    _coalescingTimer?.cancel();
    final errorResult = CFResult<T>.error('Request cancelled');
    for (final completer in _pendingRequests) {
      completer.complete(errorResult);
    }
    _pendingRequests.clear();
  }
}
