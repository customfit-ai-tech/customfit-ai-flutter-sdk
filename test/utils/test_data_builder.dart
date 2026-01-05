// test/utils/test_data_builder.dart
//
// Comprehensive test data builders for creating test objects with fluent interfaces.
// Provides builders for CFUser, EventData, CFConfig, ApplicationInfo, and DeviceContext
// with sensible defaults and convenient helper methods for common test scenarios.
//
// This file is part of the CustomFit SDK for Flutter test utilities.
import 'package:customfit_ai_flutter_sdk/src/core/model/cf_user.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/application_info.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/device_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/evaluation_context.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/context_type.dart';
import 'package:customfit_ai_flutter_sdk/src/core/model/private_attributes_request.dart';
import 'package:customfit_ai_flutter_sdk/src/config/core/cf_config.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_data.dart';
import 'package:customfit_ai_flutter_sdk/src/analytics/event/event_type.dart';
import 'package:customfit_ai_flutter_sdk/src/constants/cf_constants.dart';

/// Builder for creating test CFUser instances with fluent API
class CFUserBuilder {
  String? _userId;
  bool _anonymous = false;
  final Map<String, dynamic> _properties = {};
  final List<EvaluationContext> _contexts = [];
  DeviceContext? _device;
  ApplicationInfo? _application;
  final Set<String> _privateFieldNames = {};
  final Set<String> _sessionFieldNames = {};

  /// Create a builder for a user with the given ID
  CFUserBuilder([String? userId]) : _userId = userId;

  /// Set user ID
  CFUserBuilder withUserId(String userId) {
    _userId = userId;
    return this;
  }

  /// Set whether the user is anonymous
  CFUserBuilder makeAnonymous([bool anonymous = true]) {
    _anonymous = anonymous;
    return this;
  }

  /// Add a string property
  CFUserBuilder addStringProperty(String key, String value) {
    _properties[key] = value;
    return this;
  }

  /// Add a number property
  CFUserBuilder addNumberProperty(String key, num value) {
    _properties[key] = value;
    return this;
  }

  /// Add a boolean property
  CFUserBuilder addBooleanProperty(String key, bool value) {
    _properties[key] = value;
    return this;
  }

  /// Add a map property
  CFUserBuilder addMapProperty(String key, Map<String, dynamic> value) {
    _properties[key] = value;
    return this;
  }

  /// Add multiple properties from a map
  CFUserBuilder addProperties(Map<String, dynamic> properties) {
    _properties.addAll(properties);
    return this;
  }

  /// Add an evaluation context
  CFUserBuilder addContext(EvaluationContext context) {
    _contexts.add(context);
    return this;
  }

  /// Add a location context
  CFUserBuilder addLocationContext(String key, String value) {
    _contexts.add(EvaluationContext(
      type: ContextType.custom,
      key: key,
      name: 'location',
      properties: {'value': value},
    ));
    return this;
  }

  /// Add a device context evaluation
  CFUserBuilder addDeviceContext(String key, String value) {
    _contexts.add(EvaluationContext(
      type: ContextType.device,
      key: key,
      properties: {'value': value},
    ));
    return this;
  }

  /// Add a session context
  CFUserBuilder addSessionContext(String key, String value) {
    _contexts.add(EvaluationContext(
      type: ContextType.session,
      key: key,
      properties: {'value': value},
    ));
    return this;
  }

  /// Add a custom context
  CFUserBuilder addCustomContext(String key, Map<String, dynamic> properties) {
    _contexts.add(EvaluationContext(
      type: ContextType.custom,
      key: key,
      properties: properties,
    ));
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

  /// Mark a property as private
  CFUserBuilder markPropertyAsPrivate(String propertyName) {
    _privateFieldNames.add(propertyName);
    return this;
  }

  /// Mark multiple properties as private
  CFUserBuilder markPropertiesAsPrivate(List<String> propertyNames) {
    _privateFieldNames.addAll(propertyNames);
    return this;
  }

  /// Mark a property as session-only
  CFUserBuilder markPropertyAsSession(String propertyName) {
    _sessionFieldNames.add(propertyName);
    return this;
  }

  /// Mark multiple properties as session-only
  CFUserBuilder markPropertiesAsSession(List<String> propertyNames) {
    _sessionFieldNames.addAll(propertyNames);
    return this;
  }

  /// Build the CFUser instance
  CFUser build() {
    return CFUser(
      userCustomerId: _userId,
      anonymous: _anonymous,
      properties: Map.from(_properties),
      contexts: List.from(_contexts),
      device: _device,
      application: _application,
      privateFields: _privateFieldNames.isNotEmpty
          ? PrivateAttributesRequest(properties: _privateFieldNames)
          : null,
      sessionFields: _sessionFieldNames.isNotEmpty
          ? PrivateAttributesRequest(properties: _sessionFieldNames)
          : null,
    );
  }

  // Helper methods for common scenarios
  /// Create an anonymous user with basic properties
  static CFUser anonymous() {
    final builder = CFUser.anonymousBuilder();
    builder.addStringProperty('source', 'test');
    builder.addNumberProperty('session_count', 1);
    return builder.build();
  }

  /// Create an authenticated user with standard properties
  static CFUser authenticated(String userId) {
    final builder = CFUser.builder(userId);
    builder.addStringProperty('email', 'test@example.com');
    builder.addNumberProperty('login_count', 1);
    builder.addBooleanProperty('verified', true);
    return builder.build();
  }

  /// Create a premium user with location
  static CFUser premiumUser(String userId) {
    final builder = CFUser.builder(userId);
    builder.addStringProperty('plan', 'premium');
    builder.addStringProperty('country', 'US');
    builder.addNumberProperty('subscription_months', 12);
    builder.addBooleanProperty('auto_renew', true);
    builder.addStringProperty('region', 'CA');
    return builder.build();
  }

  /// Create a basic user for testing
  static CFUser basic(String userId) {
    final builder = CFUser.builder(userId);
    builder.addStringProperty('type', 'basic');
    builder.addNumberProperty('credits', 10);
    return builder.build();
  }

  /// Create a user with privacy-sensitive data
  static CFUser withPrivateData(String userId) {
    final builder = CFUser.builder(userId);
    builder.addStringProperty('email', 'private@example.com', isPrivate: true);
    builder.addStringProperty('phone', '+1234567890', isPrivate: true);
    builder.addStringProperty('name', 'Test User');
    return builder.build();
  }

  /// Create a user with device and app info
  static CFUser withFullContext(String userId) {
    final builder = CFUser.builder(userId);
    builder.addStringProperty('name', 'Full Context User');
    builder.addStringProperty('country', 'US');
    builder.addStringProperty('platform', 'iOS');
    return builder.build();
  }
}

/// Builder for creating test EventData instances with fluent API
class EventDataBuilder {
  String? _eventId;
  String? _eventCustomerId;
  EventType _eventType = EventType.track;
  final Map<String, dynamic> _properties = {};
  String? _sessionId;
  int? _eventTimestamp;

  /// Create a builder with default values
  EventDataBuilder();

  /// Set event ID
  EventDataBuilder withEventId(String eventId) {
    _eventId = eventId;
    return this;
  }

  /// Set event customer ID
  EventDataBuilder withEventCustomerId(String eventCustomerId) {
    _eventCustomerId = eventCustomerId;
    return this;
  }

  /// Set event type
  EventDataBuilder withEventType(EventType eventType) {
    _eventType = eventType;
    return this;
  }

  /// Set session ID
  EventDataBuilder withSessionId(String sessionId) {
    _sessionId = sessionId;
    return this;
  }

  /// Set event timestamp
  EventDataBuilder withEventTimestamp(int timestamp) {
    _eventTimestamp = timestamp;
    return this;
  }

  /// Set event timestamp from DateTime
  EventDataBuilder withEventTime(DateTime time) {
    _eventTimestamp = time.millisecondsSinceEpoch;
    return this;
  }

  /// Add a property
  EventDataBuilder addProperty(String key, dynamic value) {
    _properties[key] = value;
    return this;
  }

  /// Add multiple properties
  EventDataBuilder addProperties(Map<String, dynamic> properties) {
    _properties.addAll(properties);
    return this;
  }

  /// Add string property
  EventDataBuilder addStringProperty(String key, String value) {
    _properties[key] = value;
    return this;
  }

  /// Add number property
  EventDataBuilder addNumberProperty(String key, num value) {
    _properties[key] = value;
    return this;
  }

  /// Add boolean property
  EventDataBuilder addBooleanProperty(String key, bool value) {
    _properties[key] = value;
    return this;
  }

  /// Build the EventData instance
  EventData build() {
    final now = DateTime.now();
    return EventData(
      eventId: _eventId ?? '${now.millisecondsSinceEpoch}-${_eventType.name}',
      eventCustomerId: _eventCustomerId ?? 'test-user-123',
      eventType: _eventType,
      properties: Map.from(_properties),
      sessionId: _sessionId ?? 'test-session-123',
      eventTimestamp: _eventTimestamp ?? now.millisecondsSinceEpoch,
    );
  }

  // Helper methods for common scenarios
  /// Create a simple track event
  static EventData trackEvent(String userId, String eventName) {
    return EventData.create(
      eventCustomerId: userId,
      eventType: EventType.track,
      sessionId: "test-session",
      properties: {"event_name": eventName},
    );
  }

  /// Create a page view event
  static EventData pageView(String userId, String pageName) {
    return EventDataBuilder()
        .withEventCustomerId(userId)
        .withEventType(EventType.track)
        .addStringProperty('page_name', pageName)
        .addNumberProperty('timestamp', DateTime.now().millisecondsSinceEpoch)
        .build();
  }

  /// Create a button click event
  static EventData buttonClick(String userId, String buttonName) {
    return EventDataBuilder()
        .withEventCustomerId(userId)
        .withEventType(EventType.track)
        .addStringProperty('event_name', 'button_click')
        .addStringProperty('button_name', buttonName)
        .addNumberProperty('timestamp', DateTime.now().millisecondsSinceEpoch)
        .build();
  }

  /// Create a purchase event
  static EventData purchase(String userId, double amount, String currency) {
    return EventDataBuilder()
        .withEventCustomerId(userId)
        .withEventType(EventType.track)
        .addStringProperty('event_name', 'purchase')
        .addNumberProperty('amount', amount)
        .addStringProperty('currency', currency)
        .addNumberProperty('timestamp', DateTime.now().millisecondsSinceEpoch)
        .build();
  }

  /// Create a feature flag evaluation event
  static EventData flagEvaluation(
      String userId, String flagKey, dynamic value) {
    return EventDataBuilder()
        .withEventCustomerId(userId)
        .withEventType(EventType.track)
        .addStringProperty('flag_key', flagKey)
        .addProperty('flag_value', value)
        .addNumberProperty('timestamp', DateTime.now().millisecondsSinceEpoch)
        .build();
  }

  /// Create an error event
  static EventData error(String userId, String errorMessage) {
    return EventDataBuilder()
        .withEventCustomerId(userId)
        .withEventType(EventType.track)
        .addStringProperty('error_message', errorMessage)
        .addNumberProperty(
            'error_timestamp', DateTime.now().millisecondsSinceEpoch)
        .build();
  }

  /// Create a session start event
  static EventData sessionStart(String userId, String sessionId) {
    return EventDataBuilder()
        .withEventCustomerId(userId)
        .withSessionId(sessionId)
        .withEventType(EventType.track)
        .addStringProperty('event_name', 'session_start')
        .addBooleanProperty('is_new_session', true)
        .build();
  }

  /// Create a session end event
  static EventData sessionEnd(String userId, String sessionId, int durationMs) {
    return EventDataBuilder()
        .withEventCustomerId(userId)
        .withSessionId(sessionId)
        .withEventType(EventType.track)
        .addStringProperty('event_name', 'session_end')
        .addNumberProperty('duration_ms', durationMs)
        .build();
  }
}

/// Builder for creating test CFConfig instances with fluent API
class CFConfigBuilder {
  String? _clientKey;
  CFEnvironment _environment = CFEnvironment.production;
  int _eventsQueueSize = 100;
  int _eventsFlushTimeSeconds = 60;
  int _eventsFlushIntervalMs = 1000;
  int _maxRetryAttempts = 3;
  int _retryInitialDelayMs = 1000;
  int _retryMaxDelayMs = 30000;
  double _retryBackoffMultiplier = 2.0;
  int _networkConnectionTimeoutMs = 10000;
  int _networkReadTimeoutMs = 10000;
  bool _loggingEnabled = true;
  bool _debugLoggingEnabled = false;
  String _logLevel = 'DEBUG';
  bool _offlineMode = false;
  bool _disableBackgroundPolling = false;
  bool _localStorageEnabled = true;
  bool _remoteLoggingEnabled = false;

  /// Create a builder with default test client key
  CFConfigBuilder([String? clientKey]) {
    _clientKey = clientKey ?? _generateTestClientKey();
  }

  /// Set client key
  CFConfigBuilder withClientKey(String clientKey) {
    _clientKey = clientKey;
    return this;
  }

  /// Set environment
  CFConfigBuilder withEnvironment(CFEnvironment environment) {
    _environment = environment;
    return this;
  }

  /// Set staging environment
  CFConfigBuilder forStaging() {
    _environment = CFEnvironment.staging;
    return this;
  }

  /// Set production environment
  CFConfigBuilder forProduction() {
    _environment = CFEnvironment.production;
    return this;
  }

  /// Set events queue size
  CFConfigBuilder withEventsQueueSize(int size) {
    _eventsQueueSize = size;
    return this;
  }

  /// Set events flush time
  CFConfigBuilder withEventsFlushTimeSeconds(int seconds) {
    _eventsFlushTimeSeconds = seconds;
    return this;
  }

  /// Set events flush interval
  CFConfigBuilder withEventsFlushIntervalMs(int ms) {
    _eventsFlushIntervalMs = ms;
    return this;
  }

  /// Set max retry attempts
  CFConfigBuilder withMaxRetryAttempts(int attempts) {
    _maxRetryAttempts = attempts;
    return this;
  }

  /// Set retry initial delay
  CFConfigBuilder withRetryInitialDelayMs(int ms) {
    _retryInitialDelayMs = ms;
    return this;
  }

  /// Set retry max delay
  CFConfigBuilder withRetryMaxDelayMs(int ms) {
    _retryMaxDelayMs = ms;
    return this;
  }

  /// Set retry backoff multiplier
  CFConfigBuilder withRetryBackoffMultiplier(double multiplier) {
    _retryBackoffMultiplier = multiplier;
    return this;
  }

  /// Set network connection timeout
  CFConfigBuilder withNetworkConnectionTimeoutMs(int ms) {
    _networkConnectionTimeoutMs = ms;
    return this;
  }

  /// Set network read timeout
  CFConfigBuilder withNetworkReadTimeoutMs(int ms) {
    _networkReadTimeoutMs = ms;
    return this;
  }

  /// Enable/disable logging
  CFConfigBuilder withLoggingEnabled(bool enabled) {
    _loggingEnabled = enabled;
    return this;
  }

  /// Enable/disable debug logging
  CFConfigBuilder withDebugLoggingEnabled(bool enabled) {
    _debugLoggingEnabled = enabled;
    return this;
  }

  /// Set log level
  CFConfigBuilder withLogLevel(String level) {
    _logLevel = level;
    return this;
  }

  /// Enable/disable offline mode
  CFConfigBuilder withOfflineMode(bool offline) {
    _offlineMode = offline;
    return this;
  }

  /// Enable/disable background polling
  CFConfigBuilder withBackgroundPolling(bool enabled) {
    _disableBackgroundPolling = !enabled;
    return this;
  }

  /// Enable/disable local storage
  CFConfigBuilder withLocalStorageEnabled(bool enabled) {
    _localStorageEnabled = enabled;
    return this;
  }

  /// Enable/disable remote logging
  CFConfigBuilder withRemoteLoggingEnabled(bool enabled) {
    _remoteLoggingEnabled = enabled;
    return this;
  }

  /// Build the CFConfig instance
  CFConfig build() {
    return CFConfig.builder(_clientKey!)
        .setEnvironment(_environment)
        .setEventsQueueSize(_eventsQueueSize)
        .setEventsFlushTimeSeconds(_eventsFlushTimeSeconds)
        .setEventsFlushIntervalMs(_eventsFlushIntervalMs)
        .setMaxRetryAttempts(_maxRetryAttempts)
        .setRetryInitialDelayMs(_retryInitialDelayMs)
        .setRetryMaxDelayMs(_retryMaxDelayMs)
        .setRetryBackoffMultiplier(_retryBackoffMultiplier)
        .setNetworkConnectionTimeoutMs(_networkConnectionTimeoutMs)
        .setNetworkReadTimeoutMs(_networkReadTimeoutMs)
        .setLoggingEnabled(_loggingEnabled)
        .setDebugLoggingEnabled(_debugLoggingEnabled)
        .setLogLevel(_logLevel)
        .setOfflineMode(_offlineMode)
        .setDisableBackgroundPolling(_disableBackgroundPolling)
        .setLocalStorageEnabled(_localStorageEnabled)
        .setRemoteLoggingEnabled(_remoteLoggingEnabled)
        .build()
        .getOrThrow();
  }

  /// Generate a test client key (mock JWT format)
  String _generateTestClientKey() {
    // Create a basic test JWT-like token for testing
    const header = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
    const payload =
        'eyJzdWIiOiIxMjM0NTY3ODkwIiwidXNlcl9pZCI6InRlc3QtdXNlciIsImRpbWVuc2lvbl9pZCI6InRlc3QtZGltZW5zaW9uIiwiaWF0IjoxNTE2MjM5MDIyfQ';
    const signature = 'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
    return '$header.$payload.$signature';
  }

  // Helper methods for common scenarios
  /// Create a development configuration
  static CFConfig development() {
    return CFConfigBuilder()
        .withDebugLoggingEnabled(true)
        .withLogLevel('DEBUG')
        .forStaging()
        .withEventsFlushIntervalMs(500)
        .withNetworkConnectionTimeoutMs(5000)
        .build();
  }

  /// Create a production configuration
  static CFConfig production(String clientKey) {
    return CFConfigBuilder(clientKey)
        .forProduction()
        .withDebugLoggingEnabled(false)
        .withLogLevel('INFO')
        .withEventsFlushIntervalMs(5000)
        .withNetworkConnectionTimeoutMs(30000)
        .build();
  }

  /// Create a testing configuration with fast flush intervals
  static CFConfig testing() {
    return CFConfigBuilder()
        .withDebugLoggingEnabled(true)
        .withEventsFlushIntervalMs(100)
        .withEventsFlushTimeSeconds(1)
        .withNetworkConnectionTimeoutMs(1000)
        .withMaxRetryAttempts(1)
        .build();
  }

  /// Create an offline configuration
  static CFConfig offline() {
    return CFConfigBuilder()
        .withOfflineMode(true)
        .withBackgroundPolling(false)
        .withLocalStorageEnabled(true)
        .withEventsFlushIntervalMs(60000)
        .build();
  }

  /// Create a minimal configuration for unit testing
  static CFConfig minimal() {
    return CFConfigBuilder()
        .withLoggingEnabled(false)
        .withDebugLoggingEnabled(false)
        .withBackgroundPolling(false)
        .withEventsFlushIntervalMs(60000)
        .withMaxRetryAttempts(0)
        .build();
  }
}

/// Builder for creating test ApplicationInfo instances with fluent API
class ApplicationInfoBuilder {
  String? _appName;
  String? _packageName;
  String? _versionName;
  int? _versionCode;
  String? _installDate;
  String? _lastUpdateDate;
  String? _buildType;
  int _launchCount = 1;
  final Map<String, String> _customAttributes = {};

  /// Create a builder with default values
  ApplicationInfoBuilder();

  /// Set app name
  ApplicationInfoBuilder withAppName(String appName) {
    _appName = appName;
    return this;
  }

  /// Set package name
  ApplicationInfoBuilder withPackageName(String packageName) {
    _packageName = packageName;
    return this;
  }

  /// Set version name
  ApplicationInfoBuilder withVersionName(String versionName) {
    _versionName = versionName;
    return this;
  }

  /// Set version code
  ApplicationInfoBuilder withVersionCode(int versionCode) {
    _versionCode = versionCode;
    return this;
  }

  /// Set install date
  ApplicationInfoBuilder withInstallDate(String installDate) {
    _installDate = installDate;
    return this;
  }

  /// Set install date from DateTime
  ApplicationInfoBuilder withInstallDateTime(DateTime installDate) {
    _installDate = installDate.toIso8601String();
    return this;
  }

  /// Set last update date
  ApplicationInfoBuilder withLastUpdateDate(String lastUpdateDate) {
    _lastUpdateDate = lastUpdateDate;
    return this;
  }

  /// Set last update date from DateTime
  ApplicationInfoBuilder withLastUpdateDateTime(DateTime lastUpdateDate) {
    _lastUpdateDate = lastUpdateDate.toIso8601String();
    return this;
  }

  /// Set build type
  ApplicationInfoBuilder withBuildType(String buildType) {
    _buildType = buildType;
    return this;
  }

  /// Set as debug build
  ApplicationInfoBuilder asDebugBuild() {
    _buildType = 'debug';
    return this;
  }

  /// Set as release build
  ApplicationInfoBuilder asReleaseBuild() {
    _buildType = 'release';
    return this;
  }

  /// Set launch count
  ApplicationInfoBuilder withLaunchCount(int launchCount) {
    _launchCount = launchCount;
    return this;
  }

  /// Add custom attribute
  ApplicationInfoBuilder addCustomAttribute(String key, String value) {
    _customAttributes[key] = value;
    return this;
  }

  /// Add multiple custom attributes
  ApplicationInfoBuilder addCustomAttributes(Map<String, String> attributes) {
    _customAttributes.addAll(attributes);
    return this;
  }

  /// Build the ApplicationInfo instance
  ApplicationInfo build() {
    return ApplicationInfo(
      appName: _appName,
      packageName: _packageName,
      versionName: _versionName,
      versionCode: _versionCode,
      installDate: _installDate,
      lastUpdateDate: _lastUpdateDate,
      buildType: _buildType,
      launchCount: _launchCount,
      customAttributes: Map.from(_customAttributes),
    );
  }

  // Helper methods for common scenarios
  /// Create a test app configuration
  static ApplicationInfo testApp() {
    final now = DateTime.now();
    return ApplicationInfoBuilder()
        .withAppName('Test App')
        .withPackageName('com.customfit.testapp')
        .withVersionName('1.0.0')
        .withVersionCode(1)
        .withInstallDateTime(now.subtract(const Duration(days: 7)))
        .withLastUpdateDateTime(now.subtract(const Duration(days: 1)))
        .asDebugBuild()
        .withLaunchCount(10)
        .addCustomAttribute('test_mode', 'enabled')
        .build();
  }

  /// Create a production app configuration
  static ApplicationInfo productionApp() {
    final now = DateTime.now();
    return ApplicationInfoBuilder()
        .withAppName('CustomFit App')
        .withPackageName('com.customfit.app')
        .withVersionName('2.1.0')
        .withVersionCode(21)
        .withInstallDateTime(now.subtract(const Duration(days: 30)))
        .withLastUpdateDateTime(now.subtract(const Duration(days: 5)))
        .asReleaseBuild()
        .withLaunchCount(100)
        .build();
  }

  /// Create a new install configuration
  static ApplicationInfo newInstall() {
    final now = DateTime.now();
    return ApplicationInfoBuilder()
        .withAppName('New App')
        .withPackageName('com.customfit.newapp')
        .withVersionName('1.0.0')
        .withVersionCode(1)
        .withInstallDateTime(now)
        .withLastUpdateDateTime(now)
        .asReleaseBuild()
        .withLaunchCount(1)
        .addCustomAttribute('first_launch', 'true')
        .build();
  }

  /// Create a beta app configuration
  static ApplicationInfo betaApp() {
    final now = DateTime.now();
    return ApplicationInfoBuilder()
        .withAppName('Beta App')
        .withPackageName('com.customfit.betaapp')
        .withVersionName('2.0.0-beta.1')
        .withVersionCode(200)
        .withInstallDateTime(now.subtract(const Duration(days: 3)))
        .withLastUpdateDateTime(now.subtract(const Duration(hours: 6)))
        .asDebugBuild()
        .withLaunchCount(25)
        .addCustomAttribute('beta_user', 'true')
        .addCustomAttribute('feedback_enabled', 'true')
        .build();
  }
}

/// Builder for creating test DeviceContext instances with fluent API
class DeviceContextBuilder {
  String? _manufacturer;
  String? _model;
  String? _osName;
  String? _osVersion;
  String _sdkVersion = '1.0.0';
  String? _appId;
  String? _appVersion;
  String? _locale;
  String? _timezone;
  int? _screenWidth;
  int? _screenHeight;
  double? _screenDensity;
  String? _networkType;
  String? _networkCarrier;
  final Map<String, dynamic> _customAttributes = {};

  /// Create a builder with default values
  DeviceContextBuilder();

  /// Set manufacturer
  DeviceContextBuilder withManufacturer(String manufacturer) {
    _manufacturer = manufacturer;
    return this;
  }

  /// Set model
  DeviceContextBuilder withModel(String model) {
    _model = model;
    return this;
  }

  /// Set OS name
  DeviceContextBuilder withOsName(String osName) {
    _osName = osName;
    return this;
  }

  /// Set OS version
  DeviceContextBuilder withOsVersion(String osVersion) {
    _osVersion = osVersion;
    return this;
  }

  /// Set SDK version
  DeviceContextBuilder withSdkVersion(String sdkVersion) {
    _sdkVersion = sdkVersion;
    return this;
  }

  /// Set app ID
  DeviceContextBuilder withAppId(String appId) {
    _appId = appId;
    return this;
  }

  /// Set app version
  DeviceContextBuilder withAppVersion(String appVersion) {
    _appVersion = appVersion;
    return this;
  }

  /// Set locale
  DeviceContextBuilder withLocale(String locale) {
    _locale = locale;
    return this;
  }

  /// Set timezone
  DeviceContextBuilder withTimezone(String timezone) {
    _timezone = timezone;
    return this;
  }

  /// Set screen dimensions
  DeviceContextBuilder withScreenDimensions(int width, int height) {
    _screenWidth = width;
    _screenHeight = height;
    return this;
  }

  /// Set screen density
  DeviceContextBuilder withScreenDensity(double density) {
    _screenDensity = density;
    return this;
  }

  /// Set network type
  DeviceContextBuilder withNetworkType(String networkType) {
    _networkType = networkType;
    return this;
  }

  /// Set network carrier
  DeviceContextBuilder withNetworkCarrier(String networkCarrier) {
    _networkCarrier = networkCarrier;
    return this;
  }

  /// Add custom attribute
  DeviceContextBuilder addCustomAttribute(String key, dynamic value) {
    _customAttributes[key] = value;
    return this;
  }

  /// Add multiple custom attributes
  DeviceContextBuilder addCustomAttributes(Map<String, dynamic> attributes) {
    _customAttributes.addAll(attributes);
    return this;
  }

  /// Build the DeviceContext instance
  DeviceContext build() {
    return DeviceContext(
      manufacturer: _manufacturer,
      model: _model,
      osName: _osName,
      osVersion: _osVersion,
      sdkVersion: _sdkVersion,
      appId: _appId,
      appVersion: _appVersion,
      locale: _locale,
      timezone: _timezone,
      screenWidth: _screenWidth,
      screenHeight: _screenHeight,
      screenDensity: _screenDensity,
      networkType: _networkType,
      networkCarrier: _networkCarrier,
      customAttributes: Map.from(_customAttributes),
    );
  }

  // Helper methods for common scenarios
  /// Create an iOS device context
  static DeviceContext ios() {
    return DeviceContextBuilder()
        .withManufacturer('Apple')
        .withModel('iPhone 13')
        .withOsName('iOS')
        .withOsVersion('15.6')
        .withLocale('en_US')
        .withTimezone('America/New_York')
        .withScreenDimensions(390, 844)
        .withScreenDensity(3.0)
        .withNetworkType('wifi')
        .addCustomAttribute('device_type', 'phone')
        .build();
  }

  /// Create an Android device context
  static DeviceContext android() {
    return DeviceContextBuilder()
        .withManufacturer('Samsung')
        .withModel('Galaxy S21')
        .withOsName('Android')
        .withOsVersion('11')
        .withLocale('en_US')
        .withTimezone('America/New_York')
        .withScreenDimensions(360, 800)
        .withScreenDensity(2.75)
        .withNetworkType('cellular')
        .withNetworkCarrier('Verizon')
        .addCustomAttribute('device_type', 'phone')
        .build();
  }

  /// Create a tablet device context
  static DeviceContext tablet() {
    return DeviceContextBuilder()
        .withManufacturer('Apple')
        .withModel('iPad Air')
        .withOsName('iPadOS')
        .withOsVersion('15.6')
        .withLocale('en_US')
        .withTimezone('America/New_York')
        .withScreenDimensions(820, 1180)
        .withScreenDensity(2.0)
        .withNetworkType('wifi')
        .addCustomAttribute('device_type', 'tablet')
        .build();
  }

  /// Create a mobile device context
  static DeviceContext mobile() {
    return DeviceContextBuilder()
        .withManufacturer('Google')
        .withModel('Pixel 6')
        .withOsName('Android')
        .withOsVersion('12')
        .withLocale('en_US')
        .withTimezone('America/Los_Angeles')
        .withScreenDimensions(411, 891)
        .withScreenDensity(2.625)
        .withNetworkType('cellular')
        .withNetworkCarrier('T-Mobile')
        .addCustomAttribute('device_type', 'phone')
        .addCustomAttribute('form_factor', 'mobile')
        .build();
  }

  /// Create a desktop device context
  static DeviceContext desktop() {
    return DeviceContextBuilder()
        .withManufacturer('Apple')
        .withModel('MacBook Pro')
        .withOsName('macOS')
        .withOsVersion('12.6')
        .withLocale('en_US')
        .withTimezone('America/New_York')
        .withScreenDimensions(1440, 900)
        .withScreenDensity(2.0)
        .withNetworkType('wifi')
        .addCustomAttribute('device_type', 'computer')
        .addCustomAttribute('form_factor', 'desktop')
        .build();
  }

  /// Create a low-end device context
  static DeviceContext lowEnd() {
    return DeviceContextBuilder()
        .withManufacturer('Samsung')
        .withModel('Galaxy A12')
        .withOsName('Android')
        .withOsVersion('10')
        .withLocale('en_US')
        .withTimezone('America/New_York')
        .withScreenDimensions(360, 780)
        .withScreenDensity(2.0)
        .withNetworkType('cellular')
        .addCustomAttribute('device_type', 'phone')
        .addCustomAttribute('performance_tier', 'low')
        .build();
  }

  /// Create a high-end device context
  static DeviceContext highEnd() {
    return DeviceContextBuilder()
        .withManufacturer('Apple')
        .withModel('iPhone 14 Pro Max')
        .withOsName('iOS')
        .withOsVersion('16.1')
        .withLocale('en_US')
        .withTimezone('America/New_York')
        .withScreenDimensions(430, 932)
        .withScreenDensity(3.0)
        .withNetworkType('wifi')
        .addCustomAttribute('device_type', 'phone')
        .addCustomAttribute('performance_tier', 'high')
        .build();
  }
}
