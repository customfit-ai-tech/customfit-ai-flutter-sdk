// lib/src/core/util/string_optimizer.dart
//
// String optimization utilities for the CustomFit SDK.
// Simplified implementation using Dart's built-in capabilities.
//
// This file is part of the CustomFit SDK for Flutter.

/// String optimization utilities for better performance
class StringOptimizer {
  /// Efficiently build a string from multiple parts using StringBuffer
  ///
  /// ## Parameters
  ///
  /// - [parts]: The string parts to concatenate
  /// - [separator]: Optional separator between parts (default: empty)
  /// - [initialCapacity]: Initial buffer capacity for optimization (ignored)
  ///
  /// ## Returns
  ///
  /// The concatenated string
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = StringOptimizer.build([part1, part2, part3]);
  /// final csv = StringOptimizer.build(['a', 'b', 'c'], separator: ',');
  /// ```
  static String build(
    List<String> parts, {
    String separator = '',
    int? initialCapacity,
  }) {
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return parts.join(separator);
  }

  /// Efficiently format a string with multiple interpolations
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
  /// ## Parameters
  ///
  /// - [parts]: The strings to join
  /// - [delimiter]: The delimiter to use between parts
  /// - [useCache]: Whether to cache the result (ignored - no caching)
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
    return parts.join(delimiter);
  }

  /// Build URL paths efficiently
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

    final cleanSegments = segments
        .map((segment) => segment.replaceAll(RegExp(r'^/+|/+$'), ''))
        .toList();

    final path = cleanSegments.join('/');
    return leadingSlash ? '/$path' : path;
  }

  /// Build query strings efficiently
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

    return parameters.entries.map((entry) {
      final key = entry.key;
      final value = entry.value?.toString() ?? '';
      final encodedValue = encodeValues ? Uri.encodeComponent(value) : value;
      return '$key=$encodedValue';
    }).join('&');
  }

  /// Build log messages efficiently
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
    final parts = <String>[];

    if (includeTimestamp) {
      parts.add(DateTime.now().toIso8601String());
    }

    parts.add('[$level]');

    if (source != null && source.isNotEmpty) {
      parts.add('[$source]');
    }

    parts.add(message);

    return parts.join(' ');
  }

  /// Efficiently check if a string is null or empty
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

  /// Clear the string cache (no-op in simplified version)
  ///
  /// ## Example
  ///
  /// ```dart
  /// StringOptimizer.clearCache();
  /// ```
  static void clearCache() {
    // No-op - no caching in simplified version
  }

  /// Get cache statistics (returns empty stats in simplified version)
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
      'size': 0,
      'max_size': 0,
      'keys': <String>[],
    };
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
  final StringBuffer _buffer = StringBuffer();

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
