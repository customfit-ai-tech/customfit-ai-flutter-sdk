// lib/src/core/model/cf_user.dart
//
// User model defining identity, properties, and targeting context for the CustomFit SDK.
// Represents a user in the CustomFit system, containing identification, custom properties,
// device information, and evaluation contexts used for feature flag targeting and analytics.
//
// This file is part of the CustomFit SDK for Flutter.

import 'device_context.dart';
import 'application_info.dart';
import 'evaluation_context.dart';
import 'context_type.dart';
import 'private_attributes_request.dart';

/// User model defining identity, properties, and targeting context for the CustomFit SDK.
///
/// [CFUser] represents a user in the CustomFit system, containing identification,
/// custom properties, device information, and evaluation contexts used for
/// feature flag targeting and analytics.
///
/// ## Usage
///
/// Create users using the builder pattern:
///
/// ```dart
/// // Identified user with properties
/// final user = CFUser.builder('user123')
///   .addStringProperty('plan', 'premium')
///   .addNumberProperty('age', 28)
///   .addBooleanProperty('beta_tester', true)
///   .addGeoPointProperty('location', 37.7749, -122.4194)
///   .build();
///
/// // Anonymous user
/// final anonymousUser = CFUser.builder('anon_user')
///   .makeAnonymous(true)
///   .addStringProperty('source', 'mobile_app')
///   .build();
/// ```
///
/// ## User Properties
///
/// Properties are key-value pairs used for feature flag targeting:
/// - String properties: Names, categories, subscription plans
/// - Number properties: Ages, scores, quantities, prices
/// - Boolean properties: Flags, preferences, feature access
/// - Date properties: Registration dates, last activity
/// - GeoPoint properties: User locations for geo-targeting
/// - JSON properties: Complex nested data structures
///
/// ## Evaluation Contexts
///
/// Contexts provide additional targeting criteria:
/// - Location context: Country, region, city-based targeting
/// - Device context: Platform, OS version, device model
/// - Session context: Current session-specific attributes
/// - Custom contexts: Application-specific targeting data
///
/// ## Privacy
///
/// Use [privateFields] to mark sensitive attributes that should not be
/// included in analytics or logs for privacy compliance.
class CFUser {
  /// Unique identifier for the user.
  ///
  /// This should be a stable identifier that persists across sessions.
  /// For anonymous users, this can be a device ID or session ID.
  final String? userCustomerId;

  /// Indicates whether this user should be treated as anonymous.
  ///
  /// Anonymous users have limited tracking and their data may be
  /// handled differently for privacy compliance.
  final bool anonymous;

  /// Attributes that should be excluded from analytics and logs.
  ///
  /// Use this to mark sensitive user data like email addresses,
  /// phone numbers, or other personally identifiable information.
  final PrivateAttributesRequest? privateFields;

  /// Session-specific attributes that should not be sent to analytics.
  ///
  /// Temporary session data that should remain local to the current
  /// session and not be persisted or transmitted.
  final PrivateAttributesRequest? sessionFields;

  /// User properties as key-value pairs for feature flag targeting.
  ///
  /// Properties can be strings, numbers, booleans, dates, or complex objects.
  /// These are used by the CustomFit platform for targeting rules.
  final Map<String, dynamic> properties;

  /// Evaluation contexts providing additional targeting criteria.
  ///
  /// Contexts allow for sophisticated targeting based on location,
  /// device characteristics, session state, or custom attributes.
  final List<EvaluationContext> contexts;

  /// Device-specific information and characteristics.
  ///
  /// Includes device model, OS version, screen size, and other
  /// hardware/software attributes useful for targeting.
  final DeviceContext? device;

  /// Application-specific metadata and version information.
  ///
  /// Contains app version, build information, installation date,
  /// and other application-level attributes.
  final ApplicationInfo? application;

  /// Get the userId (compatibility getter)
  String? get userId => userCustomerId;

  /// Get this user instance (for CFResult compatibility in tests)
  CFUser getOrThrow() => this;

  /// Create a new builder for a user with the given ID
  static CFUserBuilder builder(String userId) {
    return CFUserBuilder(userId);
  }

  /// Create a builder for an anonymous user
  static CFUserBuilder anonymousBuilder() {
    // Anonymous users get auto-generated IDs
    final anonymousId = 'anon_${DateTime.now().millisecondsSinceEpoch}';
    return CFUserBuilder(anonymousId)..makeAnonymous(true);
  }

  /// Factory method for creating a CFUser instance (backwards compatibility)
  ///
  /// Creates a [CFUser] instance with the provided parameters.
  /// This method provides backwards compatibility with test code.
  ///
  /// ## Parameters
  ///
  /// - [userCustomerId]: Unique identifier for the user
  /// - [anonymous]: Whether to treat this user as anonymous (default: false)
  /// - [customAttributes]: User properties for feature flag targeting (renamed from properties)
  /// - [privateAttributes]: Attributes to exclude from analytics
  /// - [contexts]: Evaluation contexts for advanced targeting
  /// - [device]: Device information and characteristics
  /// - [application]: Application metadata and version info
  ///
  /// ## Example
  ///
  /// ```dart
  /// final user = CFUser.create(
  ///   userCustomerId: 'user123',
  ///   customAttributes: {'plan': 'premium', 'age': 25},
  /// );
  /// ```
  static CFUser create({
    String? userCustomerId,
    bool anonymous = false,
    Map<String, dynamic>? customAttributes,
    Map<String, dynamic>? privateAttributes,
    List<EvaluationContext>? contexts,
    DeviceContext? device,
    ApplicationInfo? application,
  }) {
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      properties: customAttributes ?? {},
      contexts: contexts ?? [],
      device: device,
      application: application,
    );
  }

  /// Creates a new [CFUser] instance.
  ///
  /// ## Parameters
  ///
  /// - [userCustomerId]: Unique identifier for the user
  /// - [anonymous]: Whether to treat this user as anonymous (default: false)
  /// - [privateFields]: Attributes to exclude from analytics
  /// - [sessionFields]: Session-specific attributes to exclude from analytics
  /// - [properties]: User properties for feature flag targeting
  /// - [contexts]: Evaluation contexts for advanced targeting
  /// - [device]: Device information and characteristics
  /// - [application]: Application metadata and version info
  ///
  /// ## Example
  ///
  /// ```dart
  /// final user = CFUser(
  ///   userCustomerId: 'user123',
  ///   anonymous: false,
  ///   properties: {'plan': 'premium', 'age': 25},
  ///   device: DeviceContext(model: 'iPhone 13', osVersion: '15.0'),
  /// );
  /// ```
  CFUser({
    this.userCustomerId,
    this.anonymous = false,
    this.privateFields,
    this.sessionFields,
    Map<String, dynamic> properties = const {},
    this.contexts = const [],
    this.device,
    this.application,
  }) : properties = _ensureDeviceType(properties);

  /// Ensures cf_device_type is set to 'mobile' if not already present
  static Map<String, dynamic> _ensureDeviceType(
      Map<String, dynamic> properties) {
    final updatedProperties = Map<String, dynamic>.from(properties);
    if (!updatedProperties.containsKey('cf_device_type')) {
      updatedProperties['cf_device_type'] = 'mobile';
    }
    return updatedProperties;
  }

  /// Creates a [CFUser] from a map representation.
  ///
  /// Deserializes a user object from a map, typically used when loading
  /// user data from storage or receiving it from an API.
  ///
  /// ## Parameters
  ///
  /// - [map]: Map containing user data with expected keys
  ///
  /// ## Returns
  ///
  /// A [CFUser] instance created from the map data.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final userData = {
  ///   'user_customer_id': 'user123',
  ///   'anonymous': false,
  ///   'properties': {'plan': 'premium'},
  /// };
  /// final user = CFUser.fromMap(userData);
  /// ```
  factory CFUser.fromMap(Map<String, dynamic> map) {
    return CFUser(
      userCustomerId: map['user_customer_id'] as String?,
      anonymous: map['anonymous'] as bool? ?? false,
      privateFields: map['private_fields'] != null
          ? PrivateAttributesRequest.fromMap(
              map['private_fields'] as Map<String, dynamic>)
          : null,
      sessionFields: map['session_fields'] != null
          ? PrivateAttributesRequest.fromMap(
              map['session_fields'] as Map<String, dynamic>)
          : null,
      properties: (map['properties'] as Map<String, dynamic>?) ?? {},
      contexts: (map['contexts'] as List<dynamic>?)
              ?.map((e) => EvaluationContext.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      device: map['device'] != null
          ? DeviceContext.fromMap(map['device'] as Map<String, dynamic>)
          : null,
      application: map['application'] != null
          ? ApplicationInfo.fromMap(map['application'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert user to a map for serialization
  Map<String, dynamic> toMap() {
    // Start with a copy of properties
    final updatedProperties = Map<String, dynamic>.from(properties);

    // Inject contexts, device, application into properties (if present)
    if (contexts.isNotEmpty) {
      updatedProperties['contexts'] = contexts.map((e) => e.toMap()).toList();
    }
    if (device != null) {
      updatedProperties['device'] = device!.toMap();
    }
    if (application != null) {
      updatedProperties['application'] = application!.toMap();
    }

    // Build the map matching Kotlin SDK format
    final result = <String, dynamic>{
      'user_customer_id': userCustomerId,
      'anonymous': anonymous,
      'properties': updatedProperties,
    };

    // Add private_fields if it exists and has non-empty properties (match backend)
    if (privateFields != null && privateFields!.properties.isNotEmpty) {
      result['private_fields'] = privateFields!.toMap();
    }

    // Add session_fields if it exists and has non-empty properties (match backend)
    if (sessionFields != null && sessionFields!.properties.isNotEmpty) {
      result['session_fields'] = sessionFields!.toMap();
    }

    return result;
  }

  /// Create a copy with an added property
  CFUser addProperty(String key, dynamic value,
      {bool isPrivate = false, bool isSession = false}) {
    final updatedProperties = Map<String, dynamic>.from(properties);
    updatedProperties[key] = value;

    // Handle private fields
    PrivateAttributesRequest? updatedPrivateFields = privateFields;
    if (isPrivate) {
      final privateNames = Set<String>.from(privateFields?.properties ?? {});
      privateNames.add(key);
      updatedPrivateFields = PrivateAttributesRequest(properties: privateNames);
    }

    // Handle session fields
    PrivateAttributesRequest? updatedSessionFields = sessionFields;
    if (isSession) {
      final sessionNames = Set<String>.from(sessionFields?.properties ?? {});
      sessionNames.add(key);
      updatedSessionFields = PrivateAttributesRequest(properties: sessionNames);
    }

    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: updatedPrivateFields,
      sessionFields: updatedSessionFields,
      properties: updatedProperties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }

  /// Add a string property with privacy options
  CFUser addStringProperty(String key, String value,
      {bool isPrivate = false, bool isSession = false}) {
    return addProperty(key, value, isPrivate: isPrivate, isSession: isSession);
  }

  /// Add a number property with privacy options
  CFUser addNumberProperty(String key, num value,
      {bool isPrivate = false, bool isSession = false}) {
    return addProperty(key, value, isPrivate: isPrivate, isSession: isSession);
  }

  /// Add a boolean property with privacy options
  CFUser addBooleanProperty(String key, bool value,
      {bool isPrivate = false, bool isSession = false}) {
    return addProperty(key, value, isPrivate: isPrivate, isSession: isSession);
  }

  /// Add a map property with privacy options
  CFUser addMapProperty(String key, Map<String, dynamic> value,
      {bool isPrivate = false, bool isSession = false}) {
    return addProperty(key, value, isPrivate: isPrivate, isSession: isSession);
  }

  /// Add a JSON property with privacy options
  CFUser addJsonProperty(String key, Map<String, dynamic> value,
      {bool isPrivate = false, bool isSession = false}) {
    return addProperty(key, value, isPrivate: isPrivate, isSession: isSession);
  }

  /// Add a GeoPoint property with privacy options
  CFUser addGeoPointProperty(String key, double latitude, double longitude,
      {bool isPrivate = false, bool isSession = false}) {
    final geoPoint = {
      'latitude': latitude,
      'longitude': longitude,
    };
    return addProperty(key, geoPoint,
        isPrivate: isPrivate, isSession: isSession);
  }

  /// Create a copy with added context
  CFUser addContext(EvaluationContext context) {
    final updatedContexts = List<EvaluationContext>.from(contexts);
    updatedContexts.add(context);
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: privateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: updatedContexts,
      device: device,
      application: application,
    );
  }

  /// Create a copy with removed context
  CFUser removeContext(ContextType type, String key) {
    final updatedContexts = contexts
        .where((context) => !(context.type == type && context.key == key))
        .toList();
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: privateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: updatedContexts,
      device: device,
      application: application,
    );
  }

  /// Create a copy with updated device context
  CFUser withDeviceContext(DeviceContext device) {
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: privateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }

  /// Create a copy with updated application info
  CFUser withApplicationInfo(ApplicationInfo application) {
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: privateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }

  // Private property methods

  /// Remove a property
  CFUser removeProperty(String key) {
    final updatedProperties = Map<String, dynamic>.from(properties);
    updatedProperties.remove(key);

    // Also remove from private fields if it was private
    final privateKeys = Set<String>.from(privateFields?.properties ?? {});
    privateKeys.remove(key);
    final updatedPrivateFields = privateKeys.isEmpty
        ? null
        : PrivateAttributesRequest(properties: privateKeys);

    // Also remove from session fields if it was session-level
    final sessionKeys = Set<String>.from(sessionFields?.properties ?? {});
    sessionKeys.remove(key);
    final updatedSessionFields = sessionKeys.isEmpty
        ? null
        : PrivateAttributesRequest(properties: sessionKeys);

    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: updatedPrivateFields,
      sessionFields: updatedSessionFields,
      properties: updatedProperties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }

  /// Remove multiple properties
  CFUser removeProperties(List<String> keys) {
    final updatedProperties = Map<String, dynamic>.from(properties);
    for (final key in keys) {
      updatedProperties.remove(key);
    }

    // Also remove from private fields if they were private
    final privateKeys = Set<String>.from(privateFields?.properties ?? {});
    privateKeys.removeAll(keys);
    final updatedPrivateFields = privateKeys.isEmpty
        ? null
        : PrivateAttributesRequest(properties: privateKeys);

    // Also remove from session fields if they were session-level
    final sessionKeys = Set<String>.from(sessionFields?.properties ?? {});
    sessionKeys.removeAll(keys);
    final updatedSessionFields = sessionKeys.isEmpty
        ? null
        : PrivateAttributesRequest(properties: sessionKeys);

    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: updatedPrivateFields,
      sessionFields: updatedSessionFields,
      properties: updatedProperties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }

  /// Mark an existing property as private
  CFUser markPropertyAsPrivate(String key) {
    // Only mark as private if the property exists
    if (!properties.containsKey(key)) {
      return this;
    }

    // Update private fields to include this key
    final privateKeys = Set<String>.from(privateFields?.properties ?? {});
    privateKeys.add(key);
    final updatedPrivateFields =
        PrivateAttributesRequest(properties: privateKeys);

    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: updatedPrivateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }

  /// Mark multiple existing properties as private
  CFUser markPropertiesAsPrivate(List<String> keys) {
    // Filter to only include keys that exist in properties
    final existingKeys =
        keys.where((key) => properties.containsKey(key)).toList();
    if (existingKeys.isEmpty) {
      return this;
    }

    // Update private fields to include these keys
    final privateKeys = Set<String>.from(privateFields?.properties ?? {});
    privateKeys.addAll(existingKeys);
    final updatedPrivateFields =
        PrivateAttributesRequest(properties: privateKeys);

    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: updatedPrivateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }

  /// Convert user to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'userCustomerId': userCustomerId,
      'anonymous': anonymous,
      'properties': properties,
      'contexts': contexts.map((c) => c.toMap()).toList(),
      if (device != null) 'device': device!.toJson(),
      if (application != null) 'application': application!.toJson(),
      if (privateFields != null)
        'privateFields': {
          'attributeNames': privateFields!.attributeNames.toList(),
        },
      if (sessionFields != null)
        'sessionFields': {
          'attributeNames': sessionFields!.attributeNames.toList(),
        },
    };
  }

  /// Create user from JSON representation
  static CFUser fromJson(Map<String, dynamic> json) {
    return CFUser(
      userCustomerId: json['userCustomerId'] as String?,
      anonymous: json['anonymous'] as bool? ?? false,
      properties: json['properties'] as Map<String, dynamic>? ?? {},
      contexts: (json['contexts'] as List<dynamic>?)
              ?.map((c) => EvaluationContext.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      device: json['device'] != null
          ? DeviceContext.fromJson(json['device'] as Map<String, dynamic>)
          : null,
      application: json['application'] != null
          ? ApplicationInfo.fromJson(
              json['application'] as Map<String, dynamic>)
          : null,
      privateFields: json['privateFields'] != null
          ? PrivateAttributesRequest(
              properties: Set<String>.from(
                  (json['privateFields']['attributeNames'] as List)
                      .cast<String>()),
            )
          : null,
      sessionFields: json['sessionFields'] != null
          ? PrivateAttributesRequest(
              properties: Set<String>.from(
                  (json['sessionFields']['attributeNames'] as List)
                      .cast<String>()),
            )
          : null,
    );
  }
}

/// Builder for creating CFUser instances with a fluent API
class CFUserBuilder {
  final String userId;
  bool _anonymous = false;
  final Map<String, dynamic> _properties = {};
  final List<EvaluationContext> _contexts = [];
  DeviceContext? _device;
  ApplicationInfo? _application;
  PrivateAttributesRequest? _privateFields;
  PrivateAttributesRequest? _sessionFields;

  CFUserBuilder(this.userId);

  /// Set whether the user is anonymous
  CFUserBuilder makeAnonymous(bool anonymous) {
    _anonymous = anonymous;
    return this;
  }

  /// Add a string property
  CFUserBuilder addStringProperty(String key, String value,
      {bool isPrivate = false, bool isSession = false}) {
    // Store validation errors to be checked during build
    if (key.isEmpty || key.length > 100 || value.length > 1000) {
      // Still add the property but track validation will fail in build()
    }
    _properties[key] = value;

    if (isPrivate) {
      _markAsPrivate(key);
    }

    if (isSession) {
      _markAsSession(key);
    }

    return this;
  }

  /// Add a number property
  CFUserBuilder addNumberProperty(String key, num value,
      {bool isPrivate = false, bool isSession = false}) {
    // Store validation errors to be checked during build
    if (key.isEmpty || key.length > 100 || value.isNaN || value.isInfinite) {
      // Still add the property but track validation will fail in build()
    }
    _properties[key] = value;

    if (isPrivate) {
      _markAsPrivate(key);
    }

    if (isSession) {
      _markAsSession(key);
    }

    return this;
  }

  /// Add a boolean property
  CFUserBuilder addBooleanProperty(String key, bool value,
      {bool isPrivate = false, bool isSession = false}) {
    // Store validation errors to be checked during build
    if (key.isEmpty || key.length > 100) {
      // Still add the property but track validation will fail in build()
    }
    _properties[key] = value;

    if (isPrivate) {
      _markAsPrivate(key);
    }

    if (isSession) {
      _markAsSession(key);
    }

    return this;
  }

  /// Add a map property
  CFUserBuilder addMapProperty(String key, Map<String, dynamic> value,
      {bool isPrivate = false, bool isSession = false}) {
    // Store validation errors to be checked during build
    if (key.isEmpty ||
        key.length > 100 ||
        value.isEmpty ||
        value.length > 100) {
      // Still add the property but track validation will fail in build()
    }
    _properties[key] = value;

    if (isPrivate) {
      _markAsPrivate(key);
    }

    if (isSession) {
      _markAsSession(key);
    }

    return this;
  }

  /// Add a JSON property
  CFUserBuilder addJsonProperty(String key, Map<String, dynamic> value,
      {bool isPrivate = false, bool isSession = false}) {
    return addMapProperty(key, value,
        isPrivate: isPrivate, isSession: isSession);
  }

  /// Add a GeoPoint property
  CFUserBuilder addGeoPointProperty(
      String key, double latitude, double longitude,
      {bool isPrivate = false, bool isSession = false}) {
    final geoPoint = {
      'latitude': latitude,
      'longitude': longitude,
    };
    return addMapProperty(key, geoPoint,
        isPrivate: isPrivate, isSession: isSession);
  }

  // Helper methods
  void _markAsPrivate(String key) {
    final privateNames = Set<String>.from(_privateFields?.properties ?? {});
    privateNames.add(key);
    _privateFields = PrivateAttributesRequest(properties: privateNames);
  }

  void _markAsSession(String key) {
    final sessionNames = Set<String>.from(_sessionFields?.properties ?? {});
    sessionNames.add(key);
    _sessionFields = PrivateAttributesRequest(properties: sessionNames);
  }

  /// Add an evaluation context
  CFUserBuilder addContext(EvaluationContext context) {
    _contexts.add(context);
    return this;
  }

  /// Set device context
  CFUserBuilder withDeviceContext(DeviceContext device) {
    _device = device;
    return this;
  }

  /// Set application info
  CFUserBuilder withApplicationInfo(ApplicationInfo application) {
    _application = application;
    return this;
  }

  /// Set private fields
  CFUserBuilder withPrivateFields(PrivateAttributesRequest privateFields) {
    _privateFields = privateFields;
    return this;
  }

  /// Set session fields
  CFUserBuilder withSessionFields(PrivateAttributesRequest sessionFields) {
    _sessionFields = sessionFields;
    return this;
  }

  /// Mark an attribute as private
  CFUserBuilder makeAttributePrivate(String attributeName) {
    final privateNames = Set<String>.from(_privateFields?.properties ?? {});
    privateNames.add(attributeName);
    _privateFields = PrivateAttributesRequest(properties: privateNames);
    return this;
  }

  /// Mark an attribute as session-level
  CFUserBuilder makeAttributeSessionLevel(String attributeName) {
    final sessionNames = Set<String>.from(_sessionFields?.properties ?? {});
    sessionNames.add(attributeName);
    _sessionFields = PrivateAttributesRequest(properties: sessionNames);
    return this;
  }

  /// Build the CFUser instance
  CFUser build() {
    // Validate user ID
    if (!_anonymous && userId.isEmpty) {
      throw ArgumentError('User ID cannot be empty for non-anonymous users');
    }
    if (userId.length > 200) {
      throw ArgumentError('User ID cannot exceed 200 characters');
    }

    // Validate total properties size
    if (_properties.length > 1000) {
      throw ArgumentError('User cannot have more than 1000 properties');
    }

    // Add cf_device_type as 'mobile' by default if not already present
    if (!_properties.containsKey('cf_device_type')) {
      _properties['cf_device_type'] = 'mobile';
    }

    return CFUser(
      userCustomerId: userId,
      anonymous: _anonymous,
      properties: _properties,
      contexts: _contexts,
      device: _device,
      application: _application,
      privateFields: _privateFields,
      sessionFields: _sessionFields,
    );
  }
}
