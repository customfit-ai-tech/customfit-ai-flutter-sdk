import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/core/cf_config.dart';
import 'logger.dart';

/// Log providers supported by the remote logger
enum LogProvider {
  logtail('logtail'),
  custom('custom'),
  consoleOnly('console_only');

  final String value;
  const LogProvider(this.value);

  static LogProvider fromString(String value) {
    return LogProvider.values.firstWhere((e) => e.value == value,
        orElse: () => LogProvider.consoleOnly);
  }
}

/// Remote log levels
enum RemoteLogLevel {
  debug('debug'),
  info('info'),
  warn('warn'),
  error('error');

  final String value;
  const RemoteLogLevel(this.value);
}

/// Log entry structure
class _LogEntry {
  final String dt;
  final RemoteLogLevel level;
  final String message;
  final Map<String, dynamic>? metadata;
  final int timestamp;

  _LogEntry({
    required this.dt,
    required this.level,
    required this.message,
    this.metadata,
  }) : timestamp = DateTime.now().millisecondsSinceEpoch;
}

/// Circuit breaker states
enum _CircuitBreakerState { closed, open, halfOpen }

/// Circuit breaker for handling remote logging failures
class _CircuitBreaker {
  static const int _failureThreshold =
      3; // CFConstants.remoteLogging.circuitBreakerFailureThreshold
  static const Duration _timeout = Duration(
      hours: 1); // CFConstants.remoteLogging.circuitBreakerTimeoutHours

  _CircuitBreakerState _state = _CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  _CircuitBreaker();

  bool canExecute() {
    switch (_state) {
      case _CircuitBreakerState.closed:
        return true;
      case _CircuitBreakerState.open:
        if (_lastFailureTime != null &&
            DateTime.now().difference(_lastFailureTime!) > _timeout) {
          _state = _CircuitBreakerState.halfOpen;
          return true;
        }
        return false;
      case _CircuitBreakerState.halfOpen:
        return true;
    }
  }

  void onSuccess() {
    _failureCount = 0;
    _state = _CircuitBreakerState.closed;
  }

  void onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= _failureThreshold) {
      _state = _CircuitBreakerState.open;
    }
  }
}

/// Remote logger implementation for Flutter
class RemoteLogger {
  static RemoteLogger? _instance;
  static RemoteLogger get instance => _instance ??= RemoteLogger._();

  CFConfig? _config;
  final List<_LogEntry> _logQueue = [];
  Timer? _flushTimer;
  bool _isShuttingDown = false;
  final _circuitBreaker = _CircuitBreaker();

  RemoteLogger._();

  /// Configure remote logging
  void configure(CFConfig config) {
    try {
      _config = config;

      if (config.remoteLoggingEnabled &&
          config.remoteLogProvider != 'console_only') {
        _startFlushTimer();
        Logger.i(
            '🔗 Remote logging configured with provider: ${config.remoteLogProvider}');
      } else if (config.remoteLoggingEnabled) {
        Logger.i('📝 Console-only logging enabled');
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Log a message
  void log(RemoteLogLevel level, String message,
      [Map<String, dynamic>? metadata]) {
    try {
      final cfg = _config;
      if (cfg == null || !cfg.remoteLoggingEnabled || _isShuttingDown) return;

      // Check circuit breaker
      if (!_circuitBreaker.canExecute()) return;

      // Check log level
      if (!_shouldLog(level, cfg.remoteLogLevel)) return;

      final logEntry = _LogEntry(
        dt: DateTime.now().toUtc().toIso8601String(),
        level: level,
        message: message,
        metadata: _mergeMetadata(cfg.remoteLogMetadata, metadata),
      );

      if (cfg.remoteLogProvider == 'console_only') {
        _logToConsole(logEntry);
        return;
      }

      _logQueue.add(logEntry);

      // Flush if batch size reached
      if (_logQueue.length >= cfg.remoteLogBatchSize) {
        flush();
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Flush logs to remote service
  Future<void> flush() async {
    try {
      final cfg = _config;
      if (cfg == null ||
          !cfg.remoteLoggingEnabled ||
          _logQueue.isEmpty ||
          _isShuttingDown) {
        return;
      }

      // Check circuit breaker
      if (!_circuitBreaker.canExecute()) {
        _logQueue.clear(); // Prevent memory buildup
        return;
      }

      final logsToSend = <_LogEntry>[];
      final batchSize = cfg.remoteLogBatchSize.clamp(1, _logQueue.length);

      for (int i = 0; i < batchSize && _logQueue.isNotEmpty; i++) {
        logsToSend.add(_logQueue.removeAt(0));
      }

      if (logsToSend.isNotEmpty) {
        await _sendLogs(logsToSend, cfg);
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Shutdown remote logging
  Future<void> shutdown() async {
    try {
      _isShuttingDown = true;
      _flushTimer?.cancel();
      _flushTimer = null;

      // Final flush attempt
      await flush();

      _logQueue.clear();
      Logger.i('🔌 Remote logging shutdown complete');
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _sendLogs(List<_LogEntry> logs, CFConfig config) async {
    try {
      final endpoint = _getEndpoint(config);
      if (endpoint == null) return;

      final headers = _getHeaders(config);
      final client = http.Client();

      try {
        for (final log in logs) {
          final payload = _formatPayload(log, config);

          final response = await client
              .post(
                Uri.parse(endpoint),
                headers: headers,
                body: jsonEncode(payload),
              )
              .timeout(Duration(milliseconds: config.remoteLogTimeout));

          if (response.statusCode >= 200 && response.statusCode < 300) {
            _circuitBreaker.onSuccess();
          } else {
            _circuitBreaker.onFailure();
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _circuitBreaker.onFailure();
      // Silent fail
    }
  }

  String? _getEndpoint(CFConfig config) {
    switch (config.remoteLogProvider) {
      case 'logtail':
        return config.remoteLogEndpoint ??
            'https://in.logtail.com'; // CFConstants.remoteLogging.defaultEndpoint
      case 'custom':
        return config.remoteLogEndpoint;
      default:
        return null;
    }
  }

  Map<String, String> _getHeaders(CFConfig config) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'CustomFit-Flutter-SDK',
    };

    final apiKey = config.remoteLogApiKey;
    if (apiKey != null) {
      switch (config.remoteLogProvider) {
        case 'logtail':
        case 'custom':
          headers['Authorization'] = 'Bearer $apiKey';
          break;
      }
    }

    return headers;
  }

  Map<String, dynamic> _formatPayload(_LogEntry log, CFConfig config) {
    switch (config.remoteLogProvider) {
      case 'logtail':
        final payload = <String, dynamic>{
          'dt': log.dt,
          'level': log.level.value,
          'message': log.message,
        };

        // Add metadata fields directly to payload for Logtail
        if (log.metadata != null) {
          log.metadata!.forEach((key, value) {
            payload[key] = value;
          });
        }

        return payload;

      case 'custom':
        return {
          'timestamp': log.dt,
          'level': log.level.value,
          'message': log.message,
          'metadata': log.metadata ?? {},
        };

      default:
        return {};
    }
  }

  void _logToConsole(_LogEntry log) {
    final prefix = '[${log.dt}] [${log.level.value.toUpperCase()}]';
    final message = '$prefix ${log.message}';

    switch (log.level) {
      case RemoteLogLevel.debug:
        // ignore: avoid_print
        print('🐛 $message');
        break;
      case RemoteLogLevel.info:
        // ignore: avoid_print
        print('ℹ️ $message');
        break;
      case RemoteLogLevel.warn:
        // ignore: avoid_print
        print('⚠️ $message');
        break;
      case RemoteLogLevel.error:
        // ignore: avoid_print
        print('❌ $message');
        break;
    }

    if (log.metadata != null && log.metadata!.isNotEmpty) {
      // ignore: avoid_print
      print('   Metadata: ${log.metadata}');
    }
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();

    final intervalMs = _config?.remoteLogFlushIntervalMs ??
        30000; // CFConstants.remoteLogging.defaultFlushIntervalMs
    _flushTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => flush(),
    );
  }

  Map<String, dynamic>? _mergeMetadata(
      Map<String, dynamic>? configMetadata, Map<String, dynamic>? logMetadata) {
    if (configMetadata == null && logMetadata == null) return null;

    final merged = <String, dynamic>{};
    if (configMetadata != null) merged.addAll(configMetadata);
    if (logMetadata != null) merged.addAll(logMetadata);

    return merged.isEmpty ? null : merged;
  }

  bool _shouldLog(RemoteLogLevel level, String configLevel) {
    const levelOrder = {
      'debug': 0,
      'info': 1,
      'warn': 2,
      'error': 3,
    };

    final logLevelValue = levelOrder[level.value] ?? 0;
    final configLevelValue = levelOrder[configLevel] ?? 0;

    return logLevelValue >= configLevelValue;
  }
}
