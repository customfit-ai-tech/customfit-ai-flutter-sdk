# CustomFit Flutter SDK

[![pub package](https://img.shields.io/pub/v/customfit_ai_flutter_sdk.svg)](https://pub.dev/packages/customfit_ai_flutter_sdk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2.3%2B-blue)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20Android%20%7C%20Web%20%7C%20Desktop-blue)](https://flutter.dev/multi-platform)
[![Documentation](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://docs.customfit.ai/docs/flutter)

A comprehensive Flutter SDK for integrating with CustomFit's feature flagging, A/B testing, and event tracking services. Built with performance, reliability, and developer experience in mind.

## Table of Contents

- [Key Features](#key-features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [User Management](#user-management)
- [Feature Flags](#feature-flags)
- [Event Tracking](#event-tracking)
- [Session Management](#session-management)
- [Listeners & Callbacks](#listeners--callbacks)
- [Offline Support](#offline-support)
- [Persistence Strategy](#persistence-strategy)
- [Battery Optimization](#battery-optimization)
- [Advanced Features](#advanced-features)
- [Error Handling](#error-handling)
- [Flutter Integration](#flutter-integration)
- [Best Practices](#best-practices)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## Key Features

- 🚀 **Feature Flags** - Real-time feature toggles and configuration with multiple data types
- 🧪 **A/B Testing** - Split testing and experimentation capabilities
- 📊 **Event Tracking** - Comprehensive user analytics and behavior insights
- 👤 **User Context** - Rich user properties and personalized experiences
- 📱 **Cross-platform** - iOS, Android, Web, Desktop support
- ⚡ **Offline Support** - Robust offline mode with intelligent caching
- 🔄 **Real-time Updates** - Instant configuration changes via listeners
- 🛡️ **Error Resilience** - Comprehensive error handling and recovery
- 🔒 **Privacy Compliant** - Built-in privacy controls and data protection

### Feature Flag Types
- **Boolean flags**: Simple on/off toggles
- **String flags**: Text values, configuration strings  
- **Number flags**: Numeric values, thresholds, percentages
- **JSON flags**: Complex objects, configuration maps
- **Type-safe flags**: Compile-time safe flag definitions with IDE support

## Architecture

### SDK Structure

The CustomFit Flutter SDK follows a modular architecture designed for consistency across platforms:

```
lib/
├── src/
│   ├── analytics/
│   │   ├── event/          # Event tracking classes
│   │   └── summary/        # Analytics summaries
│   ├── client/
│   │   ├── listener/       # Feature flag and config change listeners
│   │   └── managers/       # Component managers (config, user, etc.)
│   ├── config/
│   │   ├── core/          # Core configuration classes
│   │   └── validation/    # Configuration validation
│   ├── constants/         # SDK constants
│   ├── core/
│   │   ├── error/         # Error handling and recovery
│   │   ├── model/         # Core data models
│   │   ├── session/       # Session management
│   │   ├── service_locator.dart  # Service locator pattern
│   │   └── util/          # Core utilities
│   ├── di/               # Dependency injection
│   ├── events/           # Event handling
│   ├── features/         # Type-safe feature flags
│   ├── lifecycle/        # Lifecycle management
│   ├── logging/          # Logging utilities
│   ├── monitoring/       # Performance monitoring
│   ├── network/
│   │   ├── config/       # Configuration fetching
│   │   ├── connection/   # Network connectivity monitoring
│   │   └── efficiency/   # Network optimization
│   ├── platform/         # Platform-specific integrations
│   ├── services/         # SDK services
│   └── testing/          # Testing utilities
├── customfit_ai_flutter_core.dart  # Core implementation
└── customfit_ai_flutter_sdk.dart      # Main entry point (use this for imports)
```

### Design Principles

1. **Consistency Across Platforms** - Structure mirrors Kotlin and Swift SDKs
2. **Separation of Concerns** - Each module has clear responsibilities
3. **Dependency Direction** - Higher-level components depend on lower-level ones
4. **Encapsulation** - Implementation details hidden behind interfaces
5. **Error Resilience** - Comprehensive error handling and recovery

### Core Components

- **CFClient** - Main SDK client (singleton pattern)
- **CFConfig** - Configuration management with builder pattern
- **CFUser** - User context and properties with builder pattern
- **HttpClient** - Network communication with connection pooling
- **EventTracker** - Analytics and event tracking
- **SessionManager** - Session lifecycle management
- **ConnectionManager** - Network connectivity monitoring

## Installation

### Prerequisites

- Flutter 3.0.0 or higher
- Dart 3.2.3 or higher

### Add to pubspec.yaml

```yaml
dependencies:
  customfit_ai_flutter_sdk: ^0.1.4
```

### Install Dependencies

```bash
flutter pub get
```

### Import the SDK

```dart
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
```

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Configuration with builder pattern
    // Note: build() returns CFResult<CFConfig>, use getOrThrow() to unwrap
    final config = CFConfig.builder('your-client-key')
        .setDebugLoggingEnabled(true)
        .setEventsFlushIntervalMs(60000)
        .setNetworkConnectionTimeoutMs(10000)
        .build()
        .getOrThrow();  // Required: unwrap CFResult

    // Or use convenient factory methods:
    // final config = CFConfig.development('your-client-key');  // For development
    // final config = CFConfig.production('your-client-key');   // For production
    // final config = CFConfig.smart('your-client-key');        // Auto-detects environment

    // Create user with builder pattern
    final user = CFUser.builder('user-123')
        .addStringProperty('email', 'user@example.com')
        .addStringProperty('plan', 'premium')
        .addStringProperty('platform', 'Flutter')
        .addNumberProperty('age', 25)
        .addBooleanProperty('betaUser', true)
        .addJsonProperty('preferences', {
          'theme': 'dark',
          'notifications': true,
        })
        .build();

    // Initialize SDK
    final client = await CFClient.initialize(config, user);
    print('CustomFit SDK initialized successfully');

  } catch (e) {
    print('Failed to initialize CustomFit SDK: $e');
  }

  runApp(MyApp());
}
```

### 2. Use Feature Flags

```dart
final client = CFClient.getInstance();

// Recommended: Use getValue<T>() for type-safe flag evaluation
bool isEnabled = client?.getValue<bool>('newFeature', false) ?? false;
String theme = client?.getValue<String>('appTheme', 'light') ?? 'light';
double discountPercentage = client?.getValue<double>('discountPercentage', 0.0) ?? 0.0;
Map<String, dynamic> config = client?.getValue<Map<String, dynamic>>('featureConfig', {}) ?? {};

// Alternative: Use the featureFlags component
// bool isEnabled = client?.featureFlags.getBoolean('newFeature', false) ?? false;
// String theme = client?.featureFlags.getString('appTheme', 'light') ?? 'light';
```

### 3. Track Events

```dart
// Track a simple event
final result = await client?.trackEvent('buttonClicked');
if (result?.isSuccess != true) {
  print('Failed to track: ${result?.getErrorMessage()}');
}

// Track event with properties
await client?.trackEvent('purchaseCompleted', properties: {
  'productId': 'prod-123',
  'amount': 99.99,
  'currency': 'USD',
  'paymentMethod': 'creditCard',
  'platform': 'Flutter',
});

// Flush events immediately (useful before app termination)
await client?.flushEvents();
```

## Configuration

The CustomFit Flutter SDK provides flexible configuration options using factory methods or the builder pattern.

#### Factory Methods (Recommended for Simple Setup)

```dart
// Auto-detect environment based on debug mode (recommended)
final config = CFConfig.smart('your-client-key');

// Explicit environment selection
final config = CFConfig.development('your-client-key');
final config = CFConfig.production('your-client-key');
final config = CFConfig.testing('your-client-key');

// Minimal configuration
final config = CFConfig.simple('your-client-key');
```

#### Basic Configuration with Builder

```dart
// Note: build() returns CFResult<CFConfig>, use getOrThrow() to unwrap
final config = CFConfig.builder('your-client-key')
    .build()
    .getOrThrow();
```

#### Advanced Configuration

```dart
final config = CFConfig.builder('your-client-key')
    // Logging
    .setDebugLoggingEnabled(true)
    .setLogLevel('debug')  // 'debug', 'info', 'warning', 'error'

    // Events & Summaries
    .setEventsFlushIntervalMs(3000)
    .setEventsFlushTimeSeconds(3)
    .setSummariesFlushIntervalMs(5000)
    .setSummariesFlushTimeSeconds(5)

    // Network
    .setNetworkConnectionTimeoutMs(10000)
    .setNetworkReadTimeoutMs(10000)

    // Polling
    .setSdkSettingsCheckIntervalMs(10000)
    .setBackgroundPollingIntervalMs(10000)
    .setReducedPollingIntervalMs(10000)

    // Offline & Storage
    .setOfflineMode(false)
    .setLocalStorageEnabled(true)
    .setMaxStoredEvents(500)

    .build()
    .getOrThrow();
```



#### Auto-Refresh Configuration

```dart
final config = CFConfig.builder('your-client-key')
    // Auto-refresh flags when events are flushed
    .setAutoRefreshOnEventFlush(true)
    .setAutoRefreshDelayMs(100)

    // Auto-refresh flags when user properties change
    .setAutoRefreshOnUserChange(true)
    .setUserChangeRefreshDebounceMs(500)

    .build()
    .getOrThrow();
```

### Enterprise Configuration

For enterprise deployments with custom infrastructure:

```dart
final config = CFConfig.builder('your-enterprise-key')
    .setDebugLoggingEnabled(false)
    .setEventsFlushIntervalMs(30000)      // More frequent flushing
    .setNetworkConnectionTimeoutMs(15000) // Longer timeout for internal networks
    .setOfflineMode(false)
    .setSummariesFlushIntervalMs(300000)  // 5 minutes
    .setMaxStoredEvents(500)              // Higher capacity
    .build()
    .getOrThrow();
```

## User Management

### Creating Users with Builder Pattern

```dart
// Basic user
final user = CFUser.builder('user123').build();

// User with properties
final user = CFUser.builder('user123')
    .addStringProperty('email', 'user@example.com')
    .addStringProperty('plan', 'premium')
    .addNumberProperty('age', 25)
    .addBooleanProperty('beta_user', true)
    .addJsonProperty('preferences', {
      'theme': 'dark',
      'notifications': true,
    })
    .build();

// Anonymous user
final anonymousUser = CFUser.anonymousBuilder()
    .addStringProperty('source', 'mobile_app')
    .build();
```

### Updating User Context

```dart
final client = CFClient.getInstance();

// Add properties using the user component (recommended pattern)
client?.user.addProperty('plan', 'enterprise');  // Generic method for any type
client?.user.addProperty('premium_access', true);
client?.user.addProperty('usage_count', 42);
client?.user.addProperty('state', 'Karnataka');

// Or add multiple properties at once
client?.user.addProperties({
  'subscription_tier': 'pro',
  'notifications': true,
  'is_logged_in': true,
});

// Type-specific methods also available
client?.user.addStringProperty('plan', 'enterprise');
client?.user.addBooleanProperty('premium_access', true);
client?.user.addNumberProperty('usage_count', 42);

// JSON properties for complex data
client?.user.addJsonProperty('preferences', {
  'notifications': true,
  'theme': 'dark'
});
```

### Runtime Property Management

```dart
final client = CFClient.getInstance();

// Get current user properties
Map<String, dynamic> props = client?.user.getUserProperties() ?? {};

// Remove properties
client?.user.removeProperty('temp_flag');
client?.user.removeProperties(['temp_a', 'temp_b']);

// Mark properties as private (excluded from analytics)
client?.user.markPropertyAsPrivate('email');
client?.user.markPropertiesAsPrivate(['phone', 'address']);

// Get current user object
CFUser? currentUser = client?.user.getUser();

// Clear user (useful for logout)
await client?.user.clearUser();
```

### Privacy and Security

The SDK provides built-in privacy controls to mark sensitive data as private or session-level, ensuring compliance with data protection regulations.

#### Private Fields

Private fields are excluded from analytics and logs to protect sensitive user information:

```dart
// Mark properties as private using boolean flags
final user = CFUser.builder('user123')
    .addStringProperty('email', 'user@example.com', isPrivate: true)
    .addStringProperty('name', 'John Doe')  // Not private
    .addNumberProperty('ssn', 123456789, isPrivate: true)
    .addBooleanProperty('verified', true, isPrivate: true)
    .addMapProperty('preferences', {'theme': 'dark'}, isPrivate: true)
    .addJsonProperty('metadata', {'version': '1.0'}, isPrivate: true)
    .addGeoPointProperty('location', 37.7749, -122.4194, isPrivate: true)
    .build();

// Mark existing properties as private
final updatedUser = user.markPropertyAsPrivate('email');

// Using instance methods with privacy flags
final user2 = CFUser(userCustomerId: 'user456')
    .addStringProperty('phone', '+1234567890', isPrivate: true)
    .addNumberProperty('age', 25)  // Not private
    .addBooleanProperty('premium', true, isPrivate: true);
```

#### Session-Level Fields

Session-level fields are temporary data that should not be persisted beyond the current session:

```dart
// Mark properties as session-level using boolean flags
final user = CFUser.builder('user123')
    .addStringProperty('session_token', 'abc123', isSession: true)
    .addStringProperty('name', 'John Doe')  // Persistent
    .addNumberProperty('temp_score', 100, isSession: true)
    .addBooleanProperty('temp_flag', true, isSession: true)
    .addMapProperty('temp_data', {'key': 'value'}, isSession: true)
    .build();

// Mark existing properties as session-level
final updatedUser = user.makeAttributeSessionLevel('temp_token');

// Using instance methods with session flags
final user2 = CFUser(userCustomerId: 'user456')
    .addStringProperty('temp_id', 'xyz789', isSession: true)
    .addNumberProperty('session_count', 5, isSession: true);
```

#### Combined Privacy Controls

You can combine both private and session flags for maximum control:

```dart
final user = CFUser.builder('user123')
    .addStringProperty('email', 'user@example.com', isPrivate: true)
    .addStringProperty('session_token', 'abc123', isSession: true)
    .addStringProperty('temp_private_data', 'sensitive', isPrivate: true, isSession: true)
    .addStringProperty('name', 'John Doe')  // Normal property
    .build();
```

#### Backend Format

The SDK automatically serializes private and session fields to match the backend format:

```json
{
  "user_customer_id": "user123",
  "anonymous": false,
  "properties": {
    "name": "John Doe",
    "email": "user@example.com",
    "session_token": "abc123"
  },
  "private_fields": {
    "properties": ["email"]
  },
  "session_fields": {
    "properties": ["session_token"]
  }
}
```



#### Privacy Best Practices

1. **Mark PII as Private**: Always mark personally identifiable information as private
2. **Use Session Fields for Temporary Data**: Session tokens, temporary scores, etc.
3. **Regular Audits**: Review which fields are marked as private/session
4. **Compliance**: Ensure privacy settings align with GDPR, CCPA requirements

```dart
// Example: E-commerce user with proper privacy controls
final user = CFUser.builder('customer123')
    // Public properties
    .addStringProperty('plan', 'premium')
    .addNumberProperty('age', 30)
    .addBooleanProperty('newsletter_subscribed', true)
    
    // Private properties (PII)
    .addStringProperty('email', 'user@example.com', isPrivate: true)
    .addStringProperty('phone', '+1234567890', isPrivate: true)
    .addStringProperty('address', '123 Main St', isPrivate: true)
    
    // Session properties (temporary)
    .addStringProperty('cart_token', 'cart_abc123', isSession: true)
    .addNumberProperty('session_duration', 1800, isSession: true)
    .addBooleanProperty('checkout_started', true, isSession: true)
    
    .build();
```

## Feature Flags

### Unified API (Recommended)

Use `getValue<T>()` for type-safe flag evaluation:

```dart
final client = CFClient.getInstance();

// Boolean flags
bool isEnabled = client?.getValue<bool>('new_feature', false) ?? false;

// String flags
String theme = client?.getValue<String>('app_theme', 'light') ?? 'light';

// Number flags
double threshold = client?.getValue<double>('conversion_threshold', 0.5) ?? 0.5;
int maxRetries = client?.getValue<int>('max_retries', 3) ?? 3;

// JSON flags
Map<String, dynamic> config = client?.getValue<Map<String, dynamic>>('feature_config', {}) ?? {};
```

### Component API (Alternative)

Access flags via the `featureFlags` component:

```dart
final flags = client?.featureFlags;

bool isEnabled = flags?.getBoolean('new_feature', false) ?? false;
String theme = flags?.getString('app_theme', 'light') ?? 'light';
double threshold = flags?.getNumber('conversion_threshold', 0.5) ?? 0.5;
Map<String, dynamic> config = flags?.getJson('feature_config', {}) ?? {};
```

### Utility Methods

```dart
// Check if a flag exists
bool exists = client?.flagExists('feature_key') ?? false;

// Get all flags as a map
Map<String, dynamic> allFlags = client?.getAllFlags() ?? {};
```

### Advanced Flag Usage

```dart
// Using flag values in business logic
final maxRetries = client?.getValue<double>('api_max_retries', 3.0)?.toInt() ?? 3;
final timeout = client?.getValue<double>('api_timeout_ms', 5000.0)?.toInt() ?? 5000;

// Configure components based on flags
final apiClient = HttpClient(
  maxRetries: maxRetries,
  timeout: Duration(milliseconds: timeout),
);

// Feature rollout with percentage
final rolloutPercentage = client?.getValue<double>('feature_rollout', 0.0) ?? 0.0;
final userId = user.userCustomerId ?? '';
final userHash = userId.hashCode.abs() % 100;
final shouldShowFeature = userHash < (rolloutPercentage * 100);
```

### Type-Safe Feature Flags

The SDK provides a type-safe API for feature flags that eliminates runtime errors from typos and type mismatches:

```dart
final client = CFClient.getInstance();
final flags = client?.typed;

// Define strongly-typed flags
final enableNewUI = flags?.boolean(
  key: 'enable_new_ui',
  defaultValue: false,
  description: 'Enables the new dashboard UI',
);

final apiEndpoint = flags?.string(
  key: 'api_endpoint',
  defaultValue: 'https://api.production.com',
  allowedValues: ['https://api.production.com', 'https://api.staging.com'],
);

final maxUploadSize = flags?.number(
  key: 'max_upload_size_mb',
  defaultValue: 10.0,
  min: 1.0,
  max: 100.0,
  description: 'Maximum file upload size in MB',
);

// Use flags with compile-time safety
if (enableNewUI?.value ?? false) {
  print('New UI is enabled');
}

print('API endpoint: ${apiEndpoint?.value}');
print('Max upload: ${maxUploadSize?.value}MB');
```

#### Advanced Type-Safe Usage

```dart
// Enum flags for A/B testing
enum ExperimentGroup { control, variantA, variantB }

final experimentGroup = flags?.enumFlag<ExperimentGroup>(
  key: 'experiment_group',
  defaultValue: ExperimentGroup.control,
  values: ExperimentGroup.values,
);

// JSON flags with custom types
class UIConfig {
  final String primaryColor;
  final bool darkMode;
  
  UIConfig({required this.primaryColor, required this.darkMode});
  
  factory UIConfig.fromJson(Map<String, dynamic> json) {
    return UIConfig(
      primaryColor: json['primaryColor'] ?? '#007AFF',
      darkMode: json['darkMode'] ?? false,
    );
  }
}

final uiConfig = flags?.json<UIConfig>(
  key: 'ui_config',
  defaultValue: UIConfig(primaryColor: '#007AFF', darkMode: false),
  parser: (json) => UIConfig.fromJson(json),
);

// Listen to flag changes
enableNewUI?.onChange((enabled) {
  print('New UI flag changed to: $enabled');
});

// Quick flags for simple cases  
final quickFlags = QuickFlags(provider);
final debugMode = quickFlags.boolFlag('debug_mode', false);
```

#### Benefits of Type-Safe Flags

- **Compile-time safety**: Catch typos and type mismatches during development
- **IDE autocomplete**: Full IntelliSense support for flag names and values
- **Type validation**: Automatic validation and parsing of flag values
- **Change listeners**: Reactive streams for flag value changes
- **Constraints**: Built-in support for min/max values, allowed values, etc.

## Event Tracking

### Basic Event Tracking

```dart
final client = CFClient.getInstance();

// Simple event with result handling
final result = await client?.trackEvent('button_clicked');
if (result?.isSuccess != true) {
  print('Failed to track: ${result?.getErrorMessage()}');
}

// Event with properties
await client?.trackEvent('purchase_completed', properties: {
  'product_id': 'abc123',
  'price': 29.99,
  'currency': 'USD',
  'payment_method': 'credit_card',
  'platform': 'Flutter',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});

// Track conversion events
await client?.trackConversion('checkout_complete', {
  'order_id': 'order-123',
  'total': 99.99,
  'items_count': 3,
});
```

### Event Queue Management

```dart
// Flush all pending events immediately
await client?.flushEvents();

// Get count of pending events
int pendingCount = client?.getPendingEventCount() ?? 0;
print('Pending events: $pendingCount');
```

### Advanced Analytics

```dart
// Track feature usage
await client?.trackEvent('feature_used', properties: {
  'feature_name': 'premium_dashboard',
  'usage_duration': 120, // seconds
  'interactions': 5,
  'user_satisfaction': 4.5,
});

// Track user journey
await client?.trackEvent('user_journey', properties: {
  'step': 'onboarding_complete',
  'time_to_complete': 300, // seconds
  'completion_rate': 0.85,
  'drop_off_point': null,
});
```

## Session Management

Sessions are automatically managed by the SDK with configurable rotation policies:

```dart
// Sessions rotate automatically based on:
// - Time intervals (configurable)
// - User authentication changes
// - App state transitions (background/foreground)

// Access current session info using the session component (recommended)
final client = CFClient.getInstance();
final sessionId = client?.session.getCurrentSessionId();
final sessionData = client?.session.getCurrentSessionData();

// Force session rotation
await client?.session.forceSessionRotation();

// Get session statistics
final stats = client?.session.getSessionStatistics();

```

## Listeners & Callbacks

### Configuration Listeners (Recommended)

Use typed listeners for real-time flag updates. This is the primary listener API:

```dart
final client = CFClient.getInstance();

// String flag listener
client?.addConfigListener<String>('app_theme', (newValue) {
  print('Theme changed to: $newValue');
  setState(() => _theme = newValue);
});

// Boolean flag listener
client?.addConfigListener<bool>('new_feature', (isEnabled) {
  print('Feature enabled: $isEnabled');
  setState(() => _featureEnabled = isEnabled);
});

// Number flag listener
client?.addConfigListener<double>('discount_rate', (rate) {
  print('Discount rate: $rate');
  setState(() => _discountRate = rate);
});

// JSON flag listener
client?.addConfigListener<Map<String, dynamic>>('user_config', (config) {
  print('Config updated: $config');
  setState(() => _userConfig = config);
});
```

### Removing Listeners

```dart
// Remove listener for specific flag
client?.removeConfigListener('app_theme');

// Clear listeners for specific flag
client?.clearConfigListeners('app_theme');

// Clear all listeners (recommended in dispose())
client?.clearAllConfigListeners();
```

### Feature Flag Listeners (Alternative)

For listeners that need both old and new values:

```dart
// Listen to specific flag changes (receives key, old value, new value)
client?.addFeatureFlagListener('new_feature', (flagKey, oldValue, newValue) {
  print('Flag $flagKey changed from $oldValue to $newValue');
});

// Listen to all flag changes
client?.addAllFlagsListener((oldFlags, newFlags) {
  print('Flags updated');
  // Compare oldFlags and newFlags to find changes
});

// Remove listeners
client?.removeFeatureFlagListener('new_feature', listenerCallback);
client?.removeAllFlagsListener(allFlagsCallback);
```

## SDK Lifecycle Management

### Initialization

```dart
// Standard initialization
final client = await CFClient.initialize(config, user);

// With automatic retry on network failures
final client = await CFClient.initializeWithRetry(
  config,
  user,
  maxRetries: 5,
  initialDelayMs: 1000,
);

// Check initialization state
bool isReady = CFClient.isInitialized();
bool isStarting = CFClient.isInitializing();
```

### User Switching (Login/Logout)

When a user logs in or out, reinitialize the SDK with the new user context:

```dart
Future<void> switchUser(String newUserId) async {
  final client = CFClient.getInstance();

  // Step 1: Remove existing listeners first
  client?.clearAllConfigListeners();

  // Step 2: Create new user
  final newUser = CFUser.builder(newUserId)
      .addStringProperty('platform', 'Flutter')
      .addBooleanProperty('is_logged_in', true)
      .build();

  // Step 3: Reinitialize with new user (handles shutdown automatically)
  final newClient = await CFClient.reinitialize(config, newUser);

  // Step 4: Re-register listeners
  _setupListeners(newClient);

  // Step 5: Force refresh to get user-specific flags
  await newClient.forceRefresh();
}

Future<void> logout() async {
  final client = CFClient.getInstance();
  client?.clearAllConfigListeners();

  // Create anonymous user
  final anonymousUser = CFUser.anonymousBuilder()
      .addStringProperty('platform', 'Flutter')
      .addBooleanProperty('is_logged_in', false)
      .build();

  await CFClient.reinitialize(config, anonymousUser);
}
```

### Manual Refresh

```dart
// Force fetch latest configuration from server
final success = await client?.forceRefresh();
if (success == true) {
  print('Flags refreshed successfully');
}

// Flush pending events before refresh (recommended pattern)
await client?.flushEvents();
await client?.forceRefresh();
```

### Offline Mode

Toggle offline mode at runtime:

```dart
// Enable offline mode (SDK uses cached values)
client?.setOffline(true);

// Disable offline mode (SDK fetches from server)
client?.setOffline(false);

// Check current state
bool isOffline = client?.isOffline() ?? false;
```

### Shutdown

```dart
// Shutdown singleton instance (recommended for app termination)
await CFClient.shutdownSingleton();

// Or shutdown via instance method
await client?.shutdown();

// Clear instance for testing purposes
CFClient.clearInstance();
```

## Offline Support

The SDK provides robust offline capabilities:

```dart
// Enable offline mode
final config = CFConfig.builder('your-client-key')
    .setOfflineMode(true)
    .setMaxStoredEvents(1000)
    .setLocalStorageEnabled(true)
    .build();

// The SDK will:
// - Cache feature flag values locally
// - Queue events for later transmission
// - Use cached configurations when offline
// - Automatically sync when connection is restored
```

### Offline Behavior

- **Feature Flags**: Served from local cache with configurable TTL
- **Events**: Queued locally and transmitted when online
- **Configuration**: Cached with stale-while-revalidate strategy
- **Recovery**: Automatic retry with exponential backoff

## Event Persistence and Offline Support

The Flutter SDK provides comprehensive event persistence to ensure no analytics data is lost, even when the device is offline or the app is terminated.

### Event Persistence Strategy

Events are automatically persisted using SharedPreferences with the `PersistentEventQueue` class:

- **Storage Mechanism**: SharedPreferences
- **Storage Class**: `PersistentEventQueue` with 100ms debounce
- **Queue Size Limit**: Maximum 100 events (configurable)
- **Persistence Triggers**: 
  - Network failures
  - App background/termination
  - Queue size threshold reached
  - Automatic persistence with 100ms debounce

### Storage Mechanism

The SDK uses `PersistentEventQueue` to ensure no events are lost:

```dart
// Events are stored in SharedPreferences
// Key pattern: customfit_events_queue

// The PersistentEventQueue automatically persists events with:
// - 100ms debounce for efficient writes
// - Automatic persistence on network failure
// - Queue size limit triggers persistence
// - Background state triggers persistence

// Events are automatically saved when:
// 1. Network is unavailable
// 2. Queue reaches size limit (default: 100 events)
// 3. App goes to background
// 4. 100ms after any change (debounced)
```

### Configuration Options

```dart
final config = CFConfig.builder('your-client-key')
    // Event queue configuration
    .setEventsQueueSize(100)              // Max events in memory before persistence
    .setMaxStoredEvents(1000)             // Max events to persist
    .setEventsFlushIntervalMs(5000)       // Auto-flush interval
    
    // Cache TTL configuration
    .setConfigCacheTtlSeconds(300)        // Config cache: 5 minutes
    .setEventCacheTtlSeconds(3600)        // Event cache: 1 hour
    
    // Persistence settings
    .setLocalStorageEnabled(true)         // Enable local storage
    .setPersistCacheAcrossRestarts(true)  // Persist cache between app restarts
    .build();
```

### Automatic Event Recovery

Events are automatically recovered and retransmitted when:

1. **App Launch**: Persisted events are loaded from SharedPreferences
2. **Network Restored**: Queued events are sent when connectivity returns
3. **Foreground Transition**: Background events are synced
4. **SDK Initialization**: Any pending events are processed

### Cache TTL Values

The SDK implements different TTL (Time To Live) values for various cached data:

| Data Type | TTL | Description |
|-----------|-----|-------------|
| Configuration | 5 minutes | Feature flags and SDK settings |
| User Data | 24 hours | User properties and context |
| Events | Persistent | Never expires until successfully sent |
| Session Data | 30 minutes | Active session information |

### Best Practices for Event Persistence

```dart
// 1. Configure appropriate queue sizes
final config = CFConfig.builder('your-client-key')
    .setEventsQueueSize(100)        // Smaller for mobile to save memory
    .setMaxStoredEvents(500)        // Reasonable limit for storage
    .setLocalStorageEnabled(true)    // Ensure persistence is enabled
    .build();

// 2. Handle critical events
await client?.trackEvent('purchase_completed', properties: {
  'amount': 99.99,
  'product_id': 'premium_plan',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});

// 3. Flush all queued events
await client?.flushEvents();   // Send all queued events
```

### Offline Event Tracking Flow

```dart
// Events are handled seamlessly offline
await client?.trackEvent('offline_action', properties: {
  'network_status': 'offline',
  'action': 'button_tap',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});

// The SDK will:
// 1. Add event to PersistentEventQueue
// 2. Detect network failure
// 3. Persist to SharedPreferences with 100ms debounce
// 4. Retry when network is restored
// 5. Remove from storage after successful transmission
```

### Platform-Specific Considerations

```dart
// iOS - Events persist across app terminations
if (Platform.isIOS) {
  // SharedPreferences backed by NSUserDefaults
  // Data persists until app is uninstalled
}

// Android - Events persist with SharedPreferences
if (Platform.isAndroid) {
  // SharedPreferences in private mode
  // Data persists until app data is cleared
}

// Web - Events persist in localStorage
if (kIsWeb) {
  // localStorage with domain isolation
  // Data persists until browser cache is cleared
}

// Configure for optimal persistence
final config = CFConfig.builder('your-client-key')
    .setPersistCacheAcrossRestarts(true)
    .setUseStaleWhileRevalidate(true)    // Use cached data while updating
    .setMaxCacheSizeMb(50)               // Limit cache size
    .build();
```

## Persistence Strategy

The Flutter SDK implements a multi-layered persistence strategy to ensure data durability and optimal performance:

### Cache Layers
- **Memory Cache**: Fast in-memory storage with LRU eviction  
- **Disk Cache**: SharedPreferences and file-based storage for larger payloads
- **Event Queue**: Persistent queue with 100ms debounce writes

### TTL Policies
| Data Type | TTL | Storage Layer |
|-----------|-----|---------------|
| Config | 5 minutes | Memory + Disk |
| User Data | 24 hours | Memory + Disk |
| Events | Persistent | Disk only |
| Session | 30 minutes | Memory only |

### Storage Mechanisms
- **SharedPreferences**: Metadata and small configs (<100KB)
- **File Storage**: Large configurations and event queues
- **Memory Cache**: Hot data with automatic cleanup

## Battery Optimization

The SDK includes intelligent battery optimization features to reduce power consumption on mobile devices:

### Automatic Battery-Aware Polling

When the device battery is low, the SDK automatically reduces polling frequency to conserve power:

```dart
final config = CFConfig.builder('your-client-key')
    .setUseReducedPollingWhenBatteryLow(true)  // Enable battery optimization
    .setReducedPollingIntervalMs(300000)       // Poll every 5 minutes when battery is low
    .setBackgroundPollingIntervalMs(60000)     // Normal background polling: 1 minute
    .build();
```

### Battery Optimization Features

- **Adaptive Polling**: Automatically switches to reduced polling intervals when battery is low
- **Smart Thresholds**: Considers both battery level and charging state
- **Background Optimization**: Further reduces activity when app is in background
- **Event Batching**: Consolidates network requests to minimize radio usage

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `useReducedPollingWhenBatteryLow` | Enable battery-aware polling | `true` |
| `reducedPollingIntervalMs` | Polling interval when battery is low | `300000` (5 min) |
| `backgroundPollingIntervalMs` | Normal background polling interval | `60000` (1 min) |
| `disableBackgroundPolling` | Completely disable background polling | `false` |

### Battery State Detection

The SDK automatically detects battery state on supported platforms:

```dart
// The SDK monitors:
// - Battery level (low threshold typically < 20%)
// - Charging state (optimization disabled when charging)
// - Power save mode (respects system power saving settings)
```

### Best Practices for Battery Optimization

1. **Use Appropriate Intervals**: Balance between data freshness and battery life
   ```dart
   .setReducedPollingIntervalMs(300000)  // 5 minutes is a good default
   ```

2. **Consider Disabling Background Polling**: For non-critical features
   ```dart
   .setDisableBackgroundPolling(true)  // Completely stops background polling
   ```

3. **Leverage Event Batching**: Group events to reduce network calls
   ```dart
   .setEventsFlushIntervalMs(30000)  // Flush events every 30 seconds
   .setEventsQueueSize(50)           // Or when 50 events accumulate
   ```

4. **Platform Considerations**:
   - **iOS**: Integrates with iOS background modes and low power mode
   - **Android**: Respects Doze mode and app standby restrictions
   - **Web/Desktop**: Battery optimization has minimal effect

### Monitoring Battery Impact

The SDK automatically handles battery optimization internally. You can track battery-related events:

```dart
// Track battery optimization events
client?.trackEvent('battery_optimization_active', properties: {
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});
```

## Advanced Features

### Certificate Pinning

Implement certificate pinning for enhanced security in production environments:

```dart
// Production configuration with certificate pinning
final secureConfig = CFConfig.builder('your-client-key')
    .setCertificatePinningEnabled(true)
    .setPinnedCertificates([
      'sha256/PRIMARY_CERT_FINGERPRINT',
      'sha256/BACKUP_CERT_FINGERPRINT'
    ])
    .build();

// The SDK will:
// - Validate server certificates against pinned fingerprints
// - Reject connections with unpinned certificates
// - Log certificate validation failures
// - Provide detailed error information for debugging
```

### Custom Evaluation Contexts

```dart
// Add location context
final locationContext = EvaluationContext(
  type: ContextType.location,
  properties: {
    'country': 'US',
    'region': 'California',
    'city': 'San Francisco',
  },
);

// Add device context
final deviceContext = EvaluationContext(
  type: ContextType.device,
  properties: {
    'platform': 'iOS',
    'version': '15.0',
    'model': 'iPhone 13',
  },
);

final user = CFUser.builder('user123')
    .addContext(locationContext)
    .addContext(deviceContext)
    .build();
```

### Error Handling and Recovery

```dart
try {
  final client = await CFClient.initialize(config, user);
  
  // The SDK includes automatic:
  // - Session recovery on failures
  // - Event retry with exponential backoff
  // - Configuration fallback mechanisms
  // - Network error handling
  
} catch (e) {
  print('Initialization failed: $e');
  // Implement fallback behavior
}
```

## Component APIs

The SDK provides component accessors for organized API access.

### User Component (`client.user`)

```dart
final client = CFClient.getInstance();

// Set a completely new user
await client?.user.setUser(newUser);

// Get current user
CFUser? currentUser = client?.user.getUser();

// Clear user (useful for logout)
await client?.user.clearUser();

// Add properties dynamically
client?.user.addProperty('is_logged_in', true);
client?.user.addProperty('plan', 'premium');
client?.user.addProperties({
  'subscription_tier': 'pro',
  'notifications_enabled': true,
});

// Get current properties
Map<String, dynamic> props = client?.user.getUserProperties() ?? {};

// Remove properties
client?.user.removeProperty('temp_flag');
client?.user.removeProperties(['temp_a', 'temp_b']);

// Privacy controls
client?.user.markPropertyAsPrivate('email');
client?.user.markPropertiesAsPrivate(['phone', 'address']);

// Context management
client?.user.addContext(locationContext);
client?.user.removeContext(ContextType.location, 'primary');
List<EvaluationContext> contexts = client?.user.getContexts() ?? [];
```

### Session Component (`client.session`)

```dart
// Get session information
String? sessionId = client?.session.getCurrentSessionId();
SessionData? sessionData = client?.session.getCurrentSessionData();

// Force session rotation
await client?.session.forceSessionRotation();

// Update session activity (for custom activity tracking)
await client?.session.updateSessionActivity();

// Handle authentication changes
client?.session.onUserAuthenticationChange(userId);

// Get session statistics
Map<String, dynamic> stats = client?.session.getSessionStatistics() ?? {};

// Check initialization status
bool isReady = client?.session.isInitialized ?? false;
```

### Recovery Component (`client.recovery`)

```dart
// Perform system health check
final healthResult = await client?.recovery.performSystemHealthCheck();
if (healthResult?.isSuccess == true) {
  final status = healthResult?.getOrNull();
  print('Overall status: ${status?.overallStatus}');
  print('Config manager healthy: ${status?.configManagerHealthy}');
  print('Event tracker healthy: ${status?.eventTrackerHealthy}');
}

// Recover session with optional auth token refresh
await client?.recovery.recoverSession(
  reason: 'manual_recovery',
  authTokenRefreshCallback: () async => 'new-auth-token',
);
```

### Feature Flags Component (`client.featureFlags`)

```dart
// Type-specific getters (alternative to getValue<T>)
bool isEnabled = client?.featureFlags.getBoolean('feature', false) ?? false;
String theme = client?.featureFlags.getString('theme', 'light') ?? 'light';
double rate = client?.featureFlags.getNumber('rate', 0.0) ?? 0.0;
Map<String, dynamic> config = client?.featureFlags.getJson('config', {}) ?? {};

// Get all flags
Map<String, dynamic> allFlags = client?.featureFlags.getAllFlags() ?? {};

// Check flag existence
bool exists = client?.featureFlags.flagExists('feature_key') ?? false;
```

### Events Component (`client.events`)

```dart
// Track events via component
await client?.events.trackEvent('button_clicked');
await client?.events.trackEventWithProperties('purchase', {'amount': 99.99});
await client?.events.trackConversion('checkout', {'order_id': '123'});

// Lifecycle events
await client?.events.trackLifecycleEvent('app_opened', {'source': 'notification'});

// Flush events
await client?.events.flushEvents();
```

## Error Handling

The SDK provides comprehensive error handling with the `CFResult<T>` wrapper for safe operations:

```dart
// Initialization errors
try {
  final client = await CFClient.initialize(config, user);
} on CFInitializationException catch (e) {
  print('SDK initialization failed: ${e.message}');
  // Handle initialization failure
} catch (e) {
  print('Unexpected error: $e');
}

// Runtime errors are handled gracefully
// Flag evaluations return default values on error
// Events are queued for retry on network errors
// Sessions are recovered automatically
```

## Flutter Integration

### State Management with Provider

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';

class CustomFitProvider extends ChangeNotifier {
  CFClient? _client;
  bool _isInitialized = false;

  // Feature flag values
  String _theme = 'light';
  bool _newFeatureEnabled = false;
  Map<String, dynamic> _userConfig = {};

  // Getters
  bool get isInitialized => _isInitialized;
  String get theme => _theme;
  bool get newFeatureEnabled => _newFeatureEnabled;
  Map<String, dynamic> get userConfig => _userConfig;

  Future<void> initialize(String userId) async {
    final config = CFConfig.builder('your-client-key')
        .setDebugLoggingEnabled(true)
        .setEventsFlushIntervalMs(5000)
        .build()
        .getOrThrow();

    final user = CFUser.builder(userId)
        .addStringProperty('platform', 'Flutter')
        .build();

    _client = await CFClient.initialize(config, user);
    _setupListeners();
    _loadInitialValues();
    _isInitialized = true;
    notifyListeners();
  }

  void _setupListeners() {
    // Typed config listeners for real-time updates
    _client?.addConfigListener<String>('app_theme', (value) {
      _theme = value;
      notifyListeners();
    });

    _client?.addConfigListener<bool>('new_feature', (value) {
      _newFeatureEnabled = value;
      notifyListeners();
    });

    _client?.addConfigListener<Map<String, dynamic>>('user_config', (value) {
      _userConfig = value;
      notifyListeners();
    });
  }

  void _loadInitialValues() {
    _theme = _client?.getValue<String>('app_theme', 'light') ?? 'light';
    _newFeatureEnabled = _client?.getValue<bool>('new_feature', false) ?? false;
    _userConfig = _client?.getValue<Map<String, dynamic>>('user_config', {}) ?? {};
  }

  Future<void> trackEvent(String event, [Map<String, dynamic>? properties]) async {
    await _client?.trackEvent(event, properties: properties ?? {});
  }

  Future<void> refreshFlags() async {
    await _client?.forceRefresh();
    _loadInitialValues();
    notifyListeners();
  }

  Future<void> switchUser(String newUserId, {bool isLoggedIn = true}) async {
    _client?.clearAllConfigListeners();

    final newUser = CFUser.builder(newUserId)
        .addStringProperty('platform', 'Flutter')
        .addBooleanProperty('is_logged_in', isLoggedIn)
        .build();

    _client = await CFClient.reinitialize(
      CFConfig.builder('your-client-key').build().getOrThrow(),
      newUser,
    );

    _setupListeners();
    await _client?.forceRefresh();
    _loadInitialValues();
    notifyListeners();
  }

  @override
  void dispose() {
    _client?.clearAllConfigListeners();
    CFClient.shutdownSingleton();
    super.dispose();
  }
}

// Usage in main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider(
      create: (_) => CustomFitProvider()..initialize('anonymous-user'),
      child: const MyApp(),
    ),
  );
}
```

### Alternative: Basic Provider Pattern

```dart
class FeatureFlagProvider extends ChangeNotifier {
  final CFClient? _client = CFClient.getInstance();
  Map<String, dynamic> _flags = {};

  Map<String, dynamic> get flags => _flags;

  void init() {
    _client?.addAllFlagsListener((flags) {
      _flags = flags;
      notifyListeners();
    });
  }

  bool getFeature(String key, bool defaultValue) {
    return _flags[key] as bool? ?? defaultValue;
  }
}

// With Bloc
class FeatureFlagBloc extends Bloc<FeatureFlagEvent, FeatureFlagState> {
  final CFClient? _client = CFClient.getInstance();

  FeatureFlagBloc() : super(FeatureFlagInitial()) {
    _client?.addAllFlagsListener((flags) {
      add(FlagsUpdated(flags));
    });
  }
}
```

### Widget Integration

```dart
// Feature flag widget wrapper
class FeatureFlag extends StatelessWidget {
  final String flagKey;
  final bool defaultValue;
  final Widget child;
  final Widget? fallback;

  const FeatureFlag({
    Key? key,
    required this.flagKey,
    required this.defaultValue,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final client = CFClient.getInstance();
    final isEnabled = client?.getValue<bool>(flagKey, defaultValue) ?? defaultValue;

    return isEnabled ? child : (fallback ?? const SizedBox.shrink());
  }
}

// Usage
FeatureFlag(
  flagKey: 'new_dashboard',
  defaultValue: false,
  child: NewDashboard(),
  fallback: OldDashboard(),
)
```

## Best Practices

### Performance Optimization

```dart
// 1. Initialize SDK early in app lifecycle
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeCustomFitSDK(); // Initialize before runApp
  runApp(MyApp());
}

// 2. Cache flag values to avoid repeated lookups
class FeatureCache {
  static final Map<String, dynamic> _cache = {};

  static bool getFeature(String key, bool defaultValue) {
    if (_cache.containsKey(key)) {
      return _cache[key] as bool;
    }

    final client = CFClient.getInstance();
    final value = client?.getValue<bool>(key, defaultValue) ?? defaultValue;
    _cache[key] = value;
    return value;
  }
}

// 3. Use listeners for reactive updates
client?.addConfigListener<bool>('feature_key', (value) {
  FeatureCache._cache['feature_key'] = value; // Update cache
});
```

### Error Resilience

```dart
// Always provide sensible defaults
bool isFeatureEnabled(String key) {
  final client = CFClient.getInstance();
  return client?.getValue<bool>(key, false) ?? false;
}

// Graceful degradation
Widget buildFeature() {
  try {
    if (isFeatureEnabled('new_ui')) {
      return NewUIComponent();
    }
  } catch (e) {
    debugPrint('Feature flag evaluation failed: $e');
  }
  return FallbackUIComponent();
}
```

### Analytics Best Practices

```dart
// Structure event properties consistently
await client?.trackEvent('user_action', properties: {
  'action_type': 'click',
  'element_id': 'submit_button',
  'page_name': 'checkout',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'session_id': client?.session.getCurrentSessionId(),
  'user_id': user.userCustomerId,
});

// Use semantic event names
await client?.trackEvent('checkout_completed'); // Good
await client?.trackEvent('button_click'); // Too generic
```

## API Reference

### CFClient

Main SDK client providing feature flags, event tracking, and user management.

```dart
class CFClient {
  // === Initialization (Static Methods) ===
  static Future<CFClient> initialize(CFConfig config, CFUser user);
  static Future<CFClient> initializeWithRetry(CFConfig config, CFUser user, {int maxRetries, int initialDelayMs});
  static Future<CFClient> reinitialize(CFConfig config, CFUser user);
  static CFClient? getInstance();
  static bool isInitialized();
  static bool isInitializing();
  static Future<void> shutdownSingleton();
  static void clearInstance();  // For testing

  // === Feature Flags (Recommended: getValue<T>) ===
  T getValue<T>(String key, T defaultValue);  // Recommended unified API
  Map<String, dynamic> getAllFlags();
  bool flagExists(String key);

  // === Event Tracking ===
  Future<CFResult<void>> trackEvent(String eventType, {Map<String, dynamic>? properties});
  Future<CFResult<void>> trackConversion(String conversionName, Map<String, dynamic> properties);
  Future<CFResult<void>> flushEvents();
  int getPendingEventCount();

  // === Configuration Listeners (Recommended) ===
  void addConfigListener<T>(String key, void Function(T) listener);
  void removeConfigListener(String key);
  void clearConfigListeners(String key);
  void clearAllConfigListeners();

  // === Feature Flag Listeners (Alternative) ===
  void addFeatureFlagListener(String flagKey, void Function(String, dynamic, dynamic) listener);
  void removeFeatureFlagListener(String flagKey, void Function(String, dynamic, dynamic) listener);
  void addAllFlagsListener(void Function(Map<String, dynamic>, Map<String, dynamic>) listener);
  void removeAllFlagsListener(void Function(Map<String, dynamic>, Map<String, dynamic>) listener);

  // === Runtime Configuration ===
  void setOffline(bool offline);
  bool isOffline();
  Future<bool> forceRefresh();
  Future<Map<String, dynamic>> fetchAndGetAllFlags({String? lastModified});

  // === Component Accessors ===
  CFClientFeatureFlags get featureFlags;   // client.featureFlags.getBoolean(...)
  CFClientEvents get events;               // client.events.trackEvent(...)
  CFClientListeners get listeners;         // client.listeners.addConfigListener(...)
  CFClientUserManagement get user;         // client.user.addProperty(...)
  CFClientSessionManagement get session;   // client.session.getCurrentSessionId()
  CFClientRecovery get recovery;           // client.recovery.performSystemHealthCheck()
  FeatureFlags get typed;                  // Type-safe feature flags

  // === Lifecycle ===
  Future<void> shutdown();
}
```

### CFConfig

Configuration builder for SDK initialization.

```dart
class CFConfig {
  // === Factory Methods (Recommended) ===
  static CFConfig simple(String clientKey);
  static CFConfig development(String clientKey);
  static CFConfig production(String clientKey);
  static CFConfig testing(String clientKey);
  static CFConfig smart(String clientKey);  // Auto-detects environment
  static Builder builder(String clientKey);

  // === Instance Properties ===
  String get clientKey;
  String get baseApiUrl;
  bool get debugLoggingEnabled;
  bool get offlineMode;
  int get eventsFlushIntervalMs;
  int get networkConnectionTimeoutMs;
  // ... additional properties
}

class Builder {
  // Logging
  Builder setDebugLoggingEnabled(bool enabled);
  Builder setLoggingEnabled(bool enabled);
  Builder setLogLevel(String level);  // 'debug', 'info', 'warning', 'error'

  // Events
  Builder setEventsQueueSize(int size);
  Builder setEventsFlushIntervalMs(int ms);
  Builder setEventsFlushTimeSeconds(int seconds);

  // Summaries
  Builder setSummariesQueueSize(int size);
  Builder setSummariesFlushIntervalMs(int ms);
  Builder setSummariesFlushTimeSeconds(int seconds);

  // Network
  Builder setNetworkConnectionTimeoutMs(int ms);
  Builder setNetworkReadTimeoutMs(int ms);
  Builder setSdkSettingsCheckIntervalMs(int ms);

  // Polling
  Builder setBackgroundPollingIntervalMs(int ms);
  Builder setReducedPollingIntervalMs(int ms);
  Builder setDisableBackgroundPolling(bool disabled);
  Builder setUseReducedPollingWhenBatteryLow(bool use);

  // Auto-refresh
  Builder setAutoRefreshOnEventFlush(bool enabled);
  Builder setAutoRefreshOnUserChange(bool enabled);
  Builder setAutoRefreshDelayMs(int ms);
  Builder setUserChangeRefreshDebounceMs(int ms);

  // Storage
  Builder setOfflineMode(bool enabled);
  Builder setLocalStorageEnabled(bool enabled);
  Builder setMaxStoredEvents(int max);
  Builder setConfigCacheTtlSeconds(int seconds);

  // Build (returns CFResult, not CFConfig!)
  CFResult<CFConfig> build();
}
```

### CFUser

User model with builder pattern for properties and contexts.

```dart
class CFUser {
  static CFUserBuilder builder(String userId);
  static CFUserBuilder anonymousBuilder();
  
  String? get userCustomerId;
  bool get anonymous;
  Map<String, dynamic> get properties;
  List<EvaluationContext> get contexts;
}

class CFUserBuilder {
  CFUserBuilder addStringProperty(String key, String value);
  CFUserBuilder addNumberProperty(String key, num value);
  CFUserBuilder addBooleanProperty(String key, bool value);
  CFUserBuilder addJsonProperty(String key, Map<String, dynamic> value);
  CFUserBuilder addGeoPointProperty(String key, double latitude, double longitude);
  CFUserBuilder makeAnonymous(bool anonymous);
  CFUserBuilder addContext(EvaluationContext context);
  CFUser build();
}
```

## Troubleshooting

### Common Issues

#### SDK Initialization Fails

```dart
// Check configuration build result
final configResult = CFConfig.builder('client-key')
    .setDebugLoggingEnabled(true)
    .build();

if (!configResult.isSuccess) {
  print('Config error: ${configResult.getErrorMessage()}');
  return;
}

final config = configResult.getOrThrow();

// Check user ID
if (user.userCustomerId == null || user.userCustomerId!.isEmpty) {
  throw Exception('User ID is required');
}

// Initialize with error handling
try {
  final client = await CFClient.initialize(config, user);
} on SDKInitializationException catch (e) {
  print('SDK init failed: ${e.message}');
  print('Failed at step: ${e.failedStep}');
  print('Completed steps: ${e.completedSteps}');
}

// Check initialization state
if (!CFClient.isInitialized()) {
  print('SDK not initialized');
}
```

#### Feature Flags Not Updating

```dart
// Verify listener registration (use addConfigListener)
client?.addConfigListener<bool>('flag_key', (newValue) {
  print('Flag updated to: $newValue');
});

// Check polling configuration
final config = CFConfig.builder('client-key')
    .setSdkSettingsCheckIntervalMs(30000) // Check every 30 seconds
    .build()
    .getOrThrow();

// Force refresh manually
final success = await client?.forceRefresh();
print('Refresh success: $success');

// The SDK automatically handles offline mode
// Feature flags will use cached values when offline
```

#### Events Not Being Sent

```dart
// Check event queue configuration
final config = CFConfig.builder('client-key')
    .setEventsFlushIntervalMs(5000) // Flush every 5 seconds
    .setEventsQueueSize(50) // Flush when 50 events queued
    .build()
    .getOrThrow();

// Verify event structure and check result
final result = await client?.trackEvent('valid_event', properties: {
  'string_prop': 'value',
  'number_prop': 123,
  'boolean_prop': true,
  'platform': 'Flutter',
});

if (result?.isSuccess != true) {
  print('Event tracking failed: ${result?.getErrorMessage()}');
}

// Force flush events
await client?.flushEvents();

// Check pending event count
int pending = client?.getPendingEventCount() ?? 0;
print('Pending events: $pending');
```

#### User Switching Issues

```dart
// Proper user switching pattern
Future<void> switchToNewUser(String userId) async {
  final client = CFClient.getInstance();

  // 1. Clear all listeners FIRST
  client?.clearAllConfigListeners();

  // 2. Create new user
  final newUser = CFUser.builder(userId)
      .addStringProperty('platform', 'Flutter')
      .addBooleanProperty('is_logged_in', true)
      .build();

  // 3. Reinitialize (handles shutdown automatically)
  final newClient = await CFClient.reinitialize(config, newUser);

  // 4. Re-setup listeners
  _setupListeners(newClient);

  // 5. Force refresh
  await newClient.forceRefresh();
}
```

### Debug Mode

Enable debug logging to troubleshoot issues:

```dart
final config = CFConfig.builder('client-key')
    .setDebugLoggingEnabled(true)
    .setLogLevel('DEBUG')
    .build();

// This will log:
// - SDK initialization steps
// - Network requests and responses
// - Feature flag evaluations
// - Event tracking activities
// - Error conditions and recovery
```

### Performance Optimization

```dart
// Optimize configuration for performance
final config = CFConfig.builder('client-key')
    .setLocalStorageEnabled(true) // Enable caching
    .setUseStaleWhileRevalidate(true) // Use cache while updating
    .setBackgroundPollingIntervalMs(300000) // Reduce polling frequency
    .build();
```

## Support

- 📚 **Documentation**: [https://docs.customfit.ai](https://docs.customfit.ai)
- 🐛 **Issues**: [GitHub Issues](https://github.com/customfit-ai/flutter-sdk/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/customfit-ai/flutter-sdk/discussions)
- 📧 **Email**: [reach@custom.ai](mailto:reach@custom.ai)
- 🌐 **Website**: [https://customfit.ai](https://customfit.ai)

### Getting Help

When reporting issues, please include:

1. **SDK Version**: Check `pubspec.yaml` for version number
2. **Flutter/Dart Version**: Run `flutter --version`
3. **Platform**: iOS, Android, Web, Desktop
4. **Configuration**: Relevant `CFConfig` settings (remove sensitive keys)
5. **Error Messages**: Full stack traces and error logs
6. **Reproduction Steps**: Minimal code example that reproduces the issue

### Community

Join our community for:
- Best practices discussions
- Feature requests and feedback
- Technical support from other developers
- SDK updates and announcements

## License

MIT License - see [LICENSE](LICENSE) for details.

## 🔗 Related Projects

- [CustomFit React Native SDK](https://github.com/customfit-ai/customfit-react-native-sdk)
- [CustomFit Swift SDK](https://github.com/customfit-ai/customfit-swift-sdk)
- [CustomFit Kotlin SDK](https://github.com/customfit-ai/customfit-kotlin-sdk)

---

<div align="center">
  <strong>Built with ❤️ by the CustomFit team</strong>
  <br>
  <a href="https://customfit.ai">https://customfit.ai</a>
</div>