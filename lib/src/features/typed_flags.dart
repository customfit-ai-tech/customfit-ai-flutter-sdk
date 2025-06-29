import 'dart:async';
import '../logging/logger.dart';
import 'flag_definition.dart';
import 'flag_provider.dart';

/// Type-safe boolean feature flag
class BooleanFlag extends FlagDefinition<bool> {
  final FlagProvider _provider;

  BooleanFlag({
    required FlagProvider provider,
    required super.key,
    required super.defaultValue,
    super.description,
    super.tags,
  }) : _provider = provider;

  @override
  bool isValidValue(dynamic value) => value is bool;

  @override
  bool parseValue(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == 'yes' || lower == '1';
    }
    if (value is num) {
      return value != 0;
    }
    return defaultValue;
  }

  @override
  bool get value {
    try {
      final rawValue = _provider.getFlag(key);
      return parseValue(rawValue ?? defaultValue);
    } catch (e) {
      Logger.w('BooleanFlag[$key]: Error getting value: $e. Using default.');
      return defaultValue;
    }
  }

  @override
  Stream<bool> get changes {
    return _provider
        .flagChanges(key)
        .map((value) => parseValue(value ?? defaultValue));
  }

  void dispose() {
    // No resources to dispose in simplified version
  }
}

/// Type-safe string feature flag
class StringFlag extends FlagDefinition<String> {
  final FlagProvider _provider;
  final List<String>? allowedValues;

  StringFlag({
    required FlagProvider provider,
    required super.key,
    required super.defaultValue,
    super.description,
    super.tags,
    this.allowedValues,
  }) : _provider = provider;

  @override
  bool isValidValue(dynamic value) {
    if (value is! String) return false;
    if (allowedValues != null) {
      return allowedValues!.contains(value);
    }
    return true;
  }

  @override
  String parseValue(dynamic value) {
    if (value == null) return defaultValue;
    final stringValue = value.toString();

    // If allowed values are specified, validate
    if (allowedValues != null && !allowedValues!.contains(stringValue)) {
      Logger.w(
          'StringFlag[$key]: Value "$stringValue" not in allowed values $allowedValues. Using default.');
      return defaultValue;
    }

    return stringValue;
  }

  @override
  String get value {
    try {
      final rawValue = _provider.getFlag(key);
      return parseValue(rawValue);
    } catch (e) {
      Logger.w('StringFlag[$key]: Error getting value: $e. Using default.');
      return defaultValue;
    }
  }

  @override
  Stream<String> get changes {
    return _provider.flagChanges(key).map((value) => parseValue(value));
  }

  void dispose() {
    // No resources to dispose in simplified version
  }
}

/// Type-safe number feature flag
class NumberFlag extends FlagDefinition<double> {
  final FlagProvider _provider;
  final double? min;
  final double? max;

  NumberFlag({
    required FlagProvider provider,
    required super.key,
    required super.defaultValue,
    this.min,
    this.max,
    super.description,
    super.tags,
  }) : _provider = provider;

  @override
  bool isValidValue(dynamic value) {
    if (value is! num) return false;
    final doubleValue = value.toDouble();
    if (min != null && doubleValue < min!) return false;
    if (max != null && doubleValue > max!) return false;
    return true;
  }

  @override
  double parseValue(dynamic value) {
    if (value is num) {
      final doubleValue = value.toDouble();
      // Handle NaN values by returning default
      if (doubleValue.isNaN) return defaultValue;
      if (min != null && doubleValue < min!) return min!;
      if (max != null && doubleValue > max!) return max!;
      return doubleValue;
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        // Handle NaN values by returning default
        if (parsed.isNaN) return defaultValue;
        if (min != null && parsed < min!) return min!;
        if (max != null && parsed > max!) return max!;
        return parsed;
      }
    }
    return defaultValue;
  }

  @override
  double get value {
    try {
      final rawValue = _provider.getFlag(key);
      return parseValue(rawValue);
    } catch (e) {
      Logger.w('NumberFlag[$key]: Error getting value: $e. Using default.');
      return defaultValue;
    }
  }

  @override
  Stream<double> get changes {
    return _provider.flagChanges(key).map((value) => parseValue(value));
  }

  void dispose() {
    // No resources to dispose in simplified version
  }
}

/// Type-safe JSON feature flag
class JsonFlag<T> extends FlagDefinition<T> {
  final FlagProvider _provider;
  final T Function(Map<String, dynamic>)? parser;
  final Map<String, dynamic> Function(T)? serializer;

  JsonFlag({
    required FlagProvider provider,
    required super.key,
    required super.defaultValue,
    this.parser,
    this.serializer,
    super.description,
    super.tags,
  }) : _provider = provider;

  @override
  bool isValidValue(dynamic value) {
    if (value is! Map<String, dynamic>) return false;
    if (parser != null) {
      try {
        parser!(value);
        return true;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  @override
  T parseValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      if (parser != null) {
        try {
          return parser!(value);
        } catch (e) {
          Logger.e('Failed to parse JSON flag $key: $e');
          return defaultValue;
        }
      }
      return value as T;
    }
    return defaultValue;
  }

  @override
  T get value {
    try {
      final rawValue = _provider.getFlag(key);
      return parseValue(rawValue);
    } catch (e) {
      Logger.w('JsonFlag[$key]: Error getting value: $e. Using default.');
      return defaultValue;
    }
  }

  @override
  Stream<T> get changes {
    return _provider.flagChanges(key).map((value) => parseValue(value));
  }

  void dispose() {
    // No resources to dispose in simplified version
  }
}

/// Type-safe enum feature flag
class EnumFlag<T extends Enum> extends FlagDefinition<T> {
  final FlagProvider _provider;
  final List<T> values;

  EnumFlag({
    required FlagProvider provider,
    required super.key,
    required super.defaultValue,
    required this.values,
    super.description,
    super.tags,
  }) : _provider = provider;

  @override
  bool isValidValue(dynamic value) {
    if (value is! String) return false;
    if (values.isEmpty) return false;
    return values.any((v) => v.name == value);
  }

  @override
  T parseValue(dynamic value) {
    if (values.isEmpty) {
      return defaultValue;
    }

    if (value is String) {
      try {
        return values.firstWhere(
          (v) => v.name == value,
          orElse: () => defaultValue,
        );
      } catch (_) {
        return defaultValue;
      }
    }
    if (value is T) {
      return value;
    }
    return defaultValue;
  }

  @override
  T get value {
    try {
      final rawValue = _provider.getFlag(key);
      return parseValue(rawValue);
    } catch (e) {
      Logger.w('EnumFlag[$key]: Error getting value: $e. Using default.');
      return defaultValue;
    }
  }

  @override
  Stream<T> get changes {
    return _provider.flagChanges(key).map((value) => parseValue(value));
  }

  void dispose() {
    // No resources to dispose in simplified version
  }
}
