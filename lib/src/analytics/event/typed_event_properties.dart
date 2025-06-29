// lib/src/analytics/event/typed_event_properties.dart
//
// Typed event properties for analytics events with compile-time safety.
// Provides structured approach to event properties with validation.
//
// This file is part of the CustomFit SDK for Flutter.

import '../../core/util/properties_builder.dart';

/// Base class for typed event properties
abstract class TypedEventProperties {
  /// Convert to Map for serialization
  Map<String, dynamic> toMap();

  /// Validate the properties
  bool isValid();

  /// Get validation errors if any
  List<String> getValidationErrors();
}

/// Common event property types with validation
sealed class EventPropertyValue {
  const EventPropertyValue();

  /// String property
  const factory EventPropertyValue.string(String value) = StringEventProperty;

  /// Number property (int or double)
  const factory EventPropertyValue.number(num value) = NumberEventProperty;

  /// Boolean property
  const factory EventPropertyValue.boolean(bool value) = BooleanEventProperty;

  /// Get the raw value for serialization
  dynamic get value;

  /// Validate the property
  bool isValid();
}

/// String event property
final class StringEventProperty extends EventPropertyValue {
  final String _value;

  const StringEventProperty(this._value);

  @override
  String get value => _value;

  @override
  bool isValid() => _value.isNotEmpty && _value.length <= 1000;

  /// Get estimated memory size in bytes
  int get estimatedSizeBytes =>
      _value.length * 2; // Approximate UTF-16 encoding

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StringEventProperty && other._value == _value);

  @override
  int get hashCode => _value.hashCode;
}

/// Number event property
final class NumberEventProperty extends EventPropertyValue {
  final num _value;

  const NumberEventProperty(this._value);

  @override
  num get value => _value;

  @override
  bool isValid() => _value.isFinite;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NumberEventProperty && other._value == _value);

  @override
  int get hashCode => _value.hashCode;
}

/// Boolean event property
final class BooleanEventProperty extends EventPropertyValue {
  final bool _value;

  const BooleanEventProperty(this._value);

  @override
  bool get value => _value;

  @override
  bool isValid() => true; // Booleans are always valid

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BooleanEventProperty && other._value == _value);

  @override
  int get hashCode => _value.hashCode;
}

/// Builder for typed event properties
class TypedEventPropertiesBuilder {
  final Map<String, EventPropertyValue> _properties = {};

  /// Add a string property
  TypedEventPropertiesBuilder addString(String key, String value) {
    _properties[key] = EventPropertyValue.string(value);
    return this;
  }

  /// Add a number property
  TypedEventPropertiesBuilder addNumber(String key, num value) {
    _properties[key] = EventPropertyValue.number(value);
    return this;
  }

  /// Add a boolean property
  TypedEventPropertiesBuilder addBoolean(String key, bool value) {
    _properties[key] = EventPropertyValue.boolean(value);
    return this;
  }

  /// Add multiple properties from a map
  TypedEventPropertiesBuilder addAll(Map<String, dynamic> properties) {
    for (final entry in properties.entries) {
      final value = entry.value;
      if (value is String) {
        addString(entry.key, value);
      } else if (value is num) {
        addNumber(entry.key, value);
      } else if (value is bool) {
        addBoolean(entry.key, value);
      } else {
        // Convert unknown types to string
        addString(entry.key, value.toString());
      }
    }
    return this;
  }

  /// Build the final properties
  TypedEventPropertiesImpl build() {
    return TypedEventPropertiesImpl(_properties);
  }

  /// Clear all properties
  TypedEventPropertiesBuilder clear() {
    _properties.clear();
    return this;
  }

  /// Get current property count
  int get count => _properties.length;

  /// Check if has property
  bool hasProperty(String key) => _properties.containsKey(key);
}

/// Implementation of typed event properties
class TypedEventPropertiesImpl implements TypedEventProperties {
  final Map<String, EventPropertyValue> _properties;

  const TypedEventPropertiesImpl(this._properties);

  @override
  Map<String, dynamic> toMap() {
    return Map.fromEntries(
      _properties.entries.map((e) => MapEntry(e.key, e.value.value)),
    );
  }

  @override
  bool isValid() {
    // Check overall constraints
    if (_properties.length > 50) return false; // Max 50 properties

    // Check each property
    for (final property in _properties.values) {
      if (!property.isValid()) return false;
    }

    // Check key constraints
    for (final key in _properties.keys) {
      if (key.isEmpty || key.length > 100) return false;
      if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(key)) return false;
    }

    return true;
  }

  @override
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (_properties.length > 50) {
      errors.add('Too many properties: ${_properties.length} (max 50)');
    }

    // Calculate total estimated memory usage
    final totalMemoryBytes = getEstimatedMemoryUsage();
    const maxMemoryBytes = 1024 * 1024; // 1MB limit
    if (totalMemoryBytes > maxMemoryBytes) {
      errors.add(
          'Properties too large: ${totalMemoryBytes ~/ 1024}KB (max ${maxMemoryBytes ~/ 1024}KB)');
    }

    for (final entry in _properties.entries) {
      final key = entry.key;
      final property = entry.value;

      if (key.isEmpty) {
        errors.add('Property key cannot be empty');
      } else if (key.length > 100) {
        errors.add('Property key too long: $key (max 100 characters)');
      } else if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(key)) {
        errors.add(
            'Invalid property key format: $key (must start with letter/underscore, contain only alphanumeric/underscore)');
      }

      if (!property.isValid()) {
        if (property is StringEventProperty) {
          if (property.value.isEmpty) {
            errors.add('String property "$key" cannot be empty');
          } else if (property.value.length > 1000) {
            errors.add('String property "$key" too long (max 1000 characters)');
          }
        } else if (property is NumberEventProperty) {
          if (!property.value.isFinite) {
            errors.add('Number property "$key" must be finite');
          }
        }
      }
    }

    return errors;
  }

  /// Get estimated memory usage in bytes
  int getEstimatedMemoryUsage() {
    int totalBytes = 0;
    for (final entry in _properties.entries) {
      // Key memory usage
      totalBytes += entry.key.length * 2; // UTF-16 encoding

      // Property memory usage
      final property = entry.value;
      if (property is StringEventProperty) {
        totalBytes += property.estimatedSizeBytes;
      } else if (property is NumberEventProperty) {
        totalBytes += 8; // 64-bit number
      } else if (property is BooleanEventProperty) {
        totalBytes += 1; // Boolean
      }
    }
    return totalBytes;
  }

  /// Get property value by key
  EventPropertyValue? getProperty(String key) => _properties[key];

  /// Get all property keys
  Iterable<String> get keys => _properties.keys;

  /// Get property count
  int get count => _properties.length;

  /// Check if empty
  bool get isEmpty => _properties.isEmpty;

  /// Check if not empty
  bool get isNotEmpty => _properties.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TypedEventPropertiesImpl &&
          _mapEquals(other._properties, _properties));

  @override
  int get hashCode => Object.hashAll(_properties.entries);

  static bool _mapEquals(
      Map<String, EventPropertyValue> a, Map<String, EventPropertyValue> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Convenience factory for creating typed event properties
class EventProperties {
  static TypedEventPropertiesBuilder builder() => TypedEventPropertiesBuilder();

  static TypedEventPropertiesImpl empty() => const TypedEventPropertiesImpl({});

  static TypedEventPropertiesImpl fromMap(Map<String, dynamic> map) {
    return builder().addAll(map).build();
  }
}

/// Matches Kotlin's empty subclass of PropertiesBuilder
/// This class is maintained for backward compatibility
class EventPropertiesBuilder extends PropertiesBuilder {}
