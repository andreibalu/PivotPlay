//
//  ErrorHandlingTests.swift
//  PivotPlayTests
//
//  Created by Kiro on 15.07.2025.
//

import XCTest
@testable import PivotPlay

@MainActor
final class ErrorHandlingTests: XCTestCase {
    
    var errorLogger: ErrorLogger!
    
    override func setUp() async throws {
        try await super.setUp()
        errorLogger = ErrorLogger.shared
        errorLogger.clearErrorHistory()
    }
    
    override func tearDown() async throws {
        errorLogger.clearErrorHistory()
        try await super.tearDown()
    }
    
    // MARK: - PivotPlayError Tests
    
    func testPivotPlayErrorLocalizedDescriptions() {
        // Test storage errors
        let storageError = PivotPlayError.storageUnavailable
        XCTAssertNotNil(storageError.errorDescription)
        XCTAssertTrue(storageError.errorDescription!.contains("storage"))
        
        let initError = PivotPlayError.storageInitializationFailed("Database locked")
        XCTAssertNotNil(initError.errorDescription)
        XCTAssertTrue(initError.errorDescription!.contains("Database locked"))
        
        // Test connectivity errors
        let networkError = PivotPlayError.networkTimeout
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription!.contains("Watch"))
        
        let watchError = PivotPlayError.watchConnectivityFailed("Session inactive")
        XCTAssertNotNil(watchError.errorDescription)
        XCTAssertTrue(watchError.errorDescription!.contains("Session inactive"))
        
        // Test location errors
        let locationError = PivotPlayError.locationUnavailable
        XCTAssertNotNil(locationError.errorDescription)
        XCTAssertTrue(locationError.errorDescription!.contains("Location"))
        
        // Test heatmap errors
        let heatmapError = PivotPlayError.heatmapProcessingFailed("Invalid coordinates")
        XCTAssertNotNil(heatmapError.errorDescription)
        XCTAssertTrue(heatmapError.errorDescription!.contains("Invalid coordinates"))
    }
    
    func testPivotPlayErrorSeverityClassification() {
        // Critical errors
        XCTAssertEqual(PivotPlayError.storageInitializationFailed("test").severity, .critical)
        XCTAssertEqual(PivotPlayError.memoryPressure.severity, .critical)
        
        // Error level
        XCTAssertEqual(PivotPlayError.storageUnavailable.severity, .error)
        XCTAssertEqual(PivotPlayError.fetchFailed("test").severity, .error)
        XCTAssertEqual(PivotPlayError.watchConnectivityFailed("test").severity, .error)
        
        // Warning level
        XCTAssertEqual(PivotPlayError.corruptData("test").severity, .warning)
        XCTAssertEqual(PivotPlayError.networkTimeout.severity, .warning)
        
        // Info level
        XCTAssertEqual(PivotPlayError.gpsAccuracyTooLow.severity, .info)
        XCTAssertEqual(PivotPlayError.invalidCoordinates("test").severity, .info)
    }
    
    func testPivotPlayErrorUserPresentationFlags() {
        // Should present to user
        XCTAssertTrue(PivotPlayError.storageUnavailable.shouldPresentToUser)
        XCTAssertTrue(PivotPlayError.networkTimeout.shouldPresentToUser)
        XCTAssertTrue(PivotPlayError.locationPermissionDenied.shouldPresentToUser)
        XCTAssertTrue(PivotPlayError.memoryPressure.shouldPresentToUser)
        
        // Should not present to user (internal errors)
        XCTAssertFalse(PivotPlayError.corruptData("test").shouldPresentToUser)
        XCTAssertFalse(PivotPlayError.distanceCalculationFailed("test").shouldPresentToUser)
    }
    
    func testPivotPlayErrorRetryFlags() {
        // Should retry
        XCTAssertTrue(PivotPlayError.networkTimeout.shouldRetry)
        XCTAssertTrue(PivotPlayError.transferFailed("test").shouldRetry)
        XCTAssertTrue(PivotPlayError.gpsAccuracyTooLow.shouldRetry)
        
        // Should not retry
        XCTAssertFalse(PivotPlayError.storageInitializationFailed("test").shouldRetry)
        XCTAssertFalse(PivotPlayError.locationPermissionDenied.shouldRetry)
        XCTAssertFalse(PivotPlayError.corruptData("test").shouldRetry)
    }
    
    func testPivotPlayErrorRecoverySuggestions() {
        let storageError = PivotPlayError.storageUnavailable
        XCTAssertNotNil(storageError.recoverySuggestion)
        XCTAssertTrue(storageError.recoverySuggestion!.contains("restart"))
        
        let locationError = PivotPlayError.locationPermissionDenied
        XCTAssertNotNil(locationError.recoverySuggestion)
        XCTAssertTrue(locationError.recoverySuggestion!.contains("Settings"))
        
        let memoryError = PivotPlayError.memoryPressure
        XCTAssertNotNil(memoryError.recoverySuggestion)
        XCTAssertTrue(memoryError.recoverySuggestion!.contains("Close other apps"))
    }
    
    // MARK: - ErrorLogger Tests
    
    func testErrorLoggerSingleton() {
        let logger1 = ErrorLogger.shared
        let logger2 = ErrorLogger.shared
        XCTAssertTrue(logger1 === logger2, "ErrorLogger should be a singleton")
    }
    
    func testLogPivotPlayError() {
        let error = PivotPlayError.storageUnavailable
        let context = ErrorContext(component: "TestComponent", operation: "testOperation")
        
        errorLogger.logError(error, context: context)
        
        let history = errorLogger.getErrorHistory()
        XCTAssertEqual(history.count, 1)
        
        let logEntry = history.first!
        XCTAssertEqual(logEntry.severity, .error)
        XCTAssertEqual(logEntry.context.component, "TestComponent")
        XCTAssertEqual(logEntry.context.operation, "testOperation")
        XCTAssertNotNil(logEntry.error)
    }
    
    func testLogGenericError() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error description" }
        }
        
        let error = TestError()
        let context = ErrorContext(component: "TestComponent", operation: "testOperation")
        
        errorLogger.logError(error, severity: .warning, context: context)
        
        let history = errorLogger.getErrorHistory()
        XCTAssertEqual(history.count, 1)
        
        let logEntry = history.first!
        XCTAssertEqual(logEntry.severity, .warning)
        XCTAssertNotNil(logEntry.error)
    }
    
    func testLogMessage() {
        let message = "Test log message"
        let context = ErrorContext(component: "TestComponent", operation: "testOperation")
        
        errorLogger.logMessage(message, severity: .info, context: context)
        
        let history = errorLogger.getErrorHistory()
        XCTAssertEqual(history.count, 1)
        
        let logEntry = history.first!
        XCTAssertEqual(logEntry.severity, .info)
        XCTAssertEqual(logEntry.message, message)
        XCTAssertNil(logEntry.error)
    }
    
    func testConvenienceLoggingMethods() {
        errorLogger.logDebug("Debug message", component: "TestComponent")
        errorLogger.logInfo("Info message", component: "TestComponent")
        errorLogger.logWarning("Warning message", component: "TestComponent")
        errorLogger.logError("Error message", component: "TestComponent")
        errorLogger.logCritical("Critical message", component: "TestComponent")
        
        let history = errorLogger.getErrorHistory()
        XCTAssertEqual(history.count, 5)
        
        // Check severities
        let severities = history.map { $0.severity }
        XCTAssertTrue(severities.contains(.debug))
        XCTAssertTrue(severities.contains(.info))
        XCTAssertTrue(severities.contains(.warning))
        XCTAssertTrue(severities.contains(.error))
        XCTAssertTrue(severities.contains(.critical))
    }
    
    func testErrorHistoryManagement() {
        // Add multiple errors
        for i in 0..<5 {
            let context = ErrorContext(component: "TestComponent", operation: "operation\(i)")
            errorLogger.logMessage("Message \(i)", severity: .info, context: context)
        }
        
        let history = errorLogger.getErrorHistory()
        XCTAssertEqual(history.count, 5)
        
        // Test recent errors
        let recentErrors = errorLogger.getRecentErrors(count: 3)
        XCTAssertEqual(recentErrors.count, 3)
        XCTAssertEqual(recentErrors.last?.context.operation, "operation4")
        
        // Clear history
        errorLogger.clearErrorHistory()
        let clearedHistory = errorLogger.getErrorHistory()
        XCTAssertEqual(clearedHistory.count, 0)
    }
    
    func testErrorFilteringBySeverity() {
        // Add errors with different severities
        let context = ErrorContext(component: "TestComponent", operation: "testOperation")
        
        errorLogger.logMessage("Info message", severity: .info, context: context)
        errorLogger.logMessage("Warning message", severity: .warning, context: context)
        errorLogger.logMessage("Error message", severity: .error, context: context)
        errorLogger.logMessage("Another info message", severity: .info, context: context)
        
        let infoErrors = errorLogger.getErrorsWithSeverity(.info)
        XCTAssertEqual(infoErrors.count, 2)
        
        let warningErrors = errorLogger.getErrorsWithSeverity(.warning)
        XCTAssertEqual(warningErrors.count, 1)
        
        let errorErrors = errorLogger.getErrorsWithSeverity(.error)
        XCTAssertEqual(errorErrors.count, 1)
        
        let criticalErrors = errorLogger.getErrorsWithSeverity(.critical)
        XCTAssertEqual(criticalErrors.count, 0)
    }
    
    func testMinimumLogLevel() {
        // Set minimum log level to warning
        errorLogger.setMinimumLogLevel(.warning)
        
        let context = ErrorContext(component: "TestComponent", operation: "testOperation")
        
        // These should not be logged
        errorLogger.logMessage("Debug message", severity: .debug, context: context)
        errorLogger.logMessage("Info message", severity: .info, context: context)
        
        // These should be logged
        errorLogger.logMessage("Warning message", severity: .warning, context: context)
        errorLogger.logMessage("Error message", severity: .error, context: context)
        
        let history = errorLogger.getErrorHistory()
        XCTAssertEqual(history.count, 2)
        
        let severities = history.map { $0.severity }
        XCTAssertTrue(severities.contains(.warning))
        XCTAssertTrue(severities.contains(.error))
        XCTAssertFalse(severities.contains(.debug))
        XCTAssertFalse(severities.contains(.info))
    }
    
    // MARK: - ErrorContext Tests
    
    func testErrorContextCreation() {
        let additionalInfo = ["key1": "value1", "key2": 42] as [String: Any]
        let context = ErrorContext(
            component: "TestComponent",
            operation: "testOperation",
            additionalInfo: additionalInfo
        )
        
        XCTAssertEqual(context.component, "TestComponent")
        XCTAssertEqual(context.operation, "testOperation")
        XCTAssertEqual(context.additionalInfo.count, 2)
        XCTAssertEqual(context.additionalInfo["key1"] as? String, "value1")
        XCTAssertEqual(context.additionalInfo["key2"] as? Int, 42)
        XCTAssertNotNil(context.timestamp)
    }
    
    // MARK: - ErrorSeverity Tests
    
    func testErrorSeverityComparison() {
        XCTAssertTrue(ErrorSeverity.debug < ErrorSeverity.info)
        XCTAssertTrue(ErrorSeverity.info < ErrorSeverity.warning)
        XCTAssertTrue(ErrorSeverity.warning < ErrorSeverity.error)
        XCTAssertTrue(ErrorSeverity.error < ErrorSeverity.critical)
        
        XCTAssertFalse(ErrorSeverity.critical < ErrorSeverity.error)
        XCTAssertFalse(ErrorSeverity.error < ErrorSeverity.warning)
    }
    
    func testErrorSeverityAllCases() {
        let allCases = ErrorSeverity.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.debug))
        XCTAssertTrue(allCases.contains(.info))
        XCTAssertTrue(allCases.contains(.warning))
        XCTAssertTrue(allCases.contains(.error))
        XCTAssertTrue(allCases.contains(.critical))
    }
    
    // MARK: - Integration Tests
    
    func testErrorLoggingWithPivotPlayErrorIntegration() {
        // Test that PivotPlayError integrates properly with ErrorLogger
        let storageError = PivotPlayError.storageInitializationFailed("Database corruption detected")
        let context = ErrorContext(
            component: "WorkoutStorage",
            operation: "initialize",
            additionalInfo: ["databasePath": "/path/to/db", "errorCode": 500]
        )
        
        errorLogger.logError(storageError, context: context)
        
        let history = errorLogger.getErrorHistory()
        XCTAssertEqual(history.count, 1)
        
        let logEntry = history.first!
        XCTAssertEqual(logEntry.severity, .critical) // storageInitializationFailed should be critical
        XCTAssertEqual(logEntry.context.component, "WorkoutStorage")
        XCTAssertEqual(logEntry.context.operation, "initialize")
        XCTAssertEqual(logEntry.context.additionalInfo.count, 2)
        
        // Verify the error is properly stored
        if let pivotError = logEntry.error as? PivotPlayError {
            XCTAssertEqual(pivotError, storageError)
        } else {
            XCTFail("Error should be a PivotPlayError")
        }
    }
    
    func testConcurrentLogging() {
        let expectation = XCTestExpectation(description: "Concurrent logging completed")
        let context = ErrorContext(component: "TestComponent", operation: "concurrentTest")
        
        // Simulate concurrent logging from multiple threads
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            Task { @MainActor in
                errorLogger.logMessage("Concurrent message \(index)", severity: .info, context: context)
            }
        }
        
        // Wait a bit for async operations to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let history = self.errorLogger.getErrorHistory()
            XCTAssertEqual(history.count, 10)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}