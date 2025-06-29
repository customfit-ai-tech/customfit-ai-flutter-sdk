// lib/src/core/util/type_conversion_strategy.dart
//
// Improved strategy pattern implementation for type conversion with proper error handling.
// Uses CFResult for all conversions to provide detailed error information.
//
// This file is part of the CustomFit SDK for Flutter.

import '../../logging/logger.dart';
import '../error/cf_result.dart';
import '../error/error_category.dart';
import '../error/cf_error_code.dart';

/// Base strategy interface for type conversion with error handling
abstract class TypeConversionStrategy<T> {
  /// Attempts to convert the given value to type T
  /// Returns CFResult with either the converted value or error details
  CFResult<T> convert(dynamic value);

  /// Returns true if this strategy can handle the given type T
  bool canHandle(Type type);

  /// Returns the priority of this strategy (higher = tried first)
  int get priority => 0;
}

/// Strategy for string type conversion
class StringConversionStrategy extends TypeConversionStrategy<String> {
  @override
  CFResult<String> convert(dynamic value) {
    try {
      if (value == null) {
        return CFResult.error(
          'Cannot convert null to String',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidType,
        );
      }
      return CFResult.success(value.toString());
    } catch (e, stackTrace) {
      Logger.w('Failed to convert value to String: $e');
      return CFResult.error(
        'Failed to convert value to String: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'valueType': value.runtimeType.toString(),
          'value': value.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  @override
  bool canHandle(Type type) => type == String;

  @override
  int get priority => 10;
}

/// Strategy for int type conversion
class IntConversionStrategy extends TypeConversionStrategy<int> {
  @override
  CFResult<int> convert(dynamic value) {
    try {
      if (value == null) {
        return CFResult.error(
          'Cannot convert null to int',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidType,
        );
      }

      if (value is int) return CFResult.success(value);

      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return CFResult.success(parsed);
        }
        return CFResult.error(
          'Failed to parse "$value" as int',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidFormat,
          context: {'value': value},
        );
      }

      if (value is double) {
        if (value.isFinite && value == value.toInt()) {
          return CFResult.success(value.toInt());
        }
        return CFResult.error(
          'Cannot convert double $value to int without loss of precision',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidType,
          context: {'value': value},
        );
      }

      return CFResult.error(
        'Cannot convert ${value.runtimeType} to int',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {'valueType': value.runtimeType.toString()},
      );
    } catch (e, stackTrace) {
      Logger.w('Failed to convert value to int: $e');
      return CFResult.error(
        'Failed to convert value to int: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'valueType': value.runtimeType.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  @override
  bool canHandle(Type type) => type == int;

  @override
  int get priority => 10;
}

/// Strategy for double type conversion
class DoubleConversionStrategy extends TypeConversionStrategy<double> {
  @override
  CFResult<double> convert(dynamic value) {
    try {
      if (value == null) {
        return CFResult.error(
          'Cannot convert null to double',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidType,
        );
      }

      if (value is double) return CFResult.success(value);

      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return CFResult.success(parsed);
        }
        return CFResult.error(
          'Failed to parse "$value" as double',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidFormat,
          context: {'value': value},
        );
      }

      if (value is int) return CFResult.success(value.toDouble());

      return CFResult.error(
        'Cannot convert ${value.runtimeType} to double',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {'valueType': value.runtimeType.toString()},
      );
    } catch (e, stackTrace) {
      Logger.w('Failed to convert value to double: $e');
      return CFResult.error(
        'Failed to convert value to double: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'valueType': value.runtimeType.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  @override
  bool canHandle(Type type) => type == double;

  @override
  int get priority => 10;
}

/// Strategy for bool type conversion
class BoolConversionStrategy extends TypeConversionStrategy<bool> {
  @override
  CFResult<bool> convert(dynamic value) {
    try {
      if (value == null) {
        return CFResult.error(
          'Cannot convert null to bool',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidType,
        );
      }

      if (value is bool) return CFResult.success(value);

      if (value is String) {
        final lowercaseValue = value.toLowerCase();
        if (lowercaseValue == 'true' || lowercaseValue == '1') {
          return CFResult.success(true);
        } else if (lowercaseValue == 'false' || lowercaseValue == '0') {
          return CFResult.success(false);
        }
        return CFResult.error(
          'Cannot parse "$value" as bool (expected true/false/1/0)',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidFormat,
          context: {'value': value},
        );
      }

      if (value is int) return CFResult.success(value != 0);

      return CFResult.error(
        'Cannot convert ${value.runtimeType} to bool',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {'valueType': value.runtimeType.toString()},
      );
    } catch (e, stackTrace) {
      Logger.w('Failed to convert value to bool: $e');
      return CFResult.error(
        'Failed to convert value to bool: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'valueType': value.runtimeType.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  @override
  bool canHandle(Type type) => type == bool;

  @override
  int get priority => 10;
}

/// Strategy for Map type conversion
class MapConversionStrategy extends TypeConversionStrategy<Map> {
  @override
  CFResult<Map> convert(dynamic value) {
    try {
      if (value == null) {
        return CFResult.error(
          'Cannot convert null to Map',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidType,
        );
      }

      if (value is Map) return CFResult.success(value);

      return CFResult.error(
        'Cannot convert ${value.runtimeType} to Map',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {'valueType': value.runtimeType.toString()},
      );
    } catch (e, stackTrace) {
      Logger.w('Failed to convert value to Map: $e');
      return CFResult.error(
        'Failed to convert value to Map: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'valueType': value.runtimeType.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  @override
  bool canHandle(Type type) {
    return type.toString().contains('Map');
  }

  @override
  int get priority => 5;
}

/// Strategy for List type conversion
class ListConversionStrategy extends TypeConversionStrategy<List> {
  @override
  CFResult<List> convert(dynamic value) {
    try {
      if (value == null) {
        return CFResult.error(
          'Cannot convert null to List',
          category: ErrorCategory.validation,
          errorCode: CFErrorCode.validationInvalidType,
        );
      }

      if (value is List) return CFResult.success(value);

      return CFResult.error(
        'Cannot convert ${value.runtimeType} to List',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {'valueType': value.runtimeType.toString()},
      );
    } catch (e, stackTrace) {
      Logger.w('Failed to convert value to List: $e');
      return CFResult.error(
        'Failed to convert value to List: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'valueType': value.runtimeType.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  @override
  bool canHandle(Type type) {
    return type.toString().contains('List');
  }

  @override
  int get priority => 5;
}

/// Manager for type conversion strategies with improved error handling
class TypeConversionManager {
  final List<TypeConversionStrategy> _strategies = [];

  /// Default constructor with standard strategies
  TypeConversionManager() {
    // Register default strategies
    registerStrategy(StringConversionStrategy());
    registerStrategy(IntConversionStrategy());
    registerStrategy(DoubleConversionStrategy());
    registerStrategy(BoolConversionStrategy());
    registerStrategy(MapConversionStrategy());
    registerStrategy(ListConversionStrategy());
  }

  /// Register a new conversion strategy
  void registerStrategy(TypeConversionStrategy strategy) {
    _strategies.add(strategy);
    // Sort by priority (highest first)
    _strategies.sort((a, b) => b.priority.compareTo(a.priority));
    Logger.d('Registered type conversion strategy: ${strategy.runtimeType}');
  }

  /// Remove a strategy by type
  void removeStrategy<T extends TypeConversionStrategy>() {
    _strategies.removeWhere((strategy) => strategy is T);
    Logger.d('Removed type conversion strategy: $T');
  }

  /// Convert a value to the specified type using appropriate strategy with CFResult
  CFResult<T> convertValue<T>(dynamic value) {
    try {
      // First check direct cast - use safe casting
      final directCast = _safeCast<T>(value);
      if (directCast != null) {
        return CFResult.success(directCast);
      }

      // Try each strategy in priority order
      for (final strategy in _strategies) {
        if (strategy.canHandle(T)) {
          final result = strategy.convert(value);
          if (result.isSuccess) {
            // Use safe casting instead of unsafe 'as T'
            final convertedValue = _safeCast<T>(result.data);
            if (convertedValue != null) {
              Logger.trace(
                  'Successfully converted value using ${strategy.runtimeType}');
              return CFResult.success(convertedValue);
            } else {
              return CFResult.error(
                'Strategy returned incompatible type: expected $T, got ${result.data.runtimeType}',
                category: ErrorCategory.internal,
                errorCode: CFErrorCode.internalConversionError,
                context: {
                  'expectedType': T.toString(),
                  'actualType': result.data.runtimeType.toString(),
                  'strategy': strategy.runtimeType.toString(),
                },
              );
            }
          } else {
            // Return the specific error from the strategy
            return CFResult.error(
              result.error?.message ?? 'Conversion failed',
              exception: result.error?.exception,
              category: result.error?.category ?? ErrorCategory.internal,
              errorCode: result.error?.errorCode,
              context: result.error?.context,
            );
          }
        }
      }

      Logger.w('No conversion strategy found for type $T');
      return CFResult.error(
        'No conversion strategy available for type $T',
        category: ErrorCategory.validation,
        errorCode: CFErrorCode.validationInvalidType,
        context: {
          'requestedType': T.toString(),
          'valueType': value?.runtimeType.toString() ?? 'null',
          'value': value?.toString() ?? 'null',
        },
      );
    } catch (e, stackTrace) {
      Logger.e('Error in type conversion manager: $e');
      return CFResult.error(
        'Type conversion failed: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'requestedType': T.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Safe type casting that returns null instead of throwing
  T? _safeCast<T>(dynamic value) {
    try {
      if (value is T) {
        return value;
      }
      return null;
    } catch (e) {
      // In case the type check itself throws (shouldn't happen but safety first)
      Logger.w('Type check failed for ${T.toString()}: $e');
      return null;
    }
  }

  /// Get the list of registered strategies
  List<TypeConversionStrategy> getStrategies() {
    return List.unmodifiable(_strategies);
  }

  /// Check if a conversion strategy exists for the given type
  bool hasStrategyFor(Type type) {
    return _strategies.any((strategy) => strategy.canHandle(type));
  }
}

/// Utility class for safe type conversions throughout the SDK
class SafeTypeConverter {
  static final TypeConversionManager _manager = TypeConversionManager();

  /// Safely convert a value to the specified type with proper error handling
  static CFResult<T> convert<T>(dynamic value) {
    return _manager.convertValue<T>(value);
  }

  /// Safely extract a value from a Map with type conversion
  static CFResult<T> extractFromMap<T>(
    Map<String, dynamic> map,
    String key, {
    T? defaultValue,
    bool isRequired = true,
  }) {
    try {
      if (!map.containsKey(key)) {
        if (isRequired) {
          return CFResult.error(
            'Required key "$key" not found in map',
            category: ErrorCategory.validation,
            errorCode: CFErrorCode.validationMissingRequiredField,
            context: {
              'key': key,
              'expectedType': T.toString(),
              'availableKeys': map.keys.toList(),
            },
          );
        } else if (defaultValue != null) {
          return CFResult.success(defaultValue);
        } else {
          return CFResult.error(
            'Optional key "$key" not found and no default value provided',
            category: ErrorCategory.validation,
            errorCode: CFErrorCode.validationMissingRequiredField,
            context: {
              'key': key,
              'expectedType': T.toString(),
            },
          );
        }
      }

      final value = map[key];
      if (value == null && defaultValue != null) {
        return CFResult.success(defaultValue);
      }

      return convert<T>(value);
    } catch (e, stackTrace) {
      return CFResult.error(
        'Failed to extract key "$key" from map: ${e.toString()}',
        exception: e,
        category: ErrorCategory.internal,
        errorCode: CFErrorCode.internalConversionError,
        context: {
          'key': key,
          'expectedType': T.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Safely convert a nullable value with fallback
  static T convertWithFallback<T>(dynamic value, T fallback) {
    final result = convert<T>(value);
    return result.isSuccess ? result.data! : fallback;
  }

  /// Register a custom conversion strategy
  static void registerStrategy(TypeConversionStrategy strategy) {
    _manager.registerStrategy(strategy);
  }
}
