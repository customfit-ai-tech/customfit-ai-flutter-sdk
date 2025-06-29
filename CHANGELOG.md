# Changelog

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