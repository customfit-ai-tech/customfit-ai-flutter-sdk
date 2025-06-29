# Flutter SDK Publishing Checklist

## Pre-Publishing Checklist

### 1. Version Management
- [ ] Update version in `pubspec.yaml` following [semantic versioning](https://semver.org/)
- [ ] Update `CHANGELOG.md` with new version and changes
- [ ] Ensure version is higher than the current published version

### 2. Code Quality
- [ ] All tests pass: `flutter test`
- [ ] Code analysis passes: `flutter analyze`
- [ ] Code formatting is correct: `dart format --set-exit-if-changed .`
- [ ] No linter warnings: `flutter analyze --no-fatal-warnings`

### 3. Documentation
- [ ] README.md is up to date
- [ ] API documentation is complete
- [ ] Examples are working and up to date
- [ ] CHANGELOG.md reflects all changes

### 4. Dependencies
- [ ] All dependencies are at stable versions
- [ ] No dev dependencies in main dependencies
- [ ] Dependency versions are not overly restrictive

### 5. Repository Setup
- [ ] Repository URL in `pubspec.yaml` points to dedicated Flutter SDK repo
- [ ] Repository is public and accessible
- [ ] License file is present and correct
- [ ] Repository has proper README

### 6. Publishing Preparation
- [ ] Run `flutter pub publish --dry-run` successfully
- [ ] Verify package contents are correct
- [ ] Check package size is reasonable
- [ ] Verify all required files are included

## Publishing Commands

### Dry Run (Test Publishing)
```bash
cd customfit-ai-flutter-sdk
flutter pub publish --dry-run
```

### Actual Publishing
```bash
cd customfit-ai-flutter-sdk
flutter pub publish
```

## Post-Publishing
- [ ] Verify package appears on [pub.dev](https://pub.dev/packages/customfit_ai_flutter_sdk)
- [ ] Test installation in a new project
- [ ] Update internal documentation with new version
- [ ] Tag the release in the dedicated repository

## Sync from Monorepo

### Manual Sync
```bash
# From monorepo root
./scripts/sync-flutter-sdk.sh
```

### Automated Sync
Commit changes to Flutter SDK with `[flutter-sdk]` in commit message to trigger automatic sync.

## Emergency Rollback
If issues are discovered after publishing:
1. Identify the problematic version
2. Publish a hotfix version immediately
3. Consider yanking the problematic version if critical 