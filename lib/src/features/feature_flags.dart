import '../logging/logger.dart';
import 'flag_provider.dart';
import 'typed_flags.dart';

/// Type-safe feature flag definitions
///
/// This class provides a type-safe way to define and access feature flags.
///
/// ## Usage
///
/// ```dart
/// // Create a flag provider
/// final provider = MyFlagProvider();
///
/// // Create feature flags
/// final flags = FeatureFlags(provider);
///
/// // Define flags
/// final enableNewUI = flags.boolean(
///   key: 'enable_new_ui',
///   defaultValue: false,
/// );
///
/// // Use flags
/// if (enableNewUI.value) {
///   // Show new UI
/// }
/// ```
class FeatureFlags {
  /// The flag provider that supplies flag values
  final FlagProvider _provider;

  /// Public getter for the provider
  FlagProvider get provider => _provider;

  /// List of all registered flags for cleanup
  final List<dynamic> _registeredFlags = [];

  FeatureFlags(this._provider);

  /// Create a boolean flag
  BooleanFlag boolean({
    required String key,
    required bool defaultValue,
    String? description,
    Set<String>? tags,
  }) {
    final flag = BooleanFlag(
      provider: _provider,
      key: key,
      defaultValue: defaultValue,
      description: description,
      tags: tags,
    );
    _registeredFlags.add(flag);
    return flag;
  }

  /// Create a string flag
  StringFlag string({
    required String key,
    required String defaultValue,
    String? description,
    Set<String>? tags,
    List<String>? allowedValues,
  }) {
    final flag = StringFlag(
      provider: _provider,
      key: key,
      defaultValue: defaultValue,
      description: description,
      tags: tags,
      allowedValues: allowedValues,
    );
    _registeredFlags.add(flag);
    return flag;
  }

  /// Create a number flag
  NumberFlag number({
    required String key,
    required double defaultValue,
    double? min,
    double? max,
    String? description,
    Set<String>? tags,
  }) {
    final flag = NumberFlag(
      provider: _provider,
      key: key,
      defaultValue: defaultValue,
      min: min,
      max: max,
      description: description,
      tags: tags,
    );
    _registeredFlags.add(flag);
    return flag;
  }

  /// Create a JSON flag
  JsonFlag<T> json<T>({
    required String key,
    required T defaultValue,
    T Function(Map<String, dynamic>)? parser,
    Map<String, dynamic> Function(T)? serializer,
    String? description,
    Set<String>? tags,
  }) {
    final flag = JsonFlag<T>(
      provider: _provider,
      key: key,
      defaultValue: defaultValue,
      parser: parser,
      serializer: serializer,
      description: description,
      tags: tags,
    );
    _registeredFlags.add(flag);
    return flag;
  }

  /// Create an enum flag
  EnumFlag<T> enumFlag<T extends Enum>({
    required String key,
    required T defaultValue,
    required List<T> values,
    String? description,
    Set<String>? tags,
  }) {
    final flag = EnumFlag<T>(
      provider: _provider,
      key: key,
      defaultValue: defaultValue,
      values: values,
      description: description,
      tags: tags,
    );
    _registeredFlags.add(flag);
    return flag;
  }

  /// Clean up resources (call when disposing)
  void dispose() {
    for (final flag in _registeredFlags) {
      try {
        if (flag is BooleanFlag) {
          flag.dispose();
        } else if (flag is StringFlag) {
          flag.dispose();
        } else if (flag is NumberFlag) {
          flag.dispose();
        } else if (flag is JsonFlag) {
          flag.dispose();
        } else if (flag is EnumFlag) {
          flag.dispose();
        }
      } catch (e) {
        Logger.e('Error disposing flag ${flag.key}: $e');
      }
    }
    _registeredFlags.clear();
  }
}
