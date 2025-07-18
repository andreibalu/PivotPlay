# Design Document

## Overview

This design addresses critical stability issues in PivotPlay by implementing robust error handling, improving data synchronization between Watch and iPhone, fixing navigation state management, and correcting heatmap pipeline calculations. The solution focuses on defensive programming practices, comprehensive error handling, and maintaining backward compatibility while introducing enhanced reliability mechanisms.

## Architecture

### Current Architecture Analysis

The PivotPlay app follows a typical Watch-iPhone companion app architecture:

- **iPhone App**: SwiftUI with SwiftData for persistence, displays workout history and heatmaps
- **Watch App**: HealthKit integration for workout tracking, CoreLocation for GPS, WatchConnectivity for data sync
- **Shared Models**: Codable data structures for cross-platform communication
- **Data Flow**: Watch → WatchConnectivity → iPhone → SwiftData storage

### Key Issues Identified

1. **WorkoutStorage.fetchWorkouts()** returns empty array on error but UI assumes data exists
2. **WatchConnectivityManager** lacks nil-safety and retry mechanisms
3. **Navigation** has potential race conditions with async operations
4. **HeatmapPipeline** has coordinate transformation and distance calculation bugs
5. **Error handling** is inconsistent across the codebase

## Components and Interfaces

### 1. Enhanced WorkoutStorage

**Current Issues:**
- `fatalError` in initializer can crash the app
- No graceful handling of SwiftData failures
- Missing validation for corrupt data
- Race conditions during concurrent data reads

**Design Solution:**
```swift
@MainActor
class WorkoutStorage {
    enum StorageError: Error {
        case initializationFailed(String)
        case fetchFailed(String)
        case saveFailed(String)
        case corruptData(String)
    }
    
    private let container: ModelContainer?
    private let context: ModelContext?
    private var isHealthy: Bool = false
    private let accessQueue = DispatchQueue(label: "workout.storage.access", qos: .userInitiated)
    
    // Safe initialization with fallback
    private init() {
        do {
            let fullSchema = Schema([WorkoutSession.self])
            container = try ModelContainer(for: fullSchema, configurations: [])
            context = ModelContext(container!)
            isHealthy = true
        } catch {
            container = nil
            context = nil
            isHealthy = false
            ErrorLogger.shared.logError(error, context: "WorkoutStorage initialization", severity: .critical)
        }
    }
    
    // Thread-safe fetch with error handling and empty state support
    func fetchWorkouts() -> Result<[WorkoutSession], StorageError> {
        return accessQueue.sync {
            guard isHealthy, let context = context else {
                return .failure(.initializationFailed("Storage not available"))
            }
            
            do {
                let descriptor = FetchDescriptor<WorkoutSession>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let workouts = try context.fetch(descriptor)
                return .success(workouts)
            } catch {
                ErrorLogger.shared.logError(error, context: "WorkoutStorage fetch", severity: .error)
                return .failure(.fetchFailed(error.localizedDescription))
            }
        }
    }
    
    // Validation and safe decoding with default values
    func validateWorkoutData(_ data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let _ = try decoder.decode(WorkoutSession.self, from: data)
            return true
        } catch {
            ErrorLogger.shared.logError(error, context: "Workout data validation", severity: .warning)
            return false
        }
    }
    
    // Safe decoding with fallback to default values
    func safeDecodeWorkout(from data: Data) -> WorkoutSession? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WorkoutSession.self, from: data)
        } catch {
            // Attempt partial recovery with default values
            return createFallbackWorkout(from: data)
        }
    }
    
    private func createFallbackWorkout(from data: Data) -> WorkoutSession? {
        // Implementation for creating workout with safe defaults
        // when JSON is partially corrupted
        return nil
    }
}
```

### 2. Robust WatchConnectivity Layer

**Current Issues:**
- No validation of received data
- Missing retry logic for failed transfers
- Nil context data causes crashes

**Design Solution:**
```swift
class WatchConnectivityManager {
    private struct TransferAttempt {
        let data: Data
        let timestamp: Date
        let attemptCount: Int
        let maxRetries: Int = 3
    }
    
    private var pendingTransfers: [UUID: TransferAttempt] = [:]
    private let retryQueue = DispatchQueue(label: "connectivity.retry")
    
    // Enhanced data validation
    func validatePayload(_ data: Data) -> ValidationResult
    
    // Retry mechanism with exponential backoff
    func sendWithRetry<T: Codable>(_ data: T, completion: @escaping (Result<Void, Error>) -> Void)
    
    // Fallback transfer methods
    func sendViaFileTransfer<T: Codable>(_ data: T)
    
    // Handshake confirmation
    func confirmReceipt(for transferId: UUID)
}
```

### 3. Navigation State Manager

**Current Issues:**
- Multiple NavigationLink pushes can occur simultaneously
- Async operations may trigger navigation on background threads
- No centralized navigation state management

**Design Solution:**
```swift
@MainActor
class NavigationStateManager: ObservableObject {
    @Published private(set) var isTransitioning = false
    @Published var navigationPath = NavigationPath()
    
    private let transitionQueue = DispatchQueue(label: "navigation.transitions", qos: .userInitiated)
    
    func safeNavigate<T>(to destination: T) where T: Hashable {
        guard !isTransitioning else {
            // Queue the navigation for later
            return
        }
        
        isTransitioning = true
        navigationPath.append(destination)
        
        // Reset transition flag after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
}
```

### 4. Fixed HeatmapPipeline

**Current Issues:**
- Duplicate corner coordinates being recorded
- Zero distance calculations despite valid location data
- Coordinate transformation errors

**Design Solution:**
```swift
class HeatmapPipeline {
    private struct LocationPoint {
        let coordinate: CLLocationCoordinate2D
        let timestamp: Date
        let accuracy: CLLocationAccuracy
    }
    
    // Debounced corner capture
    private var lastCornerLocation: CLLocationCoordinate2D?
    private let cornerDebounceDistance: CLLocationDistance = 5.0 // meters
    
    func captureCorner(at location: CLLocationCoordinate2D) -> Bool {
        if let lastCorner = lastCornerLocation {
            let distance = location.distance(from: lastCorner)
            if distance < cornerDebounceDistance {
                return false // Too close to previous corner
            }
        }
        
        lastCornerLocation = location
        return true
    }
    
    // Enhanced distance calculation with validation
    func calculateTotalDistance(from locations: [LocationSample]) -> CLLocationDistance {
        guard locations.count >= 2 else { return 0.0 }
        
        var totalDistance: CLLocationDistance = 0.0
        var validSegments = 0
        
        for i in 1..<locations.count {
            let distance = locations[i-1].coordinate.distance(from: locations[i].coordinate)
            
            // Validate distance (filter out GPS jumps)
            if distance > 0 && distance < 1000 { // Max 1km between points
                totalDistance += distance
                validSegments += 1
            }
        }
        
        return validSegments > 0 ? totalDistance : 0.0
    }
}
```

## Data Models

### Enhanced Error Handling Models

```swift
enum PivotPlayError: Error, LocalizedError {
    case storageUnavailable
    case networkTimeout
    case corruptData(String)
    case locationUnavailable
    case watchConnectivityFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            return "Workout storage is temporarily unavailable"
        case .networkTimeout:
            return "Connection to Apple Watch timed out"
        case .corruptData(let details):
            return "Data corruption detected: \(details)"
        case .locationUnavailable:
            return "Location services are not available"
        case .watchConnectivityFailed(let reason):
            return "Watch sync failed: \(reason)"
        }
    }
}
```

### Validated Data Transfer Models

```swift
struct ValidatedPitchDataTransfer: Codable {
    let schemaVersion: Int = 1
    let workoutId: UUID
    let date: Date
    let duration: TimeInterval
    let totalDistance: Double
    let heartRateData: [HeartRateSample]
    let corners: [CoordinateDTO]
    let locationData: [LocationSample]
    let checksum: String
    
    // Validation methods
    func isValid() -> Bool
    private func calculateChecksum() -> String
}
```

## Error Handling

### Comprehensive Error Recovery Strategy

1. **Storage Failures**: Graceful degradation with in-memory fallback
2. **Network Issues**: Retry with exponential backoff, fallback to file transfer
3. **Data Corruption**: Validation with safe defaults and user notification
4. **Location Errors**: Fallback to cached location or user prompt
5. **UI State Errors**: Reset to known good state with user feedback

### Error Logging and Monitoring

```swift
class ErrorLogger {
    static let shared = ErrorLogger()
    
    func logError(_ error: Error, context: String, severity: LogSeverity) {
        let logEntry = ErrorLogEntry(
            error: error,
            context: context,
            severity: severity,
            timestamp: Date(),
            deviceInfo: DeviceInfo.current
        )
        
        // Log to OSLog for debugging
        os_log("%{public}@", log: .default, type: .error, logEntry.description)
        
        // Store critical errors for later analysis
        if severity == .critical {
            persistErrorForAnalysis(logEntry)
        }
    }
}
```

## Testing Strategy

### Unit Testing Coverage

1. **WorkoutStorage Tests**
   - Test initialization failure scenarios
   - Validate error handling for corrupt data
   - Test concurrent access patterns
   - Verify graceful degradation

2. **WatchConnectivity Tests**
   - Mock WCSession for testing
   - Test retry mechanisms
   - Validate data integrity checks
   - Test fallback scenarios

3. **HeatmapPipeline Tests**
   - Test distance calculations with known GPS coordinates
   - Validate coordinate transformation accuracy
   - Test corner debouncing logic
   - Verify edge cases (single point, duplicate points)

4. **Navigation Tests**
   - Test concurrent navigation attempts
   - Validate async operation handling
   - Test state recovery scenarios

### Integration Testing

1. **End-to-End Workout Flow**
   - Watch workout creation → iPhone display
   - Error scenarios at each step
   - Data integrity validation

2. **UI Testing**
   - Latest Workouts navigation without crashes
   - Heatmap display with various data states
   - Error state UI validation

### Performance Testing

1. **Memory Usage**: Ensure fixes don't introduce memory leaks
2. **CPU Impact**: Validate retry mechanisms don't cause excessive CPU usage
3. **Battery Impact**: Test location tracking optimizations
4. **Startup Time**: Ensure error handling doesn't slow app launch

## Implementation Phases

### Phase 1: Critical Crash Fixes
- Safe WorkoutStorage initialization
- Latest Workouts crash prevention
- Basic error handling for nil data

### Phase 2: Enhanced Sync Reliability
- WatchConnectivity retry mechanisms
- Data validation and checksums
- Fallback transfer methods

### Phase 3: Navigation and UI Stability
- Navigation state management
- Thread-safe UI updates
- Error state UI components

### Phase 4: Heatmap Pipeline Fixes
- Corner debouncing implementation
- Distance calculation validation
- Coordinate transformation fixes

### Phase 5: Testing and Validation
- Comprehensive test suite
- Performance validation
- Error scenario testing

## Backward Compatibility

The design maintains full backward compatibility by:

1. **Graceful Degradation**: New features fail safely to existing behavior
2. **Data Migration**: Existing workouts remain accessible
3. **API Compatibility**: No breaking changes to existing interfaces
4. **Progressive Enhancement**: New reliability features activate automatically

## Monitoring and Observability

### Crash Prevention Metrics
- Storage initialization success rate
- Navigation transition success rate
- Data sync completion rate
- Error recovery success rate

### Performance Metrics
- App launch time impact
- Memory usage patterns
- Battery usage optimization
- Network retry efficiency

This design provides a comprehensive solution to the stability issues while maintaining the existing user experience and ensuring robust error handling throughout the application.