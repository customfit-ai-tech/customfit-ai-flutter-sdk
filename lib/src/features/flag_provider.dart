import 'dart:async';

/// Interface for providing feature flag values
abstract class FlagProvider {
  /// Get a feature flag value by key
  dynamic getFlag(String key);

  /// Get all available flags
  Map<String, dynamic> getAllFlags();

  /// Check if a flag exists
  bool flagExists(String key);

  /// Stream of flag changes for a specific key
  Stream<dynamic> flagChanges(String key);

  /// Dispose of any resources
  Future<void> dispose();
}
