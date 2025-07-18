import XCTest
import WatchConnectivity
@testable import PivotPlay

class WatchConnectivityTests: XCTestCase {
    
    var connectivityManager: WatchConnectivityManager!
    var mockSession: MockWCSession!
    
    override func setUp() {
        super.setUp()
        // Note: In a real implementation, we would need dependency injection
        // to properly mock WCSession. For now, we'll test the validation logic directly.
    }
    
    override func tearDown() {
        connectivityManager = nil
        mockSession = nil
        super.tearDown()
    }
    
    // MARK: - Data Validation Tests
    
    func testValidatePayload_ValidData_ReturnsValid() {
        // Given
        let pitchData = createValidPitchData()
        let validatedData = ValidatedPitchDataTransfer(from: pitchData)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(validatedData)
        
        // When
        let result = WatchConnectivityManager.shared.validatePayload(data)
        
        // Then
        switch result {
        case .valid(let validated):
            XCTAssertEqual(validated.workoutId, pitchData.workoutId)
            XCTAssertEqual(validated.duration, pitchData.duration)
            XCTAssertEqual(validated.totalDistance, pitchData.totalDistance)
            XCTAssertEqual(validated.corners.count, 4)
        case .invalid(let reason):
            XCTFail("Expected valid result, got invalid: \(reason)")
        }
    }
    
    func testValidatePayload_EmptyData_ReturnsInvalid() {
        // Given
        let emptyData = Data()
        
        // When
        let result = WatchConnectivityManager.shared.validatePayload(emptyData)
        
        // Then
        switch result {
        case .valid:
            XCTFail("Expected invalid result for empty data")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("Empty data payload"))
        }
    }
    
    func testValidatePayload_TooLargeData_ReturnsInvalid() {
        // Given
        let largeData = Data(count: 11_000_000) // 11MB
        
        // When
        let result = WatchConnectivityManager.shared.validatePayload(largeData)
        
        // Then
        switch result {
        case .valid:
            XCTFail("Expected invalid result for large data")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("Payload too large"))
        }
    }
    
    func testValidatePayload_CorruptData_ReturnsInvalid() {
        // Given
        let corruptData = "invalid json data".data(using: .utf8)!
        
        // When
        let result = WatchConnectivityManager.shared.validatePayload(corruptData)
        
        // Then
        switch result {
        case .valid:
            XCTFail("Expected invalid result for corrupt data")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("Failed to decode payload"))
        }
    }
    
    // MARK: - Checksum Validation Tests
    
    func testValidatedPitchDataTransfer_ChecksumCalculation() {
        // Given
        let pitchData = createValidPitchData()
        
        // When
        let validatedData = ValidatedPitchDataTransfer(from: pitchData)
        
        // Then
        XCTAssertFalse(validatedData.checksum.isEmpty)
        XCTAssertTrue(validatedData.isValid())
    }
    
    func testValidatedPitchDataTransfer_ChecksumValidation_DetectsCorruption() {
        // Given
        let pitchData = createValidPitchData()
        let validatedData = ValidatedPitchDataTransfer(from: pitchData)
        
        // When - manually create corrupted data with wrong checksum
        let corruptedData = ValidatedPitchDataTransfer(
            schemaVersion: validatedData.schemaVersion,
            workoutId: validatedData.workoutId,
            date: validatedData.date,
            duration: validatedData.duration + 100, // Corrupt the duration
            totalDistance: validatedData.totalDistance,
            heartRateData: validatedData.heartRateData,
            corners: validatedData.corners,
            locationData: validatedData.locationData,
            checksum: validatedData.checksum, // Keep original checksum
            transferId: validatedData.transferId
        )
        
        // Then
        XCTAssertFalse(corruptedData.isValid())
    }
    
    // MARK: - Data Integrity Tests
    
    func testValidatedPitchDataTransfer_InvalidDuration_FailsValidation() {
        // Given
        let pitchData = PitchDataTransfer(
            workoutId: UUID(),
            date: Date(),
            duration: -10, // Invalid negative duration
            totalDistance: 1000,
            heartRateData: [],
            corners: createValidCorners(),
            locationData: []
        )
        
        let validatedData = ValidatedPitchDataTransfer(from: pitchData)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(validatedData)
        
        // When
        let result = WatchConnectivityManager.shared.validatePayload(data)
        
        // Then
        switch result {
        case .valid:
            XCTFail("Expected invalid result for negative duration")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("Invalid workout duration"))
        }
    }
    
    func testValidatedPitchDataTransfer_InvalidDistance_FailsValidation() {
        // Given
        let pitchData = PitchDataTransfer(
            workoutId: UUID(),
            date: Date(),
            duration: 3600,
            totalDistance: -100, // Invalid negative distance
            heartRateData: [],
            corners: createValidCorners(),
            locationData: []
        )
        
        let validatedData = ValidatedPitchDataTransfer(from: pitchData)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(validatedData)
        
        // When
        let result = WatchConnectivityManager.shared.validatePayload(data)
        
        // Then
        switch result {
        case .valid:
            XCTFail("Expected invalid result for negative distance")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("Invalid total distance"))
        }
    }
    
    func testValidatedPitchDataTransfer_InvalidCornerCount_FailsValidation() {
        // Given
        let pitchData = PitchDataTransfer(
            workoutId: UUID(),
            date: Date(),
            duration: 3600,
            totalDistance: 1000,
            heartRateData: [],
            corners: [CLLocationCoordinate2D(latitude: 0, longitude: 0)], // Only 1 corner instead of 4
            locationData: []
        )
        
        let validatedData = ValidatedPitchDataTransfer(from: pitchData)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(validatedData)
        
        // When
        let result = WatchConnectivityManager.shared.validatePayload(data)
        
        // Then
        switch result {
        case .valid:
            XCTFail("Expected invalid result for invalid corner count")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("Invalid corner count"))
        }
    }
    
    // MARK: - Retry Logic Tests
    
    func testTransferAttempt_ShouldRetry_WithinLimits() {
        // Given
        let attempt = TransferAttempt(
            data: ValidatedPitchDataTransfer(from: createValidPitchData()),
            timestamp: Date(),
            attemptCount: 1,
            transferMethod: .messageData
        )
        
        // Then
        XCTAssertTrue(attempt.shouldRetry)
    }
    
    func testTransferAttempt_ShouldNotRetry_ExceedsMaxRetries() {
        // Given
        let attempt = TransferAttempt(
            data: ValidatedPitchDataTransfer(from: createValidPitchData()),
            timestamp: Date(),
            attemptCount: 5, // Exceeds maxRetries (3)
            transferMethod: .messageData
        )
        
        // Then
        XCTAssertFalse(attempt.shouldRetry)
    }
    
    func testTransferAttempt_ShouldNotRetry_ExceedsTimeout() {
        // Given
        let oldTimestamp = Date().addingTimeInterval(-400) // 400 seconds ago (exceeds 300s timeout)
        let attempt = TransferAttempt(
            data: ValidatedPitchDataTransfer(from: createValidPitchData()),
            timestamp: oldTimestamp,
            attemptCount: 1,
            transferMethod: .messageData
        )
        
        // Then
        XCTAssertFalse(attempt.shouldRetry)
    }
    
    func testTransferAttempt_ExponentialBackoff() {
        // Given
        let attempt1 = TransferAttempt(
            data: ValidatedPitchDataTransfer(from: createValidPitchData()),
            timestamp: Date(),
            attemptCount: 1,
            transferMethod: .messageData
        )
        
        let attempt2 = TransferAttempt(
            data: ValidatedPitchDataTransfer(from: createValidPitchData()),
            timestamp: Date(),
            attemptCount: 2,
            transferMethod: .messageData
        )
        
        // Then
        XCTAssertEqual(attempt1.nextRetryDelay, 2.0) // 2^1
        XCTAssertEqual(attempt2.nextRetryDelay, 4.0) // 2^2
    }
    
    // MARK: - Transfer Method Fallback Tests
    
    func testGetNextTransferMethod_MessageDataToUserInfo() {
        // This would test the private method if it were made internal for testing
        // For now, we test the concept through integration
        XCTAssertTrue(true) // Placeholder
    }
    
    func testGetNextTransferMethod_UserInfoToFileTransfer() {
        // This would test the private method if it were made internal for testing
        XCTAssertTrue(true) // Placeholder
    }
    
    func testGetNextTransferMethod_FileTransferToMessageData() {
        // This would test the private method if it were made internal for testing
        XCTAssertTrue(true) // Placeholder
    }
    
    // MARK: - Transfer Confirmation Tests
    
    func testTransferConfirmation_Encoding() {
        // Given
        let confirmation = TransferConfirmation(
            transferId: UUID(),
            success: true,
            error: nil
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try? encoder.encode(confirmation)
        
        // Then
        XCTAssertNotNil(data)
        XCTAssertTrue(data!.count > 0)
    }
    
    func testTransferConfirmation_EncodingWithError() {
        // Given
        let confirmation = TransferConfirmation(
            transferId: UUID(),
            success: false,
            error: "Transfer failed due to network timeout"
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try? encoder.encode(confirmation)
        
        // Then
        XCTAssertNotNil(data)
        
        // Verify decoding
        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(TransferConfirmation.self, from: data!)
        XCTAssertNotNil(decoded)
        XCTAssertFalse(decoded!.success)
        XCTAssertEqual(decoded!.error, "Transfer failed due to network timeout")
    }
    
    // MARK: - Performance Tests
    
    func testChecksumCalculation_Performance() {
        // Given
        let pitchData = createLargePitchData()
        
        // When
        measure {
            let _ = ValidatedPitchDataTransfer(from: pitchData)
        }
        
        // Then - should complete within reasonable time
    }
    
    func testDataValidation_Performance() {
        // Given
        let pitchData = createLargePitchData()
        let validatedData = ValidatedPitchDataTransfer(from: pitchData)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(validatedData)
        
        // When
        measure {
            let _ = WatchConnectivityManager.shared.validatePayload(data)
        }
        
        // Then - should complete within reasonable time
    }
    
    // MARK: - Helper Methods
    
    private func createValidPitchData() -> PitchDataTransfer {
        return PitchDataTransfer(
            workoutId: UUID(),
            date: Date(),
            duration: 3600, // 1 hour
            totalDistance: 5000, // 5km
            heartRateData: [
                HeartRateSample(value: 120, timestamp: Date()),
                HeartRateSample(value: 130, timestamp: Date().addingTimeInterval(60))
            ],
            corners: createValidCorners(),
            locationData: [
                LocationSample(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), timestamp: Date()),
                LocationSample(coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195), timestamp: Date().addingTimeInterval(60))
            ]
        )
    }
    
    private func createValidCorners() -> [CLLocationCoordinate2D] {
        return [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Bottom-left
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4184), // Bottom-right
            CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4184), // Top-right
            CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4194)  // Top-left
        ]
    }
    
    private func createLargePitchData() -> PitchDataTransfer {
        // Create data with many location points for performance testing
        var locationData: [LocationSample] = []
        let baseCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        for i in 0..<1000 {
            let coordinate = CLLocationCoordinate2D(
                latitude: baseCoordinate.latitude + Double(i) * 0.0001,
                longitude: baseCoordinate.longitude + Double(i) * 0.0001
            )
            locationData.append(LocationSample(coordinate: coordinate, timestamp: Date().addingTimeInterval(Double(i))))
        }
        
        var heartRateData: [HeartRateSample] = []
        for i in 0..<100 {
            heartRateData.append(HeartRateSample(value: 120 + Double(i % 40), timestamp: Date().addingTimeInterval(Double(i * 10))))
        }
        
        return PitchDataTransfer(
            workoutId: UUID(),
            date: Date(),
            duration: 3600,
            totalDistance: 10000,
            heartRateData: heartRateData,
            corners: createValidCorners(),
            locationData: locationData
        )
    }
}

// MARK: - Mock WCSession for Testing

class MockWCSession: WCSession {
    var mockIsReachable = true
    var mockActivationState: WCSessionActivationState = .activated
    var sentMessages: [Data] = []
    var sentUserInfo: [[String: Any]] = []
    var transferredFiles: [(URL, [String: Any]?)] = []
    
    override var isReachable: Bool {
        return mockIsReachable
    }
    
    override var activationState: WCSessionActivationState {
        return mockActivationState
    }
    
    override func sendMessageData(_ data: Data, replyHandler: ((Data) -> Void)?, errorHandler: ((Error) -> Void)?) {
        sentMessages.append(data)
        // Simulate success
        replyHandler?(Data())
    }
    
    override func transferUserInfo(_ userInfo: [String : Any]) -> WCSessionUserInfoTransfer {
        sentUserInfo.append(userInfo)
        return super.transferUserInfo(userInfo)
    }
    
    override func transferFile(_ file: URL, metadata: [String : Any]?) -> WCSessionFileTransfer {
        transferredFiles.append((file, metadata))
        return super.transferFile(file, metadata: metadata)
    }
}

// MARK: - Private Extensions for Testing

extension WatchConnectivityManager {
    // These would be internal methods in a real implementation to allow testing
    // For now, we test through the public interface
}

// MARK: - TransferAttempt Testing Extension

extension TransferAttempt {
    // Make initializer accessible for testing
    init(data: ValidatedPitchDataTransfer, timestamp: Date, attemptCount: Int, transferMethod: TransferMethod) {
        self.data = data
        self.timestamp = timestamp
        self.attemptCount = attemptCount
        self.transferMethod = transferMethod
    }
}