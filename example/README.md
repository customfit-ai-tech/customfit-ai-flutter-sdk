# CustomFit.ai Flutter SDK Example

This example demonstrates how to integrate and use the CustomFit.ai Flutter SDK in your Flutter application.

## Features Demonstrated

- **SDK Initialization**: Setting up the SDK with configuration and user context
- **Feature Flag Evaluation**: Retrieving and using feature flag values
- **Event Tracking**: Sending custom analytics events
- **Error Handling**: Proper error handling and fallback behavior
- **Real-time UI Updates**: Updating UI based on feature flag values

## Getting Started

### 1. Install Dependencies

```bash
cd example
flutter pub get
```

### 2. Configure Your API Key

Open `lib/main.dart` and replace `'your-api-key-here'` with your actual CustomFit.ai API key:

```dart
final config = CFConfig.development('your-actual-api-key');
```

### 3. Run the Example

```bash
flutter run
```

## Code Overview

### SDK Initialization

The example shows how to initialize the SDK with a development configuration:

```dart
final config = CFConfig.development('your-api-key-here');

final user = CFUser.builder('example-user-123')
  .addStringProperty('name', 'Example User')
  .addStringProperty('email', 'user@example.com')
  .addStringProperty('plan', 'premium')
  .addStringProperty('region', 'us-east')
  .build();

final client = await CFClient.initialize(config, user);
```

### Feature Flag Evaluation

Evaluate feature flags with fallback values:

```dart
final isEnabled = client.featureFlags.getBoolean('example-flag', false);
final theme = client.featureFlags.getString('app_theme', 'light');
final timeout = client.featureFlags.getNumber('timeout_ms', 5000.0);
```

### Event Tracking

Track custom events with properties:

```dart
await client.trackEvent('flag_evaluated', properties: {
  'flag_key': 'example-flag',
  'result': result,
  'timestamp': DateTime.now().toIso8601String(),
});
```

## Configuration Options

The example uses `CFConfig.development()` which provides:

- Debug logging enabled
- Faster flush intervals for immediate feedback
- Shorter timeouts for development
- Reduced retry attempts to fail fast

For production apps, use `CFConfig.production()` instead.

## Next Steps

1. **Create Feature Flags**: Set up feature flags in your CustomFit.ai dashboard
2. **Update Flag Keys**: Replace `'example-flag'` with your actual flag keys
3. **Customize User Properties**: Add relevant user attributes for targeting
4. **Implement Your Logic**: Use feature flags to control app behavior
5. **Track Events**: Add analytics events for user actions

## API Reference

For complete API documentation, visit: [CustomFit.ai Documentation](https://doc.customfit.ai)

## Support

- **Issues**: [GitHub Issues](https://github.com/customfit-ai-tech/customfit-ai-flutter-sdk/issues)
- **Documentation**: [CustomFit.ai Docs](https://doc.customfit.ai)
- **Website**: [CustomFit.ai](https://customfit.ai) 