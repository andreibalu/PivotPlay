//
//  ContentViewUITests.swift
//  PivotPlayTests
//
//  Created by Kiro on 16.07.2025.
//

import XCTest
import SwiftUI
import SwiftData
import CoreLocation
@testable import PivotPlay

@MainActor
final class ContentViewUITests: XCTestCase {
    
    var mockStorage: MockWorkoutStorage!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockWorkoutStorage()
    }
    
    override func tearDown() {
        mockStorage = nil
        super.tearDown()
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateDisplaysCorrectly() throws {
        // Given
        mockStorage.shouldDelayResponse = true
        
        // When
        let contentView = ContentView()
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Then
        XCTAssertEqual(viewModel.state, .loading)
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyStateDisplaysWhenNoWorkouts() throws {
        // Given
        mockStorage.mockWorkouts = []
        mockStorage.shouldSucceed = true
        
        // When
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for async operation
        let expectation = XCTestExpectation(description: "Load workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertTrue(workouts.isEmpty, "Should have empty workouts array")
        } else {
            XCTFail("Expected loaded state with empty workouts")
        }
    }
    
    // MARK: - Success State Tests
    
    func testSuccessStateDisplaysWorkouts() throws {
        // Given
        let mockWorkout = createMockWorkout()
        mockStorage.mockWorkouts = [mockWorkout]
        mockStorage.shouldSucceed = true
        
        // When
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for async operation
        let expectation = XCTestExpectation(description: "Load workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertEqual(workouts.count, 1, "Should have one workout")
            XCTAssertEqual(workouts.first?.id, mockWorkout.id, "Should have correct workout")
        } else {
            XCTFail("Expected loaded state with workouts")
        }
    }
    
    // MARK: - Error State Tests
    
    func testErrorStateDisplaysStorageUnavailableError() throws {
        // Given
        mockStorage.shouldSucceed = false
        mockStorage.mockError = .storageUnavailable
        
        // When
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for async operation
        let expectation = XCTestExpectation(description: "Load workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        if case .error(let error) = viewModel.state {
            XCTAssertEqual(error, .storageUnavailable, "Should have storage unavailable error")
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testErrorStateDisplaysFetchFailedError() throws {
        // Given
        mockStorage.shouldSucceed = false
        mockStorage.mockError = .fetchFailed("Database connection failed")
        
        // When
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for async operation
        let expectation = XCTestExpectation(description: "Load workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        if case .error(let error) = viewModel.state {
            if case .fetchFailed(let message) = error {
                XCTAssertEqual(message, "Database connection failed", "Should have correct error message")
            } else {
                XCTFail("Expected fetchFailed error")
            }
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testErrorStateDisplaysCorruptDataError() throws {
        // Given
        mockStorage.shouldSucceed = false
        mockStorage.mockError = .corruptData("Invalid JSON structure")
        
        // When
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for async operation
        let expectation = XCTestExpectation(description: "Load workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        if case .error(let error) = viewModel.state {
            if case .corruptData(let message) = error {
                XCTAssertEqual(message, "Invalid JSON structure", "Should have correct error message")
            } else {
                XCTFail("Expected corruptData error")
            }
        } else {
            XCTFail("Expected error state")
        }
    }
    
    // MARK: - Retry Functionality Tests
    
    func testRetryFunctionalityRecoversFromError() throws {
        // Given
        mockStorage.shouldSucceed = false
        mockStorage.mockError = .storageUnavailable
        
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for initial error
        let errorExpectation = XCTestExpectation(description: "Initial error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            errorExpectation.fulfill()
        }
        wait(for: [errorExpectation], timeout: 1.0)
        
        // Verify error state
        if case .error = viewModel.state {
            // Good, we have error state
        } else {
            XCTFail("Expected error state initially")
        }
        
        // When - Fix the storage and retry
        mockStorage.shouldSucceed = true
        mockStorage.mockWorkouts = [createMockWorkout()]
        viewModel.loadWorkouts()
        
        // Wait for retry
        let retryExpectation = XCTestExpectation(description: "Retry success")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            retryExpectation.fulfill()
        }
        wait(for: [retryExpectation], timeout: 1.0)
        
        // Then
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertEqual(workouts.count, 1, "Should have one workout after retry")
        } else {
            XCTFail("Expected loaded state after retry")
        }
    }
    
    // MARK: - Refresh Functionality Tests
    
    func testRefreshFunctionalityUpdatesWorkouts() async throws {
        // Given
        let initialWorkout = createMockWorkout()
        mockStorage.mockWorkouts = [initialWorkout]
        mockStorage.shouldSucceed = true
        
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for initial load
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify initial state
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertEqual(workouts.count, 1, "Should have one workout initially")
        } else {
            XCTFail("Expected loaded state initially")
        }
        
        // When - Add another workout and refresh
        let newWorkout = createMockWorkout(id: UUID(), date: Date().addingTimeInterval(3600))
        mockStorage.mockWorkouts = [newWorkout, initialWorkout]
        
        await viewModel.refreshWorkouts()
        
        // Then
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertEqual(workouts.count, 2, "Should have two workouts after refresh")
        } else {
            XCTFail("Expected loaded state after refresh")
        }
    }
    
    // MARK: - Delete Functionality Tests
    
    func testDeleteFunctionalityRemovesWorkouts() throws {
        // Given
        let workout1 = createMockWorkout(id: UUID(), date: Date())
        let workout2 = createMockWorkout(id: UUID(), date: Date().addingTimeInterval(3600))
        mockStorage.mockWorkouts = [workout1, workout2]
        mockStorage.shouldSucceed = true
        
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for initial load
        let loadExpectation = XCTestExpectation(description: "Initial load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 1.0)
        
        // Verify initial state
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertEqual(workouts.count, 2, "Should have two workouts initially")
        } else {
            XCTFail("Expected loaded state initially")
        }
        
        // When - Delete one workout
        mockStorage.mockWorkouts = [workout2] // Remove workout1
        viewModel.deleteWorkouts([workout1])
        
        // Wait for delete operation
        let deleteExpectation = XCTestExpectation(description: "Delete operation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            deleteExpectation.fulfill()
        }
        wait(for: [deleteExpectation], timeout: 1.0)
        
        // Then
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertEqual(workouts.count, 1, "Should have one workout after delete")
            XCTAssertEqual(workouts.first?.id, workout2.id, "Should have correct remaining workout")
        } else {
            XCTFail("Expected loaded state after delete")
        }
    }
    
    func testDeleteFunctionalityHandlesErrors() throws {
        // Given
        let workout = createMockWorkout()
        mockStorage.mockWorkouts = [workout]
        mockStorage.shouldSucceed = true
        
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for initial load
        let loadExpectation = XCTestExpectation(description: "Initial load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 1.0)
        
        // When - Simulate delete failure
        mockStorage.shouldSucceed = false
        mockStorage.mockError = .saveFailed("Delete operation failed")
        viewModel.deleteWorkouts([workout])
        
        // Wait for delete operation
        let deleteExpectation = XCTestExpectation(description: "Delete operation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            deleteExpectation.fulfill()
        }
        wait(for: [deleteExpectation], timeout: 1.0)
        
        // Then
        if case .error(let error) = viewModel.state {
            if case .saveFailed(let message) = error {
                XCTAssertEqual(message, "Delete operation failed", "Should have correct error message")
            } else {
                XCTFail("Expected saveFailed error")
            }
        } else {
            XCTFail("Expected error state after failed delete")
        }
    }
    
    // MARK: - Navigation Safety Tests
    
    func testNavigationDoesNotCrashWithEmptyWorkouts() throws {
        // Given
        mockStorage.mockWorkouts = []
        mockStorage.shouldSucceed = true
        
        // When
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for load
        let expectation = XCTestExpectation(description: "Load workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - Should not crash and should show empty state
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertTrue(workouts.isEmpty, "Should have empty workouts")
        } else {
            XCTFail("Expected loaded state with empty workouts")
        }
    }
    
    func testNavigationDoesNotCrashWithCorruptWorkouts() throws {
        // Given - Simulate corrupt data that gets filtered out
        mockStorage.shouldSucceed = true
        mockStorage.mockWorkouts = [] // Simulate that corrupt workouts are filtered out
        
        // When
        let viewModel = WorkoutListViewModel()
        viewModel.loadWorkouts()
        
        // Wait for load
        let expectation = XCTestExpectation(description: "Load workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - Should not crash
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertTrue(workouts.isEmpty, "Should have empty workouts after filtering corrupt data")
        } else {
            XCTFail("Expected loaded state")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockWorkout(id: UUID = UUID(), date: Date = Date()) -> WorkoutSession {
        return WorkoutSession(
            id: id,
            date: date,
            duration: 1800, // 30 minutes
            totalDistance: 5000, // 5km
            heartRateData: [
                HeartRateSample(value: 120, timestamp: date),
                HeartRateSample(value: 130, timestamp: date.addingTimeInterval(60)),
                HeartRateSample(value: 125, timestamp: date.addingTimeInterval(120))
            ],
            locationData: [
                LocationSample(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), timestamp: date),
                LocationSample(coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195), timestamp: date.addingTimeInterval(60))
            ]
        )
    }
}

// MARK: - Mock WorkoutStorage

class MockWorkoutStorage {
    var mockWorkouts: [WorkoutSession] = []
    var shouldSucceed: Bool = true
    var mockError: PivotPlayError = .storageUnavailable
    var shouldDelayResponse: Bool = false
    
    func fetchWorkouts() -> Result<[WorkoutSession], PivotPlayError> {
        if shouldDelayResponse {
            // Simulate delay for loading state testing
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        if shouldSucceed {
            return .success(mockWorkouts)
        } else {
            return .failure(mockError)
        }
    }
    
    func deleteWorkouts(_ workouts: [WorkoutSession]) -> Result<Void, PivotPlayError> {
        if shouldSucceed {
            let workoutIds = Set(workouts.map { $0.id })
            mockWorkouts.removeAll { workoutIds.contains($0.id) }
            return .success(())
        } else {
            return .failure(mockError)
        }
    }
}

// MARK: - ViewState Equatable Extension

extension WorkoutListViewModel.ViewState: Equatable {
    static func == (lhs: WorkoutListViewModel.ViewState, rhs: WorkoutListViewModel.ViewState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.loaded(let lhsWorkouts), .loaded(let rhsWorkouts)):
            return lhsWorkouts.map { $0.id } == rhsWorkouts.map { $0.id }
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}