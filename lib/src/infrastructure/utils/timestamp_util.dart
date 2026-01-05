/// Utility class for timestamp formatting operations
class TimestampUtil {
  /// Format timestamp to match backend API expectations: "yyyy-MM-dd HH:mm:ss.SSSX"
  ///
  /// This method formats a DateTime object to a string representation that matches
  /// the backend's expected timestamp format with millisecond precision and UTC timezone.
  ///
  /// Example output: "2024-01-15 14:30:25.123Z"
  static String formatForAPI(DateTime dateTime) {
    final utc = dateTime.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    final millisecond = utc.millisecond.toString().padLeft(3, '0');

    return '$year-$month-$day $hour:$minute:$second.${millisecond}Z';
  }

  /// Format timestamp for use in filenames (removes special characters)
  ///
  /// This method formats a DateTime object to a string that is safe for use
  /// in filenames by removing colons, dashes, and dots.
  ///
  /// Example output: "20240115T143025"
  static String formatForFilename(DateTime timestamp) {
    return timestamp
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')[0];
  }
}
