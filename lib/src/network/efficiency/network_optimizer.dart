// lib/src/network/efficiency/network_optimizer.dart
//
// Network efficiency optimization system providing HTTP/2 connection pooling,
// request pipelining, bandwidth monitoring, and payload optimization.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import '../../network/http_client.dart';
import '../../core/error/cf_result.dart';
import '../../logging/logger.dart';
import '../../constants/cf_constants.dart';

/// Connection pool for efficient HTTP/2 multiplexing
class ConnectionPool {
  static const String _source = 'ConnectionPool';
  static const int _maxConnectionsPerHost =
      6; // _NetworkOptimizerConstants.maxConnectionsPerHost
  static const int _connectionTimeoutMs =
      30000; // _NetworkOptimizerConstants.connectionTimeoutMs
  static const int _idleTimeoutMs =
      60000; // _NetworkOptimizerConstants.idleTimeoutMs

  final Map<String, List<PooledConnection>> _connections = {};
  final Map<String, DateTime> _lastUsed = {};
  late final Timer _cleanupTimer;

  ConnectionPool() {
    _cleanupTimer = Timer.periodic(
        const Duration(minutes: 1),
        (timer) =>
            _cleanupIdleConnections()); // _NetworkOptimizerConstants.idleCheckIntervalMinutes
  }

  /// Get or create connection for host
  Future<PooledConnection?> getConnection(String host) async {
    final hostConnections = _connections[host] ?? [];

    // Find available connection
    for (final connection in hostConnections) {
      if (connection.isAvailable) {
        connection.markInUse();
        _lastUsed[host] = DateTime.now();
        return connection;
      }
    }

    // Create new connection if under limit
    if (hostConnections.length < _maxConnectionsPerHost) {
      try {
        final connection = await _createConnection(host);
        hostConnections.add(connection);
        _connections[host] = hostConnections;
        _lastUsed[host] = DateTime.now();

        Logger.d(
            '$_source: Created new connection to $host (${hostConnections.length}/$_maxConnectionsPerHost)');
        return connection;
      } catch (e) {
        Logger.w('$_source: Failed to create connection to $host: $e');
        return null;
      }
    }

    // Wait for available connection
    Logger.d('$_source: Waiting for available connection to $host');
    return await _waitForAvailableConnection(host);
  }

  /// Release connection back to pool
  void releaseConnection(PooledConnection connection) {
    connection.markAvailable();
    Logger.d('$_source: Released connection to ${connection.host}');
  }

  /// Close all connections
  void shutdown() {
    _cleanupTimer.cancel();

    for (final hostConnections in _connections.values) {
      for (final connection in hostConnections) {
        connection.close();
      }
    }

    _connections.clear();
    _lastUsed.clear();
    Logger.i('$_source: Connection pool shutdown complete');
  }

  Future<PooledConnection> _createConnection(String host) async {
    // Simulate connection creation
    await Future.delayed(const Duration(milliseconds: 100));
    return PooledConnection(
      host: host,
      createdAt: DateTime.now(),
      maxConcurrentStreams: 100,
    );
  }

  Future<PooledConnection?> _waitForAvailableConnection(String host) async {
    const maxWaitMs = 5000; // _NetworkOptimizerConstants.pipelineMaxWaitMs
    const checkIntervalMs =
        50; // _NetworkOptimizerConstants.pipelineCheckIntervalMs
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime).inMilliseconds < maxWaitMs) {
      final hostConnections = _connections[host] ?? [];

      for (final connection in hostConnections) {
        if (connection.isAvailable) {
          connection.markInUse();
          return connection;
        }
      }

      await Future.delayed(const Duration(milliseconds: checkIntervalMs));
    }

    Logger.w('$_source: Timeout waiting for connection to $host');
    return null;
  }

  void _cleanupIdleConnections() {
    final now = DateTime.now();
    final hostsToRemove = <String>[];

    for (final entry in _lastUsed.entries) {
      final host = entry.key;
      final lastUsed = entry.value;

      if (now.difference(lastUsed).inMilliseconds > _idleTimeoutMs) {
        final hostConnections = _connections[host] ?? [];

        // Close idle connections
        for (final connection in hostConnections) {
          if (connection.isIdle) {
            connection.close();
          }
        }

        // Remove closed connections
        hostConnections.removeWhere((c) => c.isClosed);

        if (hostConnections.isEmpty) {
          hostsToRemove.add(host);
        } else {
          _connections[host] = hostConnections;
        }
      }
    }

    // Remove empty host entries
    for (final host in hostsToRemove) {
      _connections.remove(host);
      _lastUsed.remove(host);
      Logger.d('$_source: Cleaned up idle connections for $host');
    }
  }
}

/// Individual pooled connection with stream management
class PooledConnection {
  final String host;
  final DateTime createdAt;
  final int maxConcurrentStreams;

  int _activeStreams = 0;
  bool _inUse = false;
  bool _closed = false;
  DateTime _lastActivity = DateTime.now();

  PooledConnection({
    required this.host,
    required this.createdAt,
    required this.maxConcurrentStreams,
  });

  bool get isAvailable =>
      !_inUse && !_closed && _activeStreams < maxConcurrentStreams;
  bool get isIdle =>
      !_inUse &&
      _activeStreams == 0 &&
      DateTime.now().difference(_lastActivity).inMinutes >
          5; // _NetworkOptimizerConstants.connectionIdleThresholdMinutes
  bool get isClosed => _closed;

  void markInUse() {
    _inUse = true;
    _activeStreams++;
    _lastActivity = DateTime.now();
  }

  void markAvailable() {
    _inUse = false;
    _activeStreams = max(0, _activeStreams - 1);
    _lastActivity = DateTime.now();
  }

  void close() {
    _closed = true;
    _inUse = false;
    _activeStreams = 0;
  }

  Map<String, dynamic> getStatus() {
    return {
      'host': host,
      'active_streams': _activeStreams,
      'max_streams': maxConcurrentStreams,
      'in_use': _inUse,
      'closed': _closed,
      'age_seconds': DateTime.now().difference(createdAt).inSeconds,
      'idle_seconds': DateTime.now().difference(_lastActivity).inSeconds,
    };
  }
}

/// Request pipelining manager for batching requests
class RequestPipeline {
  static const String _source = 'RequestPipeline';
  static const int _maxBatchSize =
      10; // _NetworkOptimizerConstants.maxBatchSize
  static const int _batchTimeoutMs =
      100; // _NetworkOptimizerConstants.batchTimeoutMs

  final Map<String, List<PipelinedRequest>> _pendingRequests = {};
  final Map<String, Timer> _batchTimers = {};
  final HttpClient _httpClient;

  RequestPipeline(this._httpClient);

  /// Add request to pipeline
  Future<CFResult<String>> addRequest({
    required String url,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
    int priority = 5,
  }) async {
    final completer = Completer<CFResult<String>>();
    final request = PipelinedRequest(
      url: url,
      data: data,
      headers: headers ?? {},
      priority: priority,
      completer: completer,
      timestamp: DateTime.now(),
    );

    final host = Uri.parse(url).host;
    _pendingRequests.putIfAbsent(host, () => []);
    _pendingRequests[host]!.add(request);

    // Sort by priority (higher priority first)
    _pendingRequests[host]!.sort((a, b) => b.priority.compareTo(a.priority));

    _scheduleBatch(host);

    Logger.d(
        '$_source: Queued request for $host (${_pendingRequests[host]!.length} pending)');
    return completer.future;
  }

  /// Process batched requests for host
  Future<void> processBatch(String host) async {
    final requests = _pendingRequests[host];
    if (requests == null || requests.isEmpty) return;

    final batch = requests.take(_maxBatchSize).toList();
    requests.removeRange(0, min(batch.length, requests.length));

    Logger.d(
        '$_source: Processing batch of ${batch.length} requests for $host');

    // Group by URL for potential batching
    final groupedRequests = <String, List<PipelinedRequest>>{};
    for (final request in batch) {
      groupedRequests.putIfAbsent(request.url, () => []);
      groupedRequests[request.url]!.add(request);
    }

    // Process each URL group
    final futures = <Future>[];
    for (final entry in groupedRequests.entries) {
      futures.add(_processRequestGroup(entry.key, entry.value));
    }

    await Future.wait(futures);

    // Schedule next batch if more requests pending
    if (requests.isNotEmpty) {
      _scheduleBatch(host);
    }
  }

  void shutdown() {
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();

    // Fail all pending requests
    for (final requests in _pendingRequests.values) {
      for (final request in requests) {
        request.completer.complete(CFResult.error(
          'Pipeline shutdown',
        ));
      }
    }
    _pendingRequests.clear();
  }

  void _scheduleBatch(String host) {
    _batchTimers[host]?.cancel();

    _batchTimers[host] = Timer(
      const Duration(milliseconds: _batchTimeoutMs),
      () => processBatch(host),
    );
  }

  Future<void> _processRequestGroup(
      String url, List<PipelinedRequest> requests) async {
    try {
      if (requests.length == 1) {
        // Single request
        final request = requests.first;
        final result = await _httpClient.post(
          url,
          data: jsonEncode(request.data),
          headers: request.headers,
        );
        request.completer.complete(result as CFResult<String>);
      } else {
        // Batch multiple requests
        final batchData = {
          'batch': requests.map((r) => r.data).toList(),
          'batch_metadata': {
            'count': requests.length,
            'timestamp': DateTime.now().toIso8601String(),
          },
        };

        final result = await _httpClient.post(
          url,
          data: jsonEncode(batchData),
          headers: requests.first.headers,
        );

        // Distribute result to all requests
        for (final request in requests) {
          request.completer.complete(result as CFResult<String>);
        }
      }
    } catch (e) {
      // Complete all requests with error
      for (final request in requests) {
        request.completer.complete(CFResult.error(e.toString()));
      }
    }
  }
}

/// Individual pipelined request
class PipelinedRequest {
  final String url;
  final Map<String, dynamic> data;
  final Map<String, String> headers;
  final int priority;
  final Completer<CFResult<String>> completer;
  final DateTime timestamp;

  PipelinedRequest({
    required this.url,
    required this.data,
    required this.headers,
    required this.priority,
    required this.completer,
    required this.timestamp,
  });

  int get ageMs => DateTime.now().difference(timestamp).inMilliseconds;
}

/// Bandwidth monitoring and adaptive optimization
class BandwidthMonitor {
  static const String _source = 'BandwidthMonitor';
  static const int _measurementWindow =
      30; // _NetworkOptimizerConstants.measurementWindowSeconds

  final Queue<BandwidthMeasurement> _measurements = Queue();
  double _estimatedBandwidthKbps =
      1000.0; // _NetworkOptimizerConstants.defaultBandwidthKbps (Default 1Mbps)
  DateTime _lastUpdate = DateTime.now();

  /// Record data transfer measurement
  void recordTransfer({
    required int bytesTransferred,
    required int durationMs,
    required String direction, // 'upload' or 'download'
  }) {
    final bandwidthKbps = (bytesTransferred * 8) / (durationMs * 1024);

    final measurement = BandwidthMeasurement(
      timestamp: DateTime.now(),
      bandwidthKbps: bandwidthKbps,
      direction: direction,
      bytesTransferred: bytesTransferred,
      durationMs: durationMs,
    );

    _measurements.addLast(measurement);
    _cleanOldMeasurements();
    _updateEstimate();

    Logger.d('$_source: Recorded $direction transfer: '
        '${bandwidthKbps.toStringAsFixed(0)} Kbps '
        '($bytesTransferred bytes in ${durationMs}ms)');
  }

  /// Get current bandwidth estimate
  double getCurrentBandwidthKbps() => _estimatedBandwidthKbps;

  /// Get network quality assessment
  NetworkQuality getNetworkQuality() {
    if (_estimatedBandwidthKbps >=
        CFConstants.networkOptimizer.excellentBandwidthKbps) {
      return NetworkQuality.excellent;
    }
    if (_estimatedBandwidthKbps >=
        CFConstants.networkOptimizer.goodBandwidthKbps) {
      return NetworkQuality.good;
    }
    if (_estimatedBandwidthKbps >=
        CFConstants.networkOptimizer.fairBandwidthKbps) {
      return NetworkQuality.fair;
    }
    if (_estimatedBandwidthKbps >=
        CFConstants.networkOptimizer.poorBandwidthKbps) {
      return NetworkQuality.poor;
    }
    return NetworkQuality.terrible;
  }

  /// Get adaptive configuration based on bandwidth
  AdaptiveConfig getAdaptiveConfig() {
    final quality = getNetworkQuality();

    switch (quality) {
      case NetworkQuality.excellent:
        return AdaptiveConfig(
          maxBatchSize: CFConstants.networkOptimizer.excellentMaxBatchSize,
          compressionLevel: CFConstants
              .networkOptimizer.excellentCompressionLevel, // Light compression
          requestTimeoutMs:
              CFConstants.networkOptimizer.excellentRequestTimeoutMs,
          retryIntervalMs:
              CFConstants.networkOptimizer.excellentRetryIntervalMs,
          maxConcurrentRequests:
              CFConstants.networkOptimizer.excellentMaxConcurrentRequests,
        );
      case NetworkQuality.good:
        return AdaptiveConfig(
          maxBatchSize: CFConstants.networkOptimizer.goodMaxBatchSize,
          compressionLevel: CFConstants.networkOptimizer.goodCompressionLevel,
          requestTimeoutMs: CFConstants.networkOptimizer.goodRequestTimeoutMs,
          retryIntervalMs: CFConstants.networkOptimizer.goodRetryIntervalMs,
          maxConcurrentRequests:
              CFConstants.networkOptimizer.goodMaxConcurrentRequests,
        );
      case NetworkQuality.fair:
        return AdaptiveConfig(
          maxBatchSize: CFConstants.networkOptimizer.fairMaxBatchSize,
          compressionLevel: CFConstants.networkOptimizer.fairCompressionLevel,
          requestTimeoutMs: CFConstants.networkOptimizer.fairRequestTimeoutMs,
          retryIntervalMs: CFConstants.networkOptimizer.fairRetryIntervalMs,
          maxConcurrentRequests:
              CFConstants.networkOptimizer.fairMaxConcurrentRequests,
        );
      case NetworkQuality.poor:
        return AdaptiveConfig(
          maxBatchSize: CFConstants.networkOptimizer.poorMaxBatchSize,
          compressionLevel: CFConstants.networkOptimizer.poorCompressionLevel,
          requestTimeoutMs: CFConstants.networkOptimizer.poorRequestTimeoutMs,
          retryIntervalMs: CFConstants.networkOptimizer.poorRetryIntervalMs,
          maxConcurrentRequests:
              CFConstants.networkOptimizer.poorMaxConcurrentRequests,
        );
      case NetworkQuality.terrible:
        return AdaptiveConfig(
          maxBatchSize: CFConstants.networkOptimizer.terribleMaxBatchSize,
          compressionLevel: CFConstants
              .networkOptimizer.terribleCompressionLevel, // Maximum compression
          requestTimeoutMs:
              CFConstants.networkOptimizer.terribleRequestTimeoutMs,
          retryIntervalMs: CFConstants.networkOptimizer.terribleRetryIntervalMs,
          maxConcurrentRequests:
              CFConstants.networkOptimizer.terribleMaxConcurrentRequests,
        );
    }
  }

  /// Get bandwidth statistics
  Map<String, dynamic> getStatistics() {
    if (_measurements.isEmpty) {
      return {
        'current_bandwidth_kbps': _estimatedBandwidthKbps,
        'measurement_count': 0,
        'quality': getNetworkQuality().name,
      };
    }

    final uploadMeasurements =
        _measurements.where((m) => m.direction == 'upload');
    final downloadMeasurements =
        _measurements.where((m) => m.direction == 'download');

    return {
      'current_bandwidth_kbps': _estimatedBandwidthKbps,
      'measurement_count': _measurements.length,
      'upload_measurements': uploadMeasurements.length,
      'download_measurements': downloadMeasurements.length,
      'avg_upload_kbps': uploadMeasurements.isNotEmpty
          ? uploadMeasurements
                  .map((m) => m.bandwidthKbps)
                  .reduce((a, b) => a + b) /
              uploadMeasurements.length
          : 0.0,
      'avg_download_kbps': downloadMeasurements.isNotEmpty
          ? downloadMeasurements
                  .map((m) => m.bandwidthKbps)
                  .reduce((a, b) => a + b) /
              downloadMeasurements.length
          : 0.0,
      'quality': getNetworkQuality().name,
      'last_update': _lastUpdate.toIso8601String(),
    };
  }

  void _cleanOldMeasurements() {
    final cutoff =
        DateTime.now().subtract(const Duration(seconds: _measurementWindow));

    while (_measurements.isNotEmpty &&
        _measurements.first.timestamp.isBefore(cutoff)) {
      _measurements.removeFirst();
    }
  }

  void _updateEstimate() {
    if (_measurements.isEmpty) return;

    // Use exponential weighted moving average
    final alpha = CFConstants
        .networkOptimizer.bandwidthSmoothingFactor; // Smoothing factor
    final recentMeasurements = _measurements
        .toList()
        .reversed
        .take(CFConstants.networkOptimizer.recentMeasurementsCount);

    if (recentMeasurements.isNotEmpty) {
      final recentAvg = recentMeasurements
              .map((m) => m.bandwidthKbps)
              .reduce((a, b) => a + b) /
          recentMeasurements.length;

      _estimatedBandwidthKbps =
          (alpha * recentAvg) + ((1 - alpha) * _estimatedBandwidthKbps);
      _lastUpdate = DateTime.now();
    }
  }
}

/// Individual bandwidth measurement
class BandwidthMeasurement {
  final DateTime timestamp;
  final double bandwidthKbps;
  final String direction;
  final int bytesTransferred;
  final int durationMs;

  BandwidthMeasurement({
    required this.timestamp,
    required this.bandwidthKbps,
    required this.direction,
    required this.bytesTransferred,
    required this.durationMs,
  });
}

/// Network quality levels
enum NetworkQuality {
  excellent,
  good,
  fair,
  poor,
  terrible,
}

/// Adaptive configuration based on network conditions
class AdaptiveConfig {
  final int maxBatchSize;
  final int compressionLevel;
  final int requestTimeoutMs;
  final int retryIntervalMs;
  final int maxConcurrentRequests;

  AdaptiveConfig({
    required this.maxBatchSize,
    required this.compressionLevel,
    required this.requestTimeoutMs,
    required this.retryIntervalMs,
    required this.maxConcurrentRequests,
  });

  Map<String, dynamic> toMap() {
    return {
      'max_batch_size': maxBatchSize,
      'compression_level': compressionLevel,
      'request_timeout_ms': requestTimeoutMs,
      'retry_interval_ms': retryIntervalMs,
      'max_concurrent_requests': maxConcurrentRequests,
    };
  }
}

/// Payload optimization for size reduction
class PayloadOptimizer {
  static const String _source = 'PayloadOptimizer';

  /// Optimize payload for transmission
  static Map<String, dynamic> optimizePayload(
    Map<String, dynamic> payload,
    AdaptiveConfig config,
  ) {
    var optimized = Map<String, dynamic>.from(payload);

    // Apply optimizations based on network quality
    if (config.compressionLevel >= 5) {
      optimized['_compressed'] = true;
      optimized = _compressLargeFields(optimized);
    }

    if (config.compressionLevel >= 7) {
      optimized = _removeNonEssentialFields(optimized);
    }

    if (config.compressionLevel >= 9) {
      optimized = _applyMaximumCompression(optimized);
    }

    final originalSize = jsonEncode(payload).length;
    final optimizedSize = jsonEncode(optimized).length;
    final compressionRatio = originalSize / optimizedSize;

    Logger.d(
        '$_source: Optimized payload ${originalSize}B -> ${optimizedSize}B '
        '(${compressionRatio.toStringAsFixed(2)}:1 ratio)');

    return optimized;
  }

  static Map<String, dynamic> _compressLargeFields(
      Map<String, dynamic> payload) {
    final compressed = Map<String, dynamic>.from(payload);

    compressed.forEach((key, value) {
      if (value is String &&
          value.length > CFConstants.networkOptimizer.largeStringThreshold) {
        // Simulate compression by shortening strings
        compressed[key] =
            '${value.substring(0, CFConstants.networkOptimizer.stringTruncateLength)}...[compressed]';
      } else if (value is List &&
          value.length > CFConstants.networkOptimizer.largeArrayThreshold) {
        // Limit large arrays
        compressed[key] = value
            .take(CFConstants.networkOptimizer.arrayTruncateLength)
            .toList()
          ..add('[truncated]');
      } else if (value is Map) {
        compressed[key] = _compressLargeFields(value as Map<String, dynamic>);
      }
    });

    return compressed;
  }

  static Map<String, dynamic> _removeNonEssentialFields(
      Map<String, dynamic> payload) {
    final essential = <String, dynamic>{};

    // Keep only essential fields
    const essentialKeys = {
      'id',
      'name',
      'type',
      'timestamp',
      'user_id',
      'session_id',
      'event_type',
      'properties',
      'metadata',
      'version',
      'platform'
    };

    payload.forEach((key, value) {
      if (essentialKeys.contains(key) || key.startsWith('_')) {
        if (value is Map) {
          essential[key] =
              _removeNonEssentialFields(value as Map<String, dynamic>);
        } else {
          essential[key] = value;
        }
      }
    });

    return essential;
  }

  static Map<String, dynamic> _applyMaximumCompression(
      Map<String, dynamic> payload) {
    final compressed = <String, dynamic>{};

    // Use short keys to save space
    const keyMapping = {
      'timestamp': 'ts',
      'user_id': 'uid',
      'session_id': 'sid',
      'event_type': 'et',
      'properties': 'p',
      'metadata': 'm',
      'version': 'v',
      'platform': 'pl',
    };

    payload.forEach((key, value) {
      final shortKey = keyMapping[key] ?? key;

      if (value is String) {
        // Compress common values
        if (value == 'true') {
          compressed[shortKey] = 1;
        } else if (value == 'false') {
          compressed[shortKey] = 0;
        } else {
          compressed[shortKey] = value;
        }
      } else if (value is Map) {
        compressed[shortKey] =
            _applyMaximumCompression(value as Map<String, dynamic>);
      } else {
        compressed[shortKey] = value;
      }
    });

    return compressed;
  }
}

/// Main network optimization coordinator
class NetworkOptimizer {
  static const String _source = 'NetworkOptimizer';

  final ConnectionPool _connectionPool;
  final RequestPipeline _requestPipeline;
  final BandwidthMonitor _bandwidthMonitor;
  final HttpClient _httpClient;

  NetworkOptimizer(this._httpClient)
      : _connectionPool = ConnectionPool(),
        _requestPipeline = RequestPipeline(_httpClient),
        _bandwidthMonitor = BandwidthMonitor();

  /// Optimized HTTP request with all efficiency features
  Future<CFResult<String>> optimizedRequest({
    required String url,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
    int priority = 5,
  }) async {
    final startTime = DateTime.now();
    final config = _bandwidthMonitor.getAdaptiveConfig();

    // Optimize payload based on network conditions
    final optimizedData = PayloadOptimizer.optimizePayload(data, config);
    final payloadSize = jsonEncode(optimizedData).length;

    try {
      // Use request pipelining for better efficiency
      final result = await _requestPipeline.addRequest(
        url: url,
        data: optimizedData,
        headers: headers,
        priority: priority,
      );

      final duration = DateTime.now().difference(startTime);

      // Record bandwidth measurement
      if (result.isSuccess) {
        _bandwidthMonitor.recordTransfer(
          bytesTransferred: payloadSize,
          durationMs: duration.inMilliseconds,
          direction: 'upload',
        );
      }

      Logger.d(
          '$_source: Optimized request completed in ${duration.inMilliseconds}ms '
          '($payloadSize bytes, quality: ${_bandwidthMonitor.getNetworkQuality().name})');

      return result;
    } catch (e) {
      Logger.e('$_source: Optimized request failed: $e');
      return CFResult.error('Network optimization failed: $e');
    }
  }

  /// Get current network efficiency statistics
  Map<String, dynamic> getEfficiencyStats() {
    return {
      'bandwidth': _bandwidthMonitor.getStatistics(),
      'adaptive_config': _bandwidthMonitor.getAdaptiveConfig().toMap(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Shutdown all optimization components
  void shutdown() {
    _connectionPool.shutdown();
    _requestPipeline.shutdown();
    Logger.i('$_source: Network optimizer shutdown complete');
  }
}
