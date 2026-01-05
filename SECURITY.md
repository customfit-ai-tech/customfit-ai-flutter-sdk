# Security Policy

## Supported Versions

We actively support the following versions of the CustomFit Flutter SDK with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please follow these steps:

### 🔒 Private Disclosure

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please report security issues via:

- **Email**: reach@customfit.ai
- **Subject**: [SECURITY] Flutter SDK Vulnerability Report
- **Response Time**: We aim to respond within 48 hours

### 📋 What to Include

Please include the following information in your report:

1. **Description**: Clear description of the vulnerability
2. **Impact**: Potential impact and attack scenarios
3. **Reproduction**: Step-by-step instructions to reproduce
4. **Environment**: SDK version, Flutter version, platform details
5. **Proof of Concept**: Code snippets or screenshots (if applicable)
6. **Suggested Fix**: Any ideas for remediation (optional)

### 🏆 Responsible Disclosure

We follow responsible disclosure practices:

1. **Acknowledgment**: We'll acknowledge receipt within 48 hours
2. **Investigation**: We'll investigate and validate the report
3. **Timeline**: We'll provide an estimated timeline for fixes
4. **Credit**: We'll credit you in our security advisory (unless you prefer anonymity)
5. **Coordination**: We'll coordinate disclosure timing with you

## Security Features

### 🔐 Data Protection

#### Secure Storage
- Sensitive data is stored using `flutter_secure_storage`
- User preferences and session data are encrypted at rest
- API keys and tokens are never stored in plain text

#### Network Security
- All communications use HTTPS/TLS
- Certificate pinning support for enhanced security
- Request signing and validation
- Configurable timeout and retry policies

#### Data Minimization
- Only necessary data is collected and transmitted
- User data is anonymized where possible
- Configurable data collection levels

### 🛡️ Privacy Controls

#### User Consent
```dart
// Minimal data collection - use anonymous users
final user = CFUser.anonymousBuilder()
    .build(); // No PII collected

// Simply don't call trackEvent() if you don't want analytics
// await client?.trackEvent('event_name'); // Don't call this for no analytics
```

#### Data Retention
```dart
// Configure event storage limits
final config = CFConfig.builder('your-key')
    .setMaxStoredEvents(50)         // Limit stored events
    .setEventsQueueSize(50)         // Limit in-memory queue
    .build();
```

#### GDPR Compliance
```dart
// Clear all user data (GDPR Article 17 - Right to erasure)
await client?.clearAllUserData();

// Export user data (GDPR Article 20 - Right to data portability)
final userData = await client?.exportUserData();
```

### 🔍 Security Monitoring

#### Logging Security
- Sensitive data is never logged
- Debug logs are disabled in production builds
- Log levels are configurable per environment

#### Error Handling
- Errors don't expose sensitive information
- Stack traces are sanitized in production
- Graceful degradation on security failures

## Security Best Practices

### 🏗️ Implementation Guidelines

#### 1. API Key Management
```dart
// ❌ DON'T: Hardcode API keys
final config = CFConfig.builder('hardcoded-key-here');

// ✅ DO: Use environment variables or secure configuration
final apiKey = const String.fromEnvironment('CF_API_KEY');
final config = CFConfig.builder(apiKey);
```

#### 2. User Data Handling
```dart
// ❌ DON'T: Store PII unnecessarily
user.addStringProperty('ssn', '123-45-6789');
user.addStringProperty('credit_card', '4111111111111111');

// ✅ DO: Use minimal, non-PII identifiers
user.addStringProperty('user_segment', 'premium');
user.addStringProperty('app_version', '1.2.3');
```

#### 3. Network Configuration
```dart
// ✅ DO: Configure appropriate timeouts
final config = CFConfig.builder(apiKey)
    .setNetworkConnectionTimeoutMs(10000)  // 10 seconds
    .setNetworkReadTimeoutMs(15000)        // 15 seconds
    .build();
```

#### 4. Error Handling
```dart
// ✅ DO: Handle errors gracefully without exposing internals
try {
  final value = await client?.getBoolean('feature_flag', false);
} catch (e) {
  // Log error internally, show generic message to user
  Logger.e('Feature flag evaluation failed', error: e);
  // Don't expose error details to end users
}
```

### 🔒 Certificate Pinning (Future Feature)
```dart
// Certificate pinning will be available in future releases
// for enhanced security in production deployments
```

## Vulnerability Disclosure History

### Current Status
- No known security vulnerabilities in the current release
- Regular security audits are conducted
- Dependencies are monitored for known vulnerabilities

### Security Updates
We will maintain a public record of security updates here as they occur.

## Security Contact

For security-related questions or concerns:

- **Security Team**: reach@customfit.ai
- **General Support**: reach@customfit.ai
- **Documentation**: https://docs.customfit.ai

## Dependencies Security

### Monitoring
We continuously monitor our dependencies for security vulnerabilities using:
- GitHub Security Advisories
- Dart/Flutter security announcements
- Automated dependency scanning

### Updates
- Security patches are prioritized and released quickly
- Dependencies are kept up-to-date with latest secure versions
- Breaking changes are carefully evaluated for security impact

## Compliance

### Standards
- SOC 2 Type II compliance
- GDPR compliance features
- CCPA compliance support
- ISO 27001 security practices

### Certifications
- Regular third-party security assessments
- Penetration testing
- Code security reviews

---

**Last Updated**: December 2024
**Next Review**: March 2025 