//
//  ErrorLogger.swift
//  PivotPlay
//
//  Created by Kiro on 15.07.2025.
//

import Foundation
import OSLog

/// Centralized error logging system with OSLog integration and context tracking
@MainActor
class ErrorLogger {
    static let shared = ErrorLogger()
    
    // MARK: - OSLog Categories
    private let generalLog = Logger(subsystem: "com.pivotplay.app", category: "General")
    private let storageLog = Logger(subsystem: "com.pivotplay.app", category: "Storage")
    private let connectivityLog = Logger(subsystem: "com.pivotplay.app", category: "Connectivity")
    private let locationLog = Logger(subsystem: "com.pivotplay.app", category: "Location")
    private let navigationLog = Logger(subsystem: "com.pivotplay.app", category: "Navigation")
    private let heatmapLog = Logger(subsystem: "com.pivotplay.app", category: "Heatmap")
    private let systemLog = Logger(subsystem: "com.pivotplay.app", category: "System")
    
    // MARK: - Error Storage
    private var errorHistory: [ErrorLogEntry] = []
    private let maxErrorHistory = 100
    private let errorHistoryQueue = DispatchQueue(label: "error.history.queue", qos: .utility)
    
    // MARK: - Configuration
    private var minimumLogLevel: ErrorSeverity = .info
    private var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    private init() {
        // Set minimum log level based on build configuration
        minimumLogLevel = isDebugMode ? .debug : .warning
    }
    
    // MARK: - Primary Logging Methods
    
    /// Log a PivotPlayError with full context and severity handling
    func logError(_ error: PivotPlayError, context: ErrorContext? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let severity = error.severity
        let logContext = context ?? ErrorContext(
            component: extractFileName(from: file),
            operation: function
        )
        
        let entry = ErrorLogEntry(
            error: error,
            context: logContext,
            severity: severity,
            file: file,
            function: function,
            line: line
        )
        
        logEntry(entry)
    }
    
    /// Log a generic Error with specified severity and context
    func logError(_ error: Error, severity: ErrorSeverity, context: ErrorContext, file: String = #file, function: String = #function, line: Int = #line) {
        let entry = ErrorLogEntry(
            error: error,
            context: context,
            severity: severity,
            file: file,
            function: function,
            line: line
        )
        
        logEntry(entry)
    }
    
    /// Log a message with specified severity and context
    func logMessage(_ message: String, severity: ErrorSeverity, context: ErrorContext, file: String = #file, function: String = #function, line: Int = #line) {
        let entry = ErrorLogEntry(
            message: message,
            context: context,
            severity: severity,
            file: file,
            function: function,
            line: line
        )
        
        logEntry(entry)
    }
    
    // MARK: - Convenience Methods
    
    func logDebug(_ message: String, component: String, operation: String = #function) {
        let context = ErrorContext(component: component, operation: operation)
        logMessage(message, severity: .debug, context: context)
    }
    
    func logInfo(_ message: String, component: String, operation: String = #function) {
        let context = ErrorContext(component: component, operation: operation)
        logMessage(message, severity: .info, context: context)
    }
    
    func logWarning(_ message: String, component: String, operation: String = #function) {
        let context = ErrorContext(component: component, operation: operation)
        logMessage(message, severity: .warning, context: context)
    }
    
    func logError(_ message: String, component: String, operation: String = #function) {
        let context = ErrorContext(component: component, operation: operation)
        logMessage(message, severity: .error, context: context)
    }
    
    func logCritical(_ message: String, component: String, operation: String = #function) {
        let context = ErrorContext(component: component, operation: operation)
        logMessage(message, severity: .critical, context: context)
    }
    
    // MARK: - Core Logging Implementation
    
    private func logEntry(_ entry: ErrorLogEntry) {
        // Check if we should log based on minimum level
        guard entry.severity >= minimumLogLevel else { return }
        
        // Store in history for debugging
        storeInHistory(entry)
        
        // Log to appropriate OSLog category
        let logger = getLogger(for: entry.context.component)
        let logMessage = formatLogMessage(entry)
        
        switch entry.severity {
        case .debug:
            logger.debug("\(logMessage, privacy: .public)")
        case .info:
            logger.info("\(logMessage, privacy: .public)")
        case .warning:
            logger.warning("\(logMessage, privacy: .public)")
        case .error:
            logger.error("\(logMessage, privacy: .public)")
        case .critical:
            logger.critical("\(logMessage, privacy: .public)")
        }
        
        // Additional handling for critical errors
        if entry.severity == .critical {
            handleCriticalError(entry)
        }
    }
    
    private func getLogger(for component: String) -> Logger {
        let lowercaseComponent = component.lowercased()
        
        if lowercaseComponent.contains("storage") || lowercaseComponent.contains("workout") {
            return storageLog
        } else if lowercaseComponent.contains("connectivity") || lowercaseComponent.contains("watch") {
            return connectivityLog
        } else if lowercaseComponent.contains("location") || lowercaseComponent.contains("gps") {
            return locationLog
        } else if lowercaseComponent.contains("navigation") || lowercaseComponent.contains("ui") {
            return navigationLog
        } else if lowercaseComponent.contains("heatmap") || lowercaseComponent.contains("pipeline") {
            return heatmapLog
        } else if lowercaseComponent.contains("system") || lowercaseComponent.contains("memory") {
            return systemLog
        } else {
            return generalLog
        }
    }
    
    private func formatLogMessage(_ entry: ErrorLogEntry) -> String {
        var components: [String] = []
        
        // Add severity and timestamp
        let timestamp = DateFormatter.logFormatter.string(from: entry.timestamp)
        components.append("[\(entry.severity.rawValue)] \(timestamp)")
        
        // Add component and operation
        components.append("[\(entry.context.component).\(entry.context.operation)]")
        
        // Add main message
        if let error = entry.error {
            if let pivotError = error as? PivotPlayError {
                components.append(pivotError.errorDescription ?? "Unknown PivotPlay error")
            } else {
                components.append(error.localizedDescription)
            }
        } else if let message = entry.message {
            components.append(message)
        }
        
        // Add file location in debug mode
        if isDebugMode {
            let fileName = extractFileName(from: entry.file)
            components.append("(\(fileName):\(entry.line))")
        }
        
        // Add additional context info
        if !entry.context.additionalInfo.isEmpty {
            let contextInfo = entry.context.additionalInfo
                .map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            components.append("Context: {\(contextInfo)}")
        }
        
        return components.joined(separator: " ")
    }
    
    private func storeInHistory(_ entry: ErrorLogEntry) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            self.errorHistory.append(entry)
            
            // Maintain history size limit
            if self.errorHistory.count > self.maxErrorHistory {
                self.errorHistory.removeFirst(self.errorHistory.count - self.maxErrorHistory)
            }
        }
    }
    
    private func handleCriticalError(_ entry: ErrorLogEntry) {
        // For critical errors, we might want to:
        // 1. Send crash reports (in production)
        // 2. Trigger emergency data saves
        // 3. Notify monitoring systems
        
        #if DEBUG
        // In debug mode, we can be more aggressive with critical error handling
        print("🚨 CRITICAL ERROR DETECTED 🚨")
        print(formatLogMessage(entry))
        #endif
    }
    
    // MARK: - Utility Methods
    
    private func extractFileName(from filePath: String) -> String {
        return (filePath as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
    }
    
    // MARK: - Configuration Methods
    
    func setMinimumLogLevel(_ level: ErrorSeverity) {
        minimumLogLevel = level
    }
    
    func getErrorHistory() -> [ErrorLogEntry] {
        return Array(errorHistory)
    }
    
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Debug and Testing Support
    
    func getRecentErrors(count: Int = 10) -> [ErrorLogEntry] {
        return Array(errorHistory.suffix(count))
    }
    
    func getErrorsWithSeverity(_ severity: ErrorSeverity) -> [ErrorLogEntry] {
        return errorHistory.filter { $0.severity == severity }
    }
}

// MARK: - Error Log Entry
struct ErrorLogEntry {
    let id = UUID()
    let timestamp: Date
    let error: Error?
    let message: String?
    let context: ErrorContext
    let severity: ErrorSeverity
    let file: String
    let function: String
    let line: Int
    
    init(error: Error, context: ErrorContext, severity: ErrorSeverity, file: String, function: String, line: Int) {
        self.timestamp = Date()
        self.error = error
        self.message = nil
        self.context = context
        self.severity = severity
        self.file = file
        self.function = function
        self.line = line
    }
    
    init(message: String, context: ErrorContext, severity: ErrorSeverity, file: String, function: String, line: Int) {
        self.timestamp = Date()
        self.error = nil
        self.message = message
        self.context = context
        self.severity = severity
        self.file = file
        self.function = function
        self.line = line
    }
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}