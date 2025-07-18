//
//  PivotPlayError.swift
//  PivotPlay
//
//  Created by Kiro on 15.07.2025.
//

import Foundation

/// Comprehensive error types for PivotPlay application
enum PivotPlayError: Error, LocalizedError, Equatable {
    // MARK: - Storage Errors
    case storageUnavailable
    case storageInitializationFailed(String)
    case fetchFailed(String)
    case saveFailed(String)
    case corruptData(String)
    case dataValidationFailed(String)
    
    // MARK: - Network and Connectivity Errors
    case networkTimeout
    case watchConnectivityFailed(String)
    case syncFailed(String)
    case transferFailed(String)
    
    // MARK: - Location and GPS Errors
    case locationUnavailable
    case locationPermissionDenied
    case gpsAccuracyTooLow
    case invalidCoordinates(String)
    
    // MARK: - Navigation and UI Errors
    case navigationFailed(String)
    case uiStateInconsistent(String)
    case concurrentNavigationAttempt
    
    // MARK: - Heatmap and Processing Errors
    case heatmapProcessingFailed(String)
    case distanceCalculationFailed(String)
    case coordinateTransformationFailed(String)
    case invalidPitchData(String)
    
    // MARK: - System and Resource Errors
    case memoryPressure
    case systemResourceUnavailable(String)
    case backgroundTaskExpired
    
    // MARK: - LocalizedError Implementation
    var errorDescription: String? {
        switch self {
        // Storage Errors
        case .storageUnavailable:
            return NSLocalizedString("Workout storage is temporarily unavailable. Please try again later.", 
                                   comment: "Storage unavailable error")
        case .storageInitializationFailed(let details):
            return NSLocalizedString("Failed to initialize workout storage: \(details)", 
                                   comment: "Storage initialization error")
        case .fetchFailed(let details):
            return NSLocalizedString("Failed to load workouts: \(details)", 
                                   comment: "Fetch operation error")
        case .saveFailed(let details):
            return NSLocalizedString("Failed to save workout: \(details)", 
                                   comment: "Save operation error")
        case .corruptData(let details):
            return NSLocalizedString("Workout data is corrupted: \(details)", 
                                   comment: "Data corruption error")
        case .dataValidationFailed(let details):
            return NSLocalizedString("Data validation failed: \(details)", 
                                   comment: "Data validation error")
            
        // Network and Connectivity Errors
        case .networkTimeout:
            return NSLocalizedString("Connection to Apple Watch timed out. Please ensure your Watch is nearby and connected.", 
                                   comment: "Network timeout error")
        case .watchConnectivityFailed(let reason):
            return NSLocalizedString("Watch sync failed: \(reason)", 
                                   comment: "Watch connectivity error")
        case .syncFailed(let details):
            return NSLocalizedString("Data synchronization failed: \(details)", 
                                   comment: "Sync failure error")
        case .transferFailed(let details):
            return NSLocalizedString("Data transfer failed: \(details)", 
                                   comment: "Transfer failure error")
            
        // Location and GPS Errors
        case .locationUnavailable:
            return NSLocalizedString("Location services are not available. Please enable location access in Settings.", 
                                   comment: "Location unavailable error")
        case .locationPermissionDenied:
            return NSLocalizedString("Location permission denied. Please enable location access in Settings to track workouts.", 
                                   comment: "Location permission error")
        case .gpsAccuracyTooLow:
            return NSLocalizedString("GPS accuracy is too low for reliable tracking. Please move to an area with better GPS reception.", 
                                   comment: "GPS accuracy error")
        case .invalidCoordinates(let details):
            return NSLocalizedString("Invalid GPS coordinates detected: \(details)", 
                                   comment: "Invalid coordinates error")
            
        // Navigation and UI Errors
        case .navigationFailed(let details):
            return NSLocalizedString("Navigation failed: \(details)", 
                                   comment: "Navigation error")
        case .uiStateInconsistent(let details):
            return NSLocalizedString("User interface state is inconsistent: \(details)", 
                                   comment: "UI state error")
        case .concurrentNavigationAttempt:
            return NSLocalizedString("Multiple navigation attempts detected. Please wait for the current navigation to complete.", 
                                   comment: "Concurrent navigation error")
            
        // Heatmap and Processing Errors
        case .heatmapProcessingFailed(let details):
            return NSLocalizedString("Heatmap processing failed: \(details)", 
                                   comment: "Heatmap processing error")
        case .distanceCalculationFailed(let details):
            return NSLocalizedString("Distance calculation failed: \(details)", 
                                   comment: "Distance calculation error")
        case .coordinateTransformationFailed(let details):
            return NSLocalizedString("Coordinate transformation failed: \(details)", 
                                   comment: "Coordinate transformation error")
        case .invalidPitchData(let details):
            return NSLocalizedString("Invalid pitch data: \(details)", 
                                   comment: "Invalid pitch data error")
            
        // System and Resource Errors
        case .memoryPressure:
            return NSLocalizedString("The app is experiencing memory pressure. Some features may be temporarily unavailable.", 
                                   comment: "Memory pressure error")
        case .systemResourceUnavailable(let resource):
            return NSLocalizedString("System resource unavailable: \(resource)", 
                                   comment: "System resource error")
        case .backgroundTaskExpired:
            return NSLocalizedString("Background task expired. Some data may not have been processed.", 
                                   comment: "Background task error")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .storageUnavailable, .storageInitializationFailed:
            return NSLocalizedString("The workout database could not be accessed.", 
                                   comment: "Storage failure reason")
        case .networkTimeout, .watchConnectivityFailed, .syncFailed, .transferFailed:
            return NSLocalizedString("Communication with Apple Watch failed.", 
                                   comment: "Connectivity failure reason")
        case .locationUnavailable, .locationPermissionDenied, .gpsAccuracyTooLow:
            return NSLocalizedString("Location services are required for workout tracking.", 
                                   comment: "Location failure reason")
        case .heatmapProcessingFailed, .distanceCalculationFailed, .coordinateTransformationFailed:
            return NSLocalizedString("Workout data processing encountered an error.", 
                                   comment: "Processing failure reason")
        case .memoryPressure, .systemResourceUnavailable, .backgroundTaskExpired:
            return NSLocalizedString("System resources are temporarily limited.", 
                                   comment: "System failure reason")
        default:
            return NSLocalizedString("An unexpected error occurred.", 
                                   comment: "Generic failure reason")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .storageUnavailable, .storageInitializationFailed:
            return NSLocalizedString("Try restarting the app. If the problem persists, contact support.", 
                                   comment: "Storage recovery suggestion")
        case .networkTimeout, .watchConnectivityFailed:
            return NSLocalizedString("Ensure your Apple Watch is nearby and connected, then try again.", 
                                   comment: "Connectivity recovery suggestion")
        case .locationUnavailable, .locationPermissionDenied:
            return NSLocalizedString("Go to Settings > Privacy & Security > Location Services and enable location access for PivotPlay.", 
                                   comment: "Location recovery suggestion")
        case .gpsAccuracyTooLow:
            return NSLocalizedString("Move to an open area with clear sky view and wait for better GPS signal.", 
                                   comment: "GPS recovery suggestion")
        case .memoryPressure:
            return NSLocalizedString("Close other apps to free up memory, then try again.", 
                                   comment: "Memory recovery suggestion")
        case .concurrentNavigationAttempt:
            return NSLocalizedString("Wait a moment and try navigating again.", 
                                   comment: "Navigation recovery suggestion")
        default:
            return NSLocalizedString("Try the operation again. If the problem persists, restart the app.", 
                                   comment: "Generic recovery suggestion")
        }
    }
}

// MARK: - Error Severity Classification
extension PivotPlayError {
    /// Categorizes errors by severity level for logging and handling purposes
    var severity: ErrorSeverity {
        switch self {
        case .storageInitializationFailed, .memoryPressure:
            return .critical
        case .storageUnavailable, .fetchFailed, .saveFailed, .watchConnectivityFailed, .syncFailed:
            return .error
        case .corruptData, .dataValidationFailed, .networkTimeout, .transferFailed, .heatmapProcessingFailed:
            return .warning
        case .gpsAccuracyTooLow, .invalidCoordinates, .distanceCalculationFailed, .coordinateTransformationFailed:
            return .info
        default:
            return .error
        }
    }
    
    /// Determines if the error should be presented to the user
    var shouldPresentToUser: Bool {
        switch self {
        case .storageUnavailable, .networkTimeout, .locationPermissionDenied, .concurrentNavigationAttempt:
            return true
        case .storageInitializationFailed, .memoryPressure:
            return true
        default:
            return false
        }
    }
    
    /// Determines if the error should trigger automatic retry
    var shouldRetry: Bool {
        switch self {
        case .networkTimeout, .transferFailed, .gpsAccuracyTooLow:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Context Information
struct ErrorContext {
    let timestamp: Date
    let component: String
    let operation: String
    let additionalInfo: [String: Any]
    
    init(component: String, operation: String, additionalInfo: [String: Any] = [:]) {
        self.timestamp = Date()
        self.component = component
        self.operation = operation
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Error Severity Levels
enum ErrorSeverity: String, CaseIterable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        let order: [ErrorSeverity] = [.debug, .info, .warning, .error, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}