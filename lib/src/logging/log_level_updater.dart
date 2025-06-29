import '../config/core/cf_config.dart';
import 'logger.dart';

/// Helper class to update log levels based on configuration
class LogLevelUpdater {
  /// Updates the log level based on the provided configuration
  static void updateLogLevel(CFConfig config) {
    final logEnabled = config.loggingEnabled;
    final debugLogEnabled = config.debugLoggingEnabled;

    Logger.configure(
      enabled: logEnabled,
      debugEnabled: debugLogEnabled,
    );

    // Convert the string log level to LogLevel enum and set it
    final logLevel = _parseLogLevel(config.logLevel);
    Logger.setLevel(logLevel);
  }

  /// Parse string log level to LogLevel enum
  static LogLevel _parseLogLevel(String levelString) {
    switch (levelString.toUpperCase()) {
      case 'TRACE':
        return LogLevel.trace;
      case 'DEBUG':
        return LogLevel.debug;
      case 'INFO':
        return LogLevel.info;
      case 'WARN':
      case 'WARNING':
        return LogLevel.warning;
      case 'ERROR':
        return LogLevel.error;
      default:
        return LogLevel.info; // Default fallback
    }
  }
}
