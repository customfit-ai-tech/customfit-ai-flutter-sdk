// lib/src/core/util/string_optimizer.dart
//
// String optimization utilities for the CustomFit SDK.
// Provides efficient string operations to improve performance throughout the SDK.
// Includes optimized concatenation, formatting, and caching.
//
// This file is part of the CustomFit SDK for Flutter.

/// String optimization utilities for better performance
class StringOptimizer {
  static const int _defaultBufferSize = 256;
  static const int _maxCacheSize = 50;

  // Cache for frequently used strings
  static final Map<String, String> _cache = <String, String>{};
  static final List<String> _cacheKeys = <String>[];

  /// Efficiently build a string from multiple parts using StringBuffer
  ///
  /// This is much more efficient than string concatenation when building
  /// strings from multiple parts, especially in loops.
  ///
  /// ## Parameters
  ///
  /// - [parts]: The string parts to concatenate
  /// - [separator]: Optional separator between parts (default: empty)
  /// - [initialCapacity]: Initial buffer capacity for optimization
  ///
  /// ## Returns
  ///
  /// The concatenated string
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Instead of: result = part1 + part2 + part3;
  /// final result = StringOptimizer.build([part1, part2, part3]);
  ///
  /// // With separator
  /// final csv = StringOptimizer.build(['a', 'b', 'c'], separator: ',');
  /// ```
  static String build(
    List<String> parts, {
    String separator = '',
    int? initialCapacity,
  }) {
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;

    final buffer = StringBuffer();
    if (initialCapacity != null) {
      // Note: StringBuffer doesn't have capacity parameter in Dart
      // This is kept for API consistency if future Dart versions support it
    }

    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && separator.isNotEmpty) {
        buffer.write(separator);
      }
      buffer.write(parts[i]);
    }

    return buffer.toString();
  }

  /// Efficiently format a string with multiple interpolations
  ///
  /// This provides a more efficient way to handle complex string formatting
  /// compared to multiple string interpolations.
  ///
  /// ## Parameters
  ///
  /// - [template]: Template string with {0}, {1}, etc. placeholders
  /// - [args]: Arguments to substitute into the template
  ///
  /// ## Returns
  ///
  /// The formatted string
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Instead of: 'User $name with ID $id has $count items'
  /// final result = StringOptimizer.format(
  ///   'User {0} with ID {1} has {2} items',
  ///   [name, id, count]
  /// );
  /// ```
  static String format(String template, List<dynamic> args) {
    if (args.isEmpty) return template;

    String result = template;
    for (int i = 0; i < args.length; i++) {
      result = result.replaceAll('{$i}', args[i].toString());
    }
    return result;
  }

  /// Efficiently join strings with a delimiter
  ///
  /// Optimized version of the standard join operation with caching
  /// for frequently used patterns.
  ///
  /// ## Parameters
  ///
  /// - [parts]: The strings to join
  /// - [delimiter]: The delimiter to use between parts
  /// - [useCache]: Whether to cache the result for repeated operations
  ///
  /// ## Returns
  ///
  /// The joined string
  ///
  /// ## Example
  ///
  /// ```dart
  /// final path = StringOptimizer.join(['user', 'profile', 'data'], '/');
  /// final query = StringOptimizer.join(['name=john', 'age=25'], '&');
  /// ```
  static String join(
    List<String> parts,
    String delimiter, {
    bool useCache = false,
  }) {
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;

    // Check cache if enabled
    if (useCache) {
      final cacheKey = '${parts.join('|')}:$delimiter';
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey]!;
      }
    }

    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        buffer.write(delimiter);
      }
      buffer.write(parts[i]);
    }

    final result = buffer.toString();

    // Cache result if enabled
    if (useCache) {
      _addToCache('${parts.join('|')}:$delimiter', result);
    }

    return result;
  }

  /// Build URL paths efficiently
  ///
  /// Specialized method for building URL paths with proper separator handling.
  ///
  /// ## Parameters
  ///
  /// - [segments]: URL path segments
  /// - [leadingSlash]: Whether to add a leading slash (default: true)
  ///
  /// ## Returns
  ///
  /// The URL path string
  ///
  /// ## Example
  ///
  /// ```dart
  /// final url = StringOptimizer.buildPath(['api', 'v1', 'users']);
  /// // Result: '/api/v1/users'
  /// ```
  static String buildPath(List<String> segments, {bool leadingSlash = true}) {
    if (segments.isEmpty) return leadingSlash ? '/' : '';

    final buffer = StringBuffer();

    if (leadingSlash) {
      buffer.write('/');
    }

    for (int i = 0; i < segments.length; i++) {
      if (i > 0) {
        buffer.write('/');
      }
      // Remove leading/trailing slashes from segments
      final segment = segments[i].replaceAll(RegExp(r'^/+|/+$'), '');
      buffer.write(segment);
    }

    return buffer.toString();
  }

  /// Build query strings efficiently
  ///
  /// Optimized query string building with proper encoding.
  ///
  /// ## Parameters
  ///
  /// - [parameters]: Map of query parameters
  /// - [encodeValues]: Whether to URL-encode values (default: true)
  ///
  /// ## Returns
  ///
  /// The query string (without leading '?')
  ///
  /// ## Example
  ///
  /// ```dart
  /// final query = StringOptimizer.buildQuery({
  ///   'name': 'John Doe',
  ///   'age': '25',
  ///   'active': 'true'
  /// });
  /// // Result: 'name=John%20Doe&age=25&active=true'
  /// ```
  static String buildQuery(
    Map<String, dynamic> parameters, {
    bool encodeValues = true,
  }) {
    if (parameters.isEmpty) return '';

    final buffer = StringBuffer();
    final entries = parameters.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      if (i > 0) {
        buffer.write('&');
      }

      final key = entries[i].key;
      final value = entries[i].value?.toString() ?? '';

      buffer.write(key);
      buffer.write('=');

      if (encodeValues) {
        buffer.write(Uri.encodeComponent(value));
      } else {
        buffer.write(value);
      }
    }

    return buffer.toString();
  }

  /// Build log messages efficiently
  ///
  /// Optimized log message building with level, timestamp, and message formatting.
  ///
  /// ## Parameters
  ///
  /// - [level]: Log level
  /// - [message]: Log message
  /// - [source]: Source component (optional)
  /// - [includeTimestamp]: Whether to include timestamp (default: true)
  ///
  /// ## Returns
  ///
  /// The formatted log message
  ///
  /// ## Example
  ///
  /// ```dart
  /// final log = StringOptimizer.buildLogMessage(
  ///   'INFO',
  ///   'User authentication successful',
  ///   source: 'AuthManager'
  /// );
  /// ```
  static String buildLogMessage(
    String level,
    String message, {
    String? source,
    bool includeTimestamp = true,
  }) {
    final buffer = StringBuffer();

    if (includeTimestamp) {
      buffer.write(DateTime.now().toIso8601String());
      buffer.write(' ');
    }

    buffer.write('[');
    buffer.write(level);
    buffer.write(']');

    if (source != null && source.isNotEmpty) {
      buffer.write(' [');
      buffer.write(source);
      buffer.write(']');
    }

    buffer.write(' ');
    buffer.write(message);

    return buffer.toString();
  }

  /// Efficiently check if a string is null or empty
  ///
  /// Optimized null and empty checking with minimal allocations.
  ///
  /// ## Parameters
  ///
  /// - [value]: The string to check
  ///
  /// ## Returns
  ///
  /// True if the string is null or empty
  ///
  /// ## Example
  ///
  /// ```dart
  /// if (StringOptimizer.isNullOrEmpty(userInput)) {
  ///   // Handle empty input
  /// }
  /// ```
  static bool isNullOrEmpty(String? value) {
    return value == null || value.isEmpty;
  }

  /// Efficiently check if a string is null, empty, or whitespace
  ///
  /// Optimized null, empty, and whitespace checking.
  ///
  /// ## Parameters
  ///
  /// - [value]: The string to check
  ///
  /// ## Returns
  ///
  /// True if the string is null, empty, or contains only whitespace
  ///
  /// ## Example
  ///
  /// ```dart
  /// if (StringOptimizer.isNullOrWhitespace(userInput)) {
  ///   // Handle invalid input
  /// }
  /// ```
  static bool isNullOrWhitespace(String? value) {
    return value == null || value.trim().isEmpty;
  }

  /// Safely truncate a string to a maximum length
  ///
  /// Efficiently truncate strings with ellipsis support.
  ///
  /// ## Parameters
  ///
  /// - [value]: The string to truncate
  /// - [maxLength]: Maximum length of the result
  /// - [ellipsis]: Ellipsis string to append (default: '...')
  ///
  /// ## Returns
  ///
  /// The truncated string
  ///
  /// ## Example
  ///
  /// ```dart
  /// final short = StringOptimizer.truncate(longText, 50);
  /// ```
  static String truncate(
    String value,
    int maxLength, {
    String ellipsis = '...',
  }) {
    if (value.length <= maxLength) return value;

    final truncateLength = maxLength - ellipsis.length;
    if (truncateLength <= 0) return ellipsis;

    return value.substring(0, truncateLength) + ellipsis;
  }

  /// Clear the string cache
  ///
  /// Clears all cached strings to free memory.
  ///
  /// ## Example
  ///
  /// ```dart
  /// StringOptimizer.clearCache();
  /// ```
  static void clearCache() {
    _cache.clear();
    _cacheKeys.clear();
  }

  /// Get cache statistics
  ///
  /// Returns information about the current cache state.
  ///
  /// ## Returns
  ///
  /// Map containing cache statistics
  ///
  /// ## Example
  ///
  /// ```dart
  /// final stats = StringOptimizer.getCacheStats();
  /// print('Cache size: ${stats['size']}');
  /// ```
  static Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'max_size': _maxCacheSize,
      'keys': List<String>.from(_cacheKeys),
    };
  }

  // Private helper methods

  static void _addToCache(String key, String value) {
    // Implement LRU cache
    if (_cache.containsKey(key)) {
      // Move to end (most recently used)
      _cacheKeys.remove(key);
      _cacheKeys.add(key);
    } else {
      // Add new entry
      if (_cache.length >= _maxCacheSize) {
        // Remove oldest entry
        final oldestKey = _cacheKeys.removeAt(0);
        _cache.remove(oldestKey);
      }
      _cache[key] = value;
      _cacheKeys.add(key);
    }
  }
}

/// Extension methods for String class to add optimization shortcuts
extension StringOptimizerExtensions on String {
  /// Check if the string is null or empty (extension method)
  bool get isNullOrEmpty => StringOptimizer.isNullOrEmpty(this);

  /// Check if the string is null, empty, or whitespace (extension method)
  bool get isNullOrWhitespace => StringOptimizer.isNullOrWhitespace(this);

  /// Truncate the string to a maximum length (extension method)
  String truncate(int maxLength, {String ellipsis = '...'}) {
    return StringOptimizer.truncate(this, maxLength, ellipsis: ellipsis);
  }
}

/// Builder class for complex string operations
class StringBuilder {
  final StringBuffer _buffer;

  StringBuilder([int? initialCapacity]) : _buffer = StringBuffer();

  /// Add a string to the builder
  StringBuilder add(String value) {
    _buffer.write(value);
    return this;
  }

  /// Add a line (string + newline) to the builder
  StringBuilder addLine([String value = '']) {
    _buffer.writeln(value);
    return this;
  }

  /// Add multiple strings to the builder
  StringBuilder addAll(List<String> values) {
    for (final value in values) {
      _buffer.write(value);
    }
    return this;
  }

  /// Add a formatted string to the builder
  StringBuilder addFormat(String template, List<dynamic> args) {
    _buffer.write(StringOptimizer.format(template, args));
    return this;
  }

  /// Clear the builder
  StringBuilder clear() {
    _buffer.clear();
    return this;
  }

  /// Check if the builder is empty
  bool get isEmpty => _buffer.isEmpty;

  /// Check if the builder is not empty
  bool get isNotEmpty => _buffer.isNotEmpty;

  /// Get the current length
  int get length => _buffer.length;

  /// Build the final string
  String build() {
    return _buffer.toString();
  }

  @override
  String toString() => build();
}
