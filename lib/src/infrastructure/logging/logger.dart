import 'dart:convert';
import 'dart:developer' as developer;
import 'remote_logger.dart';
import '../../config/core/cf_config.dart';

enum LogLevel {
  trace(0),
  debug(1),
  info(2),
  warning(3),
  error(4);

  const LogLevel(this.value);
  final int value;
}

/// SDK logging utility class that provides clean, minimal logging
class Logger {
  /// Whether logging is enabled
  static bool enabled = true;

  /// Whether debug logging is enabled
  static bool debugEnabled = false;

  /// Whether test mode is enabled (suppresses actual logging)
  static bool testMode = false;

  /// Log prefix - short and clean
  static const String logPrefix = 'CF';

  /// Current log level - default to WARNING for production
  static LogLevel currentLevel = LogLevel.warning;

  /// Get formatted timestamp
  static String _getTimestamp() {
    final now = DateTime.now();
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');
    final seconds = now.second.toString().padLeft(2, '0');
    final milliseconds = now.millisecond.toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$milliseconds';
  }

  /// Initialize logger with remote logging configuration
  static void initialize(CFConfig config) {
    if (config.remoteLoggingEnabled) {
      RemoteLogger.instance.configure(config);
    }
  }

  /// Clean console output without emojis
  static void _directConsoleOutput(String message) {
    if (testMode) return;

    final timestamp = _getTimestamp();
    // ignore: avoid_print
    print('[$timestamp] $logPrefix $message');
  }

  /// Log a trace message (most verbose)
  static void trace(String message, [List<dynamic>? args]) {
    if (enabled && debugEnabled && currentLevel.value <= LogLevel.trace.value) {
      if (!testMode) {
        final timestamp = _getTimestamp();
        developer.log('[$timestamp] $logPrefix [TRACE] $message',
            name: logPrefix, level: 400);
        _directConsoleOutput('[TRACE] $message');
        RemoteLogger.instance.log(RemoteLogLevel.debug, message);
      }
    }
  }

  /// Log a debug message
  static void debug(String message, [List<dynamic>? args]) {
    if (enabled && debugEnabled && currentLevel.value <= LogLevel.debug.value) {
      if (!testMode) {
        final timestamp = _getTimestamp();
        developer.log('[$timestamp] $logPrefix [DEBUG] $message',
            name: logPrefix, level: 500);
        _directConsoleOutput('[DEBUG] $message');
        RemoteLogger.instance.log(RemoteLogLevel.debug, message);
      }
    }
  }

  /// Alias for debug
  static void d(String message, [List<dynamic>? args]) {
    debug(message, args);
  }

  /// Log an info message
  static void info(String message, [List<dynamic>? args]) {
    if (enabled && currentLevel.value <= LogLevel.info.value) {
      if (!testMode) {
        final timestamp = _getTimestamp();
        developer.log('[$timestamp] $logPrefix [INFO] $message',
            name: logPrefix, level: 800);
        _directConsoleOutput('[INFO] $message');
        RemoteLogger.instance.log(RemoteLogLevel.info, message);
      }
    }
  }

  /// Alias for info
  static void i(String message, [List<dynamic>? args]) {
    info(message, args);
  }

  /// Log a warning message
  static void warning(String message, [List<dynamic>? args]) {
    if (enabled && currentLevel.value <= LogLevel.warning.value) {
      if (!testMode) {
        final timestamp = _getTimestamp();
        developer.log('[$timestamp] $logPrefix [WARN] $message',
            name: logPrefix, level: 900);
        _directConsoleOutput('[WARN] $message');
        RemoteLogger.instance.log(RemoteLogLevel.warn, message);
      }
    }
  }

  /// Alias for warning
  static void w(String message, [List<dynamic>? args]) {
    warning(message, args);
  }

  /// Alias for warning (to match React Native)
  static void warn(String message, [List<dynamic>? args]) {
    warning(message, args);
  }

  /// Log an error message
  static void error(String message, [List<dynamic>? args]) {
    if (enabled) {
      if (!testMode) {
        final timestamp = _getTimestamp();
        developer.log('[$timestamp] $logPrefix [ERROR] $message',
            name: logPrefix, level: 1000);
        _directConsoleOutput('[ERROR] $message');
        RemoteLogger.instance.log(RemoteLogLevel.error, message);
      }
    }
  }

  /// Alias for error
  static void e(String message, [List<dynamic>? args]) {
    error(message, args);
  }

  /// Log an error message with exception
  static void exception(Object error, String message,
      {StackTrace? stackTrace}) {
    if (enabled) {
      if (!testMode) {
        final timestamp = _getTimestamp();
        final errorMsg =
            '[$timestamp] $message\nError: $error${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}';
        developer.log(errorMsg,
            name: logPrefix, level: 1000, error: error, stackTrace: stackTrace);
        _directConsoleOutput('[EXCEPTION] $message\nError: $error');

        if (stackTrace != null && debugEnabled) {
          // ignore: avoid_print
          print('StackTrace: $stackTrace');
        }

        RemoteLogger.instance.log(RemoteLogLevel.error, message, {
          'error': error.toString(),
          'stackTrace': stackTrace?.toString(),
        });
      }
    }
  }

  /// Shutdown remote logging
  static Future<void> shutdown() async {
    await RemoteLogger.instance.shutdown();
  }

  /// Configure logging
  static void configure({
    required bool enabled,
    required bool debugEnabled,
  }) {
    Logger.enabled = enabled;
    Logger.debugEnabled = debugEnabled;
    d('Logging configured: enabled=$enabled, debugEnabled=$debugEnabled');
  }

  /// Set log level
  static void setLevel(LogLevel level) {
    currentLevel = level;
  }

  /// Set test mode for suppressing actual logging during tests
  static void setTestMode(bool mode) {
    testMode = mode;
  }

  /// Pretty print JSON for logging
  static String prettyPrint(dynamic obj) {
    try {
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (e) {
      return obj.toString();
    }
  }

  /// Log HTTP request/response in one line
  /// Format: METHOD /path → STATUS (duration)
  static void http(String method, String path, int? status, [int? durationMs]) {
    // Extract just the path from full URL
    final shortPath = _extractPath(path);
    final duration = durationMs != null ? ' (${durationMs}ms)' : '';
    final statusStr = status != null ? ' → $status' : '';
    final message = '$method $shortPath$statusStr$duration';

    if (status != null && status >= 400) {
      w('[HTTP] $message');
    } else {
      d('[HTTP] $message');
    }
  }

  /// Extract path from URL for cleaner logging
  static String _extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.isEmpty ? '/' : uri.path;
    } catch (_) {
      return url;
    }
  }

  /// Log a network request (legacy method - use http() instead)
  static void network(String method, String url, [int? status]) {
    http(method, url, status);
  }

  /// Log a configuration update
  static void config(String message) {
    i('[CONFIG] $message');
  }

  /// Log a tracking event
  static void track(String message) {
    d('[TRACK] $message');
  }

  /// Log a summary event
  static void summary(String message) {
    d('[SUMMARY] $message');
  }
}
