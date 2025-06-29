/// Abstract base class for property builders
abstract class PropertiesBuilder {
  /// Internal properties map
  final Map<String, dynamic> _properties = {};

  /// Add a property with any value
  void addProperty(String key, dynamic value) {
    if (key.isEmpty) {
      throw ArgumentError('Property key cannot be empty');
    }
    if (key.length > 100) {
      throw ArgumentError('Property key cannot exceed 100 characters');
    }
    _properties[key] = value;
  }

  /// Add a string property with validation
  void addStringProperty(String key, String value) {
    if (value.isEmpty) {
      throw ArgumentError("String value for '$key' cannot be blank");
    }
    addProperty(key, value);
  }

  /// Add a number property
  void addNumberProperty(String key, num value) {
    addProperty(key, value);
  }

  /// Add a boolean property
  void addBooleanProperty(String key, bool value) {
    addProperty(key, value);
  }


  /// Add a JSON property (map)
  void addJsonProperty(String key, Map<String, dynamic> value) {
    if (value.length > 100) {
      throw ArgumentError('JSON property cannot contain more than 100 entries');
    }
    addProperty(key, value);
  }

  /// Build the properties map
  Map<String, dynamic> build() => Map<String, dynamic>.from(_properties);
}
