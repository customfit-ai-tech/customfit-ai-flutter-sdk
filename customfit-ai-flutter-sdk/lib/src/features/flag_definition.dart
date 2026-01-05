/// Base class for type-safe feature flag definitions
abstract class FlagDefinition<T> {
  /// The unique key for this feature flag
  final String key;

  /// The default value if the flag is not found or cannot be parsed
  final T defaultValue;

  /// Optional description for documentation purposes
  final String? description;

  /// Optional tags for categorization
  final Set<String>? tags;

  FlagDefinition({
    required this.key,
    required this.defaultValue,
    this.description,
    this.tags,
  });

  /// Validates if a value is valid for this flag type
  bool isValidValue(dynamic value);

  /// Parses a raw value into the correct type
  T parseValue(dynamic value);

  /// Gets the current value of this flag
  T get value;

  /// Gets a stream of value changes for this flag
  Stream<T> get changes;
}
