
import Foundation
import SwiftData
import CoreLocation

#if os(iOS)
@MainActor
class WorkoutStorage {
    static let shared = WorkoutStorage()
    
    // MARK: - Storage State
    private let container: ModelContainer?
    private let context: ModelContext?
    private var isHealthy: Bool = false
    private let accessQueue = DispatchQueue(label: "workout.storage.access", qos: .userInitiated)
    
    // MARK: - Fallback Storage
    private var fallbackWorkouts: [WorkoutSession] = []
    private var isFallbackMode: Bool = false

    // MARK: - Safe Initialization
    private init() {
        do {
            let fullSchema = Schema([WorkoutSession.self])
            let container = try ModelContainer(for: fullSchema, configurations: [])
            let context = ModelContext(container)
            
            // Test the container with a simple operation
            _ = try context.fetch(FetchDescriptor<WorkoutSession>())
            
            self.container = container
            self.context = context
            self.isHealthy = true
            
            ErrorLogger.shared.logInfo(
                "WorkoutStorage initialized successfully",
                component: "WorkoutStorage",
                operation: "init"
            )
            
        } catch {
            self.container = nil
            self.context = nil
            self.isHealthy = false
            self.isFallbackMode = true
            
            let errorContext = ErrorContext(
                component: "WorkoutStorage",
                operation: "init",
                additionalInfo: ["error": error.localizedDescription]
            )
            
            ErrorLogger.shared.logError(
                PivotPlayError.storageInitializationFailed(error.localizedDescription),
                context: errorContext
            )
            
            // Initialize fallback storage
            initializeFallbackStorage()
        }
    }
    
    // MARK: - Fallback Storage Implementation
    private func initializeFallbackStorage() {
        fallbackWorkouts = []
        ErrorLogger.shared.logWarning(
            "Initialized fallback in-memory storage",
            component: "WorkoutStorage",
            operation: "initializeFallbackStorage"
        )
    }

    // MARK: - Public Interface with Result Types
    
    /// Fetch all workouts with comprehensive error handling
    func fetchWorkouts() -> Result<[WorkoutSession], PivotPlayError> {
        return accessQueue.sync {
            // Check if we're in fallback mode
            if isFallbackMode {
                ErrorLogger.shared.logInfo(
                    "Returning \(fallbackWorkouts.count) workouts from fallback storage",
                    component: "WorkoutStorage",
                    operation: "fetchWorkouts"
                )
                return .success(fallbackWorkouts)
            }
            
            // Check storage health
            guard isHealthy, let context = context else {
                let error = PivotPlayError.storageUnavailable
                ErrorLogger.shared.logError(error, context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "fetchWorkouts"
                ))
                return .failure(error)
            }
            
            do {
                let descriptor = FetchDescriptor<WorkoutSession>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let workouts = try context.fetch(descriptor)
                
                // Validate fetched data
                let validatedWorkouts = workouts.compactMap { workout in
                    validateWorkoutData(workout) ? workout : nil
                }
                
                if validatedWorkouts.count != workouts.count {
                    let corruptCount = workouts.count - validatedWorkouts.count
                    ErrorLogger.shared.logWarning(
                        "Filtered out \(corruptCount) corrupted workout(s)",
                        component: "WorkoutStorage",
                        operation: "fetchWorkouts"
                    )
                }
                
                return .success(validatedWorkouts)
                
            } catch {
                let pivotError = PivotPlayError.fetchFailed(error.localizedDescription)
                ErrorLogger.shared.logError(pivotError, context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "fetchWorkouts",
                    additionalInfo: ["error": error.localizedDescription]
                ))
                return .failure(pivotError)
            }
        }
    }
    
    /// Save workout with comprehensive error handling
    func saveWorkout(_ workout: WorkoutSession) -> Result<Void, PivotPlayError> {
        return accessQueue.sync {
            // Validate workout data before saving
            guard validateWorkoutData(workout) else {
                let error = PivotPlayError.dataValidationFailed("Invalid workout data")
                ErrorLogger.shared.logError(error, context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "saveWorkout",
                    additionalInfo: ["workoutId": workout.id.uuidString]
                ))
                return .failure(error)
            }
            
            // Handle fallback mode
            if isFallbackMode {
                fallbackWorkouts.append(workout)
                fallbackWorkouts.sort { $0.date > $1.date }
                ErrorLogger.shared.logInfo(
                    "Saved workout to fallback storage",
                    component: "WorkoutStorage",
                    operation: "saveWorkout"
                )
                return .success(())
            }
            
            // Check storage health
            guard isHealthy, let context = context else {
                let error = PivotPlayError.storageUnavailable
                ErrorLogger.shared.logError(error, context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "saveWorkout",
                    additionalInfo: ["workoutId": workout.id.uuidString]
                ))
                return .failure(error)
            }
            
            do {
                context.insert(workout)
                try context.save()
                
                ErrorLogger.shared.logInfo(
                    "Successfully saved workout",
                    component: "WorkoutStorage",
                    operation: "saveWorkout"
                )
                return .success(())
                
            } catch {
                let pivotError = PivotPlayError.saveFailed(error.localizedDescription)
                ErrorLogger.shared.logError(pivotError, context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "saveWorkout",
                    additionalInfo: [
                        "workoutId": workout.id.uuidString,
                        "error": error.localizedDescription
                    ]
                ))
                return .failure(pivotError)
            }
        }
    }
    
    /// Delete single workout with error handling
    func deleteWorkout(_ workout: WorkoutSession) -> Result<Void, PivotPlayError> {
        return accessQueue.sync {
            // Handle fallback mode
            if isFallbackMode {
                fallbackWorkouts.removeAll { $0.id == workout.id }
                ErrorLogger.shared.logInfo(
                    "Deleted workout from fallback storage",
                    component: "WorkoutStorage",
                    operation: "deleteWorkout"
                )
                return .success(())
            }
            
            // Check storage health
            guard isHealthy, let context = context else {
                let error = PivotPlayError.storageUnavailable
                ErrorLogger.shared.logError(error, context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "deleteWorkout",
                    additionalInfo: ["workoutId": workout.id.uuidString]
                ))
                return .failure(error)
            }
            
            do {
                context.delete(workout)
                try context.save()
                
                ErrorLogger.shared.logInfo(
                    "Successfully deleted workout",
                    component: "WorkoutStorage",
                    operation: "deleteWorkout"
                )
                return .success(())
                
            } catch {
                let pivotError = PivotPlayError.saveFailed(error.localizedDescription)
                ErrorLogger.shared.logError(pivotError, context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "deleteWorkout",
                    additionalInfo: [
                        "workoutId": workout.id.uuidString,
                        "error": error.localizedDescription
                    ]
                ))
                return .failure(pivotError)
            }
        }
    }
    
    /// Delete multiple workouts with error handling
    func deleteWorkouts(_ workouts: [WorkoutSession]) -> Result<Void, PivotPlayError> {
        return accessQueue.sync {
            // Handle fallback mode
            if isFallbackMode {
                let workoutIds = Set(workouts.map { $0.id })
                fallbackWorkouts.removeAll { workoutIds.contains($0.id) }
                ErrorLogger.shared.logInfo(
                    "Deleted \(workouts.count) workouts from fallback storage",
                    component: "WorkoutStorage",
                    operation: "deleteWorkouts"
                )
                return .success(())
            }
            
            // Check storage health
            guard isHealthy, let context = context else {
                let error = PivotPlayError.storageUnavailable
                ErrorLogger.shared.logError(error, context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "deleteWorkouts",
                    additionalInfo: ["count": workouts.count]
                ))
                return .failure(error)
            }
            
            do {
                for workout in workouts {
                    context.delete(workout)
                }
                try context.save()
                
                ErrorLogger.shared.logInfo(
                    "Successfully deleted \(workouts.count) workouts",
                    component: "WorkoutStorage",
                    operation: "deleteWorkouts"
                )
                return .success(())
                
            } catch {
                let pivotError = PivotPlayError.saveFailed(error.localizedDescription)
                ErrorLogger.shared.logError(pivotError, context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "deleteWorkouts",
                    additionalInfo: [
                        "count": workouts.count,
                        "error": error.localizedDescription
                    ]
                ))
                return .failure(pivotError)
            }
        }
    }
    
    // MARK: - Data Validation Methods
    
    /// Validate workout data for corruption detection
    func validateWorkoutData(_ workout: WorkoutSession) -> Bool {
        // Basic validation checks
        guard workout.duration >= 0 else {
            ErrorLogger.shared.logWarning(
                "Invalid workout duration: \(workout.duration)",
                component: "WorkoutStorage",
                operation: "validateWorkoutData"
            )
            return false
        }
        
        guard workout.totalDistance >= 0 else {
            ErrorLogger.shared.logWarning(
                "Invalid workout distance: \(workout.totalDistance)",
                component: "WorkoutStorage",
                operation: "validateWorkoutData"
            )
            return false
        }
        
        // Validate heart rate data
        for heartRate in workout.heartRateData {
            guard heartRate.value > 0 && heartRate.value < 300 else {
                ErrorLogger.shared.logWarning(
                    "Invalid heart rate value: \(heartRate.value)",
                    component: "WorkoutStorage",
                    operation: "validateWorkoutData"
                )
                return false
            }
        }
        
        // Validate location data
        for location in workout.locationData {
            guard isValidCoordinate(location.coordinate) else {
                ErrorLogger.shared.logWarning(
                    "Invalid coordinate: \(location.coordinate)",
                    component: "WorkoutStorage",
                    operation: "validateWorkoutData"
                )
                return false
            }
        }
        
        // Validate corners if present
        if let corners = workout.corners {
            for corner in corners {
                guard isValidCoordinate(corner.coordinate) else {
                    ErrorLogger.shared.logWarning(
                        "Invalid corner coordinate: \(corner.coordinate)",
                        component: "WorkoutStorage",
                        operation: "validateWorkoutData"
                    )
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Validate JSON data for safe decoding
    func validateWorkoutJSON(_ data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let _ = try decoder.decode(WorkoutSessionDTO.self, from: data)
            return true
        } catch {
            ErrorLogger.shared.logWarning(
                "JSON validation failed: \(error.localizedDescription)",
                component: "WorkoutStorage",
                operation: "validateWorkoutJSON"
            )
            return false
        }
    }
    
    /// Safe decoding with fallback to default values
    func safeDecodeWorkout(from data: Data) -> WorkoutSession? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let dto = try decoder.decode(WorkoutSessionDTO.self, from: data)
            
            let workout = WorkoutSession(
                id: dto.id,
                date: dto.date,
                duration: max(0, dto.duration), // Ensure non-negative
                totalDistance: max(0, dto.totalDistance), // Ensure non-negative
                heartRateData: dto.heartRateData.filter { $0.value > 0 && $0.value < 300 },
                locationData: dto.locationData.filter { isValidCoordinate($0.coordinate) }
            )
            
            return validateWorkoutData(workout) ? workout : nil
            
        } catch {
            ErrorLogger.shared.logError(
                PivotPlayError.corruptData(error.localizedDescription),
                context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "safeDecodeWorkout",
                    additionalInfo: ["error": error.localizedDescription]
                )
            )
            return createFallbackWorkout(from: data)
        }
    }
    
    // MARK: - Utility Methods
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180 &&
               coordinate.latitude != 0 && coordinate.longitude != 0
    }
    
    private func createFallbackWorkout(from data: Data) -> WorkoutSession? {
        // Attempt to create a minimal workout with safe defaults
        // This is a last resort for severely corrupted data
        let fallbackId = UUID()
        let fallbackDate = Date()
        
        ErrorLogger.shared.logInfo(
            "Creating fallback workout with minimal data",
            component: "WorkoutStorage",
            operation: "createFallbackWorkout"
        )
        
        return WorkoutSession(
            id: fallbackId,
            date: fallbackDate,
            duration: 0,
            totalDistance: 0,
            heartRateData: [],
            locationData: []
        )
    }
    
    // MARK: - Storage Health and Recovery
    
    /// Check if storage is healthy and attempt recovery if needed
    func checkStorageHealth() -> Bool {
        if !isHealthy && !isFallbackMode {
            // Attempt to reinitialize storage
            attemptStorageRecovery()
        }
        return isHealthy || isFallbackMode
    }
    
    private func attemptStorageRecovery() {
        ErrorLogger.shared.logInfo(
            "Attempting storage recovery",
            component: "WorkoutStorage",
            operation: "attemptStorageRecovery"
        )
        
        do {
            let fullSchema = Schema([WorkoutSession.self])
            let container = try ModelContainer(for: fullSchema, configurations: [])
            let context = ModelContext(container)
            
            // Test the container
            _ = try context.fetch(FetchDescriptor<WorkoutSession>())
            
            // Recovery successful
            isHealthy = true
            isFallbackMode = false
            
            ErrorLogger.shared.logInfo(
                "Storage recovery successful",
                component: "WorkoutStorage",
                operation: "attemptStorageRecovery"
            )
            
        } catch {
            ErrorLogger.shared.logError(
                PivotPlayError.storageInitializationFailed(error.localizedDescription),
                context: ErrorContext(
                    component: "WorkoutStorage",
                    operation: "attemptStorageRecovery",
                    additionalInfo: ["error": error.localizedDescription]
                )
            )
        }
    }
    
    // MARK: - Legacy Compatibility Methods
    
    /// Legacy method for backward compatibility - returns empty array on error
    @available(*, deprecated, message: "Use fetchWorkouts() -> Result<[WorkoutSession], PivotPlayError> instead")
    func fetchWorkoutsLegacy() -> [WorkoutSession] {
        switch fetchWorkouts() {
        case .success(let workouts):
            return workouts
        case .failure:
            return []
        }
    }
    
    /// Legacy method for backward compatibility - silently fails on error
    @available(*, deprecated, message: "Use saveWorkout(_:) -> Result<Void, PivotPlayError> instead")
    func saveWorkoutLegacy(_ workout: WorkoutSession) {
        _ = saveWorkout(workout)
    }
}
#endif
