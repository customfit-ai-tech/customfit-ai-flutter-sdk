# Contributing to CustomFit Flutter SDK

Thank you for your interest in contributing to the CustomFit Flutter SDK! We welcome contributions from the community and are grateful for your help in making this SDK better.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)
- [Release Process](#release-process)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.2.3)
- Git

### Types of Contributions

We welcome several types of contributions:

- 🐛 **Bug Reports**: Help us identify and fix issues
- ✨ **Feature Requests**: Suggest new functionality
- 📝 **Documentation**: Improve our docs and examples
- 🔧 **Code Contributions**: Fix bugs or implement features
- 🧪 **Testing**: Add or improve test coverage
- 🎨 **Examples**: Create usage examples and demos

## Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/your-username/flutter-sdk.git
   cd flutter-sdk
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Verify Setup**
   ```bash
   make dev  # Runs format, analyze, and test
   ```

4. **Start Development**
   ```bash
   make test-watch  # Auto-run tests on file changes
   ```

## Making Changes

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `test/description` - Test improvements

### Commit Messages

Follow [Conventional Commits](https://conventionalcommits.org/):

```
feat: add type-safe feature flag API
fix: resolve memory leak in event queue
docs: update installation guide
test: add integration tests for offline mode
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run with coverage
make test-coverage

# Watch tests during development
make test-watch

# Run specific test suites
make test-util          # Core utilities
flutter test test/unit/client/  # Client tests
```

### Test Requirements

- **Unit Tests**: All new code must have unit tests
- **Integration Tests**: Complex features need integration tests
- **Coverage**: Maintain >85% code coverage
- **Performance Tests**: Critical paths need performance tests

### Writing Tests

```dart
// Example test structure
group('FeatureName', () {
  late MockDependency mockDep;
  late FeatureClass feature;

  setUp(() {
    mockDep = MockDependency();
    feature = FeatureClass(mockDep);
  });

  group('methodName', () {
    test('should handle normal case', () {
      // Arrange
      when(mockDep.call()).thenReturn('expected');
      
      // Act
      final result = feature.methodName();
      
      // Assert
      expect(result, equals('expected'));
    });

    test('should handle error case', () {
      // Test error scenarios
    });
  });
});
```

## Submitting Changes

### Pull Request Process

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Write code following our style guidelines
   - Add/update tests
   - Update documentation if needed

3. **Test Your Changes**
   ```bash
   make dev  # Format, analyze, test
   ```

4. **Commit and Push**
   ```bash
   git add .
   git commit -m "feat: your descriptive commit message"
   git push origin feature/your-feature-name
   ```

5. **Create Pull Request**
   - Use our PR template
   - Reference any related issues
   - Provide clear description of changes

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
```

## Style Guidelines

### Dart Style

We follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines:

```dart
// Good: Clear, descriptive names
class FeatureFlagManager {
  Future<bool> evaluateFlag(String flagKey, bool defaultValue) async {
    // Implementation
  }
}

// Good: Proper documentation
/// Evaluates a feature flag for the current user.
/// 
/// Returns the flag value or [defaultValue] if evaluation fails.
/// Throws [FeatureFlagException] if the flag key is invalid.
Future<bool> evaluateFlag(String flagKey, bool defaultValue) async {
  // Implementation
}
```

### Code Organization

```dart
// File structure
class MyClass {
  // 1. Static constants
  static const String defaultValue = 'default';
  
  // 2. Instance variables
  final String _privateField;
  String publicField;
  
  // 3. Constructors
  MyClass(this.publicField) : _privateField = 'private';
  
  // 4. Public methods
  void publicMethod() {}
  
  // 5. Private methods
  void _privateMethod() {}
}
```

### Documentation Standards

- All public APIs must have dartdoc comments
- Include usage examples for complex APIs
- Document error conditions and exceptions
- Keep examples up-to-date

## Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- `MAJOR.MINOR.PATCH`
- Major: Breaking changes
- Minor: New features (backward compatible)
- Patch: Bug fixes (backward compatible)

### Release Checklist

- [ ] Update CHANGELOG.md
- [ ] Update version in pubspec.yaml
- [ ] Run full test suite
- [ ] Update documentation
- [ ] Create release notes
- [ ] Tag release in Git

## Getting Help

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community discussion
- **Documentation**: [docs.customfit.ai](https://docs.customfit.ai)

### Maintainer Response Times

- **Bug Reports**: Within 48 hours
- **Feature Requests**: Within 1 week
- **Pull Requests**: Within 72 hours

## Recognition

Contributors will be:
- Listed in our CONTRIBUTORS.md file
- Mentioned in release notes for significant contributions
- Invited to our contributor Discord channel

## License

By contributing, you agree that your contributions will be licensed under the same [MIT License](LICENSE) that covers the project.

---

Thank you for contributing to CustomFit Flutter SDK! 🎉 