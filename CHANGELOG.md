# Changelog

## 0.1.4 - Infrastructure and Code Quality Improvements

### Improvements
- Enhanced event tracking with improved batch processing
- Refactored infrastructure layer with better modular organization
- Improved dependency injection and service locator patterns
- Enhanced session management reliability
- Better error handling and recovery mechanisms
- Optimized network layer with improved connection management
- Code formatting and cleanup across the SDK

### Bug Fixes
- Fixed unused import warnings
- Improved graceful degradation handling
- Enhanced storage helper reliability

## 0.1.2 - Validation Simplification

### Breaking Changes
- Removed strict InputValidator that was blocking legitimate event names and properties
- Simplified validation to only check for empty strings, allowing all valid use cases

### Improvements
- Event tracking now accepts any event names (e.g., `flutter_screen_navigation`, `user_button_click`)
- Property keys and values have minimal validation, improving developer experience
- Removed overly restrictive security patterns that caused false positives
- Better performance due to reduced validation overhead

### Bug Fixes
- Fixed issue where legitimate event names containing common words were rejected
- Resolved validation errors for standard naming conventions with underscores
- Eliminated false positive security warnings for normal application events

## 0.1.1 - Bug Fixes and Improvements

### Improvements
- Enhanced dependency injection with SimpleServiceFactory
- Improved connection management and network handling
- Better error handling and client initialization
- Optimized SDK configuration management
- Enhanced test coverage and reliability
- Code cleanup and performance optimizations

### Bug Fixes
- Fixed meta dependency constraint for pub.dev compatibility
- Resolved client initialization edge cases
- Improved connection status monitoring
- Enhanced listener management reliability

## 0.1.0 - Initial Release

### Features
- Feature flag management (boolean, string, number, JSON)
- Event tracking and analytics
- User context management
- Real-time configuration updates
- Offline support with caching
- Session management
- Network connectivity monitoring
- Cross-platform support (iOS, Android, Web, Desktop)

### API
- `CFClient.initialize()` - Initialize SDK
- `CFClient.getInstance()` - Get singleton instance
- `getBoolean()`, `getString()`, `getNumber()`, `getJson()` - Get feature flags
- `trackEvent()` - Track custom events
- `addFlagListener()` - Listen for flag changes
- `CFUser.builder()` - Build user context with properties
- `CFConfig` - Configuration with development/production profiles

### Platform Support
- Flutter 3.0.0+
- Dart 3.2.3+
- iOS 12.0+
- Android API 21+ 