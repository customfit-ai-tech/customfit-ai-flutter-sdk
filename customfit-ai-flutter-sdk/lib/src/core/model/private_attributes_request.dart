/// Represents a request for private attributes that should not be sent to analytics
class PrivateAttributesRequest {
  /// Set of property names to keep private (matches backend format)
  final Set<String> properties;

  /// Constructor
  PrivateAttributesRequest({
    Set<String>? properties,
  }) : properties = Set<String>.from(properties ?? <String>{});

  /// Create from attribute names
  PrivateAttributesRequest.fromAttributeNames(Set<String> attributeNames)
      : properties = attributeNames;

  /// Creates a PrivateAttributesRequest from a map representation
  factory PrivateAttributesRequest.fromMap(Map<String, dynamic> map) {
    final propertyNames = (map['properties'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toSet() ??
        <String>{};

    return PrivateAttributesRequest(properties: propertyNames);
  }

  /// Converts the private attributes request to a map for serialization (backend format)
  Map<String, dynamic> toMap() {
    return {
      'properties': properties.toList(),
    };
  }

  /// Getter for attribute names (alias for properties)
  Set<String> get attributeNames => properties;
}
