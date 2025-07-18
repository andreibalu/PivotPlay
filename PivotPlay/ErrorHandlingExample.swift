//
//  ErrorHandlingExample.swift
//  PivotPlay
//
//  Created by Kiro on 15.07.2025.
//

import Foundation

/// Example usage of the error handling infrastructure
/// This file demonstrates how to use PivotPlayError and ErrorLogger throughout the app
class ErrorHandlingExample {
    
    // MARK: - Storage Error Example
    @MainActor
    static func handleStorageError() {
        let context = ErrorContext(
            component: "WorkoutStorage",
            operation: "fetchWorkouts",
            additionalInfo: ["attemptCount": 1, "userId": "user123"]
        )
        
        let error = PivotPlayError.storageUnavailable
        ErrorLogger.shared.logError(error, context: context)
        
        // Check if error should be presented to user
        if error.shouldPresentToUser {
            // Present error to user with localized message
            print("User message: \(error.errorDescription ?? "Unknown error")")
            print("Recovery: \(error.recoverySuggestion ?? "Try again later")")
        }
        
        // Check if error should trigger retry
        if error.shouldRetry {
            // Implement retry logic
            print("Scheduling retry for storage operation")
        }
    }
    
    // MARK: - Connectivity Error Example
    @MainActor
    static func handleConnectivityError() {
        let context = ErrorContext(
            component: "WatchConnectivityManager",
            operation: "sendWorkoutData",
            additionalInfo: [
                "sessionState": "inactive",
                "dataSize": 1024,
                "retryCount": 2
            ]
        )
        
        let error = PivotPlayError.watchConnectivityFailed("Session is not reachable")
        ErrorLogger.shared.logError(error, context: context)
        
        // Log additional debug information
        ErrorLogger.shared.logDebug(
            "Watch connectivity details: session active=false, paired=true",
            component: "WatchConnectivityManager"
        )
    }
    
    // MARK: - Location Error Example
    @MainActor
    static func handleLocationError() {
        let context = ErrorContext(
            component: "WorkoutManager",
            operation: "startLocationTracking",
            additionalInfo: [
                "authorizationStatus": "denied",
                "accuracyAuthorization": "reducedAccuracy"
            ]
        )
        
        let error = PivotPlayError.locationPermissionDenied
        ErrorLogger.shared.logError(error, context: context)
        
        // This error should be presented to user
        if error.shouldPresentToUser {
            // Show location permission alert
            print("Location permission required for workout tracking")
        }
    }
    
    // MARK: - Heatmap Processing Error Example
    @MainActor
    static func handleHeatmapError() {
        let context = ErrorContext(
            component: "HeatmapPipeline",
            operation: "calculateDistance",
            additionalInfo: [
                "locationCount": 15,
                "cornerCount": 4,
                "workoutId": "workout-123"
            ]
        )
        
        let error = PivotPlayError.distanceCalculationFailed("Invalid coordinate sequence")
        ErrorLogger.shared.logError(error, context: context)
        
        // Log warning about data quality
        ErrorLogger.shared.logWarning(
            "Workout data may be incomplete due to GPS issues",
            component: "HeatmapPipeline"
        )
    }
    
    // MARK: - Critical Error Example
    @MainActor
    static func handleCriticalError() {
        let context = ErrorContext(
            component: "PivotPlayApp",
            operation: "applicationDidFinishLaunching",
            additionalInfo: [
                "memoryUsage": "85%",
                "availableStorage": "100MB"
            ]
        )
        
        let error = PivotPlayError.memoryPressure
        ErrorLogger.shared.logError(error, context: context)
        
        // Critical errors get special handling
        ErrorLogger.shared.logCritical(
            "App may need to terminate non-essential features",
            component: "PivotPlayApp"
        )
    }
    
    // MARK: - Generic Error Handling Example
    @MainActor
    static func handleGenericError() {
        struct CustomError: Error, LocalizedError {
            let code: Int
            var errorDescription: String? {
                return "Custom error with code \(code)"
            }
        }
        
        let customError = CustomError(code: 404)
        let context = ErrorContext(
            component: "NetworkManager",
            operation: "fetchData",
            additionalInfo: ["endpoint": "/api/workouts", "httpStatus": 404]
        )
        
        // Log generic error with custom severity
        ErrorLogger.shared.logError(customError, severity: .warning, context: context)
    }
    
    // MARK: - Logging Best Practices Example
    @MainActor
    static func demonstrateLoggingBestPractices() {
        // Use appropriate severity levels
        ErrorLogger.shared.logDebug("Starting workout sync process", component: "SyncManager")
        ErrorLogger.shared.logInfo("Successfully synced 5 workouts", component: "SyncManager")
        ErrorLogger.shared.logWarning("Sync took longer than expected (30s)", component: "SyncManager")
        ErrorLogger.shared.logError("Failed to sync workout data", component: "SyncManager")
        
        // Include context information
        let context = ErrorContext(
            component: "SyncManager",
            operation: "syncWorkouts",
            additionalInfo: [
                "workoutCount": 5,
                "syncDuration": 30.5,
                "networkType": "cellular",
                "batteryLevel": 0.25
            ]
        )
        
        ErrorLogger.shared.logMessage(
            "Sync completed with warnings",
            severity: .warning,
            context: context
        )
        
        // Retrieve and analyze error history
        let recentErrors = ErrorLogger.shared.getRecentErrors(count: 10)
        print("Recent error count: \(recentErrors.count)")
        
        let criticalErrors = ErrorLogger.shared.getErrorsWithSeverity(.critical)
        if !criticalErrors.isEmpty {
            print("Found \(criticalErrors.count) critical errors requiring attention")
        }
    }
}