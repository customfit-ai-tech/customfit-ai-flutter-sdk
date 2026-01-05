// lib/src/core/util/json_parser.dart
//
// Simplified JSON parsing utilities for the CustomFit SDK.
// Simple wrapper around dart:convert with consistent error handling.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:convert';
import 'dart:typed_data';
import '../../core/error/cf_result.dart';

/// Simplified JSON parser using dart:convert
class JsonParser {
  /// Parse JSON string to `Map<String, dynamic>`
  ///
  /// ## Parameters
  ///
  /// - [jsonString]: The JSON string to parse
  /// - [cacheKey]: Optional cache key (ignored in simplified version)
  /// - [maxDepth]: Maximum nesting depth (ignored - dart:convert handles this)
  ///
  /// ## Returns
  ///
  /// `CFResult<Map<String, dynamic>>` containing parsed JSON or error information
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = JsonParser.parseObject('{"key": "value"}');
  /// if (result.isSuccess) {
  ///   final data = result.getOrNull()!;
  ///   print('Parsed: ${data['key']}');
  /// }
  /// ```
  static CFResult<Map<String, dynamic>> parseObject(
    String jsonString, {
    String? cacheKey,
    int maxDepth = 20,
  }) {
    try {
      final parsed = jsonDecode(jsonString);
      if (parsed is Map<String, dynamic>) {
        return CFResult.success(parsed);
      } else {
        return CFResult.error(
          'Parsed JSON is not an object',
          context: {
            'actual_type': parsed.runtimeType.toString(),
            'json_preview': jsonString.length > 100
                ? '${jsonString.substring(0, 100)}...'
                : jsonString,
          },
        );
      }
    } catch (e) {
      // Handle empty string specifically
      if (jsonString.trim().isEmpty) {
        return CFResult.error(
          'Cannot parse empty JSON string',
          exception: e,
          context: {
            'json_preview': 'empty string',
          },
        );
      }
      return CFResult.error(
        'Failed to parse JSON object: $e',
        exception: e,
        context: {
          'json_preview': jsonString.length > 100
              ? '${jsonString.substring(0, 100)}...'
              : jsonString,
        },
      );
    }
  }

  /// Parse JSON string to `List<dynamic>`
  ///
  /// ## Parameters
  ///
  /// - [jsonString]: The JSON string to parse
  /// - [cacheKey]: Optional cache key (ignored in simplified version)
  /// - [maxDepth]: Maximum nesting depth (ignored - dart:convert handles this)
  ///
  /// ## Returns
  ///
  /// `CFResult<List<dynamic>>` containing parsed JSON array or error information
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = JsonParser.parseArray('[1, 2, 3]');
  /// if (result.isSuccess) {
  ///   final array = result.getOrNull()!;
  ///   print('Array length: ${array.length}');
  /// }
  /// ```
  static CFResult<List<dynamic>> parseArray(
    String jsonString, {
    String? cacheKey,
    int maxDepth = 20,
  }) {
    try {
      final parsed = jsonDecode(jsonString);
      if (parsed is List<dynamic>) {
        return CFResult.success(parsed);
      } else {
        return CFResult.error(
          'Parsed JSON is not an array',
          context: {
            'actual_type': parsed.runtimeType.toString(),
            'json_preview': jsonString.length > 100
                ? '${jsonString.substring(0, 100)}...'
                : jsonString,
          },
        );
      }
    } catch (e) {
      return CFResult.error(
        'Failed to parse JSON array: $e',
        exception: e,
        context: {
          'json_preview': jsonString.length > 100
              ? '${jsonString.substring(0, 100)}...'
              : jsonString,
        },
      );
    }
  }

  /// Parse JSON string to any type
  ///
  /// ## Parameters
  ///
  /// - [jsonString]: The JSON string to parse
  /// - [cacheKey]: Optional cache key (ignored in simplified version)
  /// - [maxDepth]: Maximum nesting depth (ignored - dart:convert handles this)
  ///
  /// ## Returns
  ///
  /// `CFResult<dynamic>` containing parsed JSON or error information
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = JsonParser.parseAny('42');
  /// if (result.isSuccess) {
  ///   final value = result.getOrNull()!;
  ///   print('Parsed value: $value (${value.runtimeType})');
  /// }
  /// ```
  static CFResult<dynamic> parseAny(
    String jsonString, {
    String? cacheKey,
    int maxDepth = 20,
  }) {
    try {
      final parsed = jsonDecode(jsonString);
      return CFResult.success(parsed);
    } catch (e) {
      return CFResult.error(
        'Failed to parse JSON: $e',
        exception: e,
        context: {
          'json_preview': jsonString.length > 100
              ? '${jsonString.substring(0, 100)}...'
              : jsonString,
        },
      );
    }
  }

  /// Convert object to JSON string
  ///
  /// ## Parameters
  ///
  /// - [object]: The object to convert to JSON
  /// - [prettyPrint]: Whether to format the JSON with indentation (default: false)
  ///
  /// ## Returns
  ///
  /// `CFResult<String>` containing JSON string or error information
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = JsonParser.stringify({'key': 'value'});
  /// if (result.isSuccess) {
  ///   print('JSON: ${result.getOrNull()}');
  /// }
  /// ```
  static CFResult<String> stringify(
    dynamic object, {
    bool prettyPrint = false,
  }) {
    try {
      final encoder = prettyPrint
          ? const JsonEncoder.withIndent('  ')
          : const JsonEncoder();
      final jsonString = encoder.convert(object);
      return CFResult.success(jsonString);
    } catch (e) {
      return CFResult.error(
        'Failed to stringify object: $e',
        exception: e,
        context: {
          'object_type': object.runtimeType.toString(),
        },
      );
    }
  }

  /// Parse JSON from bytes with UTF-8 decoding
  ///
  /// ## Parameters
  ///
  /// - [bytes]: The bytes to decode and parse
  /// - [cacheKey]: Optional cache key (ignored in simplified version)
  /// - [maxDepth]: Maximum nesting depth (ignored - dart:convert handles this)
  ///
  /// ## Returns
  ///
  /// `CFResult<dynamic>` containing parsed JSON or error information
  ///
  /// ## Example
  ///
  /// ```dart
  /// final bytes = utf8.encode('{"key": "value"}');
  /// final result = JsonParser.parseFromBytes(bytes);
  /// if (result.isSuccess) {
  ///   print('Parsed: ${result.getOrNull()}');
  /// }
  /// ```
  static CFResult<dynamic> parseFromBytes(
    Uint8List bytes, {
    String? cacheKey,
    int maxDepth = 20,
  }) {
    try {
      final jsonString = utf8.decode(bytes);
      return parseAny(jsonString);
    } catch (e) {
      return CFResult.error(
        'Failed to decode bytes: $e',
        exception: e,
        context: {
          'bytes_length': bytes.length,
        },
      );
    }
  }

  /// Clear the JSON parsing cache (no-op in simplified version)
  ///
  /// ## Example
  ///
  /// ```dart
  /// JsonParser.clearCache();
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
  /// final stats = JsonParser.getCacheStats();
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
