import '../core/cf_config.dart';
import '../../constants/cf_constants.dart';

/// Result of configuration validation containing status and any issues found
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Check if validation passed without any issues
  bool get isPerfect => isValid && warnings.isEmpty;

  /// Get a formatted string of all issues
  String get summary {
    final buffer = StringBuffer();
    if (errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }
    if (warnings.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    return buffer.toString();
  }
}

/// Validates CFConfig instances to ensure they meet requirements
class CFConfigValidator {
  // Client key validation
  static const _minKeyLength = 8;
  static final _keyPattern = RegExp(r'^[a-zA-Z0-9_.-]+$');

  // Timeout constraints (ms)
  static const _minTimeout = 1000;
  static const _maxTimeout = 60000;
  static const _recommendedTimeout = 10000;

  // Interval constraints (ms)
  static const _minFlushInterval = 5000;
  static const _maxFlushInterval = 300000;
  static const _recommendedFlushInterval = 30000;

  // Cache size constraints
  static const _minCacheSize = 10;
  static const _maxCacheSize = 10000;
  static const _recommendedCacheSize = 1000;

  // Retry constraints
  static const _minRetries = 0;
  static const _maxRetries = 10;

  // SDK settings interval constraints (ms)
  static const _minSdkSettingsInterval = 30000; // 30 seconds
  static const _maxSdkSettingsInterval = 86400000; // 24 hours

  /// Validate a configuration and return detailed results
  static ValidationResult validate(CFConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Client key warnings (Builder already validates format)
    final clientKey = config.clientKey;

    // Check for test/development keys
    if (clientKey.contains('test') || clientKey.contains('development')) {
      warnings.add(
          'Client key appears to be a test/development key. Use production key for release builds');
    }

    // Validate timeouts
    _validateTimeouts(config, errors, warnings);

    // Validate flush intervals
    _validateFlushIntervals(config, errors, warnings);

    // Validate cache settings
    _validateCacheSettings(config, errors, warnings);

    // Validate retry settings
    _validateRetrySettings(config, errors, warnings);

    // Validate SDK settings interval
    _validateSdkSettingsInterval(config, errors, warnings);

    // Validate feature toggles
    _validateFeatureToggles(config, errors, warnings);

    // Validate environment
    _validateEnvironment(config, errors, warnings);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate and throw if invalid
  static void validateOrThrow(CFConfig config) {
    final result = validate(config);
    if (!result.isValid) {
      throw ConfigValidationException(
        'Invalid configuration: ${result.errors.join(', ')}',
        errors: result.errors,
        warnings: result.warnings,
      );
    }
  }

  // Private validation methods

  static void _validateTimeouts(
      CFConfig config, List<String> errors, List<String> warnings) {
    // Connection timeout
    if (config.networkConnectionTimeoutMs < _minTimeout) {
      errors.add('Connection timeout too low. Minimum: ${_minTimeout}ms');
    } else if (config.networkConnectionTimeoutMs > _maxTimeout) {
      warnings.add(
          'Connection timeout very high: ${config.networkConnectionTimeoutMs}ms. This may cause poor user experience');
    }

    // Read timeout
    if (config.networkReadTimeoutMs < _minTimeout) {
      errors.add('Read timeout too low. Minimum: ${_minTimeout}ms');
    } else if (config.networkReadTimeoutMs > _maxTimeout) {
      warnings.add(
          'Read timeout very high: ${config.networkReadTimeoutMs}ms. This may cause poor user experience');
    }

    // Read timeout should be >= connection timeout
    if (config.networkReadTimeoutMs < config.networkConnectionTimeoutMs) {
      warnings.add(
          'Read timeout should be greater than or equal to connection timeout');
    }
  }

  static void _validateFlushIntervals(
      CFConfig config, List<String> errors, List<String> warnings) {
    // Events flush interval
    if (config.eventsFlushIntervalMs < _minFlushInterval) {
      warnings.add(
          'Events flush interval very low (${config.eventsFlushIntervalMs}ms). This may impact battery life and network usage');
    } else if (config.eventsFlushIntervalMs > _maxFlushInterval) {
      warnings.add(
          'Events flush interval very high (${config.eventsFlushIntervalMs}ms). Events may be delayed');
    }

    // Summaries flush interval
    if (config.summariesFlushIntervalMs < _minFlushInterval) {
      warnings.add(
          'Summaries flush interval very low (${config.summariesFlushIntervalMs}ms). This may impact battery life');
    } else if (config.summariesFlushIntervalMs > _maxFlushInterval) {
      warnings.add(
          'Summaries flush interval very high (${config.summariesFlushIntervalMs}ms). Analytics may be delayed');
    }

    // Summaries should typically flush less frequently than events
    if (config.summariesFlushIntervalMs < config.eventsFlushIntervalMs) {
      warnings.add(
          'Summaries flush interval is less than events flush interval. Consider reversing this for efficiency');
    }
  }

  static void _validateCacheSettings(
      CFConfig config, List<String> errors, List<String> warnings) {
    // Events queue size
    if (config.eventsQueueSize < _minCacheSize) {
      errors.add('Events queue size too small. Minimum: $_minCacheSize');
    } else if (config.eventsQueueSize > _maxCacheSize) {
      warnings.add(
          'Events queue size very large (${config.eventsQueueSize}). This may impact memory usage');
    }

    // Summaries queue size
    if (config.summariesQueueSize < _minCacheSize) {
      errors.add('Summaries queue size too small. Minimum: $_minCacheSize');
    } else if (config.summariesQueueSize > _maxCacheSize) {
      warnings.add(
          'Summaries queue size very large (${config.summariesQueueSize}). This may impact memory usage');
    }

    // Max stored events for offline
    if (config.maxStoredEvents < _minCacheSize) {
      errors.add('Max stored events too small. Minimum: $_minCacheSize');
    } else if (config.maxStoredEvents > _maxCacheSize) {
      warnings.add(
          'Max stored events very large (${config.maxStoredEvents}). This may impact storage');
    }
  }

  static void _validateRetrySettings(
      CFConfig config, List<String> errors, List<String> warnings) {
    if (config.maxRetryAttempts < _minRetries) {
      errors.add('Max retry attempts cannot be negative');
    } else if (config.maxRetryAttempts > _maxRetries) {
      warnings.add(
          'Max retry attempts very high (${config.maxRetryAttempts}). This may cause delays in error scenarios');
    }

    if (config.retryInitialDelayMs < 0) {
      errors.add('Retry initial delay cannot be negative');
    } else if (config.retryInitialDelayMs > 10000) {
      warnings.add(
          'Retry initial delay very high (${config.retryInitialDelayMs}ms). This may cause poor user experience');
    }

    if (config.retryMaxDelayMs < config.retryInitialDelayMs) {
      warnings.add(
          'Retry max delay should be greater than or equal to initial delay');
    }
  }

  static void _validateSdkSettingsInterval(
      CFConfig config, List<String> errors, List<String> warnings) {
    if (config.sdkSettingsCheckIntervalMs < _minSdkSettingsInterval) {
      warnings.add(
          'SDK settings check interval very frequent (${config.sdkSettingsCheckIntervalMs}ms). Minimum recommended: ${_minSdkSettingsInterval}ms');
    } else if (config.sdkSettingsCheckIntervalMs > _maxSdkSettingsInterval) {
      warnings.add(
          'SDK settings check interval very infrequent (${config.sdkSettingsCheckIntervalMs}ms). Configuration updates may be delayed');
    }
  }

  static void _validateFeatureToggles(
      CFConfig config, List<String> errors, List<String> warnings) {
    // Offline mode warnings
    if (config.offlineMode) {
      warnings.add(
          'SDK is configured to start in offline mode. Ensure this is intentional');
    }

    // Debug logging in production
    if (config.debugLoggingEnabled &&
        config.environment == CFEnvironment.production) {
      warnings.add(
          'Debug logging is enabled in production environment. This may impact performance and expose sensitive data');
    }

    // Background polling
    if (config.disableBackgroundPolling && config.offlineMode) {
      warnings.add(
          'Background polling is disabled while in offline mode. Cached data may become stale');
    }

    // Logging configuration
    if (!config.loggingEnabled && config.debugLoggingEnabled) {
      warnings.add(
          'Debug logging is enabled but general logging is disabled. Debug logs will not appear');
    }
  }

  static void _validateEnvironment(
      CFConfig config, List<String> errors, List<String> warnings) {
    // Environment is an enum so it's always valid, but we can add warnings for certain cases
    // No validation needed as CFEnvironment is an enum with only valid values

    // Optional: Add warning if using staging in what appears to be production code
    if (config.environment == CFEnvironment.staging) {
      final keyLower = config.clientKey.toLowerCase();
      if (!keyLower.contains('stage') && !keyLower.contains('test')) {
        warnings.add(
            'Using staging environment but client key does not appear to be a staging key');
      }
    }
  }
}

/// Exception thrown when configuration validation fails
class ConfigValidationException implements Exception {
  final String message;
  final List<String> errors;
  final List<String> warnings;

  ConfigValidationException(
    this.message, {
    this.errors = const [],
    this.warnings = const [],
  });

  @override
  String toString() => message;

  /// Get a detailed error message including all validation issues
  String get detailedMessage {
    final buffer = StringBuffer(message);

    if (errors.isNotEmpty) {
      buffer.writeln('\n\nValidation Errors:');
      for (final error in errors) {
        buffer.writeln('  • $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('\n\nValidation Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  • $warning');
      }
    }

    return buffer.toString();
  }
}
