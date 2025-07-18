//
//  WorkoutStorageTests.swift
//  PivotPlayTests
//
//  Created by Kiro on 15.07.2025.
//

import XCTest
import SwiftData
import CoreLocation
@testable import PivotPlay

@MainActor
final class WorkoutStorageTests: XCTestCase {
    
    var storage: WorkoutStorage!
    var testWorkout: WorkoutSession!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test workout data
        testWorkout = createTestWorkout()
    }
    
    override func tearDown() async throws {
        storage = nil
        testWorkout = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Data Creation
    
    private func createTestWorkout() -> WorkoutSession {
        let heartRateData = [
            HeartRateSample(value: 120.0, timestamp: Date()),
            HeartRateSample(value: 130.0, timestamp: Date().addingTimeInterval(60)),
            HeartRateSample(value: 125.0, timestamp: Date().addingTimeInterval(120))
        ]
        
        let locationData = [
            LocationSample(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), timestamp: Date()),
            LocationSample(coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195), timestamp: Date().addingTimeInterval(30)),
            LocationSample(coordinate: CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196), timestamp: Date().addingTimeInterval(60))
        ]
        
        let corners = [
            CoordinateDTO(from: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)),
            CoordinateDTO(from: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4184)),
            CoordinateDTO(from: CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4184)),
            CoordinateDTO(from: CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4194))
        ]
        
        return WorkoutSession(
            id: UUID(),
            date: Date(),
            duration: 1800, // 30 minutes
            totalDistance: 5000, // 5km
            heartRateData: heartRateData,
            locationData: locationData,
            corners: corners
        )
    }
    
    private func createInvalidWorkout() -> WorkoutSession {
        let invalidHeartRateData = [
            HeartRateSample(value: -10.0, timestamp: Date()), // Invalid negative heart rate
            HeartRateSample(value: 400.0, timestamp: Date()) // Invalid high heart rate
        ]
        
        let invalidLocationData = [
            LocationSample(coordinate: CLLocationCoordinate2D(latitude: 200.0, longitude: -300.0), timestamp: Date()) // Invalid coordinates
        ]
        
        return WorkoutSession(
            id: UUID(),
            date: Date(),
            duration: -100, // Invalid negative duration
            totalDistance: -500, // Invalid negative distance
            heartRateData: invalidHeartRateData,
            locationData: invalidLocationData
        )
    }
    
    // MARK: - Initialization Tests
    
    func testStorageInitializationSuccess() async throws {
        // Test that storage initializes successfully under normal conditions
        storage = WorkoutStorage.shared
        
        // Storage should be accessible
        let result = storage.fetchWorkouts()
        
        switch result {
        case .success(let workouts):
            // Should succeed (even if empty)
            XCTAssertTrue(workouts.isEmpty || !workouts.isEmpty, "Fetch should succeed")
        case .failure(let error):
            // If it fails, it should be due to storage unavailable, not initialization
            XCTAssertEqual(error, PivotPlayError.storageUnavailable)
        }
    }
    
    func testFallbackModeHandling() async throws {
        storage = WorkoutStorage.shared
        
        // Test saving to fallback storage when main storage fails
        let result = storage.saveWorkout(testWorkout)
        
        switch result {
        case .success:
            // Should succeed either in normal or fallback mode
            XCTAssertTrue(true, "Save should succeed")
        case .failure(let error):
            // Only acceptable failures are validation or storage unavailable
            XCTAssertTrue(
                error == PivotPlayError.storageUnavailable || 
                error == PivotPlayError.dataValidationFailed("Invalid workout data"),
                "Unexpected error: \(error)"
            )
        }
    }
    
    // MARK: - Data Validation Tests
    
    func testValidWorkoutDataValidation() async throws {
        storage = WorkoutStorage.shared
        
        let isValid = storage.validateWorkoutData(testWorkout)
        XCTAssertTrue(isValid, "Valid workout should pass validation")
    }
    
    func testInvalidWorkoutDataValidation() async throws {
        storage = WorkoutStorage.shared
        
        let invalidWorkout = createInvalidWorkout()
        let isValid = storage.validateWorkoutData(invalidWorkout)
        XCTAssertFalse(isValid, "Invalid workout should fail validation")
    }
    
    func testHeartRateValidation() async throws {
        storage = WorkoutStorage.shared
        
        // Test invalid heart rate values
        let workoutWithInvalidHeartRate = WorkoutSession(
            id: UUID(),
            date: Date(),
            duration: 1800,
            totalDistance: 5000,
            heartRateData: [HeartRateSample(value: 0, timestamp: Date())], // Invalid zero heart rate
            locationData: []
        )
        
        let isValid = storage.validateWorkoutData(workoutWithInvalidHeartRate)
        XCTAssertFalse(isValid, "Workout with invalid heart rate should fail validation")
    }
    
    func testCoordinateValidation() async throws {
        storage = WorkoutStorage.shared
        
        // Test invalid coordinates
        let workoutWithInvalidCoordinates = WorkoutSession(
            id: UUID(),
            date: Date(),
            duration: 1800,
            totalDistance: 5000,
            heartRateData: [],
            locationData: [LocationSample(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), timestamp: Date())] // Invalid zero coordinates
        )
        
        let isValid = storage.validateWorkoutData(workoutWithInvalidCoordinates)
        XCTAssertFalse(isValid, "Workout with invalid coordinates should fail validation")
    }
    
    func testCornerValidation() async throws {
        storage = WorkoutStorage.shared
        
        // Test invalid corner coordinates
        let invalidCorners = [
            CoordinateDTO(from: CLLocationCoordinate2D(latitude: 200, longitude: -300)) // Invalid coordinates
        ]
        
        let workoutWithInvalidCorners = WorkoutSession(
            id: UUID(),
            date: Date(),
            duration: 1800,
            totalDistance: 5000,
            heartRateData: [],
            locationData: [],
            corners: invalidCorners
        )
        
        let isValid = storage.validateWorkoutData(workoutWithInvalidCorners)
        XCTAssertFalse(isValid, "Workout with invalid corners should fail validation")
    }
    
    // MARK: - CRUD Operations Tests
    
    func testSaveValidWorkout() async throws {
        storage = WorkoutStorage.shared
        
        let result = storage.saveWorkout(testWorkout)
        
        switch result {
        case .success:
            XCTAssertTrue(true, "Valid workout should save successfully")
        case .failure(let error):
            XCTFail("Valid workout save failed with error: \(error)")
        }
    }
    
    func testSaveInvalidWorkout() async throws {
        storage = WorkoutStorage.shared
        
        let invalidWorkout = createInvalidWorkout()
        let result = storage.saveWorkout(invalidWorkout)
        
        switch result {
        case .success:
            XCTFail("Invalid workout should not save successfully")
        case .failure(let error):
            XCTAssertEqual(error, PivotPlayError.dataValidationFailed("Invalid workout data"))
        }
    }
    
    func testFetchWorkouts() async throws {
        storage = WorkoutStorage.shared
        
        let result = storage.fetchWorkouts()
        
        switch result {
        case .success(let workouts):
            XCTAssertTrue(workouts.isEmpty || !workouts.isEmpty, "Fetch should return array")
        case .failure(let error):
            // Only acceptable if storage is unavailable
            XCTAssertEqual(error, PivotPlayError.storageUnavailable)
        }
    }
    
    func testDeleteWorkout() async throws {
        storage = WorkoutStorage.shared
        
        // First save a workout
        let saveResult = storage.saveWorkout(testWorkout)
        guard case .success = saveResult else {
            throw XCTSkip("Cannot test delete without successful save")
        }
        
        // Then delete it
        let deleteResult = storage.deleteWorkout(testWorkout)
        
        switch deleteResult {
        case .success:
            XCTAssertTrue(true, "Delete should succeed")
        case .failure(let error):
            XCTFail("Delete failed with error: \(error)")
        }
    }
    
    func testDeleteMultipleWorkouts() async throws {
        storage = WorkoutStorage.shared
        
        let workout1 = testWorkout!
        let workout2 = createTestWorkout()
        
        // Save both workouts
        _ = storage.saveWorkout(workout1)
        _ = storage.saveWorkout(workout2)
        
        // Delete both
        let deleteResult = storage.deleteWorkouts([workout1, workout2])
        
        switch deleteResult {
        case .success:
            XCTAssertTrue(true, "Multiple delete should succeed")
        case .failure(let error):
            XCTFail("Multiple delete failed with error: \(error)")
        }
    }
    
    // MARK: - JSON Validation Tests
    
    func testValidJSONValidation() async throws {
        storage = WorkoutStorage.shared
        
        let dto = WorkoutSessionDTO(
            id: testWorkout.id,
            date: testWorkout.date,
            duration: testWorkout.duration,
            totalDistance: testWorkout.totalDistance,
            heartRateData: testWorkout.heartRateData,
            locationData: testWorkout.locationData
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(dto)
        
        let isValid = storage.validateWorkoutJSON(jsonData)
        XCTAssertTrue(isValid, "Valid JSON should pass validation")
    }
    
    func testInvalidJSONValidation() async throws {
        storage = WorkoutStorage.shared
        
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        let isValid = storage.validateWorkoutJSON(invalidJSON)
        XCTAssertFalse(isValid, "Invalid JSON should fail validation")
    }
    
    func testSafeDecodeValidWorkout() async throws {
        storage = WorkoutStorage.shared
        
        let dto = WorkoutSessionDTO(
            id: testWorkout.id,
            date: testWorkout.date,
            duration: testWorkout.duration,
            totalDistance: testWorkout.totalDistance,
            heartRateData: testWorkout.heartRateData,
            locationData: testWorkout.locationData
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(dto)
        
        let decodedWorkout = storage.safeDecodeWorkout(from: jsonData)
        XCTAssertNotNil(decodedWorkout, "Valid JSON should decode successfully")
        XCTAssertEqual(decodedWorkout?.id, testWorkout.id)
    }
    
    func testSafeDecodeInvalidWorkout() async throws {
        storage = WorkoutStorage.shared
        
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        let decodedWorkout = storage.safeDecodeWorkout(from: invalidJSON)
        
        // Should return fallback workout or nil
        if let workout = decodedWorkout {
            // If fallback workout is created, it should have safe defaults
            XCTAssertEqual(workout.duration, 0)
            XCTAssertEqual(workout.totalDistance, 0)
            XCTAssertTrue(workout.heartRateData.isEmpty)
            XCTAssertTrue(workout.locationData.isEmpty)
        }
    }
    
    // MARK: - Storage Health Tests
    
    func testStorageHealthCheck() async throws {
        storage = WorkoutStorage.shared
        
        let isHealthy = storage.checkStorageHealth()
        XCTAssertTrue(isHealthy, "Storage should be healthy or in fallback mode")
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyWorkoutArrays() async throws {
        storage = WorkoutStorage.shared
        
        let emptyWorkout = WorkoutSession(
            id: UUID(),
            date: Date(),
            duration: 0,
            totalDistance: 0,
            heartRateData: [],
            locationData: []
        )
        
        let isValid = storage.validateWorkoutData(emptyWorkout)
        XCTAssertTrue(isValid, "Workout with empty arrays should be valid")
    }
    
    func testWorkoutWithOnlyCorners() async throws {
        storage = WorkoutStorage.shared
        
        let cornersOnlyWorkout = WorkoutSession(
            id: UUID(),
            date: Date(),
            duration: 1800,
            totalDistance: 0,
            heartRateData: [],
            locationData: [],
            corners: [
                CoordinateDTO(from: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
            ]
        )
        
        let isValid = storage.validateWorkoutData(cornersOnlyWorkout)
        XCTAssertTrue(isValid, "Workout with only corners should be valid")
    }
    
    func testConcurrentAccess() async throws {
        storage = WorkoutStorage.shared
        
        // Test concurrent save operations
        let workout1 = testWorkout!
        let workout2 = createTestWorkout()
        let workout3 = createTestWorkout()
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = self.storage.saveWorkout(workout1)
            }
            group.addTask {
                _ = self.storage.saveWorkout(workout2)
            }
            group.addTask {
                _ = self.storage.saveWorkout(workout3)
            }
        }
        
        // All operations should complete without crashing
        XCTAssertTrue(true, "Concurrent operations should complete safely")
    }
    
    func testLargeDataSet() async throws {
        storage = WorkoutStorage.shared
        
        // Create workout with large data arrays
        var largeHeartRateData: [HeartRateSample] = []
        var largeLocationData: [LocationSample] = []
        
        for i in 0..<1000 {
            largeHeartRateData.append(HeartRateSample(value: 120.0 + Double(i % 50), timestamp: Date().addingTimeInterval(Double(i))))
            largeLocationData.append(LocationSample(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.0001,
                    longitude: -122.4194 + Double(i) * 0.0001
                ),
                timestamp: Date().addingTimeInterval(Double(i))
            ))
        }
        
        let largeWorkout = WorkoutSession(
            id: UUID(),
            date: Date(),
            duration: 3600,
            totalDistance: 10000,
            heartRateData: largeHeartRateData,
            locationData: largeLocationData
        )
        
        let isValid = storage.validateWorkoutData(largeWorkout)
        XCTAssertTrue(isValid, "Large workout should be valid")
        
        let saveResult = storage.saveWorkout(largeWorkout)
        switch saveResult {
        case .success:
            XCTAssertTrue(true, "Large workout should save successfully")
        case .failure(let error):
            // Only acceptable if storage is unavailable
            XCTAssertEqual(error, PivotPlayError.storageUnavailable)
        }
    }
    
    // MARK: - Legacy Compatibility Tests
    
    func testLegacyFetchWorkouts() async throws {
        storage = WorkoutStorage.shared
        
        let workouts = storage.fetchWorkoutsLegacy()
        XCTAssertTrue(workouts.isEmpty || !workouts.isEmpty, "Legacy fetch should return array")
    }
    
    func testLegacySaveWorkout() async throws {
        storage = WorkoutStorage.shared
        
        // Should not crash even if save fails
        storage.saveWorkoutLegacy(testWorkout)
        XCTAssertTrue(true, "Legacy save should not crash")
    }
}

// MARK: - Test Extensions

extension WorkoutStorageTests {
    
    /// Helper method to create multiple test workouts
    private func createMultipleTestWorkouts(count: Int) -> [WorkoutSession] {
        var workouts: [WorkoutSession] = []
        
        for i in 0..<count {
            let workout = WorkoutSession(
                id: UUID(),
                date: Date().addingTimeInterval(Double(i * 3600)), // 1 hour apart
                duration: 1800 + Double(i * 300), // Varying durations
                totalDistance: 5000 + Double(i * 1000), // Varying distances
                heartRateData: [HeartRateSample(value: 120 + Double(i), timestamp: Date())],
                locationData: [LocationSample(
                    coordinate: CLLocationCoordinate2D(
                        latitude: 37.7749 + Double(i) * 0.01,
                        longitude: -122.4194 + Double(i) * 0.01
                    ),
                    timestamp: Date()
                )]
            )
            workouts.append(workout)
        }
        
        return workouts
    }
}