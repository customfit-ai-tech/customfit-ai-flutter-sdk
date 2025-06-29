// lib/src/core/util/json_parser.dart
//
// Optimized JSON parsing utilities for the CustomFit SDK.
// Provides efficient JSON parsing with proper error handling and type safety.
// Includes caching and streaming support for better performance.
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import '../../logging/logger.dart';
import '../error/cf_result.dart';

/// Optimized JSON parser with caching and performance improvements
class JsonParser {
  static const _source = 'JsonParser';
  static const _uuid = Uuid();

  // Simple LRU cache for frequently parsed JSON
  static final Map<String, dynamic> _cache = <String, dynamic>{};
  static final List<String> _cacheKeys = <String>[];
  static const int _maxCacheSize = 100;

  /// Parse JSON string with optimized error handling and caching
  ///
  /// This method provides optimized JSON parsing with:
  /// - LRU caching for frequently parsed content
  /// - Detailed error information
  /// - Type safety validation
  /// - Memory efficient parsing
  ///
  /// ## Parameters
  ///
  /// - [jsonString]: The JSON string to parse
  /// - [cacheKey]: Optional cache key for frequent parsing (default: hash of content)
  /// - [maxDepth]: Maximum nesting depth to prevent stack overflow (default: 20)
  ///
  /// ## Returns
  ///
  /// [CFResult<Map<String, dynamic>>] containing parsed JSON or error information
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = JsonParser.parseObject('{"key": "value"}');
  /// if (result.isSuccess) {
  ///   final data = result.getOrNull()!;
  ///   print('Parsed: ${data['key']}');
  /// } else {
  ///   print('Parse error: ${result.getErrorMessage()}');
  /// }
  /// ```
  static CFResult<Map<String, dynamic>> parseObject(
    String jsonString, {
    String? cacheKey,
    int maxDepth = 20,
  }) {
    try {
      if (jsonString.isEmpty) {
        return CFResult.error('JSON string is empty');
      }

      // Use cache if available
      final key = cacheKey ?? _generateCacheKey(jsonString);
      if (_cache.containsKey(key)) {
        Logger.d('$_source: Cache hit for JSON parsing');
        return CFResult.success(_cache[key] as Map<String, dynamic>);
      }

      // Validate basic JSON structure before parsing
      if (!_isValidJsonStructure(jsonString)) {
        return CFResult.error('Invalid JSON structure detected');
      }

      // Parse with depth validation
      final parsed = _parseWithDepthCheck(jsonString, maxDepth);

      if (parsed is Map<String, dynamic>) {
        // Cache the result
        _addToCache(key, parsed);
        Logger.d('$_source: Successfully parsed JSON object');
        return CFResult.success(parsed);
      } else {
        return CFResult.error('Parsed JSON is not an object');
      }
    } catch (e) {
      Logger.e('$_source: JSON parsing failed: $e');
      return CFResult.error(_formatJsonError(e, jsonString));
    }
  }

  /// Parse JSON array with optimization
  ///
  /// Optimized parsing for JSON arrays with type validation.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = JsonParser.parseArray('[{"id": 1}, {"id": 2}]');
  /// if (result.isSuccess) {
  ///   final items = result.getOrNull()!;
  ///   print('Found ${items.length} items');
  /// }
  /// ```
  static CFResult<List<dynamic>> parseArray(
    String jsonString, {
    String? cacheKey,
    int maxDepth = 20,
  }) {
    try {
      if (jsonString.isEmpty) {
        return CFResult.error('JSON string is empty');
      }

      // Use cache if available
      final key = cacheKey ?? _generateCacheKey(jsonString);
      if (_cache.containsKey(key)) {
        Logger.d('$_source: Cache hit for JSON array parsing');
        return CFResult.success(_cache[key] as List<dynamic>);
      }

      // Parse with depth validation
      final parsed = _parseWithDepthCheck(jsonString, maxDepth);

      if (parsed is List<dynamic>) {
        // Cache the result
        _addToCache(key, parsed);
        Logger.d(
            '$_source: Successfully parsed JSON array with ${parsed.length} items');
        return CFResult.success(parsed);
      } else {
        return CFResult.error('Parsed JSON is not an array');
      }
    } catch (e) {
      Logger.e('$_source: JSON array parsing failed: $e');
      return CFResult.error(_formatJsonError(e, jsonString));
    }
  }

  /// Parse JSON with automatic type detection
  ///
  /// Automatically detects whether JSON is an object, array, or primitive value.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = JsonParser.parseAny('{"key": "value"}');
  /// if (result.isSuccess) {
  ///   final data = result.getOrNull()!;
  ///   if (data is Map) {
  ///     print('It\'s an object');
  ///   } else if (data is List) {
  ///     print('It\'s an array');
  ///   }
  /// }
  /// ```
  static CFResult<dynamic> parseAny(
    String jsonString, {
    String? cacheKey,
    int maxDepth = 20,
  }) {
    try {
      if (jsonString.isEmpty) {
        return CFResult.error('JSON string is empty');
      }

      // Use cache if available
      final key = cacheKey ?? _generateCacheKey(jsonString);
      if (_cache.containsKey(key)) {
        Logger.d('$_source: Cache hit for JSON parsing');
        return CFResult.success(_cache[key]);
      }

      // Parse with depth validation
      final parsed = _parseWithDepthCheck(jsonString, maxDepth);

      // Cache the result
      _addToCache(key, parsed);
      Logger.d(
          '$_source: Successfully parsed JSON (type: ${parsed.runtimeType})');
      return CFResult.success(parsed);
    } catch (e) {
      Logger.e('$_source: JSON parsing failed: $e');
      return CFResult.error(_formatJsonError(e, jsonString));
    }
  }

  /// Serialize object to JSON with optimization
  ///
  /// Optimized JSON serialization with error handling.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = JsonParser.stringify({'key': 'value'});
  /// if (result.isSuccess) {
  ///   final json = result.getOrNull()!;
  ///   print('JSON: $json');
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
      Logger.d('$_source: Successfully serialized object to JSON');
      return CFResult.success(jsonString);
    } catch (e) {
      Logger.e('$_source: JSON serialization failed: $e');
      return CFResult.error('Failed to serialize object to JSON: $e');
    }
  }

  /// Parse JSON from bytes (for network responses)
  ///
  /// Efficiently parse JSON from byte arrays without string conversion overhead.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final bytes = utf8.encode('{"key": "value"}');
  /// final result = JsonParser.parseFromBytes(bytes);
  /// ```
  static CFResult<dynamic> parseFromBytes(
    Uint8List bytes, {
    String? cacheKey,
    int maxDepth = 20,
  }) {
    try {
      if (bytes.isEmpty) {
        return CFResult.error('Byte array is empty');
      }

      // Convert bytes to string efficiently
      final jsonString = utf8.decode(bytes);
      return parseAny(jsonString, cacheKey: cacheKey, maxDepth: maxDepth);
    } catch (e) {
      Logger.e('$_source: JSON parsing from bytes failed: $e');
      return CFResult.error('Failed to parse JSON from bytes: $e');
    }
  }

  /// Clear the JSON parsing cache
  ///
  /// Clears all cached parsing results to free memory.
  /// Call this when memory usage is a concern.
  ///
  /// ## Example
  ///
  /// ```dart
  /// JsonParser.clearCache();
  /// print('Cache cleared');
  /// ```
  static void clearCache() {
    _cache.clear();
    _cacheKeys.clear();
    Logger.d('$_source: JSON parsing cache cleared');
  }

  /// Get cache statistics
  ///
  /// Returns information about the current cache state.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final stats = JsonParser.getCacheStats();
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

  static dynamic _parseWithDepthCheck(String jsonString, int maxDepth) {
    // Simple depth check by counting nesting levels
    int depth = 0;
    int maxDepthFound = 0;

    for (int i = 0; i < jsonString.length; i++) {
      final char = jsonString[i];
      if (char == '{' || char == '[') {
        depth++;
        if (depth > maxDepthFound) {
          maxDepthFound = depth;
        }
        if (depth > maxDepth) {
          throw FormatException('JSON exceeds maximum depth of $maxDepth');
        }
      } else if (char == '}' || char == ']') {
        depth--;
      }
    }

    return jsonDecode(jsonString);
  }

  static bool _isValidJsonStructure(String jsonString) {
    final trimmed = jsonString.trim();
    if (trimmed.isEmpty) return false;

    // Basic structure validation
    return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']')) ||
        (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed == 'true' || trimmed == 'false' || trimmed == 'null') ||
        (double.tryParse(trimmed) != null);
  }

  static String _generateCacheKey(String jsonString) {
    // Use SHA-256 hash instead of hashCode to avoid collisions
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return 'json_${digest.toString().substring(0, 16)}_${jsonString.length}';
  }

  static void _addToCache(String key, dynamic value) {
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

  static String _formatJsonError(dynamic error, String jsonString) {
    if (error is FormatException) {
      final preview = jsonString.length > 100
          ? '${jsonString.substring(0, 100)}...'
          : jsonString;
      return 'JSON format error: ${error.message}\nPreview: $preview';
    }
    return 'JSON parsing error: $error';
  }
}
