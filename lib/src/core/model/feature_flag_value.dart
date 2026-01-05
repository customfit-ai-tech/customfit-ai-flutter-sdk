// lib/src/core/model/feature_flag_value.dart
//
// Sealed class for feature flag values with type safety.
// Provides compile-time safety for different feature flag value types.
//
// This file is part of the CustomFit SDK for Flutter.

/// Sealed class representing different types of feature flag values
sealed class FeatureFlagValue {
  const FeatureFlagValue();

  /// Boolean feature flag value
  const factory FeatureFlagValue.boolean(bool value) = BooleanFeatureFlagValue;

  /// String feature flag value
  const factory FeatureFlagValue.string(String value) = StringFeatureFlagValue;

  /// Number feature flag value (supports both int and double)
  const factory FeatureFlagValue.number(num value) = NumberFeatureFlagValue;

  /// JSON feature flag value (Map&lt;String, dynamic&gt;)
  const factory FeatureFlagValue.json(Map<String, dynamic> value) =
      JsonFeatureFlagValue;

  /// Create from dynamic value with type inference
  factory FeatureFlagValue.fromDynamic(dynamic value) {
    if (value == null) {
      // Return a string representation for null values
      return const FeatureFlagValue.string('null');
    } else if (value is bool) {
      return FeatureFlagValue.boolean(value);
    } else if (value is String) {
      return FeatureFlagValue.string(value);
    } else if (value is num) {
      return FeatureFlagValue.number(value);
    } else if (value is Map<String, dynamic>) {
      return FeatureFlagValue.json(value);
    } else {
      // Convert unknown types (including Lists) to string
      return FeatureFlagValue.string(value.toString());
    }
  }

  /// Get value as specific type, returns null if types don't match
  T? asType<T>() {
    final raw = rawValue;
    if (raw is T) {
      return raw;
    } else if (this is NumberFeatureFlagValue && (T == int || T == double)) {
      final numValue = (this as NumberFeatureFlagValue).value;
      if (T == int) {
        return numValue.toInt() as T;
      } else if (T == double) {
        return numValue.toDouble() as T;
      }
    }
    return null;
  }

  /// Get the raw value as dynamic
  dynamic get rawValue {
    if (this is BooleanFeatureFlagValue) {
      return (this as BooleanFeatureFlagValue).value;
    } else if (this is StringFeatureFlagValue) {
      return (this as StringFeatureFlagValue).value;
    } else if (this is NumberFeatureFlagValue) {
      return (this as NumberFeatureFlagValue).value;
    } else if (this is JsonFeatureFlagValue) {
      return (this as JsonFeatureFlagValue).value;
    } else {
      return null;
    }
  }

  /// Check if the value is of a specific type
  bool isType<T>() => asType<T>() != null;

  /// Get the type name as string
  String get typeName {
    if (this is BooleanFeatureFlagValue) {
      return 'boolean';
    } else if (this is StringFeatureFlagValue) {
      return 'string';
    } else if (this is NumberFeatureFlagValue) {
      return 'number';
    } else if (this is JsonFeatureFlagValue) {
      return 'json';
    } else {
      return 'unknown';
    }
  }

  /// Convert to string representation
  @override
  String toString() {
    if (this is BooleanFeatureFlagValue) {
      return (this as BooleanFeatureFlagValue).value.toString();
    } else if (this is StringFeatureFlagValue) {
      return (this as StringFeatureFlagValue).value;
    } else if (this is NumberFeatureFlagValue) {
      return (this as NumberFeatureFlagValue).value.toString();
    } else if (this is JsonFeatureFlagValue) {
      return (this as JsonFeatureFlagValue).value.toString();
    } else {
      return 'null';
    }
  }
}

/// Boolean feature flag value
final class BooleanFeatureFlagValue extends FeatureFlagValue {
  final bool value;

  const BooleanFeatureFlagValue(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BooleanFeatureFlagValue && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

/// String feature flag value
final class StringFeatureFlagValue extends FeatureFlagValue {
  final String value;

  const StringFeatureFlagValue(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StringFeatureFlagValue && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

/// Number feature flag value
final class NumberFeatureFlagValue extends FeatureFlagValue {
  final num value;

  const NumberFeatureFlagValue(this.value);

  /// Get as integer
  int get asInt => value.toInt();

  /// Get as double
  double get asDouble => value.toDouble();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NumberFeatureFlagValue && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

/// JSON feature flag value
final class JsonFeatureFlagValue extends FeatureFlagValue {
  final Map<String, dynamic> value;

  const JsonFeatureFlagValue(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JsonFeatureFlagValue && _mapEquals(other.value, value));

  @override
  int get hashCode =>
      Object.hashAll(value.entries.map((e) => Object.hash(e.key, e.value)));

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
