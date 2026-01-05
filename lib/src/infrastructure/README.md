# Infrastructure Module

This is the core infrastructure module for the CustomFit Flutter SDK. It provides foundational services and utilities that support all other SDK components.

## 🏗️ Architecture Overview

The infrastructure module follows a clean, modular architecture with clear separation between public interfaces and internal implementations:

```
infrastructure/
├── types.dart              # Centralized type aliases
├── index.dart              # Main module exports
├── network/                # Network operations
├── storage/                # Data persistence
├── platform/               # Platform abstraction
├── logging/                # Logging services
├── di/                     # Dependency injection
└── utils/                  # Shared utilities
```

## 📦 Module Structure

### **Network Module** (`network/`)
Handles all network communication including HTTP requests, connection management, and configuration fetching.

- **Interfaces**: `http_client.dart`, `connection_manager.dart`, `config_fetcher.dart`
- **Models**: Request/Response DTOs for API communication
- **Internal**: Implementations hidden from public API

### **Storage Module** (`storage/`)
Provides data persistence including caching, preferences, and secure storage.

- **Interfaces**: `cache_manager.dart`, `preferences_service.dart`, `secure_storage_service.dart`
- **Internal**: Platform-specific storage implementations

### **Platform Module** (`platform/`)
Abstracts platform-specific functionality like device info and background state monitoring.

- **Interfaces**: `device_info_detector.dart`, `background_state_monitor.dart`
- **Models**: Device and application context models
- **Internal**: Platform-specific implementations

### **Logging Module** (`logging/`)
Centralized logging infrastructure with level management and remote logging capabilities.

- **Core**: `logger.dart`, `log_level_updater.dart`
- **Extensions**: `remote_logger.dart` for cloud logging

### **DI Module** (`di/`)
Dependency injection container for managing SDK component lifecycles.

- **Interfaces**: `service_locator.dart`
- **Internal**: Container implementation and factory patterns

### **Utils Module** (`utils/`)
Shared utilities and helper functions used across the SDK.

- **Core Utilities**: JSON parsing, string optimization, type conversion
- **Resilience**: Circuit breaker, retry logic, exponential backoff
- **Concurrency**: Background queues, synchronization primitives

## 🔌 Interface Design

All modules follow the **Interface Segregation Principle**:

1. **Public Interfaces** - Defined in `interfaces/` directories
2. **Internal Implementations** - Hidden in `internal/` directories  
3. **Models/DTOs** - Shared data structures in `models/` directories

### Example Usage:

```dart
// Import centralized types
import 'package:customfit_ai_flutter_sdk/src/infrastructure/types.dart';

// Use type aliases for clean code
HttpClient httpClient = container.resolve<HttpClient>();
CacheManager cache = container.resolve<CacheManager>();
```

## 🛡️ Module Boundaries

Each module maintains clear boundaries:

- **No cross-module imports** between peer modules
- **Only interface dependencies** where needed
- **Centralized type definitions** in `types.dart`
- **Proper encapsulation** of internal implementations

## 📊 Dependency Graph

```
infrastructure/
├── types.dart          (defines all type aliases)
├── logging/            (no dependencies)
├── utils/              (depends on: logging)
├── storage/            (depends on: logging)
├── platform/           (depends on: logging)
├── network/            (depends on: logging, storage, utils)
└── di/                 (depends on: all modules for factory creation)
```

## 🧪 Testing Strategy

- **Interface Mocking**: All interfaces can be easily mocked for testing
- **Dependency Injection**: Components can be replaced with test doubles
- **Module Isolation**: Each module can be tested independently

## 🔧 Usage Guidelines

### For SDK Developers:

1. **Always import from module interfaces**, not internal implementations
2. **Use centralized type aliases** from `types.dart`
3. **Follow the dependency injection pattern** for component creation
4. **Respect module boundaries** - no cross-module internal imports

### For Other SDK Teams:

This infrastructure module serves as a **gold-standard reference** for implementing similar modular architectures in other SDK platforms (Kotlin, Swift, React Native, etc.).

Key patterns to replicate:
- Interface-based design
- Clear module boundaries
- Centralized type definitions
- Proper encapsulation
- Consistent directory structure

## 📈 Benefits

✅ **Modularity** - Clear separation of concerns  
✅ **Testability** - Easy mocking and testing  
✅ **Maintainability** - Isolated changes and updates  
✅ **Reusability** - Components can be reused across modules  
✅ **Consistency** - Standardized patterns across the SDK  
✅ **Scalability** - Easy to extend with new modules