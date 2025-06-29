// lib/src/core/validation/input_validator.dart
//
// Comprehensive input validation system for the CustomFit Flutter SDK
// Prevents injection attacks, crashes, and ensures data integrity
//
// This file is part of the CustomFit SDK for Flutter.

import 'dart:convert';
import '../error/cf_result.dart';
import '../error/error_category.dart';
import '../error/cf_error_code.dart';
import '../../logging/logger.dart';

/// Comprehensive input validator for SDK public APIs
class InputValidator {
  static const String _tag = 'InputValidator';

  // Security patterns to detect potential injection attacks
  static const List<String> _suspiciousPatterns = [
    '<script',
    'javascript:',
    'data:',
    'vbscript:',
    'onload=',
    'onerror=',
    'onclick=',
    'eval(',
    'setTimeout(',
    'setInterval(',
    'Function(',
    'alert(',
    'confirm(',
    'prompt(',
    'document.',
    'window.',
    'location.',
    'console.',
    'localStorage.',
    'sessionStorage.',
    'XMLHttpRequest',
    'fetch(',
    'import(',
    'require(',
    '__proto__',
    'constructor',
    'prototype',
    'toString',
    'valueOf',
    'hasOwnProperty',
    'propertyIsEnumerable',
    'isPrototypeOf',
    'call',
    'apply',
    'bind',
    r'${',
    r'#{',
    r'{{',
    '<%',
    '%>',
    '<?',
    '?>',
    'DROP TABLE',
    'SELECT *',
    'INSERT INTO',
    'UPDATE SET',
    'DELETE FROM',
    'UNION SELECT',
    'OR 1=1',
    'AND 1=1',
    "' OR '1'='1",
    '" OR "1"="1',
    '--',
    '/*',
    '*/',
    'xp_',
    'sp_',
    'EXEC',
    'EXECUTE',
    'SCRIPT',
    'IFRAME',
    'OBJECT',
    'EMBED',
    'FORM',
    'INPUT',
    'TEXTAREA',
    'SELECT',
    'OPTION',
    'BUTTON',
    'LINK',
    'META',
    'BASE',
    'STYLE',
    'TITLE',
    'HEAD',
    'BODY',
    'HTML',
    'FRAME',
    'FRAMESET',
    'APPLET',
  ];

  // Validation limits
  static const int maxStringLength = 10000;
  static const int maxPropertyKeyLength = 100;
  static const int maxPropertyValueLength = 5000;
  static const int maxEventNameLength = 100;
  static const int maxUserIdLength = 200;
  static const int maxPropertiesCount = 1000;
  static const int maxArrayLength = 1000;
  static const int maxObjectDepth = 10;
  static const int maxJsonSize = 100000; // 100KB

  /// Validate event name for tracking
  static CFResult<String> validateEventName(String eventName) {
    try {
      // Check for null or empty
      if (eventName.isEmpty) {
        return CFResult.error(
          'Event name cannot be empty',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationMissingRequiredField,
        );
      }

      // Trim whitespace
      final trimmed = eventName.trim();
      if (trimmed.isEmpty) {
        return CFResult.error(
          'Event name cannot be empty or only whitespace',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationMissingRequiredField,
        );
      }

      // Length validation
      if (trimmed.length > maxEventNameLength) {
        return CFResult.error(
          'Event name too long. Maximum length: $maxEventNameLength characters',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationExceededLimit,
          context: {
            'maxLength': maxEventNameLength,
            'actualLength': trimmed.length,
            'value': '${trimmed.substring(0, 50)}...',
          },
        );
      }

      // Character validation - allow alphanumeric, underscore, dash, dot, space
      if (!RegExp(r'^[a-zA-Z0-9_\-\.\s]+$').hasMatch(trimmed)) {
        return CFResult.error(
          'Event name contains invalid characters. Only alphanumeric, underscore, dash, dot, and space are allowed',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidFormat,
          context: {'value': trimmed},
        );
      }

      // Security validation
      final securityResult = _checkForSuspiciousContent(trimmed, 'event name');
      if (!securityResult.isSuccess) {
        return CFResult.error(
          securityResult.error?.message ?? 'Security validation failed',
          category: securityResult.error!.category,
          errorCode: securityResult.error!.errorCode,
          context: securityResult.error!.context,
        );
      }

      return CFResult.success(trimmed);
    } catch (e) {
      Logger.e('$_tag: Error validating event name: $e');
      return CFResult.error(
        'Failed to validate event name',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Validate property key
  static CFResult<String> validatePropertyKey(String key) {
    try {
      // Check for null or empty
      if (key.isEmpty) {
        return CFResult.error(
          'Property key cannot be empty',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationMissingRequiredField,
        );
      }

      // Trim whitespace
      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        return CFResult.error(
          'Property key cannot be empty or only whitespace',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationMissingRequiredField,
        );
      }

      // Length validation
      if (trimmed.length > maxPropertyKeyLength) {
        return CFResult.error(
          'Property key too long. Maximum length: $maxPropertyKeyLength characters',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationExceededLimit,
          context: {
            'maxLength': maxPropertyKeyLength,
            'actualLength': trimmed.length,
            'value': trimmed,
          },
        );
      }

      // Character validation - stricter for keys
      if (!RegExp(r'^[a-zA-Z0-9_\-\.]+$').hasMatch(trimmed)) {
        return CFResult.error(
          'Property key contains invalid characters. Only alphanumeric, underscore, dash, and dot are allowed',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidFormat,
          context: {'value': trimmed},
        );
      }

      // Reserved key validation
      if (_isReservedKey(trimmed)) {
        return CFResult.error(
          'Property key is reserved and cannot be used',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidPropertyKey,
          context: {'key': trimmed},
        );
      }

      // Security validation
      final securityResult = _checkForSuspiciousContent(trimmed, 'property key');
      if (!securityResult.isSuccess) {
        return CFResult.error(
          securityResult.error?.message ?? 'Security validation failed',
          category: securityResult.error!.category,
          errorCode: securityResult.error!.errorCode,
          context: securityResult.error!.context,
        );
      }

      return CFResult.success(trimmed);
    } catch (e) {
      Logger.e('$_tag: Error validating property key: $e');
      return CFResult.error(
        'Failed to validate property key',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Validate property value
  static CFResult<dynamic> validatePropertyValue(dynamic value) {
    try {
      if (value == null) {
        // Allow null values - they will be filtered out or handled by the backend
        return CFResult.success(null);
      }

      // Validate based on type
      if (value is String) {
        return _validateStringValue(value);
      } else if (value is num) {
        return _validateNumberValue(value);
      } else if (value is bool) {
        return CFResult.success(value);
      } else if (value is List) {
        return _validateArrayValue(value);
      } else if (value is Map) {
        return _validateMapValue(Map<String, dynamic>.from(value));
      } else {
        // Try to convert to string and validate
        final stringValue = value.toString();
        final stringResult = _validateStringValue(stringValue);
        return stringResult.isSuccess 
          ? CFResult.success(stringValue)
          : stringResult;
      }
    } catch (e) {
      Logger.e('$_tag: Error validating property value: $e');
      return CFResult.error(
        'Failed to validate property value',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Validate user ID
  static CFResult<String> validateUserId(String userId) {
    try {
      // Check for null or empty
      if (userId.isEmpty) {
        return CFResult.error(
          'User ID cannot be empty',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidUserId,
        );
      }

      // Trim whitespace
      final trimmed = userId.trim();
      if (trimmed.isEmpty) {
        return CFResult.error(
          'User ID cannot be empty or only whitespace',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidUserId,
        );
      }

      // Length validation
      if (trimmed.length > maxUserIdLength) {
        return CFResult.error(
          'User ID too long. Maximum length: $maxUserIdLength characters',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationExceededLimit,
          context: {
            'maxLength': maxUserIdLength,
            'actualLength': trimmed.length,
            'value': '${trimmed.substring(0, 50)}...',
          },
        );
      }

      // Character validation - allow alphanumeric, underscore, dash, dot, @, +
      if (!RegExp(r'^[a-zA-Z0-9_\-\.@\+]+$').hasMatch(trimmed)) {
        return CFResult.error(
          'User ID contains invalid characters. Only alphanumeric, underscore, dash, dot, @, and + are allowed',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidUserId,
          context: {'value': trimmed},
        );
      }

      // Security validation
      final securityResult = _checkForSuspiciousContent(trimmed, 'user ID');
      if (!securityResult.isSuccess) {
        return CFResult.error(
          securityResult.error?.message ?? 'Security validation failed',
          category: securityResult.error!.category,
          errorCode: securityResult.error!.errorCode,
          context: securityResult.error!.context,
        );
      }

      return CFResult.success(trimmed);
    } catch (e) {
      Logger.e('$_tag: Error validating user ID: $e');
      return CFResult.error(
        'Failed to validate user ID',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Validate properties map
  static CFResult<Map<String, dynamic>> validateProperties(Map<String, dynamic> properties) {
    try {
      if (properties.isEmpty) {
        return CFResult.success(properties);
      }

      // Check total properties count
      if (properties.length > maxPropertiesCount) {
        return CFResult.error(
          'Too many properties. Maximum allowed: $maxPropertiesCount',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationExceededLimit,
          context: {
            'maxCount': maxPropertiesCount,
            'actualCount': properties.length,
          },
        );
      }

      final validatedProperties = <String, dynamic>{};

      for (final entry in properties.entries) {
        // Validate key
        final keyResult = validatePropertyKey(entry.key);
        if (!keyResult.isSuccess) {
          return CFResult.error(
            keyResult.error?.message ?? 'Key validation failed',
            category: keyResult.error?.category ?? ErrorCategory.validation,
            errorCode: keyResult.error?.errorCode ?? CFErrorCode.validationInvalidPropertyKey,
            context: keyResult.error?.context,
          );
        }

        // Validate value
        final valueResult = validatePropertyValue(entry.value);
        if (!valueResult.isSuccess) {
          return CFResult.error(
            valueResult.error?.message ?? 'Value validation failed',
            category: valueResult.error?.category ?? ErrorCategory.validation,
            errorCode: valueResult.error?.errorCode ?? CFErrorCode.validationInvalidPropertyValue,
            context: valueResult.error?.context,
          );
        }

        // Get validated key
        final validatedKey = keyResult.data;
        if (validatedKey == null) {
          return CFResult.error(
            'Key validation returned null',
            category: ErrorCategory.internal,
          );
        }
        
        // Get validated value - can be null
        final validatedValue = valueResult.data;
        
        validatedProperties[validatedKey] = validatedValue;
      }

      return CFResult.success(validatedProperties);
    } catch (e) {
      Logger.e('$_tag: Error validating properties: $e');
      return CFResult.error(
        'Failed to validate properties',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  /// Validate feature flag key
  static CFResult<String> validateFeatureFlagKey(String key) {
    try {
      // Check for null or empty
      if (key.isEmpty) {
        return CFResult.error(
          'Feature flag key cannot be empty',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationMissingRequiredField,
        );
      }

      // Trim whitespace
      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        return CFResult.error(
          'Feature flag key cannot be empty or only whitespace',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationMissingRequiredField,
        );
      }

      // Length validation
      if (trimmed.length > maxPropertyKeyLength) {
        return CFResult.error(
          'Feature flag key too long. Maximum length: $maxPropertyKeyLength characters',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationExceededLimit,
          context: {
            'maxLength': maxPropertyKeyLength,
            'actualLength': trimmed.length,
            'value': trimmed,
          },
        );
      }

      // Character validation
      if (!RegExp(r'^[a-zA-Z0-9_\-\.]+$').hasMatch(trimmed)) {
        return CFResult.error(
          'Feature flag key contains invalid characters. Only alphanumeric, underscore, dash, and dot are allowed',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidFormat,
          context: {'value': trimmed},
        );
      }

      // Security validation
      final securityResult = _checkForSuspiciousContent(trimmed, 'feature flag key');
      if (!securityResult.isSuccess) {
        return CFResult.error(
          securityResult.error?.message ?? 'Security validation failed',
          category: securityResult.error!.category,
          errorCode: securityResult.error!.errorCode,
          context: securityResult.error!.context,
        );
      }

      return CFResult.success(trimmed);
    } catch (e) {
      Logger.e('$_tag: Error validating feature flag key: $e');
      return CFResult.error(
        'Failed to validate feature flag key',
        exception: e,
        category: ErrorCategory.internal,
      );
    }
  }

  // Private helper methods

  /// Validate string value
  static CFResult<String> _validateStringValue(String value) {
    // Length validation
    if (value.length > maxPropertyValueLength) {
      return CFResult.error(
        'String value too long. Maximum length: $maxPropertyValueLength characters',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationExceededLimit,
        context: {
          'maxLength': maxPropertyValueLength,
          'actualLength': value.length,
          'value': '${value.substring(0, 100)}...',
        },
      );
    }

    // Security validation
    final securityResult = _checkForSuspiciousContent(value, 'string value');
    if (!securityResult.isSuccess) {
      return CFResult.error(
        securityResult.error?.message ?? 'Security validation failed',
        category: securityResult.error!.category,
        errorCode: securityResult.error!.errorCode,
        context: securityResult.error!.context,
      );
    }

    return CFResult.success(value);
  }

  /// Validate number value
  static CFResult<num> _validateNumberValue(num value) {
    // Check for invalid numbers
    if (value.isNaN || value.isInfinite) {
      return CFResult.error(
        'Number value must be finite and not NaN',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidPropertyValue,
        context: {'value': value.toString()},
      );
    }

    // Range validation for reasonable values
    if (value.abs() > 1e15) {
      return CFResult.error(
        'Number value too large. Maximum absolute value: 1e15',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationExceededLimit,
        context: {'value': value.toString()},
      );
    }

    return CFResult.success(value);
  }

  /// Validate array value
  static CFResult<List> _validateArrayValue(List value, [int depth = 0]) {
    // Depth check to prevent deeply nested structures
    if (depth > maxObjectDepth) {
      return CFResult.error(
        'Array nesting too deep. Maximum depth: $maxObjectDepth',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationExceededLimit,
      );
    }

    // Length validation
    if (value.length > maxArrayLength) {
      return CFResult.error(
        'Array too long. Maximum length: $maxArrayLength elements',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationExceededLimit,
        context: {
          'maxLength': maxArrayLength,
          'actualLength': value.length,
        },
      );
    }

    // Validate each element
    final validatedArray = [];
    for (int i = 0; i < value.length; i++) {
      final element = value[i];
      
      if (element is List) {
        final result = _validateArrayValue(element, depth + 1);
        if (!result.isSuccess) {
          return result;
        }
        validatedArray.add(result.getOrThrow());
      } else if (element is Map) {
        final result = _validateMapValue(element as Map<String, dynamic>, depth + 1);
        if (!result.isSuccess) {
          return CFResult.error(
            result.error?.message ?? 'Validation failed',
            category: result.error!.category,
            errorCode: result.error!.errorCode,
            context: result.error!.context,
          );
        }
        validatedArray.add(result.getOrThrow());
      } else {
        final result = validatePropertyValue(element);
        if (!result.isSuccess) {
          return CFResult.error(
            result.error?.message ?? 'Validation failed',
            category: result.error!.category,
            errorCode: result.error!.errorCode,
            context: result.error!.context,
          );
        }
        validatedArray.add(result.getOrThrow());
      }
    }

    return CFResult.success(validatedArray);
  }

  /// Validate map value
  static CFResult<Map<String, dynamic>> _validateMapValue(Map<String, dynamic> value, [int depth = 0]) {
    // Depth check to prevent deeply nested structures
    if (depth > maxObjectDepth) {
      return CFResult.error(
        'Object nesting too deep. Maximum depth: $maxObjectDepth',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationExceededLimit,
      );
    }

    // Size validation
    if (value.length > maxPropertiesCount) {
      return CFResult.error(
        'Object has too many properties. Maximum: $maxPropertiesCount',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationExceededLimit,
        context: {
          'maxCount': maxPropertiesCount,
          'actualCount': value.length,
        },
      );
    }

    // Validate JSON size
    try {
      final jsonString = jsonEncode(value);
      if (jsonString.length > maxJsonSize) {
        return CFResult.error(
          'Object JSON representation too large. Maximum size: $maxJsonSize bytes',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationExceededLimit,
          context: {
            'maxSize': maxJsonSize,
            'actualSize': jsonString.length,
          },
        );
      }
    } catch (e) {
      return CFResult.error(
        'Object contains non-serializable data',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidPropertyValue,
        exception: e,
      );
    }

    final validatedMap = <String, dynamic>{};

    for (final entry in value.entries) {
      // Validate key
      final keyResult = validatePropertyKey(entry.key);
      if (!keyResult.isSuccess) {
        return CFResult.error(
          keyResult.error?.message ?? 'Key validation failed',
          category: keyResult.error!.category,
          errorCode: keyResult.error!.errorCode,
          context: keyResult.error!.context,
        );
      }

      // Validate value recursively
      if (entry.value is Map) {
        final result = _validateMapValue(entry.value as Map<String, dynamic>, depth + 1);
        if (!result.isSuccess) {
          return result;
        }
        validatedMap[keyResult.getOrThrow()] = result.getOrThrow();
      } else if (entry.value is List) {
        final result = _validateArrayValue(entry.value as List, depth + 1);
        if (!result.isSuccess) {
          return CFResult.error(
            result.error?.message ?? 'Validation failed',
            category: result.error!.category,
            errorCode: result.error!.errorCode,
            context: result.error!.context,
          );
        }
        validatedMap[keyResult.getOrThrow()] = result.getOrThrow();
      } else {
        final result = validatePropertyValue(entry.value);
        if (!result.isSuccess) {
          return CFResult.error(
            result.error?.message ?? 'Validation failed',
            category: result.error!.category,
            errorCode: result.error!.errorCode,
            context: result.error!.context,
          );
        }
        validatedMap[keyResult.getOrThrow()] = result.getOrThrow();
      }
    }

    return CFResult.success(validatedMap);
  }

  /// Check for suspicious content that might indicate injection attacks
  static CFResult<void> _checkForSuspiciousContent(String value, String context) {
    final lowerValue = value.toLowerCase();
    
    // Skip validation for test environment or if it's a simple alphanumeric string
    if (RegExp(r'^[a-zA-Z0-9_\-\.\s]+$').hasMatch(value) && 
        !value.contains('<') && 
        !value.contains('>') &&
        !value.contains('script') &&
        !value.contains('SELECT') &&
        !value.contains('DROP')) {
      // Basic validation passed, skip detailed pattern matching
      return CFResult.success(null);
    }
    
    for (final pattern in _suspiciousPatterns) {
      // For short patterns like 'call', 'apply', 'bind', use word boundaries
      if (pattern.length <= 6 && RegExp(r'^[a-zA-Z]+$').hasMatch(pattern)) {
        // Use word boundary matching for short keyword patterns
        if (RegExp('\\b${RegExp.escape(pattern.toLowerCase())}\\b').hasMatch(lowerValue)) {
          Logger.w('$_tag: Suspicious pattern detected in $context: $pattern');
          return CFResult.error(
            'Input contains potentially dangerous content and was rejected for security reasons',
            category: ErrorCategory.validation,
            errorCode: CFErrorCode.validationInvalidFormat,
            context: {
              'context': context,
              'suspiciousPattern': pattern,
              'value': value.length > 100 ? '${value.substring(0, 100)}...' : value,
            },
          );
        }
      } else if (lowerValue.contains(pattern.toLowerCase())) {
        // For longer patterns or special characters, use contains
        Logger.w('$_tag: Suspicious pattern detected in $context: $pattern');
        return CFResult.error(
          'Input contains potentially dangerous content and was rejected for security reasons',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidFormat,
          context: {
            'context': context,
            'suspiciousPattern': pattern,
            'value': value.length > 100 ? '${value.substring(0, 100)}...' : value,
          },
        );
      }
    }

    return CFResult.success(null);
  }

  /// Check if a key is reserved
  static bool _isReservedKey(String key) {
    const reservedKeys = [
      'cf_',
      'customfit_',
      '__',
      'prototype',
      'constructor',
      'toString',
      'valueOf',
      'hasOwnProperty',
      'propertyIsEnumerable',
      'isPrototypeOf',
      'call',
      'apply',
      'bind',
      'length',
      'name',
      'arguments',
      'caller',
      'callee',
    ];

    final lowerKey = key.toLowerCase();
    
    for (final reserved in reservedKeys) {
      if (lowerKey.startsWith(reserved)) {
        return true;
      }
    }

    return false;
  }

  /// Get validation statistics
  static Map<String, dynamic> getValidationStats() {
    return {
      'maxStringLength': maxStringLength,
      'maxPropertyKeyLength': maxPropertyKeyLength,
      'maxPropertyValueLength': maxPropertyValueLength,
      'maxEventNameLength': maxEventNameLength,
      'maxUserIdLength': maxUserIdLength,
      'maxPropertiesCount': maxPropertiesCount,
      'maxArrayLength': maxArrayLength,
      'maxObjectDepth': maxObjectDepth,
      'maxJsonSize': maxJsonSize,
      'suspiciousPatternsCount': _suspiciousPatterns.length,
    };
  }
} 