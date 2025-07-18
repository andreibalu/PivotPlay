# Implementation Plan

- [x] 1. Create error handling infrastructure and logging system
  - Implement PivotPlayError enum with localized error descriptions
  - Create ErrorLogger class with OSLog integration for debugging
  - Add error severity levels and context tracking
  - Write unit tests for error logging functionality
  - _Requirements: 5.3, 6.3_

- [x] 2. Fix WorkoutStorage initialization and crash prevention
  - Replace fatalError with safe initialization in WorkoutStorage.init()
  - Implement Result-based return types for fetchWorkouts() method
  - Add data validation methods for corrupt workout data detection
  - Create fallback mechanisms when SwiftData container fails
  - Write unit tests for storage failure scenarios and edge cases
  - _Requirements: 1.1, 1.2, 1.3, 6.1_

- [x] 3. Implement safe Latest Workouts UI with error states
  - Modify ContentView to handle WorkoutStorage errors gracefully
  - Add "No workouts yet" placeholder UI state
  - Implement error state UI components for storage failures
  - Add loading states and error recovery options
  - Write UI tests for Latest Workouts navigation without crashes
  - _Requirements: 1.1, 1.2, 1.3, 6.2_

- [x] 4. Create enhanced WatchConnectivity validation and retry system
  - ✅ Implement data validation methods in WatchConnectivityManager
  - ✅ Add payload checksum calculation and verification (SHA256)
  - ✅ Create retry mechanism with exponential backoff for failed transfers
  - ✅ Implement fallback file transfer when context transfer fails
  - ✅ Write unit tests for connectivity retry logic and validation
  - ⚠️ **Remaining compilation errors to fix:**
    - Replace remaining ErrorLogger/PivotPlayError references with print statements
    - Fix heterogeneous collection literal type annotation in userInfo
    - Remove unreachable catch block warning
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ] 5. Fix WCSession nil context handling
  - Add nil-safety checks in session didReceiveUserInfo and didReceiveMessageData
  - Implement graceful handling of empty or corrupt payload data
  - Add handshake confirmation mechanism between Watch and iPhone
  - Create error recovery for failed data transfers
  - Write integration tests for Watch-iPhone sync scenarios
  - _Requirements: 2.1, 2.2, 2.4_

- [ ] 6. Implement navigation state management system
  - Create NavigationStateManager class with transition tracking
  - Add thread-safe navigation methods with main queue dispatch
  - Implement navigation queuing to prevent concurrent transitions
  - Replace direct NavigationLink usage with managed navigation calls
  - Write unit tests for navigation state management and concurrency
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 7. Fix heatmap corner capture duplication issues
  - Implement corner debouncing logic in WorkoutManager.markCurrentCorner()
  - Add distance validation to prevent duplicate corner recordings within 5 meters
  - Create coordinate validation methods for corner capture
  - Write unit tests for corner capture debouncing and validation
  - _Requirements: 4.1, 4.3_

- [ ] 8. Implement distance calculation utilities and validation
  - Create CLLocationCoordinate2D extension with haversine distance calculation method
  - Add GPS coordinate validation to filter out invalid location points
  - Implement distance calculation validation against known test coordinates
  - Write unit tests with GPX sample files for distance validation
  - _Requirements: 4.2, 4.4, 4.5_

- [ ] 9. Reduce system log noise and deprecated API usage
  - Identify and replace deprecated BTLE APIs causing XPC warnings
  - Add log level filtering to reduce UIIntelligence noise
  - Implement conditional logging based on debug/release builds
  - Update OSLog categories for better log organization
  - Write tests to verify log noise reduction
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ] 10. Add comprehensive error handling to WorkoutDetailView
  - Implement safe unwrapping for workout data access
  - Add error states for missing or corrupt heatmap data
  - Create fallback UI when heatmap processing fails
  - Add retry mechanisms for failed heatmap generation
  - Write UI tests for WorkoutDetailView error scenarios
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 11. Create data migration and validation system
  - Implement schema version checking for workout data
  - Add data migration methods for existing workouts
  - Create validation methods for workout data integrity
  - Implement safe data cleanup for corrupt entries
  - Write tests for data migration scenarios
  - _Requirements: 6.4, 6.5_

- [ ] 12. Implement performance monitoring and memory management
  - Add memory pressure handling in HeatmapPipeline
  - Implement cleanup methods for large workout datasets
  - Create performance metrics collection for critical paths
  - Add memory leak detection in workout processing
  - Write performance tests to validate no CPU overhead from fixes
  - _Requirements: 6.5, 7.5_

- [ ] 13. Create comprehensive test suite for critical workflows
  - Write integration tests for complete workout creation and sync flow
  - Add UI tests for Latest Workouts access and heatmap display
  - Create unit tests for all error handling scenarios
  - Implement mock objects for WCSession and HealthKit testing
  - Add performance regression tests for fixed components
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 14. Integrate all fixes and validate end-to-end functionality
  - Connect all error handling systems with consistent user experience
  - Validate that all crash scenarios are resolved
  - Test complete Watch-to-iPhone workout sync with error recovery
  - Verify heatmap generation works correctly with fixed pipeline
  - Perform final integration testing across all fixed components
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1_