import 'package:customfit_ai_flutter_sdk/src/logging/logger.dart';
import 'package:mocktail/mocktail.dart';
/// Mock Logger for testing
class MockLogger extends Mock implements Logger {}
/// Sets up the logger for testing to ensure logging lines are covered
void setupTestLogger() {
  // Override the Logger's static methods to be no-ops in tests
  // This ensures logging lines are executed but don't produce output
  Logger.setTestMode(true);
}
/// Reset logger after tests
void tearDownTestLogger() {
  Logger.setTestMode(false);
}
/// Helper to verify logger was called (if needed)
class LoggerVerifier {
  static final List<String> _debugLogs = [];
  static final List<String> _infoLogs = [];
  static final List<String> _warnLogs = [];
  static final List<String> _errorLogs = [];
  static void captureDebug(String message) => _debugLogs.add(message);
  static void captureInfo(String message) => _infoLogs.add(message);
  static void captureWarn(String message) => _warnLogs.add(message);
  static void captureError(String message) => _errorLogs.add(message);
  static void clear() {
    _debugLogs.clear();
    _infoLogs.clear();
    _warnLogs.clear();
    _errorLogs.clear();
  }
  static bool hasDebugLog(String pattern) =>
      _debugLogs.any((log) => log.contains(pattern));
  static bool hasInfoLog(String pattern) =>
      _infoLogs.any((log) => log.contains(pattern));
  static bool hasWarnLog(String pattern) =>
      _warnLogs.any((log) => log.contains(pattern));
  static bool hasErrorLog(String pattern) =>
      _errorLogs.any((log) => log.contains(pattern));
}
