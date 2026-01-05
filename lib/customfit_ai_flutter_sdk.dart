/// # CustomFit.ai Flutter SDK
///
/// Real-time feature flags, A/B testing, and analytics for Flutter applications.
///
/// ## Features
///
/// - **Feature Flags**: Dynamic configuration with real-time updates
/// - **A/B Testing**: Run experiments with advanced targeting
/// - **Analytics**: Track events and user behavior
/// - **Offline Support**: Full functionality without network connectivity
/// - **Type Safety**: Strongly typed APIs with comprehensive error handling
///
/// ## Quick Start
///
/// ```dart
/// import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';
///
/// // Initialize the SDK
/// final config = CFConfig.development('your-api-key');
/// final user = CFUser.builder('user-id').build();
/// final client = await CFClient.initialize(config, user);
///
/// // Evaluate feature flags
/// final isEnabled = client.featureFlags.getBoolean('feature-key', false);
///
/// // Track events
/// await client.trackEvent('user-action');
/// ```
///
/// ## Additional Resources
///
/// - [Documentation](https://doc.customfit.ai)
/// - [API Reference](https://pub.dev/documentation/customfit_ai_flutter_sdk/latest/)
/// - [GitHub Repository](https://github.com/customfit-ai/customfit-flutter-sdk)
/// - [Support](https://customfit.ai/support)
library;

// Export all public APIs from core
export 'customfit_ai_flutter_core.dart';
