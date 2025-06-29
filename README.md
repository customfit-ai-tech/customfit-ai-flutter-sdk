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
  customfit_ai_flutter_sdk: ^0.1.0
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
    // Simple configuration
    final config = CFConfig.builder('your-client-key')
        .setDebugLoggingEnabled(true)
        .setEventsFlushIntervalMs(60000)
        .setNetworkConnectionTimeoutMs(10000)
        .build();
    
    // Create user with builder pattern
    final user = CFUser.builder('user-123')
        .addStringProperty('email', 'user@example.com')
        .addStringProperty('plan', 'premium')
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

// Boolean flag
bool isEnabled = client?.getBoolean('newFeature', false) ?? false;

// String flag
String theme = client?.getString('appTheme', 'light') ?? 'light';

// Number flag
double discountPercentage = client?.getNumber('discountPercentage', 0.0) ?? 0.0;

// JSON flag
Map<String, dynamic> config = client?.getJson('featureConfig', {}) ?? {};
```

### 3. Track Events

```dart
// Track a simple event
await client?.trackEvent('buttonClicked');

// Track event with properties
await client?.trackEvent('purchaseCompleted', properties: {
  'productId': 'prod-123',
  'amount': 99.99,
  'currency': 'USD',
  'paymentMethod': 'creditCard',
});
```

### 4. Flutter Widget Integration

```dart
// Main App Widget with Provider Pattern
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SDK before running app
  await initializeCustomFit();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => FeatureFlagProvider(),
      child: MyApp(),
    ),
  );
}

// Feature Flag Provider for State Management
class FeatureFlagProvider extends ChangeNotifier {
  final CFClient? _client = CFClient.getInstance();
  
  Map<String, dynamic> _flags = {};
  String _appTheme = 'light';
  bool _premiumEnabled = false;
  bool _newDashboard = false;
  
  FeatureFlagProvider() {
    _initializeFlags();
    _setupListeners();
  }
  
  // Getters
  String get appTheme => _appTheme;
  bool get premiumEnabled => _premiumEnabled;
  bool get newDashboard => _newDashboard;
  
  void _initializeFlags() {
    _appTheme = _client?.getString('app_theme', 'light') ?? 'light';
    _premiumEnabled = _client?.getBoolean('premium_features', false) ?? false;
    _newDashboard = _client?.getBoolean('new_dashboard', false) ?? false;
    notifyListeners();
  }
  
  void _setupListeners() {
    _client?.addAllFlagsListener((flags) {
      _flags = flags;
      _appTheme = flags['app_theme'] ?? 'light';
      _premiumEnabled = flags['premium_features'] ?? false;
      _newDashboard = flags['new_dashboard'] ?? false;
      notifyListeners();
    });
  }
  
  Future<void> trackEvent(String event, [Map<String, dynamic>? properties]) async {
    await _client?.trackEvent(event, properties: properties);
  }
}

// Main App Widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FeatureFlagProvider>(
      builder: (context, featureFlags, child) {
        return MaterialApp(
          title: 'CustomFit Demo',
          theme: featureFlags.appTheme == 'dark' 
            ? ThemeData.dark() 
            : ThemeData.light(),
          home: MainScreen(),
        );
      },
    );
  }
}

// Main Screen with Navigation
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    final featureFlags = Provider.of<FeatureFlagProvider>(context);
    
    final List<Widget> _screens = [
      HomeScreen(),
      if (featureFlags.newDashboard) DashboardScreen(),
      if (featureFlags.premiumEnabled) PremiumScreen(),
      SettingsScreen(),
    ];
    
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          featureFlags.trackEvent('tab_selected', {
            'tab_index': index,
            'tab_name': ['home', 'dashboard', 'premium', 'settings'][index],
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          if (featureFlags.newDashboard)
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
          if (featureFlags.premiumEnabled)
            BottomNavigationBarItem(
              icon: Icon(Icons.star),
              label: 'Premium',
            ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Home Screen
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final featureFlags = Provider.of<FeatureFlagProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('CustomFit Demo'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Feature Banner Widget
          if (featureFlags.newDashboard)
            FeatureBanner(
              title: '🎉 New Dashboard Available!',
              subtitle: 'Check out our redesigned dashboard',
              onTap: () {
                featureFlags.trackEvent('feature_banner_clicked', {
                  'feature': 'new_dashboard',
                });
              },
            ),
          
          SizedBox(height: 20),
          
          // Action Cards
          ActionCard(
            title: 'Track Custom Event',
            icon: Icons.analytics,
            onTap: () async {
              await featureFlags.trackEvent('custom_action', {
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'source': 'home_screen',
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Event tracked!')),
              );
            },
          ),
          
          if (featureFlags.premiumEnabled)
            ActionCard(
              title: 'Premium Features',
              icon: Icons.star,
              color: Colors.amber,
              onTap: () {
                featureFlags.trackEvent('premium_card_clicked');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PremiumScreen()),
                );
              },
            ),
        ],
      ),
    );
  }
}

// Reusable Feature Banner Widget
class FeatureBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  
  const FeatureBanner({
    Key? key,
    required this.title,
    required this.subtitle,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.blue.shade700],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.new_releases, color: Colors.white, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// Reusable Action Card Widget
class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  
  const ActionCard({
    Key? key,
    required this.title,
    required this.icon,
    this.color,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (color ?? Theme.of(context).primaryColor).withOpacity(0.1),
          child: Icon(icon, color: color ?? Theme.of(context).primaryColor),
        ),
        title: Text(title),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// Dashboard Screen (Feature Flagged)
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final featureFlags = Provider.of<FeatureFlagProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'New Dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 8),
            Text('This is a feature-flagged dashboard'),
          ],
        ),
      ),
    );
  }
}

// Premium Screen (Feature Flagged)
class PremiumScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Premium Features'),
        backgroundColor: Colors.amber,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          PremiumFeatureCard(
            title: 'Advanced Analytics',
            description: 'Get detailed insights into your usage',
            icon: Icons.analytics_outlined,
          ),
          PremiumFeatureCard(
            title: 'Priority Support',
            description: '24/7 dedicated support team',
            icon: Icons.support_agent,
          ),
          PremiumFeatureCard(
            title: 'Custom Themes',
            description: 'Personalize your app experience',
            icon: Icons.palette,
          ),
        ],
      ),
    );
  }
}

// Premium Feature Card Widget
class PremiumFeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  
  const PremiumFeatureCard({
    Key? key,
    required this.title,
    required this.description,
    required this.icon,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.amber, size: 32),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Settings Screen
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _analyticsEnabled = true;
  
  @override
  Widget build(BuildContext context) {
    final featureFlags = Provider.of<FeatureFlagProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('Theme'),
            subtitle: Text(featureFlags.appTheme.capitalize()),
            leading: Icon(Icons.palette),
          ),
          Divider(),
          SwitchListTile(
            title: Text('Push Notifications'),
            subtitle: Text('Receive updates and alerts'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              featureFlags.trackEvent('setting_changed', {
                'setting': 'notifications',
                'value': value,
              });
            },
          ),
          SwitchListTile(
            title: Text('Analytics'),
            subtitle: Text('Help us improve the app'),
            value: _analyticsEnabled,
            onChanged: (value) {
              setState(() {
                _analyticsEnabled = value;
              });
              featureFlags.trackEvent('setting_changed', {
                'setting': 'analytics',
                'value': value,
              });
            },
          ),
        ],
      ),
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
```

## Configuration

### Configuration

The CustomFit Flutter SDK provides flexible configuration options using the builder pattern.

#### Basic Configuration

```dart
// Simple configuration with default settings
final config = CFConfig.builder('your-client-key').build();
```

#### Advanced Configuration

```dart
final config = CFConfig.builder('your-client-key')
    .setDebugLoggingEnabled(true)
    .setEventsFlushIntervalMs(60000)
    .setNetworkConnectionTimeoutMs(10000)
    .setOfflineMode(false)
    .build();
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
    .build();
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

// Add properties to existing user
client?.addStringProperty('plan', 'enterprise');  // Upgrade plan
client?.addBooleanProperty('premium_access', true);
client?.addNumberProperty('usage_count', 42);

// Or add multiple properties at once
client?.addUserProperty('subscription_tier', 'pro');
client?.addJsonProperty('preferences', {
  'notifications': true,
  'theme': 'dark'
});
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

### Basic Flag Evaluation

```dart
final client = CFClient.getInstance();

// Boolean flags
bool isEnabled = client?.getBoolean('new_feature', false) ?? false;

// String flags  
String theme = client?.getString('app_theme', 'light') ?? 'light';

// Number flags
double threshold = client?.getNumber('conversion_threshold', 0.5) ?? 0.5;

// JSON flags
Map<String, dynamic> config = client?.getJson('feature_config', {}) ?? {};
```

### Advanced Flag Usage

```dart
// Using flag values in business logic
final maxRetries = client?.getNumber('api_max_retries', 3)?.toInt() ?? 3;
final timeout = client?.getNumber('api_timeout_ms', 5000)?.toInt() ?? 5000;

// Configure components based on flags
final apiClient = HttpClient(
  maxRetries: maxRetries,
  timeout: Duration(milliseconds: timeout),
);

// Feature rollout with percentage
final rolloutPercentage = client?.getNumber('feature_rollout', 0.0) ?? 0.0;
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

// Simple event
await client?.trackEvent('button_clicked');

// Event with properties
await client?.trackEvent('purchase_completed', properties: {
  'product_id': 'abc123',
  'price': 29.99,
  'currency': 'USD',
  'payment_method': 'credit_card',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});
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

// Access current session info
final client = CFClient.getInstance();
final sessionId = client?.getCurrentSessionId();
```

## Listeners & Callbacks

### Feature Flag Change Listeners

```dart
// Listen for specific flag changes
final client = CFClient.getInstance();

client?.addFeatureFlagListener('new_feature', (flagKey, newValue) {
  print('Flag $flagKey changed to: $newValue');
  
  // Update UI or trigger actions
  setState(() {
    _featureEnabled = newValue as bool;
  });
});

// Listen for all flag changes
client?.addAllFlagsListener((flags) {
  print('Flags updated: ${flags.keys}');
  
  // Batch update multiple features
  _updateAllFeatures(flags);
});
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

### State Management Integration

```dart
// With Provider
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
    final isEnabled = client?.getBoolean(flagKey, defaultValue) ?? defaultValue;
    
    return isEnabled ? child : (fallback ?? SizedBox.shrink());
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
    final value = client?.getBoolean(key, defaultValue) ?? defaultValue;
    _cache[key] = value;
    return value;
  }
}

// 3. Use listeners for reactive updates
client?.addFeatureFlagListener('feature_key', (key, value) {
  FeatureCache._cache[key] = value; // Update cache
});
```

### Error Resilience

```dart
// Always provide sensible defaults
bool isFeatureEnabled(String key) {
  final client = CFClient.getInstance();
  return client?.getBoolean(key, false) ?? false;
}

// Graceful degradation
Widget buildFeature() {
  try {
    if (isFeatureEnabled('new_ui')) {
      return NewUIComponent();
    }
  } catch (e) {
    Logger.w('Feature flag evaluation failed: $e');
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
  'session_id': client?.getCurrentSessionId(),
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
  // Initialization
  static Future<CFClient> initialize(CFConfig config, CFUser user);
  static CFClient? getInstance();
  
  // Feature flags
  bool? getBoolean(String key, bool defaultValue);
  String? getString(String key, String defaultValue);
  double? getNumber(String key, double defaultValue);
  Map<String, dynamic>? getJson(String key, Map<String, dynamic> defaultValue);
  
  // Event tracking
  Future<void> trackEvent(String eventType, {Map<String, dynamic>? properties});
  Future<CFResult<void>> flushEvents(); // Returns CFResult wrapper
  
  // User management
  void addStringProperty(String key, String value);
  void addNumberProperty(String key, num value);
  void addBooleanProperty(String key, bool value);
  void addJsonProperty(String key, Map<String, dynamic> value);
  void addGeoPointProperty(String key, double lat, double lon);
  void addDateProperty(String key, DateTime value);
  void addUserProperty(String key, dynamic value);
  
  // Listeners
  void addFeatureFlagListener(String flagKey, FeatureFlagChangeListener listener);
  void addAllFlagsListener(AllFlagsListener listener);
  // Note: Connection status listeners are accessed through the listeners component
  // client?.listeners.addConnectionStatusListener(listener);
  
  // Session management
  String? getCurrentSessionId();
  void forceSessionRotation();
  
  // Cleanup
  Future<void> shutdown();
}
```

### CFConfig

Configuration builder for SDK initialization.

```dart
class CFConfig {
  static CFConfigBuilder builder(String clientKey);
  
  // Core properties
  String get clientKey;
  bool get debugLoggingEnabled;
  bool get offlineMode;
  int get eventsFlushIntervalMs;
  int get networkConnectionTimeoutMs;
  // ... additional properties
}

class CFConfigBuilder {
  CFConfigBuilder debugLoggingEnabled(bool enabled);
  CFConfigBuilder eventsFlushIntervalMs(int interval);
  CFConfigBuilder networkConnectionTimeoutMs(int timeout);
  CFConfigBuilder offlineMode(bool offline);
  // ... additional builder methods
  CFConfig build();
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
// Check client key
if (config.clientKey.isEmpty) {
  throw Exception('Client key is required');
}

// Check user ID
if (user.userCustomerId == null || user.userCustomerId!.isEmpty) {
  throw Exception('User ID is required');
}

// Check network connectivity
final client = CFClient.getInstance();
client?.addConnectionStatusListener((status) {
  if (status == ConnectionStatus.disconnected) {
    print('Network connectivity issues detected');
  }
});
```

#### Feature Flags Not Updating

```dart
// Verify listener registration
client?.addFeatureFlagListener('flag_key', (key, value) {
  print('Flag updated: $key = $value');
});

// Check polling configuration
final config = CFConfig.builder('client-key')
    .setSdkSettingsCheckIntervalMs(30000) // Check every 30 seconds
    .build();

// The SDK automatically handles offline mode
// Feature flags will use cached values when offline
```

#### Events Not Being Sent

```dart
// Check event queue configuration
final config = CFConfig.builder('client-key')
    .setEventsFlushIntervalMs(5000) // Flush every 5 seconds
    .setEventsQueueSize(50) // Flush when 50 events queued
    .build();

// Verify event structure
await client?.trackEvent('valid_event', properties: {
  'string_prop': 'value',
  'number_prop': 123,
  'boolean_prop': true,
  // Avoid complex nested objects
});
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